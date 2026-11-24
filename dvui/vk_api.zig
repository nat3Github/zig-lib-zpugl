const std = @import("std");
const zpugl = @import("zpugl");
const zv = zpugl.vulkan;

const log = std.log.scoped(.zpugl_vulkan);

pub const VkInstance = zv.VkInstance;
pub const PhysicalDevice = *opaque {};
pub const Device = zv.VkDevice;
pub const Queue = *opaque {};
pub const Cmd = *opaque {};
pub const Surface = zv.VkSurfaceKHR;
pub const Handle = u64;
pub const Result = zv.VkResult;
pub const Name = [*:0]const u8;

pub const success: Result = 0;
pub const incomplete: Result = 5;
pub const suboptimal: Result = 1000001003;
pub const out_of_date: Result = -1000001004;
pub const surface_lost: Result = -1000000000;
pub const pool_out_of_memory: Result = -1000069000;
pub const pool_fragmented: Result = -12;

pub const api_1_0: u32 = 1 << 22;
pub const format_rgba8: i32 = 37;
pub const format_bgra8: i32 = 44;
pub const layout_undefined: i32 = 0;
pub const layout_color: i32 = 2;
pub const layout_shader_read: i32 = 5;
pub const layout_transfer_src: i32 = 6;
pub const layout_transfer_dst: i32 = 7;
pub const layout_present: i32 = 1000001002;
pub const access_shader_read: u32 = 0x20;
pub const access_color_read: u32 = 0x80;
pub const access_color_write: u32 = 0x100;
pub const access_transfer_read: u32 = 0x800;
pub const access_transfer_write: u32 = 0x1000;
pub const access_host_read: u32 = 0x2000;
pub const stage_top: u32 = 0x1;
pub const stage_fragment: u32 = 0x80;
pub const stage_color_output: u32 = 0x400;
pub const stage_transfer: u32 = 0x1000;
pub const stage_host: u32 = 0x4000;
pub const usage_transfer_src: u32 = 0x1;
pub const usage_transfer_dst: u32 = 0x2;
pub const usage_sampled: u32 = 0x4;
pub const usage_color_attachment: u32 = 0x10;
pub const usage_index: u32 = 0x40;
pub const usage_vertex: u32 = 0x80;
pub const mem_device_local: u32 = 0x1;
pub const mem_host_visible: u32 = 0x2;
pub const mem_host_coherent: u32 = 0x4;
pub const queue_graphics: u32 = 0x1;
pub const shader_vertex: u32 = 0x1;
pub const shader_fragment: u32 = 0x10;
pub const descriptor_image_sampler: i32 = 1;
pub const present_mailbox: i32 = 1;
pub const present_fifo: i32 = 2;
pub const no_timeout = std.math.maxInt(u64);

pub const Extent2D = extern struct { width: u32, height: u32 };
pub const Extent3D = extern struct { width: u32, height: u32, depth: u32 };
pub const Offset2D = extern struct { x: i32 = 0, y: i32 = 0 };
pub const Offset3D = extern struct { x: i32 = 0, y: i32 = 0, z: i32 = 0 };
pub const Rect2D = extern struct { offset: Offset2D = .{}, extent: Extent2D };
pub const Viewport = extern struct { x: f32 = 0, y: f32 = 0, width: f32, height: f32, min_depth: f32 = 0, max_depth: f32 = 1 };

pub const ApplicationInfo = extern struct {
    s_type: i32 = 0,
    next: ?*const anyopaque = null,
    app_name: ?Name = null,
    app_version: u32 = 0,
    engine_name: ?Name = null,
    engine_version: u32 = 0,
    api_version: u32,
};

pub const InstanceCreateInfo = extern struct {
    s_type: i32 = 1,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    app_info: ?*const ApplicationInfo,
    layer_count: u32 = 0,
    layers: ?[*]const Name = null,
    extension_count: u32,
    extensions: [*]const Name,
};

pub const ExtensionProperties = extern struct { name: [256]u8, spec_version: u32 };
pub const LayerProperties = extern struct { name: [256]u8, spec_version: u32, impl_version: u32, description: [256]u8 };

pub const PhysicalDeviceProperties = extern struct {
    api_version: u32,
    driver_version: u32,
    vendor_id: u32,
    device_id: u32,
    device_type: i32,
    name: [256]u8,
    rest: [1024]u8 align(8),
};

pub const MemoryType = extern struct { flags: u32, heap: u32 };
pub const MemoryHeap = extern struct { size: u64, flags: u32 };
pub const MemoryProperties = extern struct {
    type_count: u32,
    types: [32]MemoryType,
    heap_count: u32,
    heaps: [16]MemoryHeap,
};

pub const QueueFamilyProperties = extern struct { flags: u32, count: u32, timestamp_bits: u32, granularity: Extent3D };

pub const DeviceQueueCreateInfo = extern struct {
    s_type: i32 = 2,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    family: u32,
    count: u32 = 1,
    priorities: [*]const f32,
};

pub const DeviceCreateInfo = extern struct {
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

pub const SurfaceCapabilities = extern struct {
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

pub const SurfaceFormat = extern struct { format: i32, color_space: i32 };

pub const SwapchainCreateInfo = extern struct {
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

pub const PresentInfo = extern struct {
    s_type: i32 = 1000001001,
    next: ?*const anyopaque = null,
    wait_count: u32 = 1,
    wait: [*]const Handle,
    swapchain_count: u32 = 1,
    swapchains: [*]const Handle,
    indices: [*]const u32,
    results: ?[*]Result = null,
};

pub const SubmitInfo = extern struct {
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

pub const MemoryAllocateInfo = extern struct { s_type: i32 = 5, next: ?*const anyopaque = null, size: u64, type_index: u32 };
pub const MemoryRequirements = extern struct { size: u64, alignment: u64, type_bits: u32 };
pub const FenceCreateInfo = extern struct { s_type: i32 = 8, next: ?*const anyopaque = null, flags: u32 = 1 };
pub const SemaphoreCreateInfo = extern struct { s_type: i32 = 9, next: ?*const anyopaque = null, flags: u32 = 0 };

pub const BufferCreateInfo = extern struct {
    s_type: i32 = 12,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    size: u64,
    usage: u32,
    sharing: i32 = 0,
    family_count: u32 = 0,
    families: ?[*]const u32 = null,
};

pub const ImageCreateInfo = extern struct {
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

pub const SubresourceRange = extern struct { aspect: u32 = 1, base_mip: u32 = 0, mip_count: u32 = 1, base_layer: u32 = 0, layer_count: u32 = 1 };
pub const SubresourceLayers = extern struct { aspect: u32 = 1, mip: u32 = 0, base_layer: u32 = 0, layer_count: u32 = 1 };

pub const ImageViewCreateInfo = extern struct {
    s_type: i32 = 15,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    image: Handle,
    view_type: i32 = 1,
    format: i32,
    components: [4]i32 = @splat(0),
    range: SubresourceRange = .{},
};

pub const ShaderModuleCreateInfo = extern struct {
    s_type: i32 = 16,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    size: usize,
    code: [*]const u32,
};

pub const ShaderStage = extern struct {
    s_type: i32 = 18,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    stage: u32,
    module: Handle,
    name: Name,
    specialization: ?*const anyopaque = null,
};

pub const VertexBinding = extern struct { binding: u32, stride: u32, rate: i32 = 0 };
pub const VertexAttribute = extern struct { location: u32, binding: u32 = 0, format: i32, offset: u32 };

pub const VertexInputState = extern struct {
    s_type: i32 = 19,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    binding_count: u32,
    bindings: [*]const VertexBinding,
    attribute_count: u32,
    attributes: [*]const VertexAttribute,
};

pub const InputAssemblyState = extern struct { s_type: i32 = 20, next: ?*const anyopaque = null, flags: u32 = 0, topology: i32 = 3, restart: u32 = 0 };

pub const ViewportState = extern struct {
    s_type: i32 = 22,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    viewport_count: u32 = 1,
    viewports: ?*const Viewport = null,
    scissor_count: u32 = 1,
    scissors: ?*const Rect2D = null,
};

pub const RasterizationState = extern struct {
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

pub const MultisampleState = extern struct {
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

pub const BlendAttachment = extern struct {
    enable: u32 = 1,
    src_color: i32 = 1,
    dst_color: i32 = 7,
    color_op: i32 = 0,
    src_alpha: i32 = 1,
    dst_alpha: i32 = 7,
    alpha_op: i32 = 0,
    write_mask: u32 = 0xf,
};

pub const ColorBlendState = extern struct {
    s_type: i32 = 26,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    logic_op_enable: u32 = 0,
    logic_op: i32 = 0,
    attachment_count: u32 = 1,
    attachments: [*]const BlendAttachment,
    constants: [4]f32 = @splat(0),
};

pub const DynamicState = extern struct { s_type: i32 = 27, next: ?*const anyopaque = null, flags: u32 = 0, count: u32, states: [*]const i32 };

pub const GraphicsPipelineCreateInfo = extern struct {
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

pub const PushConstantRange = extern struct { stages: u32, offset: u32, size: u32 };

pub const PipelineLayoutCreateInfo = extern struct {
    s_type: i32 = 30,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    set_layout_count: u32 = 1,
    set_layouts: [*]const Handle,
    push_count: u32 = 1,
    push_ranges: [*]const PushConstantRange,
};

pub const SamplerCreateInfo = extern struct {
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

pub const SetLayoutBinding = extern struct { binding: u32, kind: i32, count: u32 = 1, stages: u32, immutable_samplers: ?[*]const Handle = null };

pub const SetLayoutCreateInfo = extern struct {
    s_type: i32 = 32,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    binding_count: u32 = 1,
    bindings: [*]const SetLayoutBinding,
};

pub const PoolSize = extern struct { kind: i32, count: u32 };

pub const DescriptorPoolCreateInfo = extern struct {
    s_type: i32 = 33,
    next: ?*const anyopaque = null,
    flags: u32 = 1,
    max_sets: u32,
    size_count: u32 = 1,
    sizes: [*]const PoolSize,
};

pub const SetAllocateInfo = extern struct {
    s_type: i32 = 34,
    next: ?*const anyopaque = null,
    pool: Handle,
    count: u32 = 1,
    layouts: [*]const Handle,
};

pub const DescriptorImageInfo = extern struct { sampler: Handle, view: Handle, layout: i32 };

pub const WriteDescriptorSet = extern struct {
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

pub const AttachmentDescription = extern struct {
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

pub const AttachmentReference = extern struct { attachment: u32, layout: i32 };

pub const SubpassDescription = extern struct {
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

pub const SubpassDependency = extern struct {
    src_subpass: u32,
    dst_subpass: u32,
    src_stages: u32,
    dst_stages: u32,
    src_access: u32,
    dst_access: u32,
    flags: u32 = 0,
};

pub const RenderPassCreateInfo = extern struct {
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

pub const FramebufferCreateInfo = extern struct {
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

pub const CommandPoolCreateInfo = extern struct { s_type: i32 = 39, next: ?*const anyopaque = null, flags: u32 = 2, family: u32 };
pub const CommandBufferAllocateInfo = extern struct { s_type: i32 = 40, next: ?*const anyopaque = null, pool: Handle, level: i32 = 0, count: u32 };
pub const CommandBufferBeginInfo = extern struct { s_type: i32 = 42, next: ?*const anyopaque = null, flags: u32 = 1, inheritance: ?*const anyopaque = null };

pub const RenderPassBeginInfo = extern struct {
    s_type: i32 = 43,
    next: ?*const anyopaque = null,
    render_pass: Handle,
    framebuffer: Handle,
    area: Rect2D,
    clear_count: u32 = 1,
    clears: [*]const [4]f32,
};

pub const ImageMemoryBarrier = extern struct {
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

pub const MemoryBarrier = extern struct { s_type: i32 = 46, next: ?*const anyopaque = null, src_access: u32, dst_access: u32 };

pub const BufferImageCopy = extern struct {
    offset: u64 = 0,
    row_length: u32,
    image_height: u32 = 0,
    layers: SubresourceLayers = .{},
    image_offset: Offset3D,
    image_extent: Extent3D,
};

pub fn Fn(comptime T: type) type {
    return *const T;
}

pub const GlobalFns = struct {
    vkCreateInstance: Fn(fn (*const InstanceCreateInfo, ?*const anyopaque, *VkInstance) callconv(.c) Result),
    vkEnumerateInstanceExtensionProperties: Fn(fn (?Name, *u32, ?[*]ExtensionProperties) callconv(.c) Result),
    vkEnumerateInstanceLayerProperties: Fn(fn (*u32, ?[*]LayerProperties) callconv(.c) Result),
};

pub const InstanceFns = struct {
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

pub const DeviceFns = struct {
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

pub fn load(comptime T: type, ctx: anytype, getter: anytype) error{BackendError}!T {
    var t: T = undefined;
    inline for (@typeInfo(T).@"struct".field_names) |name| {
        @field(t, name) = @ptrCast(getter(ctx, name) orelse {
            log.err("{s} missing", .{name});
            return error.BackendError;
        });
    }
    return t;
}

pub fn ok(r: Result, comptime what: []const u8) error{BackendError}!void {
    if (r == success) return;
    log.err(what ++ " failed: {d}", .{r});
    return error.BackendError;
}

pub fn hasName(list: anytype, name: []const u8) bool {
    for (list) |p| if (std.mem.eql(u8, std.mem.sliceTo(&p.name, 0), name)) return true;
    return false;
}
