const std = @import("std");
const builtin = @import("builtin");
const root = @import("../root.zig");

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

const supported = builtin.os.tag == .macos or builtin.os.tag == .ios;
const impl = switch (builtin.os.tag) {
    .macos => mac,
    .ios => ios,
    else => struct {},
};

fn configure(_: ?*anyopaque) root.Status {
    if (!supported) return .unsupported;
    return .success;
}

fn create(v: ?*anyopaque) root.Status {
    if (!supported) return .unsupported;
    return impl.create(v);
}

fn destroy(v: ?*anyopaque) void {
    if (!supported) return;
    impl.destroy(v);
}

fn enter(_: ?*anyopaque, _: ?*const root.ExposeEvent) root.Status {
    if (!supported) return .unsupported;
    return .success;
}

fn leave(_: ?*anyopaque, _: ?*const root.ExposeEvent) root.Status {
    if (!supported) return .unsupported;
    return .success;
}

fn get_context(v: ?*anyopaque) ?*anyopaque {
    if (!supported) return null;
    const view: *root.View = @ptrCast(@alignCast(v.?));
    if (view.gl_context == 0) return null;
    return @ptrFromInt(view.gl_context);
}

const ios = if (builtin.os.tag == .ios) struct {
    const objc = @import("objc");

    fn create(v: ?*anyopaque) root.Status {
        const view: *root.View = @ptrCast(@alignCast(v.?));
        const ui_view: objc.Object = .{ .value = @ptrCast(@alignCast(view.handle orelse return .bad_call)) };
        const layer = ui_view.msgSend(objc.Object, "layer", .{});
        if (layer.value == null) return .create_context_failed;
        layer.msgSend(void, "setPixelFormat:", .{@as(usize, 80)});
        layer.msgSend(void, "setContentsScale:", .{ui_view.msgSend(f64, "contentScaleFactor", .{})});
        view.gl_context = @intFromPtr(layer.value);
        return .success;
    }

    fn destroy(v: ?*anyopaque) void {
        const view: *root.View = @ptrCast(@alignCast(v.?));
        view.gl_context = 0;
    }
} else struct {};

// ─── macOS implementation ────────────────────────────────────────────────────

const mac = if (builtin.os.tag == .macos) struct {
    const objc = @import("objc");
    const c = objc.c;

    const CGFloat = f64;
    const NSPoint = extern struct { x: CGFloat, y: CGFloat };
    const NSSize = extern struct { width: CGFloat, height: CGFloat };
    const NSRect = extern struct { origin: NSPoint, size: NSSize };

    // MTLPixelFormatBGRA8Unorm
    const MTLPixelFormatBGRA8Unorm: usize = 80;

    fn create(v: ?*anyopaque) root.Status {
        const view: *root.View = @ptrCast(@alignCast(v.?));
        const native = view.handle orelse return .bad_call;
        const ns_view: objc.Object = .{ .value = @ptrCast(@alignCast(native)) };

        const layer_class = objc.getClass("CAMetalLayer") orelse return .create_context_failed;
        const layer = layer_class.msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "init", .{});
        if (layer.value == null) return .create_context_failed;

        layer.msgSend(void, "setPixelFormat:", .{@as(usize, MTLPixelFormatBGRA8Unorm)});

        // Layer-hosting view: setLayer must be called BEFORE setWantsLayer=YES.
        ns_view.msgSend(void, "setLayer:", .{layer});
        ns_view.msgSend(void, "setWantsLayer:", .{true});
        // Make NSView the layer's delegate so displayLayer: fires on redraw.
        layer.msgSend(void, "setDelegate:", .{ns_view});
        layer.msgSend(void, "setNeedsDisplayOnBoundsChange:", .{true});

        // Match backing scale and drawable size to view bounds in pixels.
        const bounds = ns_view.msgSend(NSRect, "bounds", .{});
        const win_id = ns_view.msgSend(c.id, "window", .{});
        const scale: CGFloat = if (win_id) |w| blk: {
            const win: objc.Object = .{ .value = w };
            break :blk win.msgSend(CGFloat, "backingScaleFactor", .{});
        } else 1.0;
        layer.msgSend(void, "setContentsScale:", .{scale});
        const drawable_size = NSSize{
            .width = bounds.size.width * scale,
            .height = bounds.size.height * scale,
        };
        layer.msgSend(void, "setDrawableSize:", .{drawable_size});

        // Stash CAMetalLayer pointer in the shared backend handle slot.
        view.gl_context = @intFromPtr(layer.value);
        return .success;
    }

    fn destroy(v: ?*anyopaque) void {
        const view: *root.View = @ptrCast(@alignCast(v.?));
        if (view.gl_context == 0) return;
        const layer: objc.Object = .{ .value = @ptrFromInt(view.gl_context) };
        // Detach from NSView before releasing.
        if (view.handle) |native| {
            const ns_view: objc.Object = .{ .value = @ptrCast(@alignCast(native)) };
            ns_view.msgSend(void, "setLayer:", .{@as(c.id, null)});
            ns_view.msgSend(void, "setWantsLayer:", .{false});
        }
        layer.msgSend(void, "release", .{});
        view.gl_context = 0;
    }
} else struct {};
