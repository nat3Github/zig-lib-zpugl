const std = @import("std");
const builtin = @import("builtin");
const root = @import("../root.zig");
const metal = @import("metal.zig");

pub const VkInstance = *opaque {};
pub const VkDevice = *opaque {};
pub const VkSurfaceKHR = enum(u64) { null_handle = 0, _ };
pub const VkResult = i32;
pub const VkAllocationCallbacks = opaque {};

pub const VK_SUCCESS: VkResult = 0;
pub const VK_ERROR_INITIALIZATION_FAILED: VkResult = -3;
pub const VK_ERROR_EXTENSION_NOT_PRESENT: VkResult = -7;

pub const PFN_vkVoidFunction = *const fn () callconv(.c) void;
pub const PFN_vkGetInstanceProcAddr = *const fn (instance: ?VkInstance, name: [*:0]const u8) callconv(.c) ?PFN_vkVoidFunction;
pub const PFN_vkGetDeviceProcAddr = *const fn (device: VkDevice, name: [*:0]const u8) callconv(.c) ?PFN_vkVoidFunction;

const is_android = builtin.abi.isAndroid();
const is_apple = builtin.os.tag == .macos or builtin.os.tag == .ios;

const Lib = if (builtin.os.tag == .windows) struct {
    const HMODULE = *opaque {};
    extern "kernel32" fn LoadLibraryExA(name: [*:0]const u8, file: ?*anyopaque, flags: u32) callconv(.winapi) ?HMODULE;
    extern "kernel32" fn GetProcAddress(module: HMODULE, name: [*:0]const u8) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn FreeLibrary(module: HMODULE) callconv(.winapi) i32;
    const LOAD_LIBRARY_SEARCH_DEFAULT_DIRS = 0x00001000;

    handle: HMODULE,

    fn open(name: ?[*:0]const u8) ?@This() {
        return .{ .handle = LoadLibraryExA(name orelse return null, null, LOAD_LIBRARY_SEARCH_DEFAULT_DIRS) orelse return null };
    }
    fn lookup(self: @This(), comptime T: type, name: [*:0]const u8) ?T {
        return @ptrCast(GetProcAddress(self.handle, name) orelse return null);
    }
    fn close(self: @This()) void {
        _ = FreeLibrary(self.handle);
    }
} else struct {
    handle: *anyopaque,

    fn open(name: ?[*:0]const u8) ?@This() {
        return .{ .handle = std.c.dlopen(name, .{ .LAZY = true }) orelse return null };
    }
    fn lookup(self: @This(), comptime T: type, name: [*:0]const u8) ?T {
        return @ptrCast(@alignCast(std.c.dlsym(self.handle, name) orelse return null));
    }
    fn close(self: @This()) void {
        _ = std.c.dlclose(self.handle);
    }
};

const default_libraries: []const ?[*:0]const u8 = if (is_android)
    &.{"libvulkan.so"}
else switch (builtin.os.tag) {
    .windows => &.{"vulkan-1.dll"},
    .macos => &.{ "libvulkan.dylib", "libvulkan.1.dylib", "libMoltenVK.dylib", "/opt/homebrew/lib/libvulkan.1.dylib", "/opt/homebrew/lib/libMoltenVK.dylib" },
    else => &.{ "libvulkan.so", "libvulkan.so.1" },
};

pub const Loader = struct {
    lib: Lib,
    get_instance_proc_addr: ?PFN_vkGetInstanceProcAddr,
    get_device_proc_addr: ?PFN_vkGetDeviceProcAddr,

    pub fn init(world: *root.World, library_name: ?[*:0]const u8) error{VulkanLibraryNotFound}!Loader {
        _ = world;
        if (builtin.os.tag == .ios) return error.VulkanLibraryNotFound;
        const lib = if (library_name) |name| Lib.open(name) else for (default_libraries) |name| {
            const l = Lib.open(name) orelse continue;
            if (l.lookup(PFN_vkGetInstanceProcAddr, "vkGetInstanceProcAddr") != null) break l;
            l.close();
        } else null;
        const l = lib orelse return error.VulkanLibraryNotFound;
        return .{
            .lib = l,
            .get_instance_proc_addr = l.lookup(PFN_vkGetInstanceProcAddr, "vkGetInstanceProcAddr"),
            .get_device_proc_addr = l.lookup(PFN_vkGetDeviceProcAddr, "vkGetDeviceProcAddr"),
        };
    }

    pub fn deinit(self: *Loader) void {
        self.lib.close();
        self.* = undefined;
    }

    pub fn getInstanceProcAddrFunc(self: *const Loader) ?PFN_vkGetInstanceProcAddr {
        return self.get_instance_proc_addr;
    }

    pub fn getDeviceProcAddrFunc(self: *const Loader) ?PFN_vkGetDeviceProcAddr {
        return self.get_device_proc_addr;
    }
};

const platform_extension: [*:0]const u8 = if (is_android)
    "VK_KHR_android_surface"
else switch (builtin.os.tag) {
    .windows => "VK_KHR_win32_surface",
    .macos, .ios => "VK_EXT_metal_surface",
    else => "VK_KHR_xlib_surface",
};

const instance_extensions = [_][*:0]const u8{ "VK_KHR_surface", platform_extension };

pub fn getInstanceExtensions() []const [*:0]const u8 {
    return &instance_extensions;
}

const VkStructureType = enum(i32) {
    xlib_surface_create_info = 1000004000,
    android_surface_create_info = 1000008000,
    win32_surface_create_info = 1000009000,
    metal_surface_create_info = 1000217000,
};

const SurfaceCreateInfo = if (is_android) extern struct {
    s_type: VkStructureType = .android_surface_create_info,
    next: ?*const anyopaque = null,
    flags: u32 = 0,
    window: *anyopaque,
} else switch (builtin.os.tag) {
    .windows => extern struct {
        s_type: VkStructureType = .win32_surface_create_info,
        next: ?*const anyopaque = null,
        flags: u32 = 0,
        hinstance: ?*anyopaque,
        hwnd: *anyopaque,
    },
    .macos, .ios => extern struct {
        s_type: VkStructureType = .metal_surface_create_info,
        next: ?*const anyopaque = null,
        flags: u32 = 0,
        layer: *anyopaque,
    },
    else => extern struct {
        s_type: VkStructureType = .xlib_surface_create_info,
        next: ?*const anyopaque = null,
        flags: u32 = 0,
        dpy: *anyopaque,
        window: c_ulong,
    },
};

const create_surface_name: [*:0]const u8 = if (is_android)
    "vkCreateAndroidSurfaceKHR"
else switch (builtin.os.tag) {
    .windows => "vkCreateWin32SurfaceKHR",
    .macos, .ios => "vkCreateMetalSurfaceEXT",
    else => "vkCreateXlibSurfaceKHR",
};

const PFN_vkCreateSurface = *const fn (VkInstance, *const SurfaceCreateInfo, ?*const VkAllocationCallbacks, *VkSurfaceKHR) callconv(.c) VkResult;

extern "kernel32" fn GetModuleHandleW(name: ?[*:0]const u16) callconv(.winapi) ?*anyopaque;

fn surfaceCreateInfo(view: *root.View) ?SurfaceCreateInfo {
    const handle = view.handle orelse return null;
    if (is_android) return .{ .window = handle };
    return switch (builtin.os.tag) {
        .windows => .{ .hinstance = GetModuleHandleW(null), .hwnd = handle },
        .macos, .ios => .{ .layer = @ptrFromInt(if (view.gl_context != 0) view.gl_context else return null) },
        else => .{
            .dpy = @as(*@import("x11.zig").WorldImpl, @ptrCast(@alignCast(view.world.impl orelse return null))).display,
            .window = @intCast(@intFromPtr(handle)),
        },
    };
}

pub fn createSurface(
    get_instance_proc_addr: PFN_vkGetInstanceProcAddr,
    view: *root.View,
    instance: VkInstance,
    allocator: ?*const VkAllocationCallbacks,
    surface: *VkSurfaceKHR,
) VkResult {
    std.debug.assert(view.graphics_backend == .vulkan);
    const info = surfaceCreateInfo(view) orelse return VK_ERROR_INITIALIZATION_FAILED;
    const create_fn: PFN_vkCreateSurface = @ptrCast(get_instance_proc_addr(instance, create_surface_name) orelse
        return VK_ERROR_EXTENSION_NOT_PRESENT);
    return create_fn(instance, &info, allocator, surface);
}

pub fn get_backend() root.GraphicsBackend {
    if (is_apple) return metal.get_backend();
    return .{
        .configure = configure,
        .create = create,
        .destroy = destroy,
        .enter = enter,
        .leave = leave,
        .get_context = get_context,
    };
}

fn configure(_: ?*anyopaque) root.Status {
    return .success;
}

fn create(_: ?*anyopaque) root.Status {
    return .success;
}

fn destroy(_: ?*anyopaque) void {}

fn enter(_: ?*anyopaque, _: ?*const root.ExposeEvent) root.Status {
    return .success;
}

fn leave(_: ?*anyopaque, _: ?*const root.ExposeEvent) root.Status {
    return .success;
}

fn get_context(v: ?*anyopaque) ?*anyopaque {
    const view: *root.View = @ptrCast(@alignCast(v.?));
    return view.handle;
}
