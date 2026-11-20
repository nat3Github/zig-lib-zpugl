const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
const zpugl = @import("zpugl");
const zv = zpugl.vulkan;
const vk = @import("vk_api.zig");
const log = std.log.scoped(.zpugl_vulkan);

const frames_in_flight = 2;
const max_images = 8;
const sets_per_pool = 256;
const vert_spv align(4) = @embedFile("vulkan.vert.spv").*;
const frag_spv align(4) = @embedFile("vulkan.frag.spv").*;

pub const Instance = struct {
    loader: zv.Loader,
    gipa: zv.PFN_vkGetInstanceProcAddr,
    gdpa: zv.PFN_vkGetDeviceProcAddr,
    handle: vk.VkInstance,
    i: vk.InstanceFns,

    pub fn init(world: *zpugl.World) error{BackendError}!Instance {
        var loader = zv.Loader.init(world, null) catch return error.BackendError;
        errdefer loader.deinit();
        const gipa = loader.getInstanceProcAddrFunc() orelse return error.BackendError;
        const gdpa = loader.getDeviceProcAddrFunc() orelse return error.BackendError;
        const g = try vk.load(vk.GlobalFns, @as(?vk.VkInstance, null), gipa);

        var avail: [256]vk.ExtensionProperties = undefined;
        var avail_n: u32 = avail.len;
        const er = g.vkEnumerateInstanceExtensionProperties(null, &avail_n, &avail);
        if (er != vk.success and er != vk.incomplete) try vk.ok(er, "vkEnumerateInstanceExtensionProperties");
        var exts: [4]vk.Name = undefined;
        var n: u32 = 0;
        for (zv.getInstanceExtensions()) |e| {
            if (!vk.hasName(avail[0..avail_n], std.mem.span(e))) {
                log.info("instance extension {s} missing", .{e});
                return error.BackendError;
            }
            std.debug.assert(n < exts.len);
            exts[n] = e;
            n += 1;
        }
        var flags: u32 = 0;
        if (vk.hasName(avail[0..avail_n], "VK_KHR_portability_enumeration")) {
            exts[n] = "VK_KHR_portability_enumeration";
            n += 1;
            flags |= 1;
        }
        const layers = [_]vk.Name{"VK_LAYER_KHRONOS_validation"};
        var layer_props: [64]vk.LayerProperties = undefined;
        var layer_n: u32 = layer_props.len;
        const validation = builtin.mode == .debug and g.vkEnumerateInstanceLayerProperties(&layer_n, &layer_props) == vk.success and vk.hasName(layer_props[0..layer_n], std.mem.span(layers[0]));
        const app: vk.ApplicationInfo = .{ .engine_name = "zpugl", .api_version = vk.api_1_2 };
        var handle: vk.VkInstance = undefined;
        try vk.ok(g.vkCreateInstance(&.{
            .flags = flags,
            .app_info = &app,
            .layer_count = @intFromBool(validation),
            .layers = &layers,
            .extension_count = n,
            .extensions = &exts,
        }, null, &handle), "vkCreateInstance");
        const i = vk.load(vk.InstanceFns, @as(?vk.VkInstance, handle), gipa) catch |err| {
            const destroy: vk.Fn(fn (vk.VkInstance, ?*const anyopaque) callconv(.c) void) = @ptrCast(gipa(handle, "vkDestroyInstance").?);
            destroy(handle, null);
            return err;
        };
        return .{ .loader = loader, .gipa = gipa, .gdpa = gdpa, .handle = handle, .i = i };
    }

    pub fn deinit(self: *Instance) void {
        self.i.vkDestroyInstance(self.handle, null);
        self.loader.deinit();
        self.* = undefined;
    }
};

const Buf = struct {
    buffer: vk.Handle = 0,
    memory: vk.Handle = 0,
    mapped: [*]u8 = undefined,
    size: u64 = 0,
};

const Tex = struct {
    image: vk.Handle = 0,
    memory: vk.Handle = 0,
    view: vk.Handle = 0,
    set: vk.Handle = 0,
    pool: vk.Handle = 0,
    framebuffer: vk.Handle = 0,
    width: u32,
    height: u32,
};

const Garbage = union(enum) { tex: *Tex, buf: Buf };

const Frame = struct {
    cmd: vk.Cmd = undefined,
    fence: vk.Handle = 0,
    acquired: vk.Handle = 0,
    ring: Buf = .{},
    used: u64 = 0,
    garbage: std.ArrayList(Garbage) = .empty,
};

const Pass = enum { none, screen, target };

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    view: *zpugl.View,
    inst: Instance,
    physical: vk.PhysicalDevice,
    family: u32,
    device: vk.Device,
    queue: vk.Queue,
    d: vk.DeviceFns,
    mem: vk.MemoryProperties,

    surface: vk.Surface = .null_handle,
    surface_handle: ?*anyopaque = null,
    surface_lost: bool = false,
    format: vk.SurfaceFormat = undefined,
    present_mode: i32 = vk.present_fifo,
    swapchain: vk.Handle = 0,
    images: [max_images]vk.Handle = @splat(0),
    image_views: [max_images]vk.Handle = @splat(0),
    framebuffers: [max_images]vk.Handle = @splat(0),
    rendered: [max_images]vk.Handle = @splat(0),
    image_count: u32 = 0,
    extent: vk.Extent2D = .{ .width = 0, .height = 0 },
    requested: vk.Extent2D = .{ .width = 0, .height = 0 },
    stale: bool = true,

    pass_clear: vk.Handle = 0,
    pass_load: vk.Handle = 0,
    pass_target: vk.Handle = 0,
    set_layout: vk.Handle = 0,
    layout: vk.Handle = 0,
    pipe_screen: vk.Handle = 0,
    pipe_target: vk.Handle = 0,
    samplers: [8]vk.Handle = @splat(0),
    pools: std.ArrayList(vk.Handle) = .empty,

    cmd_pool: vk.Handle = 0,
    frames: [frames_in_flight]Frame = @splat(.{}),
    frame: usize = 0,
    once_cmd: vk.Cmd = undefined,
    once_fence: vk.Handle = 0,
    white: ?*Tex = null,

    recording: bool = false,
    image: ?u32 = null,
    acquire_waited: bool = false,
    screen_started: bool = false,
    pass: Pass = .none,
    target: ?*Tex = null,
    screen_w: u32 = 0,
    screen_h: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, inst: Instance, view: *zpugl.View) !*Renderer {
        std.debug.assert(view.graphics_backend == .vulkan);
        const self = try allocator.create(Renderer);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .view = view, .inst = inst, .physical = undefined, .family = 0, .device = undefined, .queue = undefined, .d = undefined, .mem = undefined };
        try self.createSurface();
        errdefer self.inst.i.vkDestroySurfaceKHR(self.inst.handle, self.surface, null);
        try self.pickDevice();
        errdefer self.d.vkDestroyDevice(self.device, null);
        errdefer self.destroyObjects();
        try self.createObjects();
        return self;
    }

    pub fn deinit(self: *Renderer) void {
        _ = self.d.vkDeviceWaitIdle(self.device);
        self.destroyObjects();
        self.d.vkDestroyDevice(self.device, null);
        self.inst.i.vkDestroySurfaceKHR(self.inst.handle, self.surface, null);
        self.inst.deinit();
        self.allocator.destroy(self);
    }

    fn createSurface(self: *Renderer) !void {
        try vk.ok(zv.createSurface(self.inst.gipa, self.view, self.inst.handle, null, &self.surface), "createSurface");
        std.debug.assert(self.surface != .null_handle);
        self.surface_handle = self.view.handle;
        self.surface_lost = false;
    }

    fn pickDevice(self: *Renderer) !void {
        const i = &self.inst.i;
        var devs: [16]vk.PhysicalDevice = undefined;
        var dev_n: u32 = devs.len;
        const er = i.vkEnumeratePhysicalDevices(self.inst.handle, &dev_n, &devs);
        if (er != vk.success and er != vk.incomplete) try vk.ok(er, "vkEnumeratePhysicalDevices");
        const physical, const family = outer: for (devs[0..dev_n]) |dev| {
            var props: vk.PhysicalDeviceProperties = undefined;
            i.vkGetPhysicalDeviceProperties(dev, &props);
            if (props.api_version < vk.api_1_2) continue;
            var fam: [16]vk.QueueFamilyProperties = undefined;
            var fam_n: u32 = fam.len;
            i.vkGetPhysicalDeviceQueueFamilyProperties(dev, &fam_n, &fam);
            for (fam[0..fam_n], 0..) |f, idx| {
                if (f.flags & vk.queue_graphics == 0) continue;
                var present: u32 = 0;
                if (i.vkGetPhysicalDeviceSurfaceSupportKHR(dev, @intCast(idx), self.surface, &present) != vk.success or present == 0) continue;
                log.info("device {s}", .{std.mem.sliceTo(&props.name, 0)});
                break :outer .{ dev, @as(u32, @intCast(idx)) };
            }
        } else {
            log.info("no Vulkan 1.2 device with graphics and present queue", .{});
            return error.BackendError;
        };
        self.physical = physical;
        self.family = family;
        i.vkGetPhysicalDeviceMemoryProperties(physical, &self.mem);

        var formats: [64]vk.SurfaceFormat = undefined;
        var format_n: u32 = formats.len;
        const fr = i.vkGetPhysicalDeviceSurfaceFormatsKHR(physical, self.surface, &format_n, &formats);
        if ((fr != vk.success and fr != vk.incomplete) or format_n == 0) return error.BackendError;
        self.format = for (formats[0..format_n]) |f| {
            if (f.format == vk.format_bgra8 or f.format == vk.format_rgba8) break f;
        } else formats[0];
        var modes: [16]i32 = undefined;
        var mode_n: u32 = modes.len;
        const mr = i.vkGetPhysicalDeviceSurfacePresentModesKHR(physical, self.surface, &mode_n, &modes);
        if (mr == vk.success or mr == vk.incomplete) {
            if (std.mem.indexOfScalar(i32, modes[0..mode_n], vk.present_mailbox) != null) self.present_mode = vk.present_mailbox;
        }

        var dext: [512]vk.ExtensionProperties = undefined;
        var dext_n: u32 = dext.len;
        const dr = i.vkEnumerateDeviceExtensionProperties(physical, null, &dext_n, &dext);
        if (dr != vk.success and dr != vk.incomplete) try vk.ok(dr, "vkEnumerateDeviceExtensionProperties");
        if (!vk.hasName(dext[0..dext_n], "VK_KHR_swapchain")) return error.BackendError;
        const exts = [_]vk.Name{ "VK_KHR_swapchain", "VK_KHR_portability_subset" };
        const prio = [_]f32{1};
        try vk.ok(i.vkCreateDevice(physical, &.{
            .queue_infos = &.{.{ .family = family, .priorities = &prio }},
            .extension_count = if (vk.hasName(dext[0..dext_n], "VK_KHR_portability_subset")) 2 else 1,
            .extensions = &exts,
        }, null, &self.device), "vkCreateDevice");
        self.d = vk.load(vk.DeviceFns, self.device, self.inst.gdpa) catch |err| {
            const destroy: vk.Fn(fn (vk.Device, ?*const anyopaque) callconv(.c) void) = @ptrCast(self.inst.gdpa(self.device, "vkDestroyDevice").?);
            destroy(self.device, null);
            return err;
        };
        self.d.vkGetDeviceQueue(self.device, family, 0, &self.queue);
    }

    fn createObjects(self: *Renderer) !void {
        const d = &self.d;
        const dev = self.device;
        try vk.ok(d.vkCreateCommandPool(dev, &.{ .family = self.family }, null, &self.cmd_pool), "command pool");
        var cmds: [frames_in_flight + 1]vk.Cmd = undefined;
        try vk.ok(d.vkAllocateCommandBuffers(dev, &.{ .pool = self.cmd_pool, .count = cmds.len }, &cmds), "command buffers");
        for (&self.frames, cmds[0..frames_in_flight]) |*f, c| {
            f.cmd = c;
            try vk.ok(d.vkCreateFence(dev, &.{}, null, &f.fence), "fence");
            try vk.ok(d.vkCreateSemaphore(dev, &.{}, null, &f.acquired), "semaphore");
        }
        self.once_cmd = cmds[frames_in_flight];
        try vk.ok(d.vkCreateFence(dev, &.{ .flags = 0 }, null, &self.once_fence), "fence");

        self.pass_clear = try self.createPass(self.format.format, 1, vk.layout_undefined, vk.layout_present);
        self.pass_load = try self.createPass(self.format.format, 0, vk.layout_present, vk.layout_present);
        self.pass_target = try self.createPass(vk.format_rgba8, 0, vk.layout_shader_read, vk.layout_shader_read);

        const binding = [_]vk.SetLayoutBinding{.{ .binding = 1, .kind = vk.descriptor_image_sampler, .stages = vk.shader_fragment }};
        try vk.ok(d.vkCreateDescriptorSetLayout(dev, &.{ .bindings = &binding }, null, &self.set_layout), "descriptor set layout");
        const push = [_]vk.PushConstantRange{.{ .stages = vk.shader_vertex, .offset = 0, .size = 16 }};
        try vk.ok(d.vkCreatePipelineLayout(dev, &.{ .set_layouts = &.{self.set_layout}, .push_ranges = &push }, null, &self.layout), "pipeline layout");

        var vs: vk.Handle = 0;
        try vk.ok(d.vkCreateShaderModule(dev, &.{ .size = vert_spv.len, .code = @ptrCast(&vert_spv) }, null, &vs), "vertex shader");
        defer d.vkDestroyShaderModule(dev, vs, null);
        var fs: vk.Handle = 0;
        try vk.ok(d.vkCreateShaderModule(dev, &.{ .size = frag_spv.len, .code = @ptrCast(&frag_spv) }, null, &fs), "fragment shader");
        defer d.vkDestroyShaderModule(dev, fs, null);
        self.pipe_screen = try self.createPipeline(vs, fs, self.pass_clear);
        self.pipe_target = try self.createPipeline(vs, fs, self.pass_target);

        for (&self.samplers, 0..) |*s, key| {
            const filter: i32 = @intCast(key & 1);
            try vk.ok(d.vkCreateSampler(dev, &.{
                .mag_filter = filter,
                .min_filter = filter,
                .mipmap_mode = 0,
                .address_u = if (key & 2 != 0) 0 else 2,
                .address_v = if (key & 4 != 0) 0 else 2,
            }, null, s), "sampler");
        }
        const white = try self.textureCreate(&[_]u8{ 255, 255, 255, 255 }, .{ .width = 1, .height = 1 });
        self.white = @ptrCast(@alignCast(white.ptr));
    }

    fn destroyObjects(self: *Renderer) void {
        const d = &self.d;
        const dev = self.device;
        if (self.white) |w| self.destroyTex(w);
        self.white = null;
        for (&self.frames) |*f| {
            for (f.garbage.items) |g| self.destroyGarbage(g);
            f.garbage.deinit(self.allocator);
            self.destroyBuf(f.ring);
            if (f.fence != 0) d.vkDestroyFence(dev, f.fence, null);
            if (f.acquired != 0) d.vkDestroySemaphore(dev, f.acquired, null);
            f.* = .{};
        }
        if (self.once_fence != 0) d.vkDestroyFence(dev, self.once_fence, null);
        self.destroySwapchain();
        for (self.rendered) |s| if (s != 0) d.vkDestroySemaphore(dev, s, null);
        for (self.samplers) |s| if (s != 0) d.vkDestroySampler(dev, s, null);
        for (self.pools.items) |p| d.vkDestroyDescriptorPool(dev, p, null);
        self.pools.deinit(self.allocator);
        for ([_]vk.Handle{ self.pipe_screen, self.pipe_target }) |p| if (p != 0) d.vkDestroyPipeline(dev, p, null);
        if (self.layout != 0) d.vkDestroyPipelineLayout(dev, self.layout, null);
        if (self.set_layout != 0) d.vkDestroyDescriptorSetLayout(dev, self.set_layout, null);
        for ([_]vk.Handle{ self.pass_clear, self.pass_load, self.pass_target }) |p| if (p != 0) d.vkDestroyRenderPass(dev, p, null);
        if (self.cmd_pool != 0) d.vkDestroyCommandPool(dev, self.cmd_pool, null);
    }

    fn createPass(self: *Renderer, format: i32, load_op: i32, initial: i32, final: i32) !vk.Handle {
        const deps = [_]vk.SubpassDependency{
            .{
                .src_subpass = ~@as(u32, 0),
                .dst_subpass = 0,
                .src_stages = vk.stage_color_output | vk.stage_fragment | vk.stage_transfer,
                .dst_stages = vk.stage_color_output,
                .src_access = vk.access_color_write | vk.access_transfer_write,
                .dst_access = vk.access_color_read | vk.access_color_write,
            },
            .{
                .src_subpass = 0,
                .dst_subpass = ~@as(u32, 0),
                .src_stages = vk.stage_color_output,
                .dst_stages = vk.stage_fragment | vk.stage_transfer,
                .src_access = vk.access_color_write,
                .dst_access = vk.access_shader_read | vk.access_transfer_read,
            },
        };
        var pass: vk.Handle = 0;
        try vk.ok(self.d.vkCreateRenderPass(self.device, &.{
            .attachments = &.{.{ .format = format, .load = load_op, .initial_layout = initial, .final_layout = final }},
            .subpasses = &.{.{ .colors = &.{.{ .attachment = 0, .layout = vk.layout_color }} }},
            .dependencies = &deps,
        }, null, &pass), "render pass");
        return pass;
    }

    fn createPipeline(self: *Renderer, vs: vk.Handle, fs: vk.Handle, pass: vk.Handle) !vk.Handle {
        const V = dvui.Vertex;
        const stages = [_]vk.ShaderStage{
            .{ .stage = vk.shader_vertex, .module = vs, .name = "main" },
            .{ .stage = vk.shader_fragment, .module = fs, .name = "main" },
        };
        const attrs = [_]vk.VertexAttribute{
            .{ .location = 0, .format = 103, .offset = @offsetOf(V, "pos") },
            .{ .location = 1, .format = vk.format_rgba8, .offset = @offsetOf(V, "col") },
            .{ .location = 2, .format = 103, .offset = @offsetOf(V, "uv") },
        };
        const dynamic = [_]i32{ 0, 1 };
        var pipe: vk.Handle = 0;
        try vk.ok(self.d.vkCreateGraphicsPipelines(self.device, 0, 1, &.{.{
            .stage_count = stages.len,
            .stages = &stages,
            .vertex_input = &.{ .binding_count = 1, .bindings = &.{.{ .binding = 0, .stride = @sizeOf(V) }}, .attribute_count = attrs.len, .attributes = &attrs },
            .input_assembly = &.{},
            .viewport = &.{},
            .rasterization = &.{},
            .multisample = &.{},
            .color_blend = &.{ .attachments = &.{.{}} },
            .dynamic = &.{ .count = dynamic.len, .states = &dynamic },
            .layout = self.layout,
            .render_pass = pass,
        }}, null, &pipe), "graphics pipeline");
        return pipe;
    }

    fn destroySwapchain(self: *Renderer) void {
        for (self.framebuffers[0..self.image_count], self.image_views[0..self.image_count]) |*fb, *iv| {
            if (fb.* != 0) self.d.vkDestroyFramebuffer(self.device, fb.*, null);
            if (iv.* != 0) self.d.vkDestroyImageView(self.device, iv.*, null);
            fb.* = 0;
            iv.* = 0;
        }
        if (self.swapchain != 0) self.d.vkDestroySwapchainKHR(self.device, self.swapchain, null);
        self.swapchain = 0;
        self.image_count = 0;
    }

    fn recreateSwapchain(self: *Renderer, width: u32, height: u32) !bool {
        _ = self.d.vkDeviceWaitIdle(self.device);
        if (self.surface_lost or self.view.handle != self.surface_handle) {
            self.destroySwapchain();
            self.inst.i.vkDestroySurfaceKHR(self.inst.handle, self.surface, null);
            self.surface = .null_handle;
            if (self.view.handle == null) return false;
            try self.createSurface();
            var present: u32 = 0;
            try vk.ok(self.inst.i.vkGetPhysicalDeviceSurfaceSupportKHR(self.physical, self.family, self.surface, &present), "surface support");
            if (present == 0) return error.BackendError;
        }
        var caps: vk.SurfaceCapabilities = undefined;
        try vk.ok(self.inst.i.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(self.physical, self.surface, &caps), "surface capabilities");
        const extent: vk.Extent2D = if (caps.current_extent.width != std.math.maxInt(u32)) caps.current_extent else .{
            .width = std.math.clamp(width, caps.min_extent.width, caps.max_extent.width),
            .height = std.math.clamp(height, caps.min_extent.height, caps.max_extent.height),
        };
        if (extent.width == 0 or extent.height == 0) return false;
        var count = @max(caps.min_images + 1, frames_in_flight + 1);
        if (caps.max_images != 0) count = @min(count, caps.max_images);
        const alpha: u32 = if (caps.composite_alpha & 1 != 0) 1 else caps.composite_alpha & (~caps.composite_alpha +% 1);
        const old = self.swapchain;
        var swapchain: vk.Handle = 0;
        try vk.ok(self.d.vkCreateSwapchainKHR(self.device, &.{
            .surface = self.surface,
            .min_images = count,
            .format = self.format.format,
            .color_space = self.format.color_space,
            .extent = extent,
            .usage = vk.usage_color_attachment,
            .transform = caps.current_transform,
            .composite_alpha = alpha,
            .present_mode = self.present_mode,
            .old = old,
        }, null, &swapchain), "vkCreateSwapchainKHR");
        self.destroySwapchain();
        self.swapchain = swapchain;
        self.extent = extent;
        var n: u32 = max_images;
        const ir = self.d.vkGetSwapchainImagesKHR(self.device, swapchain, &n, &self.images);
        if (ir != vk.success and ir != vk.incomplete) try vk.ok(ir, "vkGetSwapchainImagesKHR");
        std.debug.assert(n > 0 and n <= max_images);
        self.image_count = n;
        for (0..n) |k| {
            try vk.ok(self.d.vkCreateImageView(self.device, &.{ .image = self.images[k], .format = self.format.format }, null, &self.image_views[k]), "swapchain image view");
            try vk.ok(self.d.vkCreateFramebuffer(self.device, &.{ .render_pass = self.pass_clear, .attachments = &.{self.image_views[k]}, .width = extent.width, .height = extent.height }, null, &self.framebuffers[k]), "framebuffer");
            if (self.rendered[k] == 0) try vk.ok(self.d.vkCreateSemaphore(self.device, &.{}, null, &self.rendered[k]), "semaphore");
        }
        self.stale = false;
        return true;
    }

    fn memoryType(self: *Renderer, bits: u32, want: u32) ?u32 {
        for (self.mem.types[0..self.mem.type_count], 0..) |t, k| {
            if (bits & (@as(u32, 1) << @intCast(k)) != 0 and t.flags & want == want) return @intCast(k);
        }
        return null;
    }

    fn allocate(self: *Renderer, req: vk.MemoryRequirements, want: u32, fallback: u32) !vk.Handle {
        const index = self.memoryType(req.type_bits, want) orelse self.memoryType(req.type_bits, fallback) orelse return error.BackendError;
        var memory: vk.Handle = 0;
        try vk.ok(self.d.vkAllocateMemory(self.device, &.{ .size = req.size, .type_index = index }, null, &memory), "vkAllocateMemory");
        return memory;
    }

    fn createBuf(self: *Renderer, size: u64, usage: u32) !Buf {
        var b: Buf = .{ .size = size };
        try vk.ok(self.d.vkCreateBuffer(self.device, &.{ .size = size, .usage = usage }, null, &b.buffer), "vkCreateBuffer");
        errdefer self.d.vkDestroyBuffer(self.device, b.buffer, null);
        var req: vk.MemoryRequirements = undefined;
        self.d.vkGetBufferMemoryRequirements(self.device, b.buffer, &req);
        b.memory = try self.allocate(req, vk.mem_host_visible | vk.mem_host_coherent, vk.mem_host_visible | vk.mem_host_coherent);
        errdefer self.d.vkFreeMemory(self.device, b.memory, null);
        try vk.ok(self.d.vkBindBufferMemory(self.device, b.buffer, b.memory, 0), "vkBindBufferMemory");
        var ptr: ?*anyopaque = null;
        try vk.ok(self.d.vkMapMemory(self.device, b.memory, 0, size, 0, &ptr), "vkMapMemory");
        b.mapped = @ptrCast(ptr.?);
        return b;
    }

    fn destroyBuf(self: *Renderer, b: Buf) void {
        if (b.buffer != 0) self.d.vkDestroyBuffer(self.device, b.buffer, null);
        if (b.memory != 0) self.d.vkFreeMemory(self.device, b.memory, null);
    }

    fn destroyTex(self: *Renderer, t: *Tex) void {
        const d = &self.d;
        if (t.framebuffer != 0) d.vkDestroyFramebuffer(self.device, t.framebuffer, null);
        if (t.set != 0) _ = d.vkFreeDescriptorSets(self.device, t.pool, 1, &.{t.set});
        if (t.view != 0) d.vkDestroyImageView(self.device, t.view, null);
        if (t.image != 0) d.vkDestroyImage(self.device, t.image, null);
        if (t.memory != 0) d.vkFreeMemory(self.device, t.memory, null);
        self.allocator.destroy(t);
    }

    fn destroyGarbage(self: *Renderer, g: Garbage) void {
        switch (g) {
            .tex => |t| self.destroyTex(t),
            .buf => |b| self.destroyBuf(b),
        }
    }

    fn trash(self: *Renderer, g: Garbage) void {
        self.frames[self.frame].garbage.append(self.allocator, g) catch {
            if (self.recording) self.flush() catch {};
            _ = self.d.vkDeviceWaitIdle(self.device);
            self.destroyGarbage(g);
        };
    }

    fn allocateSet(self: *Renderer, t: *Tex) !void {
        if (self.pools.items.len > 0) {
            const pool = self.pools.items[self.pools.items.len - 1];
            const r = self.d.vkAllocateDescriptorSets(self.device, &.{ .pool = pool, .layouts = &.{self.set_layout} }, &t.set);
            if (r == vk.success) {
                t.pool = pool;
                return;
            }
            if (r != vk.pool_out_of_memory and r != vk.pool_fragmented) try vk.ok(r, "vkAllocateDescriptorSets");
        }
        var pool: vk.Handle = 0;
        try vk.ok(self.d.vkCreateDescriptorPool(self.device, &.{ .max_sets = sets_per_pool, .sizes = &.{.{ .kind = vk.descriptor_image_sampler, .count = sets_per_pool }} }, null, &pool), "vkCreateDescriptorPool");
        self.pools.append(self.allocator, pool) catch |err| {
            self.d.vkDestroyDescriptorPool(self.device, pool, null);
            return err;
        };
        try vk.ok(self.d.vkAllocateDescriptorSets(self.device, &.{ .pool = pool, .layouts = &.{self.set_layout} }, &t.set), "vkAllocateDescriptorSets");
        t.pool = pool;
    }

    fn createTex(self: *Renderer, options: dvui.Texture.CreateOptions, usage: u32) !*Tex {
        std.debug.assert(options.width > 0 and options.height > 0);
        const t = try self.allocator.create(Tex);
        t.* = .{ .width = options.width, .height = options.height };
        errdefer self.destroyTex(t);
        const d = &self.d;
        try vk.ok(d.vkCreateImage(self.device, &.{ .extent = .{ .width = t.width, .height = t.height, .depth = 1 }, .usage = usage }, null, &t.image), "vkCreateImage");
        var req: vk.MemoryRequirements = undefined;
        d.vkGetImageMemoryRequirements(self.device, t.image, &req);
        t.memory = try self.allocate(req, vk.mem_device_local, 0);
        try vk.ok(d.vkBindImageMemory(self.device, t.image, t.memory, 0), "vkBindImageMemory");
        try vk.ok(d.vkCreateImageView(self.device, &.{ .image = t.image, .format = vk.format_rgba8 }, null, &t.view), "vkCreateImageView");
        try self.allocateSet(t);
        const key: usize = @as(usize, @intFromBool(options.interpolation == .linear)) | @as(usize, @intFromBool(options.wrap_u == .repeat)) << 1 | @as(usize, @intFromBool(options.wrap_v == .repeat)) << 2;
        const info = [_]vk.DescriptorImageInfo{.{ .sampler = self.samplers[key], .view = t.view, .layout = vk.layout_shader_read }};
        d.vkUpdateDescriptorSets(self.device, 1, &.{.{ .set = t.set, .binding = 1, .kind = vk.descriptor_image_sampler, .images = &info }}, 0, null);
        return t;
    }

    fn texture(t: *Tex, options: dvui.Texture.CreateOptions) dvui.Texture {
        return .{
            .ptr = t,
            .width = options.width,
            .height = options.height,
            .format = options.format,
            .interpolation = options.interpolation,
            .wrap_u = options.wrap_u,
            .wrap_v = options.wrap_v,
        };
    }

    fn tex(ptr: *anyopaque) *Tex {
        return @ptrCast(@alignCast(ptr));
    }

    fn barrier(self: *Renderer, cmd: vk.Cmd, image: vk.Handle, old: i32, new: i32, src_stage: u32, dst_stage: u32, src_access: u32, dst_access: u32) void {
        self.d.vkCmdPipelineBarrier(cmd, src_stage, dst_stage, 0, 0, null, 0, null, 1, &.{.{ .src_access = src_access, .dst_access = dst_access, .old_layout = old, .new_layout = new, .image = image }});
    }

    fn beginOnce(self: *Renderer) !vk.Cmd {
        try vk.ok(self.d.vkBeginCommandBuffer(self.once_cmd, &.{}), "vkBeginCommandBuffer");
        return self.once_cmd;
    }

    fn beginTransfer(self: *Renderer) !vk.Cmd {
        if (!self.recording) return self.beginOnce();
        self.endPass();
        return self.frames[self.frame].cmd;
    }

    fn endTransfer(self: *Renderer) !void {
        if (!self.recording) try self.submitOnce();
    }

    fn submitOnce(self: *Renderer) !void {
        try vk.ok(self.d.vkEndCommandBuffer(self.once_cmd), "vkEndCommandBuffer");
        try vk.ok(self.d.vkQueueSubmit(self.queue, 1, &.{.{ .cmds = &.{self.once_cmd} }}, self.once_fence), "vkQueueSubmit");
        try vk.ok(self.d.vkWaitForFences(self.device, 1, &.{self.once_fence}, 1, vk.no_timeout), "vkWaitForFences");
        try vk.ok(self.d.vkResetFences(self.device, 1, &.{self.once_fence}), "vkResetFences");
    }

    fn upload(self: *Renderer, t: *Tex, pixels: [*]const u8, x: u32, y: u32, w: u32, h: u32, fresh: bool) !void {
        std.debug.assert(x + w <= t.width and y + h <= t.height);
        if (w == 0 or h == 0) return;
        const row: usize = @as(usize, t.width) * 4;
        const staging = try self.createBuf(@as(u64, w) * h * 4, vk.usage_transfer_src);
        defer self.trash(.{ .buf = staging });
        for (0..h) |r| @memcpy(staging.mapped[r * w * 4 ..][0 .. w * 4], pixels[(y + r) * row + x * 4 ..][0 .. w * 4]);
        const cmd = try self.beginTransfer();
        const old: i32 = if (fresh) vk.layout_undefined else vk.layout_shader_read;
        self.barrier(cmd, t.image, old, vk.layout_transfer_dst, vk.stage_fragment | vk.stage_transfer | vk.stage_color_output, vk.stage_transfer, 0, vk.access_transfer_write);
        self.d.vkCmdCopyBufferToImage(cmd, staging.buffer, t.image, vk.layout_transfer_dst, 1, &.{.{
            .row_length = w,
            .image_offset = .{ .x = @intCast(x), .y = @intCast(y) },
            .image_extent = .{ .width = w, .height = h, .depth = 1 },
        }});
        self.barrier(cmd, t.image, vk.layout_transfer_dst, vk.layout_shader_read, vk.stage_transfer, vk.stage_fragment, vk.access_transfer_write, vk.access_shader_read);
        try self.endTransfer();
    }

    pub fn textureCreate(self: *Renderer, pixels: [*]const u8, options: dvui.Texture.CreateOptions) !dvui.Texture {
        const t = try self.createTex(options, vk.usage_sampled | vk.usage_transfer_dst);
        errdefer self.destroyTex(t);
        try self.upload(t, pixels, 0, 0, t.width, t.height, true);
        return texture(t, options);
    }

    pub fn textureUpdate(self: *Renderer, t: dvui.Texture, pixels: [*]const u8) !void {
        return self.upload(tex(t.ptr), pixels, 0, 0, t.width, t.height, false);
    }

    pub fn textureUpdateSubRect(self: *Renderer, t: dvui.Texture, pixels: [*]const u8, x: u32, y: u32, w: u32, h: u32) !void {
        return self.upload(tex(t.ptr), pixels, x, y, w, h, false);
    }

    pub fn textureDestroy(self: *Renderer, t: dvui.Texture) void {
        const p = tex(t.ptr);
        if (self.target == p) self.target = null;
        self.trash(.{ .tex = p });
    }

    pub fn targetCreate(self: *Renderer, options: dvui.Texture.CreateOptions) !dvui.TextureTarget {
        const t = try self.createTex(options, vk.usage_sampled | vk.usage_color_attachment | vk.usage_transfer_src | vk.usage_transfer_dst);
        errdefer self.destroyTex(t);
        try vk.ok(self.d.vkCreateFramebuffer(self.device, &.{ .render_pass = self.pass_target, .attachments = &.{t.view}, .width = t.width, .height = t.height }, null, &t.framebuffer), "target framebuffer");
        try self.clear(t, vk.layout_undefined);
        return .cast(texture(t, options));
    }

    fn clear(self: *Renderer, t: *Tex, old: i32) !void {
        const cmd = try self.beginTransfer();
        self.barrier(cmd, t.image, old, vk.layout_transfer_dst, vk.stage_fragment | vk.stage_transfer | vk.stage_color_output, vk.stage_transfer, vk.access_color_write, vk.access_transfer_write);
        self.d.vkCmdClearColorImage(cmd, t.image, vk.layout_transfer_dst, &@splat(0), 1, &.{.{}});
        self.barrier(cmd, t.image, vk.layout_transfer_dst, vk.layout_shader_read, vk.stage_transfer, vk.stage_fragment | vk.stage_color_output, vk.access_transfer_write, vk.access_shader_read | vk.access_color_read | vk.access_color_write);
        try self.endTransfer();
    }

    pub fn targetClear(self: *Renderer, target: dvui.TextureTarget) void {
        self.clear(tex(target.ptr), vk.layout_shader_read) catch {};
    }

    pub fn targetRead(self: *Renderer, target: dvui.TextureTarget, pixels_out: [*]u8) !void {
        if (self.recording) try self.flush();
        const t = tex(target.ptr);
        const size: u64 = @as(u64, t.width) * t.height * 4;
        const staging = try self.createBuf(size, vk.usage_transfer_dst);
        defer self.destroyBuf(staging);
        const cmd = try self.beginOnce();
        self.barrier(cmd, t.image, vk.layout_shader_read, vk.layout_transfer_src, vk.stage_color_output | vk.stage_fragment, vk.stage_transfer, vk.access_color_write, vk.access_transfer_read);
        self.d.vkCmdCopyImageToBuffer(cmd, t.image, vk.layout_transfer_src, staging.buffer, 1, &.{.{
            .row_length = t.width,
            .image_offset = .{},
            .image_extent = .{ .width = t.width, .height = t.height, .depth = 1 },
        }});
        self.barrier(cmd, t.image, vk.layout_transfer_src, vk.layout_shader_read, vk.stage_transfer, vk.stage_fragment, 0, vk.access_shader_read);
        self.d.vkCmdPipelineBarrier(cmd, vk.stage_transfer, vk.stage_host, 0, 1, &.{.{ .src_access = vk.access_transfer_write, .dst_access = vk.access_host_read }}, 0, null, 0, null);
        try self.submitOnce();
        @memcpy(pixels_out[0..@intCast(size)], staging.mapped[0..@intCast(size)]);
    }

    pub fn renderTarget(self: *Renderer, target: ?dvui.TextureTarget) void {
        self.endPass();
        self.target = if (target) |t| tex(t.ptr) else null;
    }

    pub fn begin(self: *Renderer, w: u32, h: u32) !void {
        std.debug.assert(!self.recording);
        self.frame = (self.frame + 1) % frames_in_flight;
        const f = &self.frames[self.frame];
        try vk.ok(self.d.vkWaitForFences(self.device, 1, &.{f.fence}, 1, vk.no_timeout), "vkWaitForFences");
        for (f.garbage.items) |g| self.destroyGarbage(g);
        f.garbage.clearRetainingCapacity();
        f.used = 0;
        try vk.ok(self.d.vkBeginCommandBuffer(f.cmd, &.{}), "vkBeginCommandBuffer");
        self.recording = true;
        self.image = null;
        self.acquire_waited = false;
        self.screen_started = false;
        self.pass = .none;
        self.target = null;
        self.screen_w = w;
        self.screen_h = h;
        if (w == 0 or h == 0) return;
        if (self.stale or self.surface_lost or self.view.handle != self.surface_handle or self.requested.width != w or self.requested.height != h) {
            self.requested = .{ .width = w, .height = h };
            const ready = self.recreateSwapchain(w, h) catch false;
            if (!ready) {
                self.stale = true;
                return;
            }
        }
        var index: u32 = 0;
        const r = self.d.vkAcquireNextImageKHR(self.device, self.swapchain, vk.no_timeout, f.acquired, 0, &index);
        switch (r) {
            vk.success, vk.suboptimal => {},
            vk.out_of_date => {
                self.stale = true;
                return;
            },
            vk.surface_lost => {
                self.surface_lost = true;
                return;
            },
            else => {
                vk.ok(r, "vkAcquireNextImageKHR") catch {};
                self.stale = true;
                return;
            },
        }
        std.debug.assert(index < self.image_count);
        self.image = index;
    }

    fn submit(self: *Renderer, signal: bool) !void {
        const f = &self.frames[self.frame];
        self.endPass();
        try vk.ok(self.d.vkEndCommandBuffer(f.cmd), "vkEndCommandBuffer");
        const wait = self.image != null and !self.acquire_waited;
        const wait_stage = [_]u32{vk.stage_color_output};
        self.acquire_waited = self.acquire_waited or wait;
        try vk.ok(self.d.vkResetFences(self.device, 1, &.{f.fence}), "vkResetFences");
        try vk.ok(self.d.vkQueueSubmit(self.queue, 1, &.{.{
            .wait_count = @intFromBool(wait),
            .wait = @ptrCast(&f.acquired),
            .wait_stages = &wait_stage,
            .cmds = @ptrCast(&f.cmd),
            .signal_count = @intFromBool(signal),
            .signal = if (self.image) |i| self.rendered[i..].ptr else null,
        }}, f.fence), "vkQueueSubmit");
    }

    fn flush(self: *Renderer) !void {
        const f = &self.frames[self.frame];
        try self.submit(false);
        try vk.ok(self.d.vkWaitForFences(self.device, 1, &.{f.fence}, 1, vk.no_timeout), "vkWaitForFences");
        try vk.ok(self.d.vkBeginCommandBuffer(f.cmd, &.{}), "vkBeginCommandBuffer");
    }

    pub fn end(self: *Renderer) !void {
        std.debug.assert(self.recording);
        self.recording = false;
        self.target = null;
        if (self.image != null and !self.screen_started) self.beginPass(.screen);
        try self.submit(self.image != null);
        const index = self.image orelse return;
        const r = self.d.vkQueuePresentKHR(self.queue, &.{ .wait = &.{self.rendered[index]}, .swapchains = &.{self.swapchain}, .indices = &.{index} });
        switch (r) {
            vk.success => {},
            vk.suboptimal, vk.out_of_date => self.stale = true,
            vk.surface_lost => self.surface_lost = true,
            else => try vk.ok(r, "vkQueuePresentKHR"),
        }
    }

    fn endPass(self: *Renderer) void {
        if (self.pass == .none) return;
        self.d.vkCmdEndRenderPass(self.frames[self.frame].cmd);
        self.pass = .none;
    }

    fn beginPass(self: *Renderer, want: Pass) void {
        if (self.pass == want and (want == .screen or self.target != null)) return;
        self.endPass();
        const cmd = self.frames[self.frame].cmd;
        const clear_color = [_][4]f32{.{ 0, 0.6, 0.8, 1 }};
        const pass: vk.Handle, const fb: vk.Handle, const w: u32, const h: u32 = switch (want) {
            .screen => .{ if (self.screen_started) self.pass_load else self.pass_clear, self.framebuffers[self.image.?], self.extent.width, self.extent.height },
            .target => .{ self.pass_target, self.target.?.framebuffer, self.target.?.width, self.target.?.height },
            .none => unreachable,
        };
        if (want == .screen) self.screen_started = true;
        self.d.vkCmdBeginRenderPass(cmd, &.{ .render_pass = pass, .framebuffer = fb, .area = .{ .extent = .{ .width = w, .height = h } }, .clears = &clear_color }, 0);
        self.d.vkCmdBindPipeline(cmd, 0, if (want == .screen) self.pipe_screen else self.pipe_target);
        self.d.vkCmdSetViewport(cmd, 0, 1, &.{.{ .width = @floatFromInt(w), .height = @floatFromInt(h) }});
        const push = [4]f32{ 2.0 / @as(f32, @floatFromInt(w)), 2.0 / @as(f32, @floatFromInt(h)), -1, -1 };
        self.d.vkCmdPushConstants(cmd, self.layout, vk.shader_vertex, 0, @sizeOf(@TypeOf(push)), &push);
        self.pass = want;
    }

    fn reserve(self: *Renderer, len: u64) !void {
        const f = &self.frames[self.frame];
        if (std.mem.alignForward(u64, f.used, 16) + len <= f.ring.size) return;
        const size = @max(1 << 20, std.math.ceilPowerOfTwoAssert(u64, (f.used + len) * 2));
        const ring = try self.createBuf(size, vk.usage_vertex | vk.usage_index);
        if (f.ring.buffer != 0) self.trash(.{ .buf = f.ring });
        f.ring = ring;
        f.used = 0;
    }

    fn stream(self: *Renderer, bytes: []const u8) u64 {
        const f = &self.frames[self.frame];
        const offset = std.mem.alignForward(u64, f.used, 16);
        std.debug.assert(offset + bytes.len <= f.ring.size);
        @memcpy(f.ring.mapped[@intCast(offset)..][0..bytes.len], bytes);
        f.used = offset + bytes.len;
        return offset;
    }

    pub fn drawClippedTriangles(self: *Renderer, texture_: ?dvui.Texture, vtx: []const dvui.Vertex, idx: []const dvui.Vertex.Index, clipr: ?dvui.Rect.Physical) !void {
        std.debug.assert(self.recording);
        if (idx.len == 0) return;
        if (self.target == null and self.image == null) return;
        const f = &self.frames[self.frame];
        const vbytes = std.mem.sliceAsBytes(vtx);
        const ibytes = std.mem.sliceAsBytes(idx);
        try self.reserve(vbytes.len + ibytes.len + 32);
        const voff = self.stream(vbytes);
        const ioff = self.stream(ibytes);
        self.beginPass(if (self.target != null) .target else .screen);
        const w: f32, const h: f32 = if (self.target) |t| .{ @floatFromInt(t.width), @floatFromInt(t.height) } else .{ @floatFromInt(self.extent.width), @floatFromInt(self.extent.height) };
        const r = clipr orelse dvui.Rect.Physical{ .x = 0, .y = 0, .w = w, .h = h };
        const x0 = std.math.clamp(r.x, 0, w);
        const y0 = std.math.clamp(r.y, 0, h);
        const x1 = std.math.clamp(r.x + r.w, x0, w);
        const y1 = std.math.clamp(r.y + r.h, y0, h);
        if (x1 - x0 < 1 or y1 - y0 < 1) return;
        const cmd = f.cmd;
        self.d.vkCmdSetScissor(cmd, 0, 1, &.{.{ .offset = .{ .x = @intFromFloat(x0), .y = @intFromFloat(y0) }, .extent = .{ .width = @intFromFloat(x1 - x0), .height = @intFromFloat(y1 - y0) } }});
        const t = if (texture_) |tx| tex(tx.ptr) else self.white.?;
        self.d.vkCmdBindDescriptorSets(cmd, 0, self.layout, 0, 1, &.{t.set}, 0, null);
        self.d.vkCmdBindVertexBuffers(cmd, 0, 1, &.{f.ring.buffer}, &.{voff});
        self.d.vkCmdBindIndexBuffer(cmd, f.ring.buffer, ioff, if (dvui.Vertex.Index == u16) 0 else 1);
        self.d.vkCmdDrawIndexed(cmd, @intCast(idx.len), 1, 0, 0, 0);
    }
};
