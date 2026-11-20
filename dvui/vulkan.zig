const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
const zpugl = @import("zpugl");
const zv = zpugl.vulkan;

const log = std.log.scoped(.zpugl_vulkan);

const VkInstance = zv.VkInstance;
const PhysicalDevice = *opaque {};
const Device = zv.VkDevice;
const Queue = *opaque {};
const Cmd = *opaque {};
const Surface = zv.VkSurfaceKHR;
const Handle = u64;
const Result = zv.VkResult;
const Name = [*:0]const u8;

const success: Result = 0;
const incomplete: Result = 5;
const suboptimal: Result = 1000001003;
const out_of_date: Result = -1000001004;
const surface_lost: Result = -1000000000;
const pool_out_of_memory: Result = -1000069000;
const pool_fragmented: Result = -12;

const api_1_2: u32 = (1 << 22) | (2 << 12);
const format_rgba8: i32 = 37;
const format_bgra8: i32 = 44;
const layout_undefined: i32 = 0;
const layout_color: i32 = 2;
const layout_shader_read: i32 = 5;
const layout_transfer_src: i32 = 6;
const layout_transfer_dst: i32 = 7;
const layout_present: i32 = 1000001002;
const access_shader_read: u32 = 0x20;
const access_color_read: u32 = 0x80;
const access_color_write: u32 = 0x100;
const access_transfer_read: u32 = 0x800;
const access_transfer_write: u32 = 0x1000;
const access_host_read: u32 = 0x2000;
const stage_top: u32 = 0x1;
const stage_fragment: u32 = 0x80;
const stage_color_output: u32 = 0x400;
const stage_transfer: u32 = 0x1000;
const stage_host: u32 = 0x4000;
const usage_transfer_src: u32 = 0x1;
const usage_transfer_dst: u32 = 0x2;
const usage_sampled: u32 = 0x4;
const usage_color_attachment: u32 = 0x10;
const usage_index: u32 = 0x40;
const usage_vertex: u32 = 0x80;
const mem_device_local: u32 = 0x1;
const mem_host_visible: u32 = 0x2;
const mem_host_coherent: u32 = 0x4;
const queue_graphics: u32 = 0x1;
const shader_vertex: u32 = 0x1;
const shader_fragment: u32 = 0x10;
const descriptor_image_sampler: i32 = 1;
const present_mailbox: i32 = 1;
const present_fifo: i32 = 2;
const no_timeout = std.math.maxInt(u64);
const frames_in_flight = 2;
const max_images = 8;
const sets_per_pool = 256;

const vert_spv align(4) = @embedFile("vulkan.vert.spv").*;
const frag_spv align(4) = @embedFile("vulkan.frag.spv").*;

const Extent2D = extern struct { width: u32, height: u32 };
const Extent3D = extern struct { width: u32, height: u32, depth: u32 };
const Offset2D = extern struct { x: i32 = 0, y: i32 = 0 };
const Offset3D = extern struct { x: i32 = 0, y: i32 = 0, z: i32 = 0 };
const Rect2D = extern struct { offset: Offset2D = .{}, extent: Extent2D };
const Viewport = extern struct { x: f32 = 0, y: f32 = 0, width: f32, height: f32, min_depth: f32 = 0, max_depth: f32 = 1 };

const ApplicationInfo = extern struct {
    s_type: i32 = 0,
    next: ?*const anyopaque = null,
    app_name: ?Name = null,
    app_version: u32 = 0,
    engine_name: ?Name = null,
    engine_version: u32 = 0,
    api_version: u32,
};

const InstanceCreateInfo = extern struct {
    s_type: i32 = 1,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    app_info: ?*const ApplicationInfo,
    layer_count: u32 = 0,
    layers: ?[*]const Name = null,
    extension_count: u32,
    extensions: [*]const Name,
};

const ExtensionProperties = extern struct { name: [256]u8, spec_version: u32 };
const LayerProperties = extern struct { name: [256]u8, spec_version: u32, impl_version: u32, description: [256]u8 };

const PhysicalDeviceProperties = extern struct {
    api_version: u32,
    driver_version: u32,
    vendor_id: u32,
    device_id: u32,
    device_type: i32,
    name: [256]u8,
    rest: [1024]u8 align(8),
};

const MemoryType = extern struct { flags: u32, heap: u32 };
const MemoryHeap = extern struct { size: u64, flags: u32 };
const MemoryProperties = extern struct {
    type_count: u32,
    types: [32]MemoryType,
    heap_count: u32,
    heaps: [16]MemoryHeap,
};

const QueueFamilyProperties = extern struct { flags: u32, count: u32, timestamp_bits: u32, granularity: Extent3D };

const DeviceQueueCreateInfo = extern struct {
    s_type: i32 = 2,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    family: u32,
    count: u32 = 1,
    priorities: [*]const f32,
};

const DeviceCreateInfo = extern struct {
    s_type: i32 = 3,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    queue_info_count: u32 = 1,
    queue_infos: [*]const DeviceQueueCreateInfo,
    layer_count: u32 = 0,
    layers: ?[*]const Name = null,
    extension_count: u32,
    extensions: [*]const Name,
    features: ?*const anyopaque = null,
};

const SurfaceCapabilities = extern struct {
    min_images: u32,
    max_images: u32,
    current_extent: Extent2D,
    min_extent: Extent2D,
    max_extent: Extent2D,
    max_layers: u32,
    transforms: u32,
    current_transform: u32,
    composite_alpha: u32,
    usage: u32,
};

const SurfaceFormat = extern struct { format: i32, color_space: i32 };

const SwapchainCreateInfo = extern struct {
    s_type: i32 = 1000001000,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    surface: Surface,
    min_images: u32,
    format: i32,
    color_space: i32,
    extent: Extent2D,
    layers: u32 = 1,
    usage: u32,
    sharing: i32 = 0,
    family_count: u32 = 0,
    families: ?[*]const u32 = null,
    transform: u32,
    composite_alpha: u32,
    present_mode: i32,
    clipped: u32 = 1,
    old: Handle,
};

const PresentInfo = extern struct {
    s_type: i32 = 1000001001,
    next: ?*const anyopaque = null,
    wait_count: u32 = 1,
    wait: [*]const Handle,
    swapchain_count: u32 = 1,
    swapchains: [*]const Handle,
    indices: [*]const u32,
    results: ?[*]Result = null,
};

const SubmitInfo = extern struct {
    s_type: i32 = 4,
    next: ?*const anyopaque = null,
    wait_count: u32 = 0,
    wait: ?[*]const Handle = null,
    wait_stages: ?[*]const u32 = null,
    cmd_count: u32 = 1,
    cmds: [*]const Cmd,
    signal_count: u32 = 0,
    signal: ?[*]const Handle = null,
};

const MemoryAllocateInfo = extern struct { s_type: i32 = 5, next: ?*const anyopaque = null, size: u64, type_index: u32 };
const MemoryRequirements = extern struct { size: u64, alignment: u64, type_bits: u32 };
const FenceCreateInfo = extern struct { s_type: i32 = 8, next: ?*const anyopaque = null, flags: u32 = 1 };
const SemaphoreCreateInfo = extern struct { s_type: i32 = 9, next: ?*const anyopaque = null, flags: u32 = 0 };

const BufferCreateInfo = extern struct {
    s_type: i32 = 12,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    size: u64,
    usage: u32,
    sharing: i32 = 0,
    family_count: u32 = 0,
    families: ?[*]const u32 = null,
};

const ImageCreateInfo = extern struct {
    s_type: i32 = 14,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    image_type: i32 = 1,
    format: i32 = format_rgba8,
    extent: Extent3D,
    mip_levels: u32 = 1,
    array_layers: u32 = 1,
    samples: u32 = 1,
    tiling: i32 = 0,
    usage: u32,
    sharing: i32 = 0,
    family_count: u32 = 0,
    families: ?[*]const u32 = null,
    initial_layout: i32 = layout_undefined,
};

const SubresourceRange = extern struct { aspect: u32 = 1, base_mip: u32 = 0, mip_count: u32 = 1, base_layer: u32 = 0, layer_count: u32 = 1 };
const SubresourceLayers = extern struct { aspect: u32 = 1, mip: u32 = 0, base_layer: u32 = 0, layer_count: u32 = 1 };

const ImageViewCreateInfo = extern struct {
    s_type: i32 = 15,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    image: Handle,
    view_type: i32 = 1,
    format: i32,
    components: [4]i32 = @splat(0),
    range: SubresourceRange = .{},
};

const ShaderModuleCreateInfo = extern struct {
    s_type: i32 = 16,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    size: usize,
    code: [*]const u32,
};

const ShaderStage = extern struct {
    s_type: i32 = 18,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    stage: u32,
    module: Handle,
    name: Name,
    specialization: ?*const anyopaque = null,
};

const VertexBinding = extern struct { binding: u32, stride: u32, rate: i32 = 0 };
const VertexAttribute = extern struct { location: u32, binding: u32 = 0, format: i32, offset: u32 };

const VertexInputState = extern struct {
    s_type: i32 = 19,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    binding_count: u32,
    bindings: [*]const VertexBinding,
    attribute_count: u32,
    attributes: [*]const VertexAttribute,
};

const InputAssemblyState = extern struct { s_type: i32 = 20, next: ?*const anyopaque = null, flags: u32 = 0, topology: i32 = 3, restart: u32 = 0 };

const ViewportState = extern struct {
    s_type: i32 = 22,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    viewport_count: u32 = 1,
    viewports: ?*const Viewport = null,
    scissor_count: u32 = 1,
    scissors: ?*const Rect2D = null,
};

const RasterizationState = extern struct {
    s_type: i32 = 23,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    depth_clamp: u32 = 0,
    discard: u32 = 0,
    polygon_mode: i32 = 0,
    cull_mode: u32 = 0,
    front_face: i32 = 0,
    depth_bias: u32 = 0,
    depth_bias_constant: f32 = 0,
    depth_bias_clamp: f32 = 0,
    depth_bias_slope: f32 = 0,
    line_width: f32 = 1,
};

const MultisampleState = extern struct {
    s_type: i32 = 24,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    samples: u32 = 1,
    sample_shading: u32 = 0,
    min_sample_shading: f32 = 0,
    sample_mask: ?*const u32 = null,
    alpha_to_coverage: u32 = 0,
    alpha_to_one: u32 = 0,
};

const BlendAttachment = extern struct {
    enable: u32 = 1,
    src_color: i32 = 1,
    dst_color: i32 = 7,
    color_op: i32 = 0,
    src_alpha: i32 = 1,
    dst_alpha: i32 = 7,
    alpha_op: i32 = 0,
    write_mask: u32 = 0xf,
};

const ColorBlendState = extern struct {
    s_type: i32 = 26,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    logic_op_enable: u32 = 0,
    logic_op: i32 = 0,
    attachment_count: u32 = 1,
    attachments: [*]const BlendAttachment,
    constants: [4]f32 = @splat(0),
};

const DynamicState = extern struct { s_type: i32 = 27, next: ?*const anyopaque = null, flags: u32 = 0, count: u32, states: [*]const i32 };

const GraphicsPipelineCreateInfo = extern struct {
    s_type: i32 = 28,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    stage_count: u32,
    stages: [*]const ShaderStage,
    vertex_input: *const VertexInputState,
    input_assembly: *const InputAssemblyState,
    tessellation: ?*const anyopaque = null,
    viewport: *const ViewportState,
    rasterization: *const RasterizationState,
    multisample: *const MultisampleState,
    depth_stencil: ?*const anyopaque = null,
    color_blend: *const ColorBlendState,
    dynamic: *const DynamicState,
    layout: Handle,
    render_pass: Handle,
    subpass: u32 = 0,
    base: Handle = 0,
    base_index: i32 = -1,
};

const PushConstantRange = extern struct { stages: u32, offset: u32, size: u32 };

const PipelineLayoutCreateInfo = extern struct {
    s_type: i32 = 30,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    set_layout_count: u32 = 1,
    set_layouts: [*]const Handle,
    push_count: u32 = 1,
    push_ranges: [*]const PushConstantRange,
};

const SamplerCreateInfo = extern struct {
    s_type: i32 = 31,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    mag_filter: i32,
    min_filter: i32,
    mipmap_mode: i32,
    address_u: i32,
    address_v: i32,
    address_w: i32 = 2,
    lod_bias: f32 = 0,
    anisotropy: u32 = 0,
    max_anisotropy: f32 = 1,
    compare: u32 = 0,
    compare_op: i32 = 0,
    min_lod: f32 = 0,
    max_lod: f32 = 0.25,
    border: i32 = 0,
    unnormalized: u32 = 0,
};

const SetLayoutBinding = extern struct { binding: u32, kind: i32, count: u32 = 1, stages: u32, immutable_samplers: ?[*]const Handle = null };

const SetLayoutCreateInfo = extern struct {
    s_type: i32 = 32,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    binding_count: u32 = 1,
    bindings: [*]const SetLayoutBinding,
};

const PoolSize = extern struct { kind: i32, count: u32 };

const DescriptorPoolCreateInfo = extern struct {
    s_type: i32 = 33,
    next: ?*const anyopaque = null,
    flags: u32 = 1,
    max_sets: u32,
    size_count: u32 = 1,
    sizes: [*]const PoolSize,
};

const SetAllocateInfo = extern struct {
    s_type: i32 = 34,
    next: ?*const anyopaque = null,
    pool: Handle,
    count: u32 = 1,
    layouts: [*]const Handle,
};

const DescriptorImageInfo = extern struct { sampler: Handle, view: Handle, layout: i32 };

const WriteDescriptorSet = extern struct {
    s_type: i32 = 35,
    next: ?*const anyopaque = null,
    set: Handle,
    binding: u32,
    element: u32 = 0,
    count: u32 = 1,
    kind: i32,
    images: ?[*]const DescriptorImageInfo,
    buffers: ?*const anyopaque = null,
    texel_views: ?*const anyopaque = null,
};

const AttachmentDescription = extern struct {
    flags: u32 = 0,
    format: i32,
    samples: u32 = 1,
    load: i32,
    store: i32 = 0,
    stencil_load: i32 = 2,
    stencil_store: i32 = 1,
    initial_layout: i32,
    final_layout: i32,
};

const AttachmentReference = extern struct { attachment: u32, layout: i32 };

const SubpassDescription = extern struct {
    flags: u32 = 0,
    bind_point: i32 = 0,
    input_count: u32 = 0,
    inputs: ?[*]const AttachmentReference = null,
    color_count: u32 = 1,
    colors: [*]const AttachmentReference,
    resolves: ?[*]const AttachmentReference = null,
    depth_stencil: ?*const AttachmentReference = null,
    preserve_count: u32 = 0,
    preserves: ?[*]const u32 = null,
};

const SubpassDependency = extern struct {
    src_subpass: u32,
    dst_subpass: u32,
    src_stages: u32,
    dst_stages: u32,
    src_access: u32,
    dst_access: u32,
    flags: u32 = 0,
};

const RenderPassCreateInfo = extern struct {
    s_type: i32 = 38,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    attachment_count: u32 = 1,
    attachments: [*]const AttachmentDescription,
    subpass_count: u32 = 1,
    subpasses: [*]const SubpassDescription,
    dependency_count: u32 = 2,
    dependencies: [*]const SubpassDependency,
};

const FramebufferCreateInfo = extern struct {
    s_type: i32 = 37,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    render_pass: Handle,
    attachment_count: u32 = 1,
    attachments: [*]const Handle,
    width: u32,
    height: u32,
    layers: u32 = 1,
};

const CommandPoolCreateInfo = extern struct { s_type: i32 = 39, next: ?*const anyopaque = null, flags: u32 = 2, family: u32 };
const CommandBufferAllocateInfo = extern struct { s_type: i32 = 40, next: ?*const anyopaque = null, pool: Handle, level: i32 = 0, count: u32 };
const CommandBufferBeginInfo = extern struct { s_type: i32 = 42, next: ?*const anyopaque = null, flags: u32 = 1, inheritance: ?*const anyopaque = null };

const RenderPassBeginInfo = extern struct {
    s_type: i32 = 43,
    next: ?*const anyopaque = null,
    render_pass: Handle,
    framebuffer: Handle,
    area: Rect2D,
    clear_count: u32 = 1,
    clears: [*]const [4]f32,
};

const ImageMemoryBarrier = extern struct {
    s_type: i32 = 45,
    next: ?*const anyopaque = null,
    src_access: u32,
    dst_access: u32,
    old_layout: i32,
    new_layout: i32,
    src_family: u32 = ~@as(u32, 0),
    dst_family: u32 = ~@as(u32, 0),
    image: Handle,
    range: SubresourceRange = .{},
};

const MemoryBarrier = extern struct { s_type: i32 = 46, next: ?*const anyopaque = null, src_access: u32, dst_access: u32 };

const BufferImageCopy = extern struct {
    offset: u64 = 0,
    row_length: u32,
    image_height: u32 = 0,
    layers: SubresourceLayers = .{},
    image_offset: Offset3D,
    image_extent: Extent3D,
};

fn Fn(comptime T: type) type {
    return *const T;
}

const GlobalFns = struct {
    vkCreateInstance: Fn(fn (*const InstanceCreateInfo, ?*const anyopaque, *VkInstance) callconv(.c) Result),
    vkEnumerateInstanceExtensionProperties: Fn(fn (?Name, *u32, ?[*]ExtensionProperties) callconv(.c) Result),
    vkEnumerateInstanceLayerProperties: Fn(fn (*u32, ?[*]LayerProperties) callconv(.c) Result),
};

const InstanceFns = struct {
    vkDestroyInstance: Fn(fn (VkInstance, ?*const anyopaque) callconv(.c) void),
    vkEnumeratePhysicalDevices: Fn(fn (VkInstance, *u32, ?[*]PhysicalDevice) callconv(.c) Result),
    vkGetPhysicalDeviceProperties: Fn(fn (PhysicalDevice, *PhysicalDeviceProperties) callconv(.c) void),
    vkGetPhysicalDeviceMemoryProperties: Fn(fn (PhysicalDevice, *MemoryProperties) callconv(.c) void),
    vkGetPhysicalDeviceQueueFamilyProperties: Fn(fn (PhysicalDevice, *u32, ?[*]QueueFamilyProperties) callconv(.c) void),
    vkGetPhysicalDeviceSurfaceSupportKHR: Fn(fn (PhysicalDevice, u32, Surface, *u32) callconv(.c) Result),
    vkGetPhysicalDeviceSurfaceCapabilitiesKHR: Fn(fn (PhysicalDevice, Surface, *SurfaceCapabilities) callconv(.c) Result),
    vkGetPhysicalDeviceSurfaceFormatsKHR: Fn(fn (PhysicalDevice, Surface, *u32, ?[*]SurfaceFormat) callconv(.c) Result),
    vkGetPhysicalDeviceSurfacePresentModesKHR: Fn(fn (PhysicalDevice, Surface, *u32, ?[*]i32) callconv(.c) Result),
    vkEnumerateDeviceExtensionProperties: Fn(fn (PhysicalDevice, ?Name, *u32, ?[*]ExtensionProperties) callconv(.c) Result),
    vkCreateDevice: Fn(fn (PhysicalDevice, *const DeviceCreateInfo, ?*const anyopaque, *Device) callconv(.c) Result),
    vkDestroySurfaceKHR: Fn(fn (VkInstance, Surface, ?*const anyopaque) callconv(.c) void),
};

const DeviceFns = struct {
    vkDestroyDevice: Fn(fn (Device, ?*const anyopaque) callconv(.c) void),
    vkGetDeviceQueue: Fn(fn (Device, u32, u32, *Queue) callconv(.c) void),
    vkDeviceWaitIdle: Fn(fn (Device) callconv(.c) Result),
    vkCreateSwapchainKHR: Fn(fn (Device, *const SwapchainCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroySwapchainKHR: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkGetSwapchainImagesKHR: Fn(fn (Device, Handle, *u32, ?[*]Handle) callconv(.c) Result),
    vkAcquireNextImageKHR: Fn(fn (Device, Handle, u64, Handle, Handle, *u32) callconv(.c) Result),
    vkQueuePresentKHR: Fn(fn (Queue, *const PresentInfo) callconv(.c) Result),
    vkQueueSubmit: Fn(fn (Queue, u32, [*]const SubmitInfo, Handle) callconv(.c) Result),
    vkCreateCommandPool: Fn(fn (Device, *const CommandPoolCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroyCommandPool: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkAllocateCommandBuffers: Fn(fn (Device, *const CommandBufferAllocateInfo, [*]Cmd) callconv(.c) Result),
    vkBeginCommandBuffer: Fn(fn (Cmd, *const CommandBufferBeginInfo) callconv(.c) Result),
    vkEndCommandBuffer: Fn(fn (Cmd) callconv(.c) Result),
    vkCreateSemaphore: Fn(fn (Device, *const SemaphoreCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroySemaphore: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkCreateFence: Fn(fn (Device, *const FenceCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroyFence: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkWaitForFences: Fn(fn (Device, u32, [*]const Handle, u32, u64) callconv(.c) Result),
    vkResetFences: Fn(fn (Device, u32, [*]const Handle) callconv(.c) Result),
    vkCreateBuffer: Fn(fn (Device, *const BufferCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroyBuffer: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkGetBufferMemoryRequirements: Fn(fn (Device, Handle, *MemoryRequirements) callconv(.c) void),
    vkBindBufferMemory: Fn(fn (Device, Handle, Handle, u64) callconv(.c) Result),
    vkCreateImage: Fn(fn (Device, *const ImageCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroyImage: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkGetImageMemoryRequirements: Fn(fn (Device, Handle, *MemoryRequirements) callconv(.c) void),
    vkBindImageMemory: Fn(fn (Device, Handle, Handle, u64) callconv(.c) Result),
    vkAllocateMemory: Fn(fn (Device, *const MemoryAllocateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkFreeMemory: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkMapMemory: Fn(fn (Device, Handle, u64, u64, u32, *?*anyopaque) callconv(.c) Result),
    vkCreateImageView: Fn(fn (Device, *const ImageViewCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroyImageView: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkCreateSampler: Fn(fn (Device, *const SamplerCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroySampler: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkCreateShaderModule: Fn(fn (Device, *const ShaderModuleCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroyShaderModule: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkCreateDescriptorSetLayout: Fn(fn (Device, *const SetLayoutCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroyDescriptorSetLayout: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkCreateDescriptorPool: Fn(fn (Device, *const DescriptorPoolCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroyDescriptorPool: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkAllocateDescriptorSets: Fn(fn (Device, *const SetAllocateInfo, *Handle) callconv(.c) Result),
    vkFreeDescriptorSets: Fn(fn (Device, Handle, u32, [*]const Handle) callconv(.c) Result),
    vkUpdateDescriptorSets: Fn(fn (Device, u32, [*]const WriteDescriptorSet, u32, ?*const anyopaque) callconv(.c) void),
    vkCreatePipelineLayout: Fn(fn (Device, *const PipelineLayoutCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroyPipelineLayout: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkCreateGraphicsPipelines: Fn(fn (Device, Handle, u32, [*]const GraphicsPipelineCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroyPipeline: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkCreateRenderPass: Fn(fn (Device, *const RenderPassCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroyRenderPass: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkCreateFramebuffer: Fn(fn (Device, *const FramebufferCreateInfo, ?*const anyopaque, *Handle) callconv(.c) Result),
    vkDestroyFramebuffer: Fn(fn (Device, Handle, ?*const anyopaque) callconv(.c) void),
    vkCmdBeginRenderPass: Fn(fn (Cmd, *const RenderPassBeginInfo, i32) callconv(.c) void),
    vkCmdEndRenderPass: Fn(fn (Cmd) callconv(.c) void),
    vkCmdBindPipeline: Fn(fn (Cmd, i32, Handle) callconv(.c) void),
    vkCmdBindVertexBuffers: Fn(fn (Cmd, u32, u32, [*]const Handle, [*]const u64) callconv(.c) void),
    vkCmdBindIndexBuffer: Fn(fn (Cmd, Handle, u64, i32) callconv(.c) void),
    vkCmdBindDescriptorSets: Fn(fn (Cmd, i32, Handle, u32, u32, [*]const Handle, u32, ?[*]const u32) callconv(.c) void),
    vkCmdPushConstants: Fn(fn (Cmd, Handle, u32, u32, u32, *const anyopaque) callconv(.c) void),
    vkCmdSetViewport: Fn(fn (Cmd, u32, u32, [*]const Viewport) callconv(.c) void),
    vkCmdSetScissor: Fn(fn (Cmd, u32, u32, [*]const Rect2D) callconv(.c) void),
    vkCmdDrawIndexed: Fn(fn (Cmd, u32, u32, u32, i32, u32) callconv(.c) void),
    vkCmdPipelineBarrier: Fn(fn (Cmd, u32, u32, u32, u32, ?[*]const MemoryBarrier, u32, ?*const anyopaque, u32, ?[*]const ImageMemoryBarrier) callconv(.c) void),
    vkCmdCopyBufferToImage: Fn(fn (Cmd, Handle, Handle, i32, u32, [*]const BufferImageCopy) callconv(.c) void),
    vkCmdCopyImageToBuffer: Fn(fn (Cmd, Handle, i32, Handle, u32, [*]const BufferImageCopy) callconv(.c) void),
    vkCmdClearColorImage: Fn(fn (Cmd, Handle, i32, *const [4]f32, u32, [*]const SubresourceRange) callconv(.c) void),
};

fn load(comptime T: type, ctx: anytype, getter: anytype) error{BackendError}!T {
    var t: T = undefined;
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        @field(t, name) = @ptrCast(getter(ctx, name) orelse {
            log.err("{s} missing", .{name});
            return error.BackendError;
        });
    }
    return t;
}

fn ok(r: Result, comptime what: []const u8) error{BackendError}!void {
    if (r == success) return;
    log.err(what ++ " failed: {d}", .{r});
    return error.BackendError;
}

fn hasName(list: anytype, name: []const u8) bool {
    for (list) |p| if (std.mem.eql(u8, std.mem.sliceTo(&p.name, 0), name)) return true;
    return false;
}

pub const Instance = struct {
    loader: zv.Loader,
    gipa: zv.PFN_vkGetInstanceProcAddr,
    gdpa: zv.PFN_vkGetDeviceProcAddr,
    handle: VkInstance,
    i: InstanceFns,

    pub fn init(world: *zpugl.World) error{BackendError}!Instance {
        var loader = zv.Loader.init(world, null) catch return error.BackendError;
        errdefer loader.deinit();
        const gipa = loader.getInstanceProcAddrFunc() orelse return error.BackendError;
        const gdpa = loader.getDeviceProcAddrFunc() orelse return error.BackendError;
        const g = try load(GlobalFns, @as(?VkInstance, null), gipa);

        var avail: [256]ExtensionProperties = undefined;
        var avail_n: u32 = avail.len;
        const er = g.vkEnumerateInstanceExtensionProperties(null, &avail_n, &avail);
        if (er != success and er != incomplete) try ok(er, "vkEnumerateInstanceExtensionProperties");
        var exts: [4]Name = undefined;
        var n: u32 = 0;
        for (zv.getInstanceExtensions()) |e| {
            if (!hasName(avail[0..avail_n], std.mem.span(e))) {
                log.info("instance extension {s} missing", .{e});
                return error.BackendError;
            }
            std.debug.assert(n < exts.len);
            exts[n] = e;
            n += 1;
        }
        var flags: u32 = 0;
        if (hasName(avail[0..avail_n], "VK_KHR_portability_enumeration")) {
            exts[n] = "VK_KHR_portability_enumeration";
            n += 1;
            flags |= 1;
        }
        const layers = [_]Name{"VK_LAYER_KHRONOS_validation"};
        var layer_props: [64]LayerProperties = undefined;
        var layer_n: u32 = layer_props.len;
        const validation = builtin.mode == .debug and g.vkEnumerateInstanceLayerProperties(&layer_n, &layer_props) == success and hasName(layer_props[0..layer_n], std.mem.span(layers[0]));
        const app: ApplicationInfo = .{ .engine_name = "zpugl", .api_version = api_1_2 };
        var handle: VkInstance = undefined;
        try ok(g.vkCreateInstance(&.{
            .flags = flags,
            .app_info = &app,
            .layer_count = @intFromBool(validation),
            .layers = &layers,
            .extension_count = n,
            .extensions = &exts,
        }, null, &handle), "vkCreateInstance");
        const i = load(InstanceFns, @as(?VkInstance, handle), gipa) catch |err| {
            const destroy: Fn(fn (VkInstance, ?*const anyopaque) callconv(.c) void) = @ptrCast(gipa(handle, "vkDestroyInstance").?);
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
    buffer: Handle = 0,
    memory: Handle = 0,
    mapped: [*]u8 = undefined,
    size: u64 = 0,
};

const Tex = struct {
    image: Handle = 0,
    memory: Handle = 0,
    view: Handle = 0,
    set: Handle = 0,
    pool: Handle = 0,
    framebuffer: Handle = 0,
    width: u32,
    height: u32,
};

const Garbage = union(enum) { tex: *Tex, buf: Buf };

const Frame = struct {
    cmd: Cmd = undefined,
    fence: Handle = 0,
    acquired: Handle = 0,
    ring: Buf = .{},
    used: u64 = 0,
    garbage: std.ArrayList(Garbage) = .empty,
};

const Pass = enum { none, screen, target };

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    view: *zpugl.View,
    inst: Instance,
    physical: PhysicalDevice,
    family: u32,
    device: Device,
    queue: Queue,
    d: DeviceFns,
    mem: MemoryProperties,

    surface: Surface = .null_handle,
    surface_handle: ?*anyopaque = null,
    surface_lost: bool = false,
    format: SurfaceFormat = undefined,
    present_mode: i32 = present_fifo,
    swapchain: Handle = 0,
    images: [max_images]Handle = @splat(0),
    image_views: [max_images]Handle = @splat(0),
    framebuffers: [max_images]Handle = @splat(0),
    rendered: [max_images]Handle = @splat(0),
    image_count: u32 = 0,
    extent: Extent2D = .{ .width = 0, .height = 0 },
    requested: Extent2D = .{ .width = 0, .height = 0 },
    stale: bool = true,

    pass_clear: Handle = 0,
    pass_load: Handle = 0,
    pass_target: Handle = 0,
    set_layout: Handle = 0,
    layout: Handle = 0,
    pipe_screen: Handle = 0,
    pipe_target: Handle = 0,
    samplers: [8]Handle = @splat(0),
    pools: std.ArrayList(Handle) = .empty,

    cmd_pool: Handle = 0,
    frames: [frames_in_flight]Frame = @splat(.{}),
    frame: usize = 0,
    once_cmd: Cmd = undefined,
    once_fence: Handle = 0,
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
        try ok(zv.createSurface(self.inst.gipa, self.view, self.inst.handle, null, &self.surface), "createSurface");
        std.debug.assert(self.surface != .null_handle);
        self.surface_handle = self.view.handle;
        self.surface_lost = false;
    }

    fn pickDevice(self: *Renderer) !void {
        const i = &self.inst.i;
        var devs: [16]PhysicalDevice = undefined;
        var dev_n: u32 = devs.len;
        const er = i.vkEnumeratePhysicalDevices(self.inst.handle, &dev_n, &devs);
        if (er != success and er != incomplete) try ok(er, "vkEnumeratePhysicalDevices");
        const physical, const family = outer: for (devs[0..dev_n]) |dev| {
            var props: PhysicalDeviceProperties = undefined;
            i.vkGetPhysicalDeviceProperties(dev, &props);
            if (props.api_version < api_1_2) continue;
            var fam: [16]QueueFamilyProperties = undefined;
            var fam_n: u32 = fam.len;
            i.vkGetPhysicalDeviceQueueFamilyProperties(dev, &fam_n, &fam);
            for (fam[0..fam_n], 0..) |f, idx| {
                if (f.flags & queue_graphics == 0) continue;
                var present: u32 = 0;
                if (i.vkGetPhysicalDeviceSurfaceSupportKHR(dev, @intCast(idx), self.surface, &present) != success or present == 0) continue;
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

        var formats: [64]SurfaceFormat = undefined;
        var format_n: u32 = formats.len;
        const fr = i.vkGetPhysicalDeviceSurfaceFormatsKHR(physical, self.surface, &format_n, &formats);
        if ((fr != success and fr != incomplete) or format_n == 0) return error.BackendError;
        self.format = for (formats[0..format_n]) |f| {
            if (f.format == format_bgra8 or f.format == format_rgba8) break f;
        } else formats[0];
        var modes: [16]i32 = undefined;
        var mode_n: u32 = modes.len;
        const mr = i.vkGetPhysicalDeviceSurfacePresentModesKHR(physical, self.surface, &mode_n, &modes);
        if (mr == success or mr == incomplete) {
            if (std.mem.indexOfScalar(i32, modes[0..mode_n], present_mailbox) != null) self.present_mode = present_mailbox;
        }

        var dext: [512]ExtensionProperties = undefined;
        var dext_n: u32 = dext.len;
        const dr = i.vkEnumerateDeviceExtensionProperties(physical, null, &dext_n, &dext);
        if (dr != success and dr != incomplete) try ok(dr, "vkEnumerateDeviceExtensionProperties");
        if (!hasName(dext[0..dext_n], "VK_KHR_swapchain")) return error.BackendError;
        const exts = [_]Name{ "VK_KHR_swapchain", "VK_KHR_portability_subset" };
        const prio = [_]f32{1};
        try ok(i.vkCreateDevice(physical, &.{
            .queue_infos = &.{.{ .family = family, .priorities = &prio }},
            .extension_count = if (hasName(dext[0..dext_n], "VK_KHR_portability_subset")) 2 else 1,
            .extensions = &exts,
        }, null, &self.device), "vkCreateDevice");
        self.d = load(DeviceFns, self.device, self.inst.gdpa) catch |err| {
            const destroy: Fn(fn (Device, ?*const anyopaque) callconv(.c) void) = @ptrCast(self.inst.gdpa(self.device, "vkDestroyDevice").?);
            destroy(self.device, null);
            return err;
        };
        self.d.vkGetDeviceQueue(self.device, family, 0, &self.queue);
    }

    fn createObjects(self: *Renderer) !void {
        const d = &self.d;
        const dev = self.device;
        try ok(d.vkCreateCommandPool(dev, &.{ .family = self.family }, null, &self.cmd_pool), "command pool");
        var cmds: [frames_in_flight + 1]Cmd = undefined;
        try ok(d.vkAllocateCommandBuffers(dev, &.{ .pool = self.cmd_pool, .count = cmds.len }, &cmds), "command buffers");
        for (&self.frames, cmds[0..frames_in_flight]) |*f, c| {
            f.cmd = c;
            try ok(d.vkCreateFence(dev, &.{}, null, &f.fence), "fence");
            try ok(d.vkCreateSemaphore(dev, &.{}, null, &f.acquired), "semaphore");
        }
        self.once_cmd = cmds[frames_in_flight];
        try ok(d.vkCreateFence(dev, &.{ .flags = 0 }, null, &self.once_fence), "fence");

        self.pass_clear = try self.createPass(self.format.format, 1, layout_undefined, layout_present);
        self.pass_load = try self.createPass(self.format.format, 0, layout_present, layout_present);
        self.pass_target = try self.createPass(format_rgba8, 0, layout_shader_read, layout_shader_read);

        const binding = [_]SetLayoutBinding{.{ .binding = 1, .kind = descriptor_image_sampler, .stages = shader_fragment }};
        try ok(d.vkCreateDescriptorSetLayout(dev, &.{ .bindings = &binding }, null, &self.set_layout), "descriptor set layout");
        const push = [_]PushConstantRange{.{ .stages = shader_vertex, .offset = 0, .size = 16 }};
        try ok(d.vkCreatePipelineLayout(dev, &.{ .set_layouts = &.{self.set_layout}, .push_ranges = &push }, null, &self.layout), "pipeline layout");

        var vs: Handle = 0;
        try ok(d.vkCreateShaderModule(dev, &.{ .size = vert_spv.len, .code = @ptrCast(&vert_spv) }, null, &vs), "vertex shader");
        defer d.vkDestroyShaderModule(dev, vs, null);
        var fs: Handle = 0;
        try ok(d.vkCreateShaderModule(dev, &.{ .size = frag_spv.len, .code = @ptrCast(&frag_spv) }, null, &fs), "fragment shader");
        defer d.vkDestroyShaderModule(dev, fs, null);
        self.pipe_screen = try self.createPipeline(vs, fs, self.pass_clear);
        self.pipe_target = try self.createPipeline(vs, fs, self.pass_target);

        for (&self.samplers, 0..) |*s, key| {
            const filter: i32 = @intCast(key & 1);
            try ok(d.vkCreateSampler(dev, &.{
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
        for ([_]Handle{ self.pipe_screen, self.pipe_target }) |p| if (p != 0) d.vkDestroyPipeline(dev, p, null);
        if (self.layout != 0) d.vkDestroyPipelineLayout(dev, self.layout, null);
        if (self.set_layout != 0) d.vkDestroyDescriptorSetLayout(dev, self.set_layout, null);
        for ([_]Handle{ self.pass_clear, self.pass_load, self.pass_target }) |p| if (p != 0) d.vkDestroyRenderPass(dev, p, null);
        if (self.cmd_pool != 0) d.vkDestroyCommandPool(dev, self.cmd_pool, null);
    }

    fn createPass(self: *Renderer, format: i32, load_op: i32, initial: i32, final: i32) !Handle {
        const deps = [_]SubpassDependency{
            .{
                .src_subpass = ~@as(u32, 0),
                .dst_subpass = 0,
                .src_stages = stage_color_output | stage_fragment | stage_transfer,
                .dst_stages = stage_color_output,
                .src_access = access_color_write | access_transfer_write,
                .dst_access = access_color_read | access_color_write,
            },
            .{
                .src_subpass = 0,
                .dst_subpass = ~@as(u32, 0),
                .src_stages = stage_color_output,
                .dst_stages = stage_fragment | stage_transfer,
                .src_access = access_color_write,
                .dst_access = access_shader_read | access_transfer_read,
            },
        };
        var pass: Handle = 0;
        try ok(self.d.vkCreateRenderPass(self.device, &.{
            .attachments = &.{.{ .format = format, .load = load_op, .initial_layout = initial, .final_layout = final }},
            .subpasses = &.{.{ .colors = &.{.{ .attachment = 0, .layout = layout_color }} }},
            .dependencies = &deps,
        }, null, &pass), "render pass");
        return pass;
    }

    fn createPipeline(self: *Renderer, vs: Handle, fs: Handle, pass: Handle) !Handle {
        const V = dvui.Vertex;
        const stages = [_]ShaderStage{
            .{ .stage = shader_vertex, .module = vs, .name = "main" },
            .{ .stage = shader_fragment, .module = fs, .name = "main" },
        };
        const attrs = [_]VertexAttribute{
            .{ .location = 0, .format = 103, .offset = @offsetOf(V, "pos") },
            .{ .location = 1, .format = format_rgba8, .offset = @offsetOf(V, "col") },
            .{ .location = 2, .format = 103, .offset = @offsetOf(V, "uv") },
        };
        const dynamic = [_]i32{ 0, 1 };
        var pipe: Handle = 0;
        try ok(self.d.vkCreateGraphicsPipelines(self.device, 0, 1, &.{.{
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
            try ok(self.inst.i.vkGetPhysicalDeviceSurfaceSupportKHR(self.physical, self.family, self.surface, &present), "surface support");
            if (present == 0) return error.BackendError;
        }
        var caps: SurfaceCapabilities = undefined;
        try ok(self.inst.i.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(self.physical, self.surface, &caps), "surface capabilities");
        const extent: Extent2D = if (caps.current_extent.width != std.math.maxInt(u32)) caps.current_extent else .{
            .width = std.math.clamp(width, caps.min_extent.width, caps.max_extent.width),
            .height = std.math.clamp(height, caps.min_extent.height, caps.max_extent.height),
        };
        if (extent.width == 0 or extent.height == 0) return false;
        var count = @max(caps.min_images + 1, frames_in_flight + 1);
        if (caps.max_images != 0) count = @min(count, caps.max_images);
        const alpha: u32 = if (caps.composite_alpha & 1 != 0) 1 else caps.composite_alpha & (~caps.composite_alpha +% 1);
        const old = self.swapchain;
        var swapchain: Handle = 0;
        try ok(self.d.vkCreateSwapchainKHR(self.device, &.{
            .surface = self.surface,
            .min_images = count,
            .format = self.format.format,
            .color_space = self.format.color_space,
            .extent = extent,
            .usage = usage_color_attachment,
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
        if (ir != success and ir != incomplete) try ok(ir, "vkGetSwapchainImagesKHR");
        std.debug.assert(n > 0 and n <= max_images);
        self.image_count = n;
        for (0..n) |k| {
            try ok(self.d.vkCreateImageView(self.device, &.{ .image = self.images[k], .format = self.format.format }, null, &self.image_views[k]), "swapchain image view");
            try ok(self.d.vkCreateFramebuffer(self.device, &.{ .render_pass = self.pass_clear, .attachments = &.{self.image_views[k]}, .width = extent.width, .height = extent.height }, null, &self.framebuffers[k]), "framebuffer");
            if (self.rendered[k] == 0) try ok(self.d.vkCreateSemaphore(self.device, &.{}, null, &self.rendered[k]), "semaphore");
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

    fn allocate(self: *Renderer, req: MemoryRequirements, want: u32, fallback: u32) !Handle {
        const index = self.memoryType(req.type_bits, want) orelse self.memoryType(req.type_bits, fallback) orelse return error.BackendError;
        var memory: Handle = 0;
        try ok(self.d.vkAllocateMemory(self.device, &.{ .size = req.size, .type_index = index }, null, &memory), "vkAllocateMemory");
        return memory;
    }

    fn createBuf(self: *Renderer, size: u64, usage: u32) !Buf {
        var b: Buf = .{ .size = size };
        try ok(self.d.vkCreateBuffer(self.device, &.{ .size = size, .usage = usage }, null, &b.buffer), "vkCreateBuffer");
        errdefer self.d.vkDestroyBuffer(self.device, b.buffer, null);
        var req: MemoryRequirements = undefined;
        self.d.vkGetBufferMemoryRequirements(self.device, b.buffer, &req);
        b.memory = try self.allocate(req, mem_host_visible | mem_host_coherent, mem_host_visible | mem_host_coherent);
        errdefer self.d.vkFreeMemory(self.device, b.memory, null);
        try ok(self.d.vkBindBufferMemory(self.device, b.buffer, b.memory, 0), "vkBindBufferMemory");
        var ptr: ?*anyopaque = null;
        try ok(self.d.vkMapMemory(self.device, b.memory, 0, size, 0, &ptr), "vkMapMemory");
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
            if (r == success) {
                t.pool = pool;
                return;
            }
            if (r != pool_out_of_memory and r != pool_fragmented) try ok(r, "vkAllocateDescriptorSets");
        }
        var pool: Handle = 0;
        try ok(self.d.vkCreateDescriptorPool(self.device, &.{ .max_sets = sets_per_pool, .sizes = &.{.{ .kind = descriptor_image_sampler, .count = sets_per_pool }} }, null, &pool), "vkCreateDescriptorPool");
        self.pools.append(self.allocator, pool) catch |err| {
            self.d.vkDestroyDescriptorPool(self.device, pool, null);
            return err;
        };
        try ok(self.d.vkAllocateDescriptorSets(self.device, &.{ .pool = pool, .layouts = &.{self.set_layout} }, &t.set), "vkAllocateDescriptorSets");
        t.pool = pool;
    }

    fn createTex(self: *Renderer, options: dvui.Texture.CreateOptions, usage: u32) !*Tex {
        std.debug.assert(options.width > 0 and options.height > 0);
        const t = try self.allocator.create(Tex);
        t.* = .{ .width = options.width, .height = options.height };
        errdefer self.destroyTex(t);
        const d = &self.d;
        try ok(d.vkCreateImage(self.device, &.{ .extent = .{ .width = t.width, .height = t.height, .depth = 1 }, .usage = usage }, null, &t.image), "vkCreateImage");
        var req: MemoryRequirements = undefined;
        d.vkGetImageMemoryRequirements(self.device, t.image, &req);
        t.memory = try self.allocate(req, mem_device_local, 0);
        try ok(d.vkBindImageMemory(self.device, t.image, t.memory, 0), "vkBindImageMemory");
        try ok(d.vkCreateImageView(self.device, &.{ .image = t.image, .format = format_rgba8 }, null, &t.view), "vkCreateImageView");
        try self.allocateSet(t);
        const key: usize = @as(usize, @intFromBool(options.interpolation == .linear)) | @as(usize, @intFromBool(options.wrap_u == .repeat)) << 1 | @as(usize, @intFromBool(options.wrap_v == .repeat)) << 2;
        const info = [_]DescriptorImageInfo{.{ .sampler = self.samplers[key], .view = t.view, .layout = layout_shader_read }};
        d.vkUpdateDescriptorSets(self.device, 1, &.{.{ .set = t.set, .binding = 1, .kind = descriptor_image_sampler, .images = &info }}, 0, null);
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

    fn barrier(self: *Renderer, cmd: Cmd, image: Handle, old: i32, new: i32, src_stage: u32, dst_stage: u32, src_access: u32, dst_access: u32) void {
        self.d.vkCmdPipelineBarrier(cmd, src_stage, dst_stage, 0, 0, null, 0, null, 1, &.{.{ .src_access = src_access, .dst_access = dst_access, .old_layout = old, .new_layout = new, .image = image }});
    }

    fn beginOnce(self: *Renderer) !Cmd {
        try ok(self.d.vkBeginCommandBuffer(self.once_cmd, &.{}), "vkBeginCommandBuffer");
        return self.once_cmd;
    }

    fn beginTransfer(self: *Renderer) !Cmd {
        if (!self.recording) return self.beginOnce();
        self.endPass();
        return self.frames[self.frame].cmd;
    }

    fn endTransfer(self: *Renderer) !void {
        if (!self.recording) try self.submitOnce();
    }

    fn submitOnce(self: *Renderer) !void {
        try ok(self.d.vkEndCommandBuffer(self.once_cmd), "vkEndCommandBuffer");
        try ok(self.d.vkQueueSubmit(self.queue, 1, &.{.{ .cmds = &.{self.once_cmd} }}, self.once_fence), "vkQueueSubmit");
        try ok(self.d.vkWaitForFences(self.device, 1, &.{self.once_fence}, 1, no_timeout), "vkWaitForFences");
        try ok(self.d.vkResetFences(self.device, 1, &.{self.once_fence}), "vkResetFences");
    }

    fn upload(self: *Renderer, t: *Tex, pixels: [*]const u8, x: u32, y: u32, w: u32, h: u32, fresh: bool) !void {
        std.debug.assert(x + w <= t.width and y + h <= t.height);
        if (w == 0 or h == 0) return;
        const row: usize = @as(usize, t.width) * 4;
        const staging = try self.createBuf(@as(u64, w) * h * 4, usage_transfer_src);
        defer self.trash(.{ .buf = staging });
        for (0..h) |r| @memcpy(staging.mapped[r * w * 4 ..][0 .. w * 4], pixels[(y + r) * row + x * 4 ..][0 .. w * 4]);
        const cmd = try self.beginTransfer();
        const old: i32 = if (fresh) layout_undefined else layout_shader_read;
        self.barrier(cmd, t.image, old, layout_transfer_dst, stage_fragment | stage_transfer | stage_color_output, stage_transfer, 0, access_transfer_write);
        self.d.vkCmdCopyBufferToImage(cmd, staging.buffer, t.image, layout_transfer_dst, 1, &.{.{
            .row_length = w,
            .image_offset = .{ .x = @intCast(x), .y = @intCast(y) },
            .image_extent = .{ .width = w, .height = h, .depth = 1 },
        }});
        self.barrier(cmd, t.image, layout_transfer_dst, layout_shader_read, stage_transfer, stage_fragment, access_transfer_write, access_shader_read);
        try self.endTransfer();
    }

    pub fn textureCreate(self: *Renderer, pixels: [*]const u8, options: dvui.Texture.CreateOptions) !dvui.Texture {
        const t = try self.createTex(options, usage_sampled | usage_transfer_dst);
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
        const t = try self.createTex(options, usage_sampled | usage_color_attachment | usage_transfer_src | usage_transfer_dst);
        errdefer self.destroyTex(t);
        try ok(self.d.vkCreateFramebuffer(self.device, &.{ .render_pass = self.pass_target, .attachments = &.{t.view}, .width = t.width, .height = t.height }, null, &t.framebuffer), "target framebuffer");
        try self.clear(t, layout_undefined);
        return .cast(texture(t, options));
    }

    fn clear(self: *Renderer, t: *Tex, old: i32) !void {
        const cmd = try self.beginTransfer();
        self.barrier(cmd, t.image, old, layout_transfer_dst, stage_fragment | stage_transfer | stage_color_output, stage_transfer, access_color_write, access_transfer_write);
        self.d.vkCmdClearColorImage(cmd, t.image, layout_transfer_dst, &@splat(0), 1, &.{.{}});
        self.barrier(cmd, t.image, layout_transfer_dst, layout_shader_read, stage_transfer, stage_fragment | stage_color_output, access_transfer_write, access_shader_read | access_color_read | access_color_write);
        try self.endTransfer();
    }

    pub fn targetClear(self: *Renderer, target: dvui.TextureTarget) void {
        self.clear(tex(target.ptr), layout_shader_read) catch {};
    }

    pub fn targetRead(self: *Renderer, target: dvui.TextureTarget, pixels_out: [*]u8) !void {
        if (self.recording) try self.flush();
        const t = tex(target.ptr);
        const size: u64 = @as(u64, t.width) * t.height * 4;
        const staging = try self.createBuf(size, usage_transfer_dst);
        defer self.destroyBuf(staging);
        const cmd = try self.beginOnce();
        self.barrier(cmd, t.image, layout_shader_read, layout_transfer_src, stage_color_output | stage_fragment, stage_transfer, access_color_write, access_transfer_read);
        self.d.vkCmdCopyImageToBuffer(cmd, t.image, layout_transfer_src, staging.buffer, 1, &.{.{
            .row_length = t.width,
            .image_offset = .{},
            .image_extent = .{ .width = t.width, .height = t.height, .depth = 1 },
        }});
        self.barrier(cmd, t.image, layout_transfer_src, layout_shader_read, stage_transfer, stage_fragment, 0, access_shader_read);
        self.d.vkCmdPipelineBarrier(cmd, stage_transfer, stage_host, 0, 1, &.{.{ .src_access = access_transfer_write, .dst_access = access_host_read }}, 0, null, 0, null);
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
        try ok(self.d.vkWaitForFences(self.device, 1, &.{f.fence}, 1, no_timeout), "vkWaitForFences");
        for (f.garbage.items) |g| self.destroyGarbage(g);
        f.garbage.clearRetainingCapacity();
        f.used = 0;
        try ok(self.d.vkBeginCommandBuffer(f.cmd, &.{}), "vkBeginCommandBuffer");
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
        const r = self.d.vkAcquireNextImageKHR(self.device, self.swapchain, no_timeout, f.acquired, 0, &index);
        switch (r) {
            success, suboptimal => {},
            out_of_date => {
                self.stale = true;
                return;
            },
            surface_lost => {
                self.surface_lost = true;
                return;
            },
            else => {
                ok(r, "vkAcquireNextImageKHR") catch {};
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
        try ok(self.d.vkEndCommandBuffer(f.cmd), "vkEndCommandBuffer");
        const wait = self.image != null and !self.acquire_waited;
        const wait_stage = [_]u32{stage_color_output};
        self.acquire_waited = self.acquire_waited or wait;
        try ok(self.d.vkResetFences(self.device, 1, &.{f.fence}), "vkResetFences");
        try ok(self.d.vkQueueSubmit(self.queue, 1, &.{.{
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
        try ok(self.d.vkWaitForFences(self.device, 1, &.{f.fence}, 1, no_timeout), "vkWaitForFences");
        try ok(self.d.vkBeginCommandBuffer(f.cmd, &.{}), "vkBeginCommandBuffer");
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
            success => {},
            suboptimal, out_of_date => self.stale = true,
            surface_lost => self.surface_lost = true,
            else => try ok(r, "vkQueuePresentKHR"),
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
        const pass: Handle, const fb: Handle, const w: u32, const h: u32 = switch (want) {
            .screen => .{ if (self.screen_started) self.pass_load else self.pass_clear, self.framebuffers[self.image.?], self.extent.width, self.extent.height },
            .target => .{ self.pass_target, self.target.?.framebuffer, self.target.?.width, self.target.?.height },
            .none => unreachable,
        };
        if (want == .screen) self.screen_started = true;
        self.d.vkCmdBeginRenderPass(cmd, &.{ .render_pass = pass, .framebuffer = fb, .area = .{ .extent = .{ .width = w, .height = h } }, .clears = &clear_color }, 0);
        self.d.vkCmdBindPipeline(cmd, 0, if (want == .screen) self.pipe_screen else self.pipe_target);
        self.d.vkCmdSetViewport(cmd, 0, 1, &.{.{ .width = @floatFromInt(w), .height = @floatFromInt(h) }});
        const push = [4]f32{ 2.0 / @as(f32, @floatFromInt(w)), 2.0 / @as(f32, @floatFromInt(h)), -1, -1 };
        self.d.vkCmdPushConstants(cmd, self.layout, shader_vertex, 0, @sizeOf(@TypeOf(push)), &push);
        self.pass = want;
    }

    fn reserve(self: *Renderer, len: u64) !void {
        const f = &self.frames[self.frame];
        if (std.mem.alignForward(u64, f.used, 16) + len <= f.ring.size) return;
        const size = @max(1 << 20, std.math.ceilPowerOfTwoAssert(u64, (f.used + len) * 2));
        const ring = try self.createBuf(size, usage_vertex | usage_index);
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
