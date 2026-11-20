const root = @import("../root.zig");

pub fn create(view: *root.View) root.Status {
    _ = view;
    return .success;
}

pub fn destroy(view: *root.View) void {
    _ = view;
}

pub fn enter(view: *root.View, expose: ?*const root.ExposeEvent) root.Status {
    _ = view;
    _ = expose;
    return .success;
}

pub fn leave(view: *root.View, expose: ?*const root.ExposeEvent) root.Status {
    _ = view;
    _ = expose;
    return .success;
}

pub fn get_backend() root.GraphicsBackend {
    return .{
        .configure = configure,
        .create = create_opaque,
        .destroy = destroy_opaque,
        .enter = enter_opaque,
        .leave = leave_opaque,
        .get_context = get_context,
    };
}

fn configure(v: ?*anyopaque) root.Status {
    _ = v;
    return .success;
}

fn create_opaque(v: ?*anyopaque) root.Status {
    return create(@ptrCast(@alignCast(v.?)));
}

fn destroy_opaque(v: ?*anyopaque) void {
    destroy(@ptrCast(@alignCast(v.?)));
}

fn enter_opaque(v: ?*anyopaque, expose: ?*const root.ExposeEvent) root.Status {
    return enter(@ptrCast(@alignCast(v.?)), expose);
}

fn leave_opaque(v: ?*anyopaque, expose: ?*const root.ExposeEvent) root.Status {
    return leave(@ptrCast(@alignCast(v.?)), expose);
}

fn get_context(v: ?*anyopaque) ?*anyopaque {
    _ = v;
    return null;
}
