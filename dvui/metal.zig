const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
const zpugl = @import("zpugl");
const objc = zpugl.objc;
const c = objc.c;

const NSUInteger = usize;
const CGSize = extern struct { width: f64, height: f64 };
const MTLClearColor = extern struct { r: f64, g: f64, b: f64, a: f64 };
const MTLScissorRect = extern struct { x: NSUInteger, y: NSUInteger, width: NSUInteger, height: NSUInteger };
const MTLOrigin = extern struct { x: NSUInteger, y: NSUInteger, z: NSUInteger };
const MTLSize = extern struct { width: NSUInteger, height: NSUInteger, depth: NSUInteger };
const MTLRegion = extern struct { origin: MTLOrigin, size: MTLSize };

const pixel_bgra8: NSUInteger = 80;
const pixel_rgba8: NSUInteger = 70;
const vertex_float2: NSUInteger = 29;
const vertex_uchar4_norm: NSUInteger = 9;
const blend_one: NSUInteger = 1;
const blend_one_minus_src_alpha: NSUInteger = 5;
const load_load: NSUInteger = 1;
const load_clear: NSUInteger = 2;
const store_store: NSUInteger = 1;
const primitive_triangle: NSUInteger = 3;
const index_u16: NSUInteger = 0;
const index_u32: NSUInteger = 1;
const usage_shader_read: NSUInteger = 1;
const usage_render_target: NSUInteger = 4;

extern "c" fn MTLCreateSystemDefaultDevice() c.id;
extern "c" fn objc_autoreleasePoolPush() ?*anyopaque;
extern "c" fn objc_autoreleasePoolPop(pool: ?*anyopaque) void;

const shader_src =
    \\#include <metal_stdlib>
    \\using namespace metal;
    \\struct VIn { float2 pos [[attribute(0)]]; float4 col [[attribute(1)]]; float2 uv [[attribute(2)]]; };
    \\struct VOut { float4 pos [[position]]; float4 col; float2 uv; };
    \\vertex VOut vs(VIn in [[stage_in]], constant float2 &size [[buffer(1)]]) {
    \\    VOut o;
    \\    o.pos = float4(in.pos.x * 2.0 / size.x - 1.0, 1.0 - in.pos.y * 2.0 / size.y, 0.0, 1.0);
    \\    o.col = in.col;
    \\    o.uv = in.uv;
    \\    return o;
    \\}
    \\fragment float4 fs(VOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler s [[sampler(0)]]) {
    \\    return tex.sample(s, in.uv) * in.col;
    \\}
;

inline fn obj(id: c.id) objc.Object {
    return .{ .value = id };
}

inline fn cls(name: [:0]const u8) objc.Class {
    return objc.getClass(name).?;
}

fn nsString(s: [*:0]const u8) objc.Object {
    return cls("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{s});
}

const frames_in_flight = 3;

const Frame = struct {
    buffer: ?objc.Object = null,
    cmd: ?objc.Object = null,

    fn wait(self: *Frame) void {
        const cmd = self.cmd orelse return;
        cmd.msgSend(void, "waitUntilCompleted", .{});
        cmd.release();
        self.cmd = null;
    }
};

pub const Renderer = struct {
    view: *zpugl.View,
    layer: objc.Object,
    device: objc.Object,
    queue: objc.Object,
    pipeline_screen: objc.Object,
    pipeline_target: objc.Object,
    white: objc.Object,
    samplers: [8]?objc.Object = @splat(null),
    frames: [frames_in_flight]Frame = @splat(.{}),
    frame: usize = 0,
    buffer_used: usize = 0,
    pool: ?*anyopaque = null,
    cmd: ?objc.Object = null,
    encoder: ?objc.Object = null,
    drawable: ?objc.Object = null,
    screen_cleared: bool = false,
    target: ?dvui.TextureTarget = null,
    screen_w: u32 = 0,
    screen_h: u32 = 0,

    pub fn init(_: std.mem.Allocator, view: *zpugl.View) !Renderer {
        const layer = obj(@ptrCast(@alignCast(view.getContext() orelse return error.NoMetalLayer)));
        const device = obj(MTLCreateSystemDefaultDevice() orelse return error.NoMetalDevice);
        layer.msgSend(void, "setDevice:", .{device});
        const queue = obj(device.msgSend(c.id, "newCommandQueue", .{}) orelse return error.NoMetalQueue);

        var err: c.id = null;
        const lib = obj(device.msgSend(c.id, "newLibraryWithSource:options:error:", .{ nsString(shader_src), @as(c.id, null), &err }) orelse {
            if (err) |e| std.log.err("metal shader: {s}", .{obj(e).msgSend(objc.Object, "localizedDescription", .{}).msgSend([*:0]const u8, "UTF8String", .{})});
            return error.MetalShader;
        });
        defer lib.release();

        var self: Renderer = .{
            .view = view,
            .layer = layer,
            .device = device,
            .queue = queue,
            .pipeline_screen = try makePipeline(device, lib, pixel_bgra8),
            .pipeline_target = try makePipeline(device, lib, pixel_rgba8),
            .white = undefined,
        };
        const white = self.textureCreate(&[_]u8{ 255, 255, 255, 255 }, .{ .width = 1, .height = 1 });
        self.white = obj(@ptrCast(@alignCast(white.ptr)));
        return self;
    }

    fn makePipeline(device: objc.Object, lib: objc.Object, format: NSUInteger) !objc.Object {
        const vfn = lib.msgSend(objc.Object, "newFunctionWithName:", .{nsString("vs")});
        defer vfn.release();
        const ffn = lib.msgSend(objc.Object, "newFunctionWithName:", .{nsString("fs")});
        defer ffn.release();

        const vd = cls("MTLVertexDescriptor").msgSend(objc.Object, "vertexDescriptor", .{});
        const attrs = vd.msgSend(objc.Object, "attributes", .{});
        const layout = [_]struct { NSUInteger, NSUInteger }{
            .{ vertex_float2, @offsetOf(dvui.Vertex, "pos") },
            .{ vertex_uchar4_norm, @offsetOf(dvui.Vertex, "col") },
            .{ vertex_float2, @offsetOf(dvui.Vertex, "uv") },
        };
        for (layout, 0..) |l, i| {
            const a = attrs.msgSend(objc.Object, "objectAtIndexedSubscript:", .{@as(NSUInteger, i)});
            a.msgSend(void, "setFormat:", .{l[0]});
            a.msgSend(void, "setOffset:", .{l[1]});
            a.msgSend(void, "setBufferIndex:", .{@as(NSUInteger, 0)});
        }
        vd.msgSend(objc.Object, "layouts", .{}).msgSend(objc.Object, "objectAtIndexedSubscript:", .{@as(NSUInteger, 0)})
            .msgSend(void, "setStride:", .{@as(NSUInteger, @sizeOf(dvui.Vertex))});

        const desc = cls("MTLRenderPipelineDescriptor").msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
        defer desc.release();
        desc.msgSend(void, "setVertexFunction:", .{vfn});
        desc.msgSend(void, "setFragmentFunction:", .{ffn});
        desc.msgSend(void, "setVertexDescriptor:", .{vd});
        const ca = desc.msgSend(objc.Object, "colorAttachments", .{}).msgSend(objc.Object, "objectAtIndexedSubscript:", .{@as(NSUInteger, 0)});
        ca.msgSend(void, "setPixelFormat:", .{format});
        ca.msgSend(void, "setBlendingEnabled:", .{true});
        ca.msgSend(void, "setSourceRGBBlendFactor:", .{blend_one});
        ca.msgSend(void, "setSourceAlphaBlendFactor:", .{blend_one});
        ca.msgSend(void, "setDestinationRGBBlendFactor:", .{blend_one_minus_src_alpha});
        ca.msgSend(void, "setDestinationAlphaBlendFactor:", .{blend_one_minus_src_alpha});

        var err: c.id = null;
        return obj(device.msgSend(c.id, "newRenderPipelineStateWithDescriptor:error:", .{ desc, &err }) orelse return error.MetalPipeline);
    }

    pub fn deinit(self: *Renderer) void {
        self.finishFrame(false);
        for (&self.frames) |*f| {
            f.wait();
            if (f.buffer) |b| b.release();
        }
        for (self.samplers) |s| if (s) |o| o.release();
        self.white.release();
        self.pipeline_screen.release();
        self.pipeline_target.release();
        self.queue.release();
        self.device.release();
    }

    pub fn begin(self: *Renderer, w: u32, h: u32) void {
        self.pool = objc_autoreleasePoolPush();
        self.screen_cleared = false;
        self.target = null;
        self.screen_w = w;
        self.screen_h = h;
        self.frame = (self.frame + 1) % frames_in_flight;
        self.frames[self.frame].wait();
        self.buffer_used = 0;
        self.cmd = self.queue.msgSend(objc.Object, "commandBuffer", .{});
        if ((builtin.os.tag == .ios and !self.view.visible) or w == 0 or h == 0) return;
        const size = self.layer.msgSend(CGSize, "drawableSize", .{});
        if (size.width != @as(f64, @floatFromInt(w)) or size.height != @as(f64, @floatFromInt(h))) {
            self.layer.msgSend(void, "setDrawableSize:", .{CGSize{ .width = @floatFromInt(w), .height = @floatFromInt(h) }});
        }
        self.drawable = obj(self.layer.msgSend(c.id, "nextDrawable", .{}) orelse return);
        self.ensureEncoder();
    }

    pub fn end(self: *Renderer) void {
        self.finishFrame(true);
        objc_autoreleasePoolPop(self.pool);
        self.pool = null;
    }

    fn finishFrame(self: *Renderer, present: bool) void {
        self.endEncoder();
        if (self.cmd) |cmd| {
            if (present) if (self.drawable) |d| cmd.msgSend(void, "presentDrawable:", .{d});
            cmd.msgSend(void, "commit", .{});
            self.frames[self.frame].cmd = cmd.retain();
        }
        self.cmd = null;
        self.drawable = null;
    }

    fn endEncoder(self: *Renderer) void {
        if (self.encoder) |e| e.msgSend(void, "endEncoding", .{});
        self.encoder = null;
    }

    fn passDescriptor(texture: objc.Object, clear: bool, color: MTLClearColor) objc.Object {
        const pass = cls("MTLRenderPassDescriptor").msgSend(objc.Object, "renderPassDescriptor", .{});
        const ca = pass.msgSend(objc.Object, "colorAttachments", .{}).msgSend(objc.Object, "objectAtIndexedSubscript:", .{@as(NSUInteger, 0)});
        ca.msgSend(void, "setTexture:", .{texture});
        ca.msgSend(void, "setLoadAction:", .{if (clear) load_clear else load_load});
        ca.msgSend(void, "setStoreAction:", .{store_store});
        ca.msgSend(void, "setClearColor:", .{color});
        return pass;
    }

    fn ensureEncoder(self: *Renderer) void {
        if (self.encoder != null) return;
        const cmd = self.cmd orelse return;
        const pass = if (self.target) |t|
            passDescriptor(obj(@ptrCast(@alignCast(t.ptr))), false, .{ .r = 0, .g = 0, .b = 0, .a = 0 })
        else blk: {
            const d = self.drawable orelse return;
            const clear = !self.screen_cleared;
            self.screen_cleared = true;
            break :blk passDescriptor(d.msgSend(objc.Object, "texture", .{}), clear, .{ .r = 0, .g = 0.6, .b = 0.8, .a = 1 });
        };
        const enc = cmd.msgSend(objc.Object, "renderCommandEncoderWithDescriptor:", .{pass});
        enc.msgSend(void, "setRenderPipelineState:", .{if (self.target != null) self.pipeline_target else self.pipeline_screen});
        self.encoder = enc;
    }

    fn upload(self: *Renderer, bytes: []const u8) struct { objc.Object, usize } {
        const offset = std.mem.alignForward(usize, self.buffer_used, 16);
        const slot = &self.frames[self.frame].buffer;
        const cap = if (slot.*) |b| b.msgSend(NSUInteger, "length", .{}) else 0;
        if (offset + bytes.len > cap) {
            if (slot.*) |b| b.release();
            const len = @max(1 << 20, std.math.ceilPowerOfTwoAssert(usize, bytes.len) * 2);
            slot.* = obj(self.device.msgSend(c.id, "newBufferWithLength:options:", .{ len, @as(NSUInteger, 0) }));
            self.buffer_used = 0;
            return self.upload(bytes);
        }
        const buf = slot.*.?;
        const contents: [*]u8 = @ptrCast(buf.msgSend(*anyopaque, "contents", .{}));
        @memcpy(contents[offset..][0..bytes.len], bytes);
        self.buffer_used = offset + bytes.len;
        return .{ buf, offset };
    }

    fn sampler(self: *Renderer, texture: ?dvui.Texture) objc.Object {
        const t = texture orelse return self.sampler(.{ .ptr = undefined, .width = 1, .height = 1, .format = .rgba_32, .interpolation = .nearest, .wrap_u = .clamp, .wrap_v = .clamp });
        const key: usize = @as(usize, @intFromBool(t.interpolation == .linear)) | @as(usize, @intFromBool(t.wrap_u == .repeat)) << 1 | @as(usize, @intFromBool(t.wrap_v == .repeat)) << 2;
        if (self.samplers[key]) |s| return s;
        const desc = cls("MTLSamplerDescriptor").msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
        defer desc.release();
        const filter: NSUInteger = @intFromBool(t.interpolation == .linear);
        desc.msgSend(void, "setMinFilter:", .{filter});
        desc.msgSend(void, "setMagFilter:", .{filter});
        desc.msgSend(void, "setSAddressMode:", .{@as(NSUInteger, if (t.wrap_u == .repeat) 2 else 0)});
        desc.msgSend(void, "setTAddressMode:", .{@as(NSUInteger, if (t.wrap_v == .repeat) 2 else 0)});
        const s = self.device.msgSend(objc.Object, "newSamplerStateWithDescriptor:", .{desc});
        self.samplers[key] = s;
        return s;
    }

    pub fn drawClippedTriangles(self: *Renderer, texture: ?dvui.Texture, vtx: []const dvui.Vertex, idx: []const dvui.Vertex.Index, clipr: ?dvui.Rect.Physical) !void {
        self.ensureEncoder();
        const enc = self.encoder orelse return;
        const w: f32 = if (self.target) |t| @floatFromInt(t.width) else @floatFromInt(self.screen_w);
        const h: f32 = if (self.target) |t| @floatFromInt(t.height) else @floatFromInt(self.screen_h);

        const vbuf, const voff = self.upload(std.mem.sliceAsBytes(vtx));
        enc.msgSend(void, "setVertexBuffer:offset:atIndex:", .{ vbuf, voff, @as(NSUInteger, 0) });
        const size = [2]f32{ w, h };
        enc.msgSend(void, "setVertexBytes:length:atIndex:", .{ &size, @as(NSUInteger, @sizeOf(@TypeOf(size))), @as(NSUInteger, 1) });

        const tex = if (texture) |t| obj(@ptrCast(@alignCast(t.ptr))) else self.white;
        enc.msgSend(void, "setFragmentTexture:atIndex:", .{ tex, @as(NSUInteger, 0) });
        enc.msgSend(void, "setFragmentSamplerState:atIndex:", .{ self.sampler(texture), @as(NSUInteger, 0) });

        const fw: f32 = w;
        const fh: f32 = h;
        const r = clipr orelse dvui.Rect.Physical{ .x = 0, .y = 0, .w = fw, .h = fh };
        const x0 = std.math.clamp(r.x, 0, fw);
        const y0 = std.math.clamp(r.y, 0, fh);
        const x1 = std.math.clamp(r.x + r.w, x0, fw);
        const y1 = std.math.clamp(r.y + r.h, y0, fh);
        if (x1 - x0 < 1 or y1 - y0 < 1) return;
        enc.msgSend(void, "setScissorRect:", .{MTLScissorRect{
            .x = @intFromFloat(x0),
            .y = @intFromFloat(y0),
            .width = @intFromFloat(x1 - x0),
            .height = @intFromFloat(y1 - y0),
        }});

        const ibuf, const ioff = self.upload(std.mem.sliceAsBytes(idx));
        enc.msgSend(void, "drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:", .{
            primitive_triangle,
            idx.len,
            if (dvui.Vertex.Index == u16) index_u16 else index_u32,
            ibuf,
            ioff,
        });
    }

    fn newTexture(self: *Renderer, options: dvui.Texture.CreateOptions, usage: NSUInteger) objc.Object {
        const desc = cls("MTLTextureDescriptor").msgSend(objc.Object, "texture2DDescriptorWithPixelFormat:width:height:mipmapped:", .{
            pixel_rgba8,
            @as(NSUInteger, options.width),
            @as(NSUInteger, options.height),
            false,
        });
        desc.msgSend(void, "setUsage:", .{usage});
        return self.device.msgSend(objc.Object, "newTextureWithDescriptor:", .{desc});
    }

    fn region(w: u32, h: u32) MTLRegion {
        return .{ .origin = .{ .x = 0, .y = 0, .z = 0 }, .size = .{ .width = w, .height = h, .depth = 1 } };
    }

    pub fn textureCreate(self: *Renderer, pixels: [*]const u8, options: dvui.Texture.CreateOptions) dvui.Texture {
        const tex = self.newTexture(options, usage_shader_read);
        tex.msgSend(void, "replaceRegion:mipmapLevel:withBytes:bytesPerRow:", .{ region(options.width, options.height), @as(NSUInteger, 0), pixels, @as(NSUInteger, options.width * 4) });
        return .{
            .ptr = @ptrCast(tex.value),
            .width = options.width,
            .height = options.height,
            .format = options.format,
            .interpolation = options.interpolation,
            .wrap_u = options.wrap_u,
            .wrap_v = options.wrap_v,
        };
    }

    pub fn textureUpdate(self: *Renderer, texture: dvui.Texture, pixels: [*]const u8) void {
        const row: NSUInteger = texture.width * 4;
        const len: NSUInteger = row * texture.height;
        const staging = self.device.msgSend(objc.Object, "newBufferWithBytes:length:options:", .{ pixels, len, @as(NSUInteger, 0) });
        defer staging.release();
        self.endEncoder();
        const cmd = self.cmd orelse self.queue.msgSend(objc.Object, "commandBuffer", .{});
        const blit = cmd.msgSend(objc.Object, "blitCommandEncoder", .{});
        const r = region(texture.width, texture.height);
        blit.msgSend(void, "copyFromBuffer:sourceOffset:sourceBytesPerRow:sourceBytesPerImage:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:", .{
            staging,                                @as(NSUInteger, 0), row,                len,      r.size,
            obj(@ptrCast(@alignCast(texture.ptr))), @as(NSUInteger, 0), @as(NSUInteger, 0), r.origin,
        });
        blit.msgSend(void, "endEncoding", .{});
        if (self.cmd == null) cmd.msgSend(void, "commit", .{});
    }

    pub fn textureDestroy(_: *Renderer, texture: dvui.Texture) void {
        obj(@ptrCast(@alignCast(texture.ptr))).release();
    }

    pub fn targetCreate(self: *Renderer, options: dvui.Texture.CreateOptions) dvui.TextureTarget {
        const tex = self.newTexture(options, usage_shader_read | usage_render_target);
        const target: dvui.TextureTarget = .{
            .ptr = @ptrCast(tex.value),
            .width = options.width,
            .height = options.height,
            .format = options.format,
            .interpolation = options.interpolation,
            .wrap_u = options.wrap_u,
            .wrap_v = options.wrap_v,
        };
        self.targetClear(target);
        return target;
    }

    pub fn targetClear(self: *Renderer, target: dvui.TextureTarget) void {
        const own_cmd = self.cmd == null;
        self.endEncoder();
        const cmd = self.cmd orelse self.queue.msgSend(objc.Object, "commandBuffer", .{});
        cmd.msgSend(objc.Object, "renderCommandEncoderWithDescriptor:", .{passDescriptor(obj(@ptrCast(@alignCast(target.ptr))), true, .{ .r = 0, .g = 0, .b = 0, .a = 0 })})
            .msgSend(void, "endEncoding", .{});
        if (own_cmd) cmd.msgSend(void, "commit", .{});
    }

    pub fn renderTarget(self: *Renderer, target: ?dvui.TextureTarget) void {
        self.endEncoder();
        self.target = target;
    }

    pub fn targetRead(self: *Renderer, target: dvui.TextureTarget, pixels_out: [*]u8) void {
        self.endEncoder();
        const tex = obj(@ptrCast(@alignCast(target.ptr)));
        const cmd = self.cmd orelse self.queue.msgSend(objc.Object, "commandBuffer", .{});
        if (builtin.os.tag == .macos) {
            const blit = cmd.msgSend(objc.Object, "blitCommandEncoder", .{});
            blit.msgSend(void, "synchronizeResource:", .{tex});
            blit.msgSend(void, "endEncoding", .{});
        }
        cmd.msgSend(void, "commit", .{});
        cmd.msgSend(void, "waitUntilCompleted", .{});
        if (self.cmd != null) self.cmd = self.queue.msgSend(objc.Object, "commandBuffer", .{});
        tex.msgSend(void, "getBytes:bytesPerRow:fromRegion:mipmapLevel:", .{ pixels_out, @as(NSUInteger, target.width * 4), region(target.width, target.height), @as(NSUInteger, 0) });
    }
};
