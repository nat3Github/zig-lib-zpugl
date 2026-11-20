// Vulkan surface-only backend for zpugl.
//
// Mirrors pugl's Vulkan backend contract: the host application owns
// VkInstance/VkPhysicalDevice/VkDevice/VkQueue and the swapchain. This
// backend's only job is to:
//   * (optionally) attach a CAMetalLayer to the NSView on macOS so the host
//     can call vkCreateMetalSurfaceEXT against it.
//   * expose a `createSurface` helper that wraps the platform-specific
//     surface-creation Vulkan extension.
//
// All Vulkan symbols are looked up at runtime via vkGetInstanceProcAddr,
// supplied by the host through `setLoader`. We do NOT link Vulkan and we
// do NOT @cImport vulkan.h — only the few ABI bits we need are hand-declared.

const std = @import("std");
const builtin = @import("builtin");
const root = @import("../root.zig");

// ─── Hand-declared Vulkan ABI ────────────────────────────────────────────────

pub const VkInstance = *opaque {};
pub const VkSurfaceKHR = *opaque {};
pub const VkResult = i32;
pub const VkFlags = u32;
pub const VK_SUCCESS: VkResult = 0;

// Opaque allocation callback pointer (we never construct one).
pub const VkAllocationCallbacks = opaque {};

// VkStructureType values we use.
const VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT: i32 = 1000217000;
const VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR: i32 = 1000004000;
const VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR: i32 = 1000009000;

pub const VkMetalSurfaceCreateInfoEXT = extern struct {
    sType: i32 = VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT,
    pNext: ?*const anyopaque = null,
    flags: VkFlags = 0,
    pLayer: *const anyopaque, // const CAMetalLayer*
};

pub const VkXlibSurfaceCreateInfoKHR = extern struct {
    sType: i32 = VK_STRUCTURE_TYPE_XLIB_SURFACE_CREATE_INFO_KHR,
    pNext: ?*const anyopaque = null,
    flags: VkFlags = 0,
    dpy: *anyopaque, // Display*
    window: c_ulong, // Window
};

pub const VkWin32SurfaceCreateInfoKHR = extern struct {
    sType: i32 = VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
    pNext: ?*const anyopaque = null,
    flags: VkFlags = 0,
    hinstance: ?*anyopaque, // HINSTANCE
    hwnd: ?*anyopaque, // HWND
};

pub const PFN_vkVoidFunction = *const fn () callconv(.c) void;
pub const PFN_vkGetInstanceProcAddr = *const fn (
    instance: ?VkInstance,
    name: [*:0]const u8,
) callconv(.c) ?PFN_vkVoidFunction;

const PFN_vkCreateMetalSurfaceEXT = *const fn (
    instance: VkInstance,
    pCreateInfo: *const VkMetalSurfaceCreateInfoEXT,
    pAllocator: ?*const VkAllocationCallbacks,
    pSurface: *VkSurfaceKHR,
) callconv(.c) VkResult;

const PFN_vkCreateXlibSurfaceKHR = *const fn (
    instance: VkInstance,
    pCreateInfo: *const VkXlibSurfaceCreateInfoKHR,
    pAllocator: ?*const VkAllocationCallbacks,
    pSurface: *VkSurfaceKHR,
) callconv(.c) VkResult;

const PFN_vkCreateWin32SurfaceKHR = *const fn (
    instance: VkInstance,
    pCreateInfo: *const VkWin32SurfaceCreateInfoKHR,
    pAllocator: ?*const VkAllocationCallbacks,
    pSurface: *VkSurfaceKHR,
) callconv(.c) VkResult;

const PFN_vkDestroySurfaceKHR = *const fn (
    instance: VkInstance,
    surface: VkSurfaceKHR,
    pAllocator: ?*const VkAllocationCallbacks,
) callconv(.c) void;

// ─── Public surface helpers ──────────────────────────────────────────────────

pub const VkLoader = PFN_vkGetInstanceProcAddr;

var g_loader: ?VkLoader = null;

pub fn setLoader(loader: VkLoader) void {
    g_loader = loader;
}

pub const SurfaceError = error{
    NoLoader,
    MissingExtension,
    NoContext,
    SurfaceCreateFailed,
};

pub fn createSurface(view: *root.View, instance: VkInstance) SurfaceError!VkSurfaceKHR {
    const loader = g_loader orelse return error.NoLoader;
    var surface: VkSurfaceKHR = undefined;

    switch (builtin.os.tag) {
        .macos => {
            const layer = mac.get_context_ptr(view) orelse return error.NoContext;
            const fn_ptr = loader(instance, "vkCreateMetalSurfaceEXT") orelse
                return error.MissingExtension;
            const create_fn: PFN_vkCreateMetalSurfaceEXT = @ptrCast(@alignCast(fn_ptr));
            const info = VkMetalSurfaceCreateInfoEXT{ .pLayer = layer };
            const r = create_fn(instance, &info, null, &surface);
            if (r != VK_SUCCESS) return error.SurfaceCreateFailed;
            return surface;
        },
        .windows => {
            const hwnd = view.handle orelse return error.NoContext;
            const win32 = @import("win32.zig");
            const hinstance = win32.GetModuleHandleW(null);
            const fn_ptr = loader(instance, "vkCreateWin32SurfaceKHR") orelse
                return error.MissingExtension;
            const create_fn: PFN_vkCreateWin32SurfaceKHR = @ptrCast(@alignCast(fn_ptr));
            const info = VkWin32SurfaceCreateInfoKHR{
                .hinstance = hinstance,
                .hwnd = hwnd,
            };
            const r = create_fn(instance, &info, null, &surface);
            if (r != VK_SUCCESS) return error.SurfaceCreateFailed;
            return surface;
        },
        .linux => {
            const x11 = @import("x11.zig");
            const win_id: c_ulong = @intCast(@intFromPtr(view.handle orelse return error.NoContext));
            const world_impl: *x11.WorldImpl = @ptrCast(@alignCast(view.world.impl orelse
                return error.NoContext));
            const fn_ptr = loader(instance, "vkCreateXlibSurfaceKHR") orelse
                return error.MissingExtension;
            const create_fn: PFN_vkCreateXlibSurfaceKHR = @ptrCast(@alignCast(fn_ptr));
            const info = VkXlibSurfaceCreateInfoKHR{
                .dpy = @ptrCast(world_impl.display),
                .window = win_id,
            };
            const r = create_fn(instance, &info, null, &surface);
            if (r != VK_SUCCESS) return error.SurfaceCreateFailed;
            return surface;
        },
        else => return error.MissingExtension,
    }
}

pub fn destroySurface(instance: VkInstance, surface: VkSurfaceKHR) void {
    const loader = g_loader orelse return;
    const fn_ptr = loader(instance, "vkDestroySurfaceKHR") orelse return;
    const destroy_fn: PFN_vkDestroySurfaceKHR = @ptrCast(@alignCast(fn_ptr));
    destroy_fn(instance, surface, null);
}

// ─── GraphicsBackend dispatch ────────────────────────────────────────────────

pub fn get_backend() root.GraphicsBackend {
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

fn create(v: ?*anyopaque) root.Status {
    const view: *root.View = @ptrCast(@alignCast(v.?));
    return switch (builtin.os.tag) {
        .macos => mac.create(view),
        // Linux/Windows: nothing to do at create time. Surface handle lives
        // with caller, and view.handle already carries the window id.
        else => .success,
    };
}

fn destroy(v: ?*anyopaque) void {
    const view: *root.View = @ptrCast(@alignCast(v.?));
    if (builtin.os.tag == .macos) mac.destroy(view);
}

fn enter(_: ?*anyopaque, _: ?*const root.ExposeEvent) root.Status {
    return .success;
}

fn leave(_: ?*anyopaque, _: ?*const root.ExposeEvent) root.Status {
    return .success;
}

fn get_context(v: ?*anyopaque) ?*anyopaque {
    const view: *root.View = @ptrCast(@alignCast(v.?));
    return switch (builtin.os.tag) {
        .macos => mac.get_context_ptr(view),
        .windows => view.handle, // HWND
        else => view.handle, // X11 Window cast as ptr — caller pairs with world.impl
    };
}

// ─── macOS: CAMetalLayer attachment ──────────────────────────────────────────

const mac = if (builtin.os.tag == .macos) struct {
    const objc = @import("objc");
    const c = objc.c;

    const CGFloat = f64;
    const NSPoint = extern struct { x: CGFloat, y: CGFloat };
    const NSSize = extern struct { width: CGFloat, height: CGFloat };
    const NSRect = extern struct { origin: NSPoint, size: NSSize };
    const MTLPixelFormatBGRA8Unorm: usize = 80;

    fn create(view: *root.View) root.Status {
        const native = view.handle orelse return .bad_call;
        const ns_view: objc.Object = .{ .value = @ptrCast(@alignCast(native)) };

        const layer_class = objc.getClass("CAMetalLayer") orelse return .create_context_failed;
        const layer = layer_class.msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "init", .{});
        if (layer.value == null) return .create_context_failed;

        layer.msgSend(void, "setPixelFormat:", .{@as(usize, MTLPixelFormatBGRA8Unorm)});
        ns_view.msgSend(void, "setLayer:", .{layer});
        ns_view.msgSend(void, "setWantsLayer:", .{true});
        layer.msgSend(void, "setDelegate:", .{ns_view});

        const bounds = ns_view.msgSend(NSRect, "bounds", .{});
        const win_id = ns_view.msgSend(c.id, "window", .{});
        const scale: CGFloat = if (win_id) |w| blk: {
            const win: objc.Object = .{ .value = w };
            break :blk win.msgSend(CGFloat, "backingScaleFactor", .{});
        } else 1.0;
        layer.msgSend(void, "setContentsScale:", .{scale});
        layer.msgSend(void, "setDrawableSize:", .{NSSize{
            .width = bounds.size.width * scale,
            .height = bounds.size.height * scale,
        }});

        view.gl_context = @intFromPtr(layer.value);
        return .success;
    }

    fn destroy(view: *root.View) void {
        if (view.gl_context == 0) return;
        const layer: objc.Object = .{ .value = @ptrFromInt(view.gl_context) };
        if (view.handle) |native| {
            const ns_view: objc.Object = .{ .value = @ptrCast(@alignCast(native)) };
            ns_view.msgSend(void, "setLayer:", .{@as(c.id, null)});
            ns_view.msgSend(void, "setWantsLayer:", .{false});
        }
        layer.msgSend(void, "release", .{});
        view.gl_context = 0;
    }

    fn get_context_ptr(view: *root.View) ?*anyopaque {
        if (view.gl_context == 0) return null;
        return @ptrFromInt(view.gl_context);
    }
} else struct {
    fn get_context_ptr(_: *root.View) ?*anyopaque {
        return null;
    }
};
