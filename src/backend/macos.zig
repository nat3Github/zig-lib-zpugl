const std = @import("std");
const root = @import("../root.zig");
const common = root.common;

// Pull in pure-Zig ObjC implementation (replaces former .m files).
comptime {
    _ = @import("../objc/macos_objc.zig");
}

// --- ObjC -> Zig callbacks ---

export fn zpugl_on_expose(view_ptr: *anyopaque, x: i16, y: i16, w: u16, h: u16) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const ev = root.Event{ .expose = .{ .x = x, .y = y, .width = w, .height = h } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_configure(view_ptr: *anyopaque, x: i16, y: i16, w: u16, h: u16, state: u32, changed_only: bool) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const now: root.ViewStyleFlags = @bitCast(state);
    if (changed_only and now.mapped == view.style.mapped and now.hidden == view.style.hidden) return;
    view.style.mapped = now.mapped;
    view.style.hidden = now.hidden;
    view.size_hints[@backingInt(root.SizeHint.current_size)] = .{ .width = w, .height = h };
    const ev = root.Event{ .configure = .{ .x = x, .y = y, .width = w, .height = h, .style = view.style } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_close(view_ptr: *anyopaque) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const ev = root.Event{ .close = {} };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_button(view_ptr: *anyopaque, press: bool, time: f64, x: f64, y: f64, button: u32, mods: u32) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const state: root.Mods = @bitCast(mods);
    const ev = if (press)
        root.Event{ .button_press = .{ .time = time, .x = x, .y = y, .root_x = x, .root_y = y, .state = state, .button = button } }
    else
        root.Event{ .button_release = .{ .time = time, .x = x, .y = y, .root_x = x, .root_y = y, .state = state, .button = button } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_motion(view_ptr: *anyopaque, time: f64, x: f64, y: f64, mods: u32) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const ev = root.Event{ .motion = .{ .time = time, .x = x, .y = y, .root_x = x, .root_y = y, .state = @bitCast(mods) } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_scroll(view_ptr: *anyopaque, time: f64, x: f64, y: f64, dx: f64, dy: f64, mods: u32) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    // Match pugl/src/mac.m: negate dx; classify by axis exclusivity.
    const ndx = -dx;
    const direction: root.ScrollDirection = if (ndx == 0 and dy > 0)
        .up
    else if (ndx == 0 and dy < 0)
        .down
    else if (dy == 0 and ndx > 0)
        .right
    else if (dy == 0 and ndx < 0)
        .left
    else
        .smooth;
    const ev = root.Event{ .scroll = .{
        .time = time,
        .x = x,
        .y = y,
        .root_x = x,
        .root_y = y,
        .state = @bitCast(mods),
        .direction = direction,
        .dx = ndx,
        .dy = dy,
    } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_key(view_ptr: *anyopaque, press: bool, time: f64, x: f64, y: f64, keycode: u32, key: u32, mods: u32) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const state: root.Mods = @bitCast(mods);
    const ev = if (press)
        root.Event{ .key_press = .{ .time = time, .x = x, .y = y, .root_x = x, .root_y = y, .state = state, .keycode = keycode, .key = key } }
    else
        root.Event{ .key_release = .{ .time = time, .x = x, .y = y, .root_x = x, .root_y = y, .state = state, .keycode = keycode, .key = key } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_text(view_ptr: *anyopaque, time: f64, x: f64, y: f64, keycode: u32, character: u32, str: [*:0]const u8, mods: u32) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const s = std.mem.span(str);
    // Backspace/Return/Tab/Esc/Delete reach here as their control chars
    // (keyDown fallback); they're already sent as key events, and as text
    // they'd insert an invisible char right after the key deleted one.
    if (s.len == 1 and (s[0] < 0x20 or s[0] == 0x7f)) return;
    if (character >= 0xF700 and character <= 0xF8FF) return; // NSF* function/arrow keys
    var string: [8]u8 = @splat(0);
    @memcpy(string[0..@min(s.len, 7)], s[0..@min(s.len, 7)]);
    const ev = root.Event{ .text = .{
        .time = time,
        .x = x,
        .y = y,
        .root_x = x,
        .root_y = y,
        .state = @bitCast(mods),
        .keycode = keycode,
        .character = character,
        .string = string,
    } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_focus(view_ptr: *anyopaque, gained: bool, mode: u32) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const crossing: root.CrossingMode = @fromBackingInt(@intCast(mode));
    const ev = if (gained)
        root.Event{ .focus_in = .{ .mode = crossing } }
    else
        root.Event{ .focus_out = .{ .mode = crossing } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_pointer_cross(view_ptr: *anyopaque, entered: bool, time: f64, x: f64, y: f64, mods: u32, mode: u32) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const crossing: root.CrossingMode = @fromBackingInt(@intCast(mode));
    const ev = if (entered)
        root.Event{ .pointer_in = .{ .time = time, .x = x, .y = y, .root_x = x, .root_y = y, .state = @bitCast(mods), .mode = crossing } }
    else
        root.Event{ .pointer_out = .{ .time = time, .x = x, .y = y, .root_x = x, .root_y = y, .state = @bitCast(mods), .mode = crossing } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_timer(view_ptr: *anyopaque, timer_id: usize) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const ev = root.Event{ .timer = .{ .id = timer_id } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_data_offer(view_ptr: *anyopaque, time: f64, clipboard: u32) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const cb: root.Clipboard = if (clipboard == 1) .drag else .general;
    const ev = root.Event{ .data_offer = .{ .time = time, .x = 0, .y = 0, .clipboard = cb } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_data(view_ptr: *anyopaque, time: f64, x: f64, y: f64, clipboard: u32, type_index: u32) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const cb: root.Clipboard = if (clipboard == 1) .drag else .general;
    const ev = root.Event{ .data = .{ .time = time, .x = x, .y = y, .clipboard = cb, .type_index = type_index } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_client(view_ptr: *anyopaque, data1: usize, data2: usize) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const ev = root.Event{ .client = .{ .data1 = data1, .data2 = data2 } };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_loop_enter(view_ptr: *anyopaque) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const ev = root.Event{ .loop_enter = {} };
    _ = common.dispatchEvent(view, &ev);
}

export fn zpugl_on_resizing(view_ptr: *anyopaque, resizing: bool) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    view.style.resizing = resizing;
}

export fn zpugl_on_loop_leave(view_ptr: *anyopaque) void {
    const view: *root.View = @ptrCast(@alignCast(view_ptr));
    const ev = root.Event{ .loop_leave = {} };
    _ = common.dispatchEvent(view, &ev);
}

// --- Zig -> ObjC extern functions ---

pub extern fn zpugl_mac_create_view(
    view_ptr: *anyopaque,
    parent: usize,
    x: f64,
    y: f64,
    w: f64,
    h: f64,
    resizable: bool,
    dark_frame: bool,
    view_type: u32,
    has_pos: bool,
    metal: bool,
) usize;

pub extern fn zpugl_mac_destroy_view(native: usize) void;
pub extern fn zpugl_mac_realized(native: usize, view: *anyopaque) void;
pub extern fn zpugl_mac_show_view(native: usize, command: u32) void; // command = ShowCommand value
pub extern fn zpugl_mac_hide_view(native: usize) void;
pub extern fn zpugl_mac_set_size(native: usize, w: u32, h: u32) void;
pub extern fn zpugl_mac_window_position(native: usize, x: *i32, y: *i32) bool;
pub extern fn zpugl_mac_set_view_position(native: usize, x: i32, y: i32) void;
pub extern fn zpugl_mac_set_min_size(native: usize, w: u32, h: u32) void;
pub extern fn zpugl_mac_set_max_size(native: usize, w: u32, h: u32) void;
pub extern fn zpugl_mac_set_title(native: usize, title: [*:0]const u8) void;
pub extern fn zpugl_mac_get_scale_factor(native: usize) f64;
pub extern fn zpugl_mac_grab_focus(native: usize) bool;
pub extern fn zpugl_mac_has_focus(native: usize) bool;
pub extern fn zpugl_mac_set_cursor(native: usize, cursor: u32) void;
pub extern fn zpugl_mac_obscure_view(native: usize) void;
pub extern fn zpugl_mac_update(timeout: f64) void;
pub extern fn zpugl_mac_get_time() f64;

// Style/timer/clipboard
pub extern fn zpugl_mac_set_view_style(native: usize, flags: u32) void;
pub extern fn zpugl_mac_send_close(native: usize) u32;
pub extern fn zpugl_mac_send_client(native: usize, data1: usize, data2: usize) u32;
pub extern fn zpugl_mac_start_timer(zig_view: *anyopaque, id: usize, freq: f64) u32;
pub extern fn zpugl_mac_stop_timer(zig_view: *anyopaque, id: usize) u32;
pub extern fn zpugl_mac_set_clipboard(mime: [*:0]const u8, data: [*]const u8, len: usize) u32;
pub extern fn zpugl_mac_get_clipboard(native: usize, clipboard: u32, out_data: *[*]const u8, out_len: *usize, type_index: u32) u32;
pub extern fn zpugl_mac_get_num_clipboard_types(native: usize, clipboard: u32) u32;
pub extern fn zpugl_mac_get_clipboard_type(native: usize, clipboard: u32, idx: u32) ?[*:0]const u8;
pub extern fn zpugl_mac_paste(zig_view: *anyopaque) u32;
pub extern fn zpugl_mac_obscure_region(native: usize, x: f64, y: f64, w: f64, h: f64) void;
pub extern fn zpugl_mac_set_transient_parent(child_native: usize, parent_native: usize) u32;
pub extern fn zpugl_mac_register_drop_type(native: usize, mime: [*:0]const u8) u32;
pub extern fn zpugl_mac_accept_offer(native: usize, type_index: u32, action: u32) u32;

// GL-specific
pub extern fn zpugl_mac_gl_create(native: usize, major: i32, minor: i32, profile: i32, double_buf: bool, swap_interval: i32) usize;
pub extern fn zpugl_mac_gl_destroy(ctx: usize) void;
pub extern fn zpugl_mac_gl_enter(ctx: usize) void;
pub extern fn zpugl_mac_gl_leave(ctx: usize, swap: bool) void;
pub extern fn zpugl_mac_gl_resize(ctx: usize) void;

// --- Backend functions called from root.zig ---

pub fn createView(view: *root.View) root.Status {
    const hints = view.hints;
    const size = view.size_hints[@backingInt(root.SizeHint.default_size)];
    const pos = view.pos_hints[@backingInt(root.PositionHint.default_position)];
    const resizable = hints[@backingInt(root.ViewHint.resizable)] == @backingInt(root.ViewHintValue.true);
    const dark_frame = hints[@backingInt(root.ViewHint.dark_frame)] == @backingInt(root.ViewHintValue.true);
    const view_type: u32 = @intCast(@max(0, hints[@backingInt(root.ViewHint.view_type)]));
    const has_pos = pos.x != std.math.minInt(i16) and pos.y != std.math.minInt(i16);
    const rx: f64 = @floatFromInt(if (has_pos) pos.x else 0);
    const ry: f64 = @floatFromInt(if (has_pos) pos.y else 0);
    const rw: f64 = @floatFromInt(if (size.width == 0) 800 else size.width);
    const rh: f64 = @floatFromInt(if (size.height == 0) 600 else size.height);
    const native = zpugl_mac_create_view(view, view.parent, rx, ry, rw, rh, resizable, dark_frame, view_type, has_pos, view.graphics_backend == .metal or view.graphics_backend == .vulkan);
    if (native == 0) return .realize_failed;
    view.handle = @ptrFromInt(native);
    view.visible = view.parent != 0;
    const title = view.getViewString(.window_title);
    if (title.len > 0) {
        var buf: [256]u8 = undefined;
        const n = @min(title.len, buf.len - 1);
        @memcpy(buf[0..n], title[0..n]);
        buf[n] = 0;
        zpugl_mac_set_title(native, buf[0..n :0]);
    }
    return .success;
}

pub fn realized(view: *root.View) void {
    zpugl_mac_realized(@intFromPtr(view.handle.?), view);
}

pub fn destroyView(view: *root.View) void {
    if (view.handle) |h| {
        zpugl_mac_destroy_view(@intFromPtr(h));
        view.handle = null;
    }
}

pub fn showView(view: *root.View, command: root.ShowCommand) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    zpugl_mac_show_view(native, @backingInt(command));
    view.visible = true;
    if (view.transient_parent != 0) _ = zpugl_mac_set_transient_parent(native, view.transient_parent);
    return .success;
}

pub fn hideView(view: *root.View) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    zpugl_mac_hide_view(native);
    view.visible = false;
    return .success;
}

pub fn update(world: *root.World, timeout: f64) root.Status {
    // Module worlds are embedded inside a host that owns the NSApp event loop.
    // Draining the global event queue here would steal events the host needs.
    // The host's own pump dispatches `sendEvent:`, which routes to our views.
    if (world.type == .module) return .success;
    zpugl_mac_update(timeout);
    return .success;
}

pub fn getTime(world: *root.World) f64 {
    _ = world;
    return zpugl_mac_get_time();
}

pub fn getScaleFactor(view: *root.View) f64 {
    return zpugl_mac_get_scale_factor(@intFromPtr(view.handle));
}

pub extern fn zpugl_mac_is_occluded(native: usize) bool;

pub fn isOccluded(view: *root.View) bool {
    return zpugl_mac_is_occluded(@intFromPtr(view.handle orelse return false));
}

pub fn obscureView(view: *root.View) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    zpugl_mac_obscure_view(native);
    return .success;
}

pub fn grabFocus(view: *root.View) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    return if (zpugl_mac_grab_focus(native)) .success else .failure;
}

pub fn hasFocus(view: *root.View) bool {
    const native = @intFromPtr(view.handle orelse return false);
    return zpugl_mac_has_focus(native);
}

pub fn setCursor(view: *root.View, cursor: root.Cursor) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    zpugl_mac_set_cursor(native, @backingInt(cursor));
    return .success;
}

pub fn deinitWorld(world: *root.World) void {
    _ = world;
}

// Stubs for unimplemented features
pub fn getNativeWorld(world: *root.World) ?*anyopaque {
    _ = world;
    return null;
}
pub fn startTimer(world: *root.World, view: *root.View, id: usize, freq: f64) root.Status {
    _ = world;
    const r = zpugl_mac_start_timer(view, id, freq);
    return if (r == 0) .success else .failure;
}
pub fn stopTimer(world: *root.World, view: *root.View, id: usize) root.Status {
    _ = world;
    const r = zpugl_mac_stop_timer(view, id);
    return if (r == 0) .success else .failure;
}
pub fn setViewStyle(view: *root.View, flags: root.ViewStyleFlags) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    const bits: u32 = @bitCast(flags);
    zpugl_mac_set_view_style(native, bits);
    view.style = root.common.keepState(view.style, flags);
    return .success;
}
pub fn applySizeHints(view: *root.View) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    const min = view.size_hints[@backingInt(root.SizeHint.min_size)];
    const max = view.size_hints[@backingInt(root.SizeHint.max_size)];
    if (min.width != 0 or min.height != 0) {
        zpugl_mac_set_min_size(native, min.width, min.height);
    }
    if (max.width != 0 or max.height != 0) {
        zpugl_mac_set_max_size(native, max.width, max.height);
    }
    return .success;
}
pub fn setViewSize(view: *root.View, w: u32, h: u32) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    zpugl_mac_set_size(native, w, h);
    return .success;
}
pub fn getWindowPosition(view: *root.View) ?root.Point {
    var x: i32 = 0;
    var y: i32 = 0;
    if (!zpugl_mac_window_position(@intFromPtr(view.handle.?), &x, &y)) return null;
    return .{ .x = @intCast(std.math.clamp(x, std.math.minInt(i16) + 1, std.math.maxInt(i16))), .y = @intCast(std.math.clamp(y, std.math.minInt(i16) + 1, std.math.maxInt(i16))) };
}

pub fn setViewPosition(view: *root.View, x: i32, y: i32) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    zpugl_mac_set_view_position(native, x, y);
    return .success;
}
pub fn obscureRegion(view: *root.View, x: i32, y: i32, w: u32, h: u32) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    zpugl_mac_obscure_region(native, @floatFromInt(x), @floatFromInt(y), @floatFromInt(w), @floatFromInt(h));
    return .success;
}

pub fn setTransientParent(view: *root.View, parent: root.NativeView) root.Status {
    if (parent == 0 or !view.visible) return .success;
    const child_native = @intFromPtr(view.handle.?);
    const r = zpugl_mac_set_transient_parent(child_native, parent);
    return if (r == 0) .success else .failure;
}
pub fn sendEvent(view: *root.View, event: *const root.Event) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    switch (event.*) {
        .close => {
            const r = zpugl_mac_send_close(native);
            return if (r == 0) .success else .failure;
        },
        .client => |cl| return if (view.world.type == .module or view.parent != 0) .unsupported else if (zpugl_mac_send_client(native, cl.data1, cl.data2) == 0) .success else .failure,
        else => return .unsupported,
    }
}
pub fn registerDropType(view: *root.View, mime_type: []const u8) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    var buf: [128]u8 = undefined;
    if (mime_type.len >= buf.len) return .bad_parameter;
    @memcpy(buf[0..mime_type.len], mime_type);
    buf[mime_type.len] = 0;
    const r = zpugl_mac_register_drop_type(native, @ptrCast(&buf));
    return if (r == 0) .success else .failure;
}
pub fn paste(view: *root.View) root.Status {
    const r = zpugl_mac_paste(view);
    return if (r == 0) .success else .failure;
}
pub fn getNumClipboardTypes(view: *root.View, clipboard: root.Clipboard) u32 {
    const native = @intFromPtr(view.handle orelse return 0);
    const cb: u32 = if (clipboard == .drag) 1 else 0;
    return zpugl_mac_get_num_clipboard_types(native, cb);
}
pub fn getClipboardType(view: *root.View, clipboard: root.Clipboard, type_index: u32) ?[]const u8 {
    const native = @intFromPtr(view.handle orelse return null);
    const cb: u32 = if (clipboard == .drag) 1 else 0;
    const c = zpugl_mac_get_clipboard_type(native, cb, type_index) orelse return null;
    return std.mem.span(c);
}
pub fn acceptOffer(view: *root.View, offer: *const root.DataOfferEvent, type_index: u32, action: root.DataAction, rx: i32, ry: i32, rw: u32, rh: u32) root.Status {
    _ = offer;
    _ = rx;
    _ = ry;
    _ = rw;
    _ = rh;
    const native = @intFromPtr(view.handle orelse return .bad_call);
    const r = zpugl_mac_accept_offer(native, type_index, @backingInt(action));
    return if (r == 0) .success else .failure;
}
pub fn rejectOffer(view: *root.View, offer: *const root.DataOfferEvent, rx: i32, ry: i32, rw: u32, rh: u32) root.Status {
    _ = view;
    _ = offer;
    _ = rx;
    _ = ry;
    _ = rw;
    _ = rh;
    return .unsupported;
}
pub fn setClipboard(view: *root.View, clipboard: root.Clipboard, mime_type: []const u8, data: []const u8) root.Status {
    if (clipboard != .general) return .unsupported;
    var mime_buf: [128]u8 = undefined;
    if (mime_type.len >= mime_buf.len) return .bad_parameter;
    @memcpy(mime_buf[0..mime_type.len], mime_type);
    mime_buf[mime_type.len] = 0;
    const allocator = view.world.allocator;
    const data_ptr = if (data.len > 0) data.ptr else blk: {
        const empty = allocator.alloc(u8, 1) catch return .no_memory;
        defer allocator.free(empty);
        break :blk empty.ptr;
    };
    const r = zpugl_mac_set_clipboard(@ptrCast(&mime_buf), data_ptr, data.len);
    return if (r == 0) .success else .failure;
}
pub fn getClipboard(view: *root.View, clipboard: root.Clipboard, type_index: u32) ?[]const u8 {
    const native = @intFromPtr(view.handle orelse return null);
    const cb: u32 = if (clipboard == .drag) 1 else 0;
    var ptr: [*]const u8 = undefined;
    var len: usize = 0;
    if (zpugl_mac_get_clipboard(native, cb, &ptr, &len, type_index) != 0) return null;
    return ptr[0..len];
}

extern fn zpugl_nswindow_content_view(nswindow: *anyopaque) ?*anyopaque;
pub fn nswindowContentView(nswindow: *anyopaque) ?*anyopaque {
    return zpugl_nswindow_content_view(nswindow);
}

pub extern fn zpugl_mac_start_text_input(native: usize, x: i32, y: i32, w: u32, h: u32) void;
pub extern fn zpugl_mac_stop_text_input(native: usize) void;
pub extern fn zpugl_mac_set_text_input_rect(native: usize, x: i32, y: i32, w: u32, h: u32) void;

pub fn startTextInput(view: *root.View, rect: root.TextInputRect) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    zpugl_mac_start_text_input(native, rect.x, rect.y, rect.width, rect.height);
    return .success;
}
pub fn stopTextInput(view: *root.View) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    zpugl_mac_stop_text_input(native);
    return .success;
}
pub fn setTextInputRect(view: *root.View, rect: root.TextInputRect) root.Status {
    const native = @intFromPtr(view.handle orelse return .bad_call);
    zpugl_mac_set_text_input_rect(native, rect.x, rect.y, rect.width, rect.height);
    return .success;
}

extern fn zpugl_mac_open_url(url: [*:0]const u8) u32;
extern fn zpugl_mac_prefers_dark(native: usize) bool;

pub fn openUrl(url: [:0]const u8) root.Status {
    return if (zpugl_mac_open_url(url.ptr) == 0) .success else .failure;
}

pub fn prefersDark(view: *root.View) ?bool {
    return zpugl_mac_prefers_dark(if (view.handle) |h| @intFromPtr(h) else 0);
}
