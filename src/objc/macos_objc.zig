// Pure-Zig Cocoa glue using zig-objc.
// Classes registered at runtime with names suffixed by a per-dylib hash so
// multiple plugins statically linking zpugl into the same host process do not
// collide in the global ObjC class registry.

const std = @import("std");
const objc = @import("objc");
const c = objc.c;

// --- Apple types ---

const CGFloat = f64;
const NSPoint = extern struct { x: CGFloat, y: CGFloat };
const NSSize = extern struct { width: CGFloat, height: CGFloat };
const NSRect = extern struct { origin: NSPoint, size: NSSize };
const NSTimeInterval = f64;
const NSUInteger = usize;
const NSInteger = isize;

const NSWindowStyleMaskTitled: NSUInteger = 1 << 0;
const NSWindowStyleMaskClosable: NSUInteger = 1 << 1;
const NSWindowStyleMaskMiniaturizable: NSUInteger = 1 << 2;
const NSWindowStyleMaskResizable: NSUInteger = 1 << 3;
const NSWindowStyleMaskUtilityWindow: NSUInteger = 1 << 4;
const NSWindowStyleMaskDocModalWindow: NSUInteger = 1 << 6;
const NSWindowStyleMaskFullScreen: NSUInteger = 1 << 14;

const NSBackingStoreBuffered: NSUInteger = 2;
const NSViewLayerContentsRedrawOnSetNeedsDisplay: NSInteger = 1;

const NSEventMaskAny: u64 = ~@as(u64, 0);
const NSEventTypeKeyDown: NSUInteger = 10;
const NSEventTypeKeyUp: NSUInteger = 11;
const NSTerminateCancel: NSUInteger = 0;

const NSTrackingMouseEnteredAndExited: NSUInteger = 0x01;
const NSTrackingMouseMoved: NSUInteger = 0x02;
const NSTrackingActiveInKeyWindow: NSUInteger = 0x20;
const NSTrackingInVisibleRect: NSUInteger = 0x200;

const NSEventModifierFlagCapsLock: NSUInteger = 1 << 16;
const NSEventModifierFlagShift: NSUInteger = 1 << 17;
const NSEventModifierFlagControl: NSUInteger = 1 << 18;
const NSEventModifierFlagOption: NSUInteger = 1 << 19;
const NSEventModifierFlagCommand: NSUInteger = 1 << 20;

const NSFloatingWindowLevel: NSInteger = 3;
const NSNormalWindowLevel: NSInteger = 0;

const NSViewWidthSizable: NSUInteger = 1 << 1;
const NSViewHeightSizable: NSUInteger = 1 << 4;
const NSViewMinYMargin: NSUInteger = 1 << 3;

// --- Zig callbacks (defined in backend/macos.zig) ---

extern fn zpugl_on_expose(view_ptr: *anyopaque, x: i16, y: i16, w: u16, h: u16) void;
extern fn zpugl_on_configure(view_ptr: *anyopaque, x: i16, y: i16, w: u16, h: u16, state: u32, changed_only: bool) void;
extern fn zpugl_on_close(view_ptr: *anyopaque) void;
extern fn zpugl_on_button(view_ptr: *anyopaque, press: bool, time: f64, x: f64, y: f64, button: u32, mods: u32) void;
extern fn zpugl_on_motion(view_ptr: *anyopaque, time: f64, x: f64, y: f64, mods: u32) void;
extern fn zpugl_on_scroll(view_ptr: *anyopaque, time: f64, x: f64, y: f64, dx: f64, dy: f64, mods: u32) void;
extern fn zpugl_on_key(view_ptr: *anyopaque, press: bool, time: f64, x: f64, y: f64, keycode: u32, key: u32, mods: u32) void;
extern fn zpugl_on_text(view_ptr: *anyopaque, time: f64, x: f64, y: f64, keycode: u32, character: u32, str: [*:0]const u8, mods: u32) void;
extern fn zpugl_on_focus(view_ptr: *anyopaque, gained: bool, mode: u32) void;
extern fn zpugl_on_pointer_cross(view_ptr: *anyopaque, entered: bool, time: f64, x: f64, y: f64, mods: u32, mode: u32) void;
extern fn zpugl_on_timer(view_ptr: *anyopaque, id: usize) void;
extern fn zpugl_on_data_offer(view_ptr: *anyopaque, time: f64, clipboard: u32) void;
extern fn zpugl_on_data(view_ptr: *anyopaque, time: f64, x: f64, y: f64, clipboard: u32, type_index: u32) void;
extern fn zpugl_on_client(view_ptr: *anyopaque, data1: usize, data2: usize) void;

// Mirror of root.ViewStyleFlags layout (must match exactly).
const ViewStyleFlags = packed struct(u32) {
    mapped: bool = false,
    modal: bool = false,
    above: bool = false,
    below: bool = false,
    hidden: bool = false,
    tall: bool = false,
    wide: bool = false,
    fullscreen: bool = false,
    resizing: bool = false,
    demanding: bool = false,
    _reserved: u22 = 0,
};

// --- Per-dylib unique class names ---

var class_name_buf_view: [64]u8 = undefined;
var class_name_buf_timer: [64]u8 = undefined;
var class_name_buf_app_delegate: [64]u8 = undefined;
var class_name_buf_text_proxy: [64]u8 = undefined;
var class_name_buf_metal_view: [64]u8 = undefined;

const Dl_info = extern struct {
    dli_fname: ?[*:0]const u8,
    dli_fbase: ?*anyopaque,
    dli_sname: ?[*:0]const u8,
    dli_saddr: ?*anyopaque,
};
extern "c" fn dladdr(addr: ?*const anyopaque, info: *Dl_info) c_int;

fn dylibSuffix() u64 {
    var info: Dl_info = undefined;
    const probe: *const fn () u64 = &dylibSuffix;
    if (dladdr(@ptrCast(probe), &info) != 0) {
        if (info.dli_fname) |name| {
            return std.hash.Wyhash.hash(0, std.mem.span(name));
        }
    }
    return 0xDEADBEEF;
}

fn viewClassName() [:0]const u8 {
    const s = std.fmt.bufPrintSentinel(&class_name_buf_view, "ZpuglView_{x}", .{dylibSuffix()}, 0) catch unreachable;
    return s;
}
fn timerClassName() [:0]const u8 {
    const s = std.fmt.bufPrintSentinel(&class_name_buf_timer, "ZpuglTimerTarget_{x}", .{dylibSuffix()}, 0) catch unreachable;
    return s;
}
fn appDelegateClassName() [:0]const u8 {
    return std.fmt.bufPrintSentinel(&class_name_buf_app_delegate, "ZpuglAppDelegate_{x}", .{dylibSuffix()}, 0) catch unreachable;
}
fn metalViewClassName() [:0]const u8 {
    return std.fmt.bufPrintSentinel(&class_name_buf_metal_view, "ZpuglMetalView_{x}", .{dylibSuffix()}, 0) catch unreachable;
}
fn textProxyClassName() [:0]const u8 {
    return std.fmt.bufPrintSentinel(&class_name_buf_text_proxy, "ZpuglTextProxy_{x}", .{dylibSuffix()}, 0) catch unreachable;
}

// --- Class registration ---

var view_class: ?objc.Class = null;
var metal_view_class: ?objc.Class = null;
var timer_class: ?objc.Class = null;
var app_delegate_class: ?objc.Class = null;
var text_proxy_class: ?objc.Class = null;
var focus_switch = false;

fn nsView() objc.Class {
    return objc.getClass("NSView").?;
}
fn nsObject() objc.Class {
    return objc.getClass("NSObject").?;
}

fn modsFromFlags(flags: NSUInteger) u32 {
    var m: u32 = 0;
    if (flags & NSEventModifierFlagShift != 0) m |= 1 << 0;
    if (flags & NSEventModifierFlagControl != 0) m |= 1 << 1;
    if (flags & NSEventModifierFlagOption != 0) m |= 1 << 2;
    if (flags & NSEventModifierFlagCommand != 0) m |= 1 << 3;
    if (flags & NSEventModifierFlagCapsLock != 0) m |= 1 << 6;
    return m;
}

inline fn objFromId(id: c.id) objc.Object {
    return .{ .value = id };
}

inline fn ivarPtr(self: c.id) ?*anyopaque {
    const ivar = c.object_getInstanceVariable(self, "zigView", null);
    return @ptrCast(@alignCast(c.object_getIvar(self, ivar)));
}

inline fn setIvarPtr(self: c.id, ptr: ?*anyopaque) void {
    const ivar = c.object_getInstanceVariable(self, "zigView", null);
    c.object_setIvar(self, ivar, @ptrCast(@alignCast(ptr)));
}

inline fn timerIvarSet(self: c.id, view_ptr: ?*anyopaque, id: usize) void {
    const v_ivar = c.object_getInstanceVariable(self, "zigView", null);
    c.object_setIvar(self, v_ivar, @ptrCast(@alignCast(view_ptr)));
    timerIdPtr(self).* = id;
}

inline fn timerIdPtr(self: c.id) *usize {
    const ivar = c.class_getInstanceVariable(c.object_getClass(self), "timerId");
    return @ptrFromInt(@intFromPtr(self) + @as(usize, @intCast(c.ivar_getOffset(ivar))));
}

inline fn timerIvarGet(self: c.id) struct { view: ?*anyopaque, id: usize } {
    const v_ivar = c.object_getInstanceVariable(self, "zigView", null);
    return .{
        .view = @ptrCast(c.object_getIvar(self, v_ivar)),
        .id = timerIdPtr(self).*,
    };
}

// --- Method implementations ---

fn impAcceptsFirstResponder(_: c.id, _: c.SEL) callconv(.c) bool {
    return true;
}
fn impIsFlipped(_: c.id, _: c.SEL) callconv(.c) bool {
    return true;
}
fn impWindowShouldClose(self: c.id, _: c.SEL, _: c.id) callconv(.c) bool {
    if (ivarPtr(self)) |p| zpugl_on_close(p);
    return false;
}

fn exposeIfVisible(self: c.id, rect: NSRect) void {
    const p = ivarPtr(self) orelse return;
    const win = objFromId(self).msgSend(c.id, "window", .{}) orelse return;
    if (!objFromId(win).msgSend(bool, "isVisible", .{})) return;
    if (objFromId(self).msgSend(bool, "isHiddenOrHasHiddenAncestor", .{})) return;
    sendRect(zpugl_on_expose, p, rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
}

fn sendRect(comptime f: anytype, p: *anyopaque, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) void {
    f(p, std.math.lossyCast(i16, x), std.math.lossyCast(i16, y), std.math.lossyCast(u16, w), std.math.lossyCast(u16, h));
}

fn impDrawRect(self: c.id, _: c.SEL, dirty: NSRect) callconv(.c) void {
    exposeIfVisible(self, dirty);
}

fn impSetFrameSize(self: c.id, _: c.SEL, new_size: NSSize) callconv(.c) void {
    const old = objFromId(self).msgSend(NSRect, "frame", .{}).size;
    objFromId(self).msgSendSuper(nsView(), void, "setFrameSize:", .{new_size});
    if (old.width != new_size.width or old.height != new_size.height) objFromId(self).msgSend(void, "setNeedsDisplay:", .{true});
    sendConfigure(self, false);
}

fn windowState(self: c.id) u32 {
    const win = ownWindow(@intFromPtr(self)) orelse return 0;
    const flags: ViewStyleFlags = .{ .mapped = win.msgSend(bool, "isVisible", .{}), .hidden = win.msgSend(bool, "isMiniaturized", .{}) };
    return @bitCast(flags);
}

fn sendConfigure(self: c.id, changed_only: bool) void {
    const p = ivarPtr(self) orelse return;
    const f = objFromId(self).msgSend(NSRect, "frame", .{});
    zpugl_on_configure(p, std.math.lossyCast(i16, f.origin.x), std.math.lossyCast(i16, f.origin.y), std.math.lossyCast(u16, f.size.width), std.math.lossyCast(u16, f.size.height), windowState(self), changed_only);
}

fn impWindowStateChanged(self: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    sendConfigure(self, false);
}

fn impOcclusionChanged(self: c.id, _: c.SEL, note: c.id) callconv(.c) void {
    const win = objFromId(self).msgSend(c.id, "window", .{}) orelse return;
    if (objFromId(note).msgSend(c.id, "object", .{}) != win) return;
    sendConfigure(self, false);
}

fn occlusionName() objc.Object {
    return nsClass("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{@as([*:0]const u8, "NSWindowDidChangeOcclusionStateNotification")});
}

const NSWindowOcclusionStateVisible: NSUInteger = 1 << 1;

export fn zpugl_mac_is_occluded(native: usize) bool {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const win = viewWindow(native) orelse return false;
    return win.msgSend(NSUInteger, "occlusionState", .{}) & NSWindowOcclusionStateVisible == 0;
}

fn buttonImpl(self: c.id, event: c.id, press: bool, btn: u32) void {
    const ev = objFromId(event);
    const win_pt = ev.msgSend(NSPoint, "locationInWindow", .{});
    const obj = objFromId(self);
    const p = obj.msgSend(NSPoint, "convertPoint:fromView:", .{ win_pt, @as(c.id, null) });
    const time = ev.msgSend(NSTimeInterval, "timestamp", .{});
    const flags = ev.msgSend(NSUInteger, "modifierFlags", .{});
    if (ivarPtr(self)) |zp| zpugl_on_button(zp, press, time, p.x, p.y, btn, modsFromFlags(flags));
}

fn impMouseDown(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    focusView(self);
    buttonImpl(self, ev, true, 0);
}
fn impMouseUp(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    buttonImpl(self, ev, false, 0);
}
fn impRightMouseDown(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    buttonImpl(self, ev, true, 1);
}
fn impRightMouseUp(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    buttonImpl(self, ev, false, 1);
}
fn impOtherMouseDown(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    const e = objFromId(ev);
    const n = e.msgSend(NSInteger, "buttonNumber", .{});
    buttonImpl(self, ev, true, @intCast(n));
}
fn impOtherMouseUp(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    const e = objFromId(ev);
    const n = e.msgSend(NSInteger, "buttonNumber", .{});
    buttonImpl(self, ev, false, @intCast(n));
}

fn motionImpl(self: c.id, event: c.id) void {
    const ev = objFromId(event);
    const win_pt = ev.msgSend(NSPoint, "locationInWindow", .{});
    const obj = objFromId(self);
    const p = obj.msgSend(NSPoint, "convertPoint:fromView:", .{ win_pt, @as(c.id, null) });
    const time = ev.msgSend(NSTimeInterval, "timestamp", .{});
    const flags = ev.msgSend(NSUInteger, "modifierFlags", .{});
    if (ivarPtr(self)) |zp| zpugl_on_motion(zp, time, p.x, p.y, modsFromFlags(flags));
}

fn impMouseMoved(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    motionImpl(self, ev);
}
fn impMouseDragged(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    motionImpl(self, ev);
}
fn impRightMouseDragged(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    motionImpl(self, ev);
}
fn impOtherMouseDragged(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    motionImpl(self, ev);
}

fn impScrollWheel(self: c.id, _: c.SEL, event: c.id) callconv(.c) void {
    const ev = objFromId(event);
    const win_pt = ev.msgSend(NSPoint, "locationInWindow", .{});
    const obj = objFromId(self);
    const p = obj.msgSend(NSPoint, "convertPoint:fromView:", .{ win_pt, @as(c.id, null) });
    const div: CGFloat = if (ev.msgSend(bool, "hasPreciseScrollingDeltas", .{})) 20 else 1;
    const dx = ev.msgSend(CGFloat, "scrollingDeltaX", .{}) / div;
    const dy = ev.msgSend(CGFloat, "scrollingDeltaY", .{}) / div;
    const time = ev.msgSend(NSTimeInterval, "timestamp", .{});
    const flags = ev.msgSend(NSUInteger, "modifierFlags", .{});
    if (ivarPtr(self)) |zp| zpugl_on_scroll(zp, time, p.x, p.y, dx, dy, modsFromFlags(flags));
}

fn keyFromEvent(ev: objc.Object) struct { key: u32, ch: u32, has_text: bool, utf8: [*:0]const u8 } {
    const chars_ig = ev.msgSend(c.id, "charactersIgnoringModifiers", .{});
    const keycode = ev.msgSend(u16, "keyCode", .{});
    var k: u32 = 0;
    var ch: u32 = 0;
    if (chars_ig) |ig| {
        const ig_obj: objc.Object = .{ .value = ig };
        const len = ig_obj.msgSend(NSUInteger, "length", .{});
        if (len > 0) {
            var u = ig_obj.msgSend(u16, "characterAtIndex:", .{@as(NSUInteger, 0)});
            // Pugl contract: key is unmodified keysym, ASCII letters lowercased.
            if (u >= 'A' and u <= 'Z') u += 0x20;
            ch = u;
            k = switch (keycode) {
                0x7A => 0xE000,
                0x78 => 0xE001,
                0x63 => 0xE002,
                0x76 => 0xE003,
                0x60 => 0xE004,
                0x61 => 0xE005,
                0x62 => 0xE006,
                0x64 => 0xE007,
                0x65 => 0xE008,
                0x6D => 0xE009,
                0x67 => 0xE00A,
                0x6F => 0xE00B,
                0x7E => 0xE036,
                0x7D => 0xE038,
                0x7B => 0xE035,
                0x7C => 0xE037,
                0x74 => 0xE031,
                0x79 => 0xE032,
                0x73 => 0xE034,
                0x77 => 0xE033,
                0x75 => 0x007F,
                0x35 => 0x001B,
                0x24 => 0x000D,
                0x30 => 0x0009,
                0x33 => 0x0008,
                0x31 => 0x0020,
                else => if (u < 0xF700) @as(u32, u) else 0,
            };
        }
    }
    var utf8: [*:0]const u8 = "";
    var has_text = false;
    const chars = ev.msgSend(c.id, "characters", .{});
    if (chars) |s| {
        const so: objc.Object = .{ .value = s };
        const slen = so.msgSend(NSUInteger, "length", .{});
        if (slen > 0 and k >= 0x20 and k < 0xE000) {
            utf8 = so.msgSend([*:0]const u8, "UTF8String", .{});
            has_text = true;
        }
    }
    return .{ .key = k, .ch = ch, .has_text = has_text, .utf8 = utf8 };
}

fn impKeyDown(self: c.id, _: c.SEL, event: c.id) callconv(.c) void {
    const ev = objFromId(event);
    const time = ev.msgSend(NSTimeInterval, "timestamp", .{});
    const flags = ev.msgSend(NSUInteger, "modifierFlags", .{});
    const keycode = ev.msgSend(u16, "keyCode", .{});
    const k = keyFromEvent(ev);
    const zp = ivarPtr(self) orelse return;
    zpugl_on_key(zp, true, time, 0, 0, keycode, k.key, modsFromFlags(flags));
    const ctx_id = c.object_getIvar(self, c.object_getInstanceVariable(self, "textInputContext", null));
    if (ctx_id != null) {
        _ = (objc.Object{ .value = ctx_id }).msgSend(bool, "handleEvent:", .{ev});
        return;
    }
    const command = flags & NSEventModifierFlagCommand != 0 or (flags & NSEventModifierFlagControl != 0 and flags & NSEventModifierFlagOption == 0);
    if (k.has_text and !command) zpugl_on_text(zp, time, 0, 0, keycode, k.ch, k.utf8, modsFromFlags(flags));
}

fn impKeyUp(self: c.id, _: c.SEL, event: c.id) callconv(.c) void {
    const ev = objFromId(event);
    const time = ev.msgSend(NSTimeInterval, "timestamp", .{});
    const flags = ev.msgSend(NSUInteger, "modifierFlags", .{});
    const keycode = ev.msgSend(u16, "keyCode", .{});
    const k = keyFromEvent(ev);
    if (ivarPtr(self)) |zp| zpugl_on_key(zp, false, time, 0, 0, keycode, k.key, modsFromFlags(flags));
}

fn impFlagsChanged(self: c.id, _: c.SEL, event: c.id) callconv(.c) void {
    const ev = objFromId(event);
    const flags = ev.msgSend(NSUInteger, "modifierFlags", .{});
    const keycode = ev.msgSend(u16, "keyCode", .{});
    const mask: NSUInteger, const key: u32 = switch (keycode) {
        0x38 => .{ NSEventModifierFlagShift, 0xE051 },
        0x3C => .{ NSEventModifierFlagShift, 0xE052 },
        0x3B => .{ NSEventModifierFlagControl, 0xE053 },
        0x3E => .{ NSEventModifierFlagControl, 0xE054 },
        0x3A => .{ NSEventModifierFlagOption, 0xE055 },
        0x3D => .{ NSEventModifierFlagOption, 0xE056 },
        0x37 => .{ NSEventModifierFlagCommand, 0xE057 },
        0x36 => .{ NSEventModifierFlagCommand, 0xE058 },
        0x39 => .{ NSEventModifierFlagCapsLock, 0xE047 },
        else => return,
    };
    const press = flags & mask != 0;
    const zp = ivarPtr(self) orelse return;
    zpugl_on_key(zp, press, ev.msgSend(NSTimeInterval, "timestamp", .{}), 0, 0, keycode, key, modsFromFlags(flags));
}

fn impAcceptsFirstMouse(_: c.id, _: c.SEL, _: c.id) callconv(.c) bool {
    return true;
}

fn crossImpl(self: c.id, event: c.id, entered: bool) void {
    const ev = objFromId(event);
    const win_pt = ev.msgSend(NSPoint, "locationInWindow", .{});
    const obj = objFromId(self);
    const p = obj.msgSend(NSPoint, "convertPoint:fromView:", .{ win_pt, @as(c.id, null) });
    const time = ev.msgSend(NSTimeInterval, "timestamp", .{});
    const flags = ev.msgSend(NSUInteger, "modifierFlags", .{});
    if (ivarPtr(self)) |zp| zpugl_on_pointer_cross(zp, entered, time, p.x, p.y, modsFromFlags(flags), 0);
}

fn impMouseEntered(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    crossImpl(self, ev, true);
}
fn impMouseExited(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    crossImpl(self, ev, false);
}

fn impBecomeFirstResponder(self: c.id, _: c.SEL) callconv(.c) bool {
    const r = objFromId(self).msgSendSuper(nsView(), bool, "becomeFirstResponder", .{});
    if (!focus_switch) if (ivarPtr(self)) |zp| zpugl_on_focus(zp, true, 0);
    return r;
}
fn impResignFirstResponder(self: c.id, _: c.SEL) callconv(.c) bool {
    const r = objFromId(self).msgSendSuper(nsView(), bool, "resignFirstResponder", .{});
    if (!focus_switch) if (ivarPtr(self)) |zp| zpugl_on_focus(zp, false, 0);
    return r;
}

// --- Text proxy ---
// Hosts such as REAPER keep Space and other shortcuts for themselves unless the
// focused view is an NSTextView. While dvui edits text, a zero-sized NSTextView
// subview is first responder and hands every key to the pugl view.

inline fn textInputActive(view: c.id) bool {
    return c.object_getIvar(view, c.object_getInstanceVariable(view, "textInputContext", null)) != null;
}

inline fn textProxy(view: c.id) c.id {
    return c.object_getIvar(view, c.object_getInstanceVariable(view, "textProxy", null));
}

fn focusView(view: c.id) void {
    const win = objFromId(view).msgSend(c.id, "window", .{}) orelse return;
    const proxy = textProxy(view);
    const target = if (proxy != null and textInputActive(view)) proxy else view;
    const fr = objFromId(win).msgSend(c.id, "firstResponder", .{});
    if (fr == target) return;
    focus_switch = fr == view or (proxy != null and fr == proxy);
    defer focus_switch = false;
    objFromId(win).msgSend(void, "makeFirstResponder:", .{objFromId(target)});
}

fn proxyView(self: c.id) ?objc.Object {
    const sv = objFromId(self).msgSend(c.id, "superview", .{}) orelse return null;
    return objFromId(sv);
}
fn impProxyKeyDown(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    if (proxyView(self)) |v| v.msgSend(void, "keyDown:", .{objFromId(ev)});
}
fn impProxyKeyUp(self: c.id, _: c.SEL, ev: c.id) callconv(.c) void {
    if (proxyView(self)) |v| v.msgSend(void, "keyUp:", .{objFromId(ev)});
}
fn impProxyBecomeFirstResponder(self: c.id, _: c.SEL) callconv(.c) bool {
    const r = objFromId(self).msgSendSuper(nsClass("NSTextView"), bool, "becomeFirstResponder", .{});
    if (!focus_switch) if (proxyView(self)) |v| if (ivarPtr(v.value)) |zp| zpugl_on_focus(zp, true, 0);
    return r;
}
fn impProxyResignFirstResponder(self: c.id, _: c.SEL) callconv(.c) bool {
    const r = objFromId(self).msgSendSuper(nsClass("NSTextView"), bool, "resignFirstResponder", .{});
    if (!focus_switch) if (proxyView(self)) |v| if (ivarPtr(v.value)) |zp| zpugl_on_focus(zp, false, 0);
    return r;
}
fn impProxyInputContext(self: c.id, _: c.SEL) callconv(.c) c.id {
    const v = proxyView(self) orelse return null;
    return c.object_getIvar(v.value, c.object_getInstanceVariable(v.value, "textInputContext", null));
}
fn impProxyValidate(_: c.id, _: c.SEL, _: c.id) callconv(.c) bool {
    return true;
}
fn impProxyDrawRect(_: c.id, _: c.SEL, _: NSRect) callconv(.c) void {}
fn proxyForward(self: c.id, comptime sel: [:0]const u8) void {
    if (proxyView(self)) |v| v.msgSend(void, sel, .{@as(c.id, null)});
}
fn impProxyCut(self: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    proxyForward(self, "cut:");
}
fn impProxyCopy(self: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    proxyForward(self, "copy:");
}
fn impProxyPaste(self: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    proxyForward(self, "paste:");
}
fn impProxySelectAll(self: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    proxyForward(self, "selectAll:");
}

fn ensureTextProxyClass() objc.Class {
    if (text_proxy_class) |cls| return cls;
    const cls = objc.allocateClassPair(nsClass("NSTextView"), textProxyClassName()).?;
    std.debug.assert(cls.addMethod("keyDown:", impProxyKeyDown));
    std.debug.assert(cls.addMethod("keyUp:", impProxyKeyUp));
    std.debug.assert(cls.addMethod("becomeFirstResponder", impProxyBecomeFirstResponder));
    std.debug.assert(cls.addMethod("resignFirstResponder", impProxyResignFirstResponder));
    std.debug.assert(cls.addMethod("inputContext", impProxyInputContext));
    std.debug.assert(cls.addMethod("validateMenuItem:", impProxyValidate));
    std.debug.assert(cls.addMethod("validateUserInterfaceItem:", impProxyValidate));
    std.debug.assert(cls.addMethod("drawRect:", impProxyDrawRect));
    std.debug.assert(cls.addMethod("cut:", impProxyCut));
    std.debug.assert(cls.addMethod("copy:", impProxyCopy));
    std.debug.assert(cls.addMethod("paste:", impProxyPaste));
    std.debug.assert(cls.addMethod("selectAll:", impProxySelectAll));
    objc.registerClassPair(cls);
    text_proxy_class = cls;
    return cls;
}

fn ensureTextProxy(view: c.id) void {
    if (textProxy(view) != null) return;
    const proxy = ensureTextProxyClass().msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithFrame:", .{std.mem.zeroes(NSRect)});
    objFromId(view).msgSend(void, "addSubview:", .{proxy});
    proxy.release();
    c.object_setIvar(view, c.object_getInstanceVariable(view, "textProxy", null), proxy.value);
}

// --- NSDraggingDestination ---

const NSDragOperationNone: NSUInteger = 0;
const NSDragOperationCopy: NSUInteger = 1;
const NSDragOperationLink: NSUInteger = 2;
const NSDragOperationMove: NSUInteger = 16;
const NSDragOperationPrivate: NSUInteger = 64;

inline fn dropIvarsGet(self: c.id) struct { drag_source: c.id, drop_types: c.id, accepted_idx: usize, marked_text: c.id, drag_op: NSUInteger } {
    const ds = c.object_getInstanceVariable(self, "dragSource", null);
    const dt = c.object_getInstanceVariable(self, "dropTypes", null);
    const mt = c.object_getInstanceVariable(self, "markedText", null);
    return .{
        .drag_source = c.object_getIvar(self, ds),
        .drop_types = c.object_getIvar(self, dt),
        .accepted_idx = getIvarSmall(self, "acceptedDragTypeIndex"),
        .marked_text = c.object_getIvar(self, mt),
        .drag_op = getIvarSmall(self, "dragOp"),
    };
}

inline fn setIvar(self: c.id, name: [*:0]const u8, val: ?*anyopaque) void {
    const iv = c.object_getInstanceVariable(self, name, null);
    c.object_setIvar(self, iv, @ptrCast(@alignCast(val)));
}

// For storing small integers (<= usize >> 3) packed as ivar pointers, shift left 3 to keep 8-byte alignment.
inline fn setIvarSmall(self: c.id, name: [*:0]const u8, val: usize) void {
    const iv = c.object_getInstanceVariable(self, name, null);
    const shifted: usize = val << 3;
    c.object_setIvar(self, iv, @ptrFromInt(shifted));
}

inline fn getIvarSmall(self: c.id, name: [*:0]const u8) usize {
    const iv = c.object_getInstanceVariable(self, name, null);
    return @intFromPtr(c.object_getIvar(self, iv)) >> 3;
}

fn impDraggingEntered(self: c.id, _: c.SEL, sender: c.id) callconv(.c) c_ulong {
    setIvar(self, "dragSource", sender);
    setIvarSmall(self, "dragOp", NSDragOperationNone);
    setIvarSmall(self, "acceptedDragTypeIndex", 0);
    if (ivarPtr(self)) |p| zpugl_on_data_offer(p, zpugl_mac_get_time(), 1);
    const iv = dropIvarsGet(self);
    return iv.drag_op;
}

fn impDraggingUpdated(self: c.id, _: c.SEL, sender: c.id) callconv(.c) c_ulong {
    setIvar(self, "dragSource", sender);
    if (ivarPtr(self)) |p| zpugl_on_data_offer(p, zpugl_mac_get_time(), 1);
    const iv = dropIvarsGet(self);
    return iv.drag_op;
}

fn impPrepareForDragOperation(_: c.id, _: c.SEL, _: c.id) callconv(.c) bool {
    return true;
}

fn impPerformDragOperation(self: c.id, _: c.SEL, sender: c.id) callconv(.c) bool {
    const iv = dropIvarsGet(self);
    if (iv.accepted_idx == 0) return false;
    const sender_obj: objc.Object = .{ .value = sender };
    const wloc = sender_obj.msgSend(NSPoint, "draggingLocation", .{});
    if (ivarPtr(self)) |p| {
        zpugl_on_data(p, zpugl_mac_get_time(), wloc.x, wloc.y, 1, @intCast(iv.accepted_idx - 1));
    }
    return true;
}

fn impConcludeDragOperation(self: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    setIvar(self, "dragSource", null);
    setIvarSmall(self, "dragOp", NSDragOperationPrivate);
    setIvarSmall(self, "acceptedDragTypeIndex", 0);
}

// --- NSTextInputClient ---

fn impHasMarkedText(self: c.id, _: c.SEL) callconv(.c) bool {
    const iv = dropIvarsGet(self);
    if (iv.marked_text == null) return false;
    const mt: objc.Object = .{ .value = iv.marked_text };
    return mt.msgSend(NSUInteger, "length", .{}) > 0;
}

const NSRange = extern struct { location: c_ulong, length: c_ulong };
const NSNotFound: c_ulong = std.math.maxInt(c_ulong);

fn impMarkedRange(self: c.id, _: c.SEL) callconv(.c) NSRange {
    const iv = dropIvarsGet(self);
    if (iv.marked_text != null) {
        const mt: objc.Object = .{ .value = iv.marked_text };
        const len = mt.msgSend(NSUInteger, "length", .{});
        if (len > 0) return .{ .location = 0, .length = len - 1 };
    }
    return .{ .location = NSNotFound, .length = 0 };
}

fn impSelectedRange(_: c.id, _: c.SEL) callconv(.c) NSRange {
    return .{ .location = NSNotFound, .length = 0 };
}

fn impSetMarkedText(self: c.id, _: c.SEL, string: c.id, _: NSRange, _: NSRange) callconv(.c) void {
    const iv = dropIvarsGet(self);
    if (iv.marked_text != null) {
        (objc.Object{ .value = iv.marked_text }).release();
    }
    if (string == null) {
        setIvar(self, "markedText", null);
        return;
    }
    const NSAttributedString = nsClass("NSAttributedString");
    const NSMutableAttributedString = nsClass("NSMutableAttributedString");
    const so: objc.Object = .{ .value = string };
    const is_attr = so.msgSend(bool, "isKindOfClass:", .{NSAttributedString});
    const new = if (is_attr)
        NSMutableAttributedString.msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "initWithAttributedString:", .{so})
    else
        NSMutableAttributedString.msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "initWithString:", .{so});
    setIvar(self, "markedText", new.value);
}

fn impUnmarkText(self: c.id, _: c.SEL) callconv(.c) void {
    const iv = dropIvarsGet(self);
    if (iv.marked_text != null) {
        const mt: objc.Object = .{ .value = iv.marked_text };
        const ms = mt.msgSend(objc.Object, "mutableString", .{});
        const empty = nsClass("NSString").msgSend(objc.Object, "string", .{});
        ms.msgSend(void, "setString:", .{empty});
    }
}

fn impValidAttributesForMarkedText(_: c.id, _: c.SEL) callconv(.c) c.id {
    return nsClass("NSArray").msgSend(objc.Object, "array", .{}).value;
}

fn impAttributedSubstringForProposedRange(_: c.id, _: c.SEL, _: NSRange, _: ?*NSRange) callconv(.c) c.id {
    return null;
}

fn impCharacterIndexForPoint(_: c.id, _: c.SEL, _: NSPoint) callconv(.c) c_ulong {
    return 0;
}

fn impFirstRectForCharacterRange(self: c.id, _: c.SEL, _: NSRange, _: ?*NSRange) callconv(.c) NSRect {
    const obj = objFromId(self);
    const rx = @as(CGFloat, @floatFromInt(getIvarSmall(self, "textInputRectX")));
    const ry = @as(CGFloat, @floatFromInt(getIvarSmall(self, "textInputRectY")));
    const rw = @as(CGFloat, @floatFromInt(getIvarSmall(self, "textInputRectW")));
    const rh = @as(CGFloat, @floatFromInt(getIvarSmall(self, "textInputRectH")));
    // Convert from view-local coordinates to screen coordinates as NSTextInputClient requires.
    const local = NSRect{ .origin = .{ .x = rx, .y = ry }, .size = .{ .width = rw, .height = rh } };
    const win_id = obj.msgSend(c.id, "window", .{});
    if (win_id) |w| {
        const win: objc.Object = .{ .value = w };
        const win_rect = obj.msgSend(NSRect, "convertRect:toView:", .{ local, @as(c.id, null) });
        return win.msgSend(NSRect, "convertRectToScreen:", .{win_rect});
    }
    return local;
}

fn impDoCommandBySelector(_: c.id, _: c.SEL, _: c.SEL) callconv(.c) void {}

fn impInsertText(self: c.id, _: c.SEL, string: c.id, _: NSRange) callconv(.c) void {
    if (string == null) return;
    const NSAttributedString = nsClass("NSAttributedString");
    const so: objc.Object = .{ .value = string };
    const is_attr = so.msgSend(bool, "isKindOfClass:", .{NSAttributedString});
    const ns_str = if (is_attr) so.msgSend(objc.Object, "string", .{}) else so;
    const utf8 = ns_str.msgSend([*:0]const u8, "UTF8String", .{});
    const length = ns_str.msgSend(NSUInteger, "length", .{});
    if (length == 0) return;

    const app = nsApp();
    const cur_event = app.msgSend(c.id, "currentEvent", .{});
    var time: f64 = zpugl_mac_get_time();
    var keycode: u16 = 0;
    var flags: NSUInteger = 0;
    if (cur_event) |e| {
        const eo: objc.Object = .{ .value = e };
        time = eo.msgSend(NSTimeInterval, "timestamp", .{});
        flags = eo.msgSend(NSUInteger, "modifierFlags", .{});
        const t = eo.msgSend(NSUInteger, "type", .{});
        if (t == NSEventTypeKeyDown or t == NSEventTypeKeyUp) keycode = eo.msgSend(u16, "keyCode", .{});
    }
    const ch0 = ns_str.msgSend(u16, "characterAtIndex:", .{@as(NSUInteger, 0)});
    impUnmarkText(self, undefined);
    if (ivarPtr(self)) |p| {
        zpugl_on_text(p, time, 0, 0, keycode, ch0, utf8, modsFromFlags(flags));
    }
}

fn editKey(self: c.id, key: u32, keycode: u32) void {
    const p = ivarPtr(self) orelse return;
    const cmd: u32 = 1 << 3;
    zpugl_on_key(p, true, 0, 0, 0, keycode, key, cmd);
    zpugl_on_key(p, false, 0, 0, 0, keycode, key, cmd);
}
fn impCut(self: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    editKey(self, 'x', 7);
}
fn impCopy(self: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    editKey(self, 'c', 8);
}
fn impPaste(self: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    editKey(self, 'v', 9);
}
fn impSelectAll(self: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    editKey(self, 'a', 0);
}

fn zigViewOfWindow(win: objc.Object) ?*anyopaque {
    const cv = win.msgSend(c.id, "contentView", .{}) orelse return null;
    if (!objFromId(cv).msgSend(bool, "isKindOfClass:", .{ensureViewClass()})) return null;
    return ivarPtr(cv);
}

fn impApplicationShouldTerminate(_: c.id, _: c.SEL, _: c.id) callconv(.c) c_ulong {
    const windows = nsApp().msgSend(objc.Object, "windows", .{});
    const n = windows.msgSend(NSUInteger, "count", .{});
    var i: NSUInteger = 0;
    while (i < n) : (i += 1) {
        const win = windows.msgSend(objc.Object, "objectAtIndex:", .{i});
        if (zigViewOfWindow(win)) |p| zpugl_on_close(p);
    }
    return NSTerminateCancel;
}

fn impTimerFire(self: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    const t = timerIvarGet(self);
    if (t.view) |v| zpugl_on_timer(v, t.id);
}

// --- Class init ---

fn ensureViewClass() objc.Class {
    if (view_class) |cls| return cls;
    const cls = objc.allocateClassPair(nsView(), viewClassName()).?;
    _ = cls.addIvar("zigView");
    _ = cls.addIvar("dragSource");
    _ = cls.addIvar("dropTypes");
    _ = cls.addIvar("acceptedDragTypeIndex");
    _ = cls.addIvar("markedText");
    _ = cls.addIvar("dragOp");
    _ = cls.addIvar("textInputContext");
    _ = cls.addIvar("textProxy");
    _ = cls.addIvar("textInputRectX");
    _ = cls.addIvar("textInputRectY");
    _ = cls.addIvar("textInputRectW");
    _ = cls.addIvar("textInputRectH");
    std.debug.assert(cls.addMethod("acceptsFirstResponder", impAcceptsFirstResponder));
    std.debug.assert(cls.addMethod("isFlipped", impIsFlipped));
    std.debug.assert(cls.addMethod("windowShouldClose:", impWindowShouldClose));
    std.debug.assert(cls.addMethod("windowDidMiniaturize:", impWindowStateChanged));
    std.debug.assert(cls.addMethod("windowDidDeminiaturize:", impWindowStateChanged));
    std.debug.assert(cls.addMethod("zpuglOcclusionChanged:", impOcclusionChanged));
    std.debug.assert(cls.addMethod("drawRect:", impDrawRect));
    std.debug.assert(cls.addMethod("setFrameSize:", impSetFrameSize));
    std.debug.assert(cls.addMethod("mouseDown:", impMouseDown));
    std.debug.assert(cls.addMethod("mouseUp:", impMouseUp));
    std.debug.assert(cls.addMethod("rightMouseDown:", impRightMouseDown));
    std.debug.assert(cls.addMethod("rightMouseUp:", impRightMouseUp));
    std.debug.assert(cls.addMethod("otherMouseDown:", impOtherMouseDown));
    std.debug.assert(cls.addMethod("otherMouseUp:", impOtherMouseUp));
    std.debug.assert(cls.addMethod("mouseMoved:", impMouseMoved));
    std.debug.assert(cls.addMethod("mouseDragged:", impMouseDragged));
    std.debug.assert(cls.addMethod("rightMouseDragged:", impRightMouseDragged));
    std.debug.assert(cls.addMethod("otherMouseDragged:", impOtherMouseDragged));
    std.debug.assert(cls.addMethod("scrollWheel:", impScrollWheel));
    std.debug.assert(cls.addMethod("keyDown:", impKeyDown));
    std.debug.assert(cls.addMethod("keyUp:", impKeyUp));
    std.debug.assert(cls.addMethod("flagsChanged:", impFlagsChanged));
    std.debug.assert(cls.addMethod("acceptsFirstMouse:", impAcceptsFirstMouse));
    std.debug.assert(cls.addMethod("mouseEntered:", impMouseEntered));
    std.debug.assert(cls.addMethod("mouseExited:", impMouseExited));
    std.debug.assert(cls.addMethod("becomeFirstResponder", impBecomeFirstResponder));
    std.debug.assert(cls.addMethod("resignFirstResponder", impResignFirstResponder));
    // NSDraggingDestination
    std.debug.assert(cls.addMethod("draggingEntered:", impDraggingEntered));
    std.debug.assert(cls.addMethod("draggingUpdated:", impDraggingUpdated));
    std.debug.assert(cls.addMethod("prepareForDragOperation:", impPrepareForDragOperation));
    std.debug.assert(cls.addMethod("performDragOperation:", impPerformDragOperation));
    std.debug.assert(cls.addMethod("concludeDragOperation:", impConcludeDragOperation));
    // NSTextInputClient
    std.debug.assert(cls.addMethod("hasMarkedText", impHasMarkedText));
    std.debug.assert(cls.addMethod("markedRange", impMarkedRange));
    std.debug.assert(cls.addMethod("selectedRange", impSelectedRange));
    std.debug.assert(cls.addMethod("setMarkedText:selectedRange:replacementRange:", impSetMarkedText));
    std.debug.assert(cls.addMethod("unmarkText", impUnmarkText));
    std.debug.assert(cls.addMethod("validAttributesForMarkedText", impValidAttributesForMarkedText));
    std.debug.assert(cls.addMethod("attributedSubstringForProposedRange:actualRange:", impAttributedSubstringForProposedRange));
    std.debug.assert(cls.addMethod("characterIndexForPoint:", impCharacterIndexForPoint));
    std.debug.assert(cls.addMethod("firstRectForCharacterRange:actualRange:", impFirstRectForCharacterRange));
    std.debug.assert(cls.addMethod("doCommandBySelector:", impDoCommandBySelector));
    std.debug.assert(cls.addMethod("insertText:replacementRange:", impInsertText));
    // NSTextInputContext only calls insertText:replacementRange: on clients
    // that declare the protocol; without it handleEvent: eats every key.
    if (c.objc_getProtocol("NSTextInputClient")) |proto| _ = c.class_addProtocol(cls.value, proto);
    std.debug.assert(cls.addMethod("cut:", impCut));
    std.debug.assert(cls.addMethod("copy:", impCopy));
    std.debug.assert(cls.addMethod("paste:", impPaste));
    std.debug.assert(cls.addMethod("selectAll:", impSelectAll));
    objc.registerClassPair(cls);
    view_class = cls;
    return cls;
}

fn impMakeBackingLayer(self: c.id, _: c.SEL) callconv(.c) c.id {
    const layer = nsClass("CAMetalLayer").msgSend(objc.Object, "layer", .{});
    layer.msgSend(void, "setDelegate:", .{self});
    return layer.value;
}

fn displayRequestedPtr(self: c.id) *usize {
    const ivar = c.class_getInstanceVariable(c.object_getClass(self), "displayRequested");
    return @ptrFromInt(@intFromPtr(self) + @as(usize, @intCast(c.ivar_getOffset(ivar))));
}

fn impMetalSetNeedsDisplay(self: c.id, _: c.SEL, flag: bool) callconv(.c) void {
    if (flag) displayRequestedPtr(self).* = 1;
    objFromId(self).msgSendSuper(ensureViewClass(), void, "setNeedsDisplay:", .{flag});
}

fn impMetalSetNeedsDisplayInRect(self: c.id, _: c.SEL, rect: NSRect) callconv(.c) void {
    displayRequestedPtr(self).* = 1;
    objFromId(self).msgSendSuper(ensureViewClass(), void, "setNeedsDisplayInRect:", .{rect});
}

fn impMetalDisplayLayer(self: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    const requested = displayRequestedPtr(self);
    if (requested.* == 0) return;
    requested.* = 0;
    exposeIfVisible(self, objFromId(self).msgSend(NSRect, "bounds", .{}));
}

fn ensureMetalViewClass() objc.Class {
    if (metal_view_class) |cls| return cls;
    const cls = objc.allocateClassPair(ensureViewClass(), metalViewClassName()).?;
    _ = cls.addIvar("displayRequested");
    std.debug.assert(cls.addMethod("makeBackingLayer", impMakeBackingLayer));
    std.debug.assert(cls.addMethod("setNeedsDisplay:", impMetalSetNeedsDisplay));
    std.debug.assert(cls.addMethod("setNeedsDisplayInRect:", impMetalSetNeedsDisplayInRect));
    std.debug.assert(cls.addMethod("displayLayer:", impMetalDisplayLayer));
    objc.registerClassPair(cls);
    metal_view_class = cls;
    return cls;
}

fn ensureTimerClass() objc.Class {
    if (timer_class) |cls| return cls;
    const cls = objc.allocateClassPair(nsObject(), timerClassName()).?;
    _ = cls.addIvar("zigView");
    _ = cls.addIvar("timerId");
    std.debug.assert(cls.addMethod("fire:", impTimerFire));
    objc.registerClassPair(cls);
    timer_class = cls;
    return cls;
}

fn ensureAppDelegateClass() objc.Class {
    if (app_delegate_class) |cls| return cls;
    const cls = objc.allocateClassPair(nsObject(), appDelegateClassName()).?;
    std.debug.assert(cls.addMethod("applicationShouldTerminate:", impApplicationShouldTerminate));
    objc.registerClassPair(cls);
    app_delegate_class = cls;
    return cls;
}

fn nsString(s: [*:0]const u8) objc.Object {
    return nsClass("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{s});
}

fn menuItem(title: objc.Object, action: ?[:0]const u8, key: [*:0]const u8) objc.Object {
    const sel: c.SEL = if (action) |a| objc.sel(a).value else null;
    return nsClass("NSMenuItem").msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithTitle:action:keyEquivalent:", .{ title, sel, nsString(key) });
}

fn addSubmenu(bar: objc.Object, title: [*:0]const u8, items: []const objc.Object) void {
    const menu = nsClass("NSMenu").msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithTitle:", .{nsString(title)});
    for (items) |item| menu.msgSend(void, "addItem:", .{item});
    const holder = menuItem(nsString(title), null, "");
    holder.msgSend(void, "setSubmenu:", .{menu});
    bar.msgSend(void, "addItem:", .{holder});
}

fn installAppMenu(app: objc.Object) void {
    if (app.msgSend(c.id, "delegate", .{}) == null) {
        const delegate = ensureAppDelegateClass().msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
        app.msgSend(void, "setDelegate:", .{delegate});
    }
    if (app.msgSend(c.id, "mainMenu", .{}) != null) return;
    const name = nsClass("NSProcessInfo").msgSend(objc.Object, "processInfo", .{}).msgSend(objc.Object, "processName", .{});
    const quit_title = nsString("Quit ").msgSend(objc.Object, "stringByAppendingString:", .{name});
    const bar = nsClass("NSMenu").msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
    addSubmenu(bar, "", &.{menuItem(quit_title, "terminate:", "q")});
    addSubmenu(bar, "Edit", &.{
        menuItem(nsString("Cut"), "cut:", "x"),
        menuItem(nsString("Copy"), "copy:", "c"),
        menuItem(nsString("Paste"), "paste:", "v"),
        menuItem(nsString("Select All"), "selectAll:", "a"),
    });
    app.msgSend(void, "setMainMenu:", .{bar});
}

// --- Helpers ---

inline fn nsClass(name: [:0]const u8) objc.Class {
    return objc.getClass(name).?;
}

fn nsApp() objc.Object {
    return nsClass("NSApplication").msgSend(objc.Object, "sharedApplication", .{});
}

fn isMainThread() bool {
    return nsClass("NSThread").msgSend(bool, "isMainThread", .{});
}

// --- Exported C ABI for backend/macos.zig ---

// Tracking area so the view gets mouseMoved: by geometry rather than only via
// first-responder routing. Required for embedded child views — they are never
// made first responder, so without this they receive no hover events.
fn addTrackingArea(view: objc.Object) void {
    const bounds = view.msgSend(NSRect, "bounds", .{});
    const area = nsClass("NSTrackingArea")
        .msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithRect:options:owner:userInfo:", .{
        bounds,
        NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect,
        view,
        @as(c.id, null),
    });
    view.msgSend(void, "addTrackingArea:", .{area});
}

export fn zpugl_mac_create_view(
    view_ptr: *anyopaque,
    parent_native: usize,
    x: f64,
    y: f64,
    w: f64,
    h: f64,
    resizable: bool,
    dark_frame: bool,
    view_type: u32,
    has_pos: bool,
    metal: bool,
) usize {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (!isMainThread()) return 0;

    const app = nsApp();
    const running = app.msgSend(bool, "isRunning", .{});
    if (!running) {
        app.msgSend(void, "setActivationPolicy:", .{@as(NSInteger, 0)});
        installAppMenu(app);
        app.msgSend(void, "finishLaunching", .{});
    }

    const cls = if (metal) ensureMetalViewClass() else ensureViewClass();
    const view = cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithFrame:", .{NSRect{
        .origin = .{ .x = x, .y = y },
        .size = .{ .width = w, .height = h },
    }});
    _ = view_ptr;
    if (metal) {
        view.msgSend(void, "setWantsLayer:", .{true});
        view.msgSend(void, "setLayerContentsRedrawPolicy:", .{NSViewLayerContentsRedrawOnSetNeedsDisplay});
        view.msgSend(void, "setNeedsDisplay:", .{true});
    }

    if (parent_native != 0) {
        const parent: objc.Object = .{ .value = @ptrFromInt(parent_native) };
        parent.msgSend(void, "addSubview:", .{view});
        if (!parent.msgSend(bool, "isFlipped", .{})) view.msgSend(void, "setAutoresizingMask:", .{NSViewMinYMargin});
        zpugl_mac_set_view_position(@intFromPtr(view.value), @intFromFloat(x), @intFromFloat(y));
        addTrackingArea(view);
    } else {
        var style: NSUInteger = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable;
        if (resizable) style |= NSWindowStyleMaskResizable;
        if (view_type == 1) style |= NSWindowStyleMaskUtilityWindow;
        if (view_type == 2) style |= NSWindowStyleMaskDocModalWindow;

        const win = nsClass("NSWindow")
            .msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "initWithContentRect:styleMask:backing:defer:", .{
            NSRect{ .origin = .{ .x = x, .y = y }, .size = .{ .width = w, .height = h } },
            style,
            NSBackingStoreBuffered,
            false,
        });
        // NSWindow defaults releaseWhenClosed=YES; explicit retain balances it.
        _ = win.retain();

        if (dark_frame) {
            const ns_str = nsClass("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{@as([*:0]const u8, "NSAppearanceNameDarkAqua")});
            const appearance = nsClass("NSAppearance").msgSend(objc.Object, "appearanceNamed:", .{ns_str});
            win.msgSend(void, "setAppearance:", .{appearance});
        }

        if (!has_pos or !placeWindow(win, x, y)) win.msgSend(void, "center", .{});

        win.msgSend(void, "setContentView:", .{view});
        win.msgSend(void, "setDelegate:", .{view});
        win.msgSend(void, "makeFirstResponder:", .{view});

        addTrackingArea(view);
    }

    return @intFromPtr(view.value);
}

export fn zpugl_mac_realized(native: usize, view_ptr: *anyopaque) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const view = objFromId(@ptrFromInt(native));
    setIvarPtr(view.value, view_ptr);
    nsClass("NSNotificationCenter").msgSend(objc.Object, "defaultCenter", .{}).msgSend(void, "addObserver:selector:name:object:", .{ view, objc.sel("zpuglOcclusionChanged:"), occlusionName(), @as(c.id, null) });
    sendConfigure(view.value, false);
}

export fn zpugl_mac_destroy_view(native: usize) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (native == 0) return;
    const view: objc.Object = .{ .value = @ptrFromInt(native) };
    if (ivarPtr(view.value)) |p| stopViewTimers(@intFromPtr(p));
    nsClass("NSNotificationCenter").msgSend(objc.Object, "defaultCenter", .{}).msgSend(void, "removeObserver:", .{view});
    zpugl_mac_stop_text_input(native);
    const win_id = view.msgSend(c.id, "window", .{});
    var owned_window: ?objc.Object = null;
    if (win_id) |w| {
        const wo: objc.Object = .{ .value = w };
        const cv = wo.msgSend(c.id, "contentView", .{});
        if (cv == view.value) owned_window = wo;
    }
    view.msgSend(void, "removeFromSuperview", .{});
    if (owned_window) |wo| {
        wo.msgSend(void, "setDelegate:", .{@as(c.id, null)});
        wo.msgSend(void, "close", .{});
    }
    view.release();
    if (owned_window) |wo| {
        wo.release();
    }
}

export fn zpugl_mac_show_view(native: usize, command: u32) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const view: objc.Object = .{ .value = @ptrFromInt(native) };
    view.msgSend(void, "setNeedsDisplay:", .{true});
    const win = ownWindow(native) orelse return view.msgSend(void, "setHidden:", .{false});
    switch (command) {
        2 => {
            nsApp().msgSend(void, "activateIgnoringOtherApps:", .{true});
            win.msgSend(void, "makeKeyAndOrderFront:", .{@as(c.id, null)});
        },
        1 => win.msgSend(void, "makeKeyAndOrderFront:", .{@as(c.id, null)}),
        else => win.msgSend(void, "orderFront:", .{@as(c.id, null)}),
    }
    sendConfigure(view.value, true);
}

export fn zpugl_mac_hide_view(native: usize) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const win = ownWindow(native) orelse return objFromId(@ptrFromInt(native)).msgSend(void, "setHidden:", .{true});
    win.msgSend(void, "orderOut:", .{@as(c.id, null)});
    sendConfigure(@ptrFromInt(native), true);
}

inline fn viewWindow(native: usize) ?objc.Object {
    const view: objc.Object = .{ .value = @ptrFromInt(native) };
    const w = view.msgSend(c.id, "window", .{}) orelse return null;
    return .{ .value = w };
}

fn ownWindow(native: usize) ?objc.Object {
    const win = viewWindow(native) orelse return null;
    return if (win.msgSend(c.id, "contentView", .{}) == @as(c.id, @ptrFromInt(native))) win else null;
}

fn primaryScreenHeight() CGFloat {
    const screens = nsClass("NSScreen").msgSend(objc.Object, "screens", .{});
    if (screens.msgSend(NSUInteger, "count", .{}) == 0) return 0;
    return screens.msgSend(objc.Object, "objectAtIndex:", .{@as(NSUInteger, 0)}).msgSend(NSRect, "frame", .{}).size.height;
}

fn placeWindow(win: objc.Object, x: f64, y: f64) bool {
    const screens = nsClass("NSScreen").msgSend(objc.Object, "screens", .{});
    const n = screens.msgSend(NSUInteger, "count", .{});
    if (n == 0) return false;
    var f = win.msgSend(NSRect, "frame", .{});
    f.origin = .{ .x = x, .y = primaryScreenHeight() - y - f.size.height };
    for (0..n) |i| {
        const s = screens.msgSend(objc.Object, "objectAtIndex:", .{@as(NSUInteger, i)}).msgSend(NSRect, "visibleFrame", .{});
        if (f.origin.x < s.origin.x + s.size.width and s.origin.x < f.origin.x + f.size.width and
            f.origin.y < s.origin.y + s.size.height and s.origin.y < f.origin.y + f.size.height)
        {
            win.msgSend(void, "setFrameOrigin:", .{f.origin});
            return true;
        }
    }
    return false;
}

export fn zpugl_mac_window_position(native: usize, x: *i32, y: *i32) bool {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const win = viewWindow(native) orelse return false;
    const f = win.msgSend(NSRect, "frame", .{});
    x.* = @intFromFloat(@round(f.origin.x));
    y.* = @intFromFloat(@round(primaryScreenHeight() - f.origin.y - f.size.height));
    return true;
}

export fn zpugl_mac_set_size(native: usize, w: u32, h: u32) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const view: objc.Object = .{ .value = @ptrFromInt(native) };
    const size: NSSize = .{ .width = @floatFromInt(w), .height = @floatFromInt(h) };
    const win = viewWindow(native);
    if (win) |wo| if (wo.msgSend(c.id, "contentView", .{}) == view.value) {
        wo.msgSend(void, "setContentSize:", .{size});
        return;
    };
    const sv_id = view.msgSend(c.id, "superview", .{}) orelse return;
    var frame = view.msgSend(NSRect, "frame", .{});
    if (!(objc.Object{ .value = sv_id }).msgSend(bool, "isFlipped", .{})) frame.origin.y += frame.size.height - size.height;
    frame.size = size;
    view.msgSend(void, "setFrame:", .{frame});
}
// Move an embedded child view to (x, y) within its superview. The host passes
// top-left coordinates; macOS NSViews are bottom-left unless flipped, so the
// y is converted when the superview is not flipped.
export fn zpugl_mac_set_view_position(native: usize, x: i32, y: i32) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (ownWindow(native)) |win| {
        const f = win.msgSend(NSRect, "frame", .{});
        win.msgSend(void, "setFrameOrigin:", .{NSPoint{ .x = @floatFromInt(x), .y = primaryScreenHeight() - @as(CGFloat, @floatFromInt(y)) - f.size.height }});
        return;
    }
    const view: objc.Object = .{ .value = @ptrFromInt(native) };
    const sv_id = view.msgSend(c.id, "superview", .{}) orelse return;
    const superview: objc.Object = .{ .value = sv_id };
    const frame = view.msgSend(NSRect, "frame", .{});
    var oy: CGFloat = @floatFromInt(y);
    if (!superview.msgSend(bool, "isFlipped", .{})) {
        const sb = superview.msgSend(NSRect, "bounds", .{});
        oy = sb.size.height - @as(CGFloat, @floatFromInt(y)) - frame.size.height;
    }
    view.msgSend(void, "setFrameOrigin:", .{NSPoint{ .x = @floatFromInt(x), .y = oy }});
}
export fn zpugl_mac_set_min_size(native: usize, w: u32, h: u32) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (ownWindow(native)) |win| {
        win.msgSend(void, "setContentMinSize:", .{NSSize{ .width = @floatFromInt(w), .height = @floatFromInt(h) }});
    }
}
export fn zpugl_mac_set_max_size(native: usize, w: u32, h: u32) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (ownWindow(native)) |win| {
        win.msgSend(void, "setContentMaxSize:", .{NSSize{ .width = @floatFromInt(w), .height = @floatFromInt(h) }});
    }
}
export fn zpugl_mac_set_title(native: usize, title: [*:0]const u8) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (ownWindow(native)) |win| {
        const s = nsClass("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{title});
        win.msgSend(void, "setTitle:", .{s});
    }
}
export fn zpugl_mac_get_scale_factor(native: usize) f64 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (viewWindow(native)) |win| return win.msgSend(CGFloat, "backingScaleFactor", .{});
    const screen = nsClass("NSScreen").msgSend(c.id, "mainScreen", .{}) orelse return 1.0;
    return objFromId(screen).msgSend(CGFloat, "backingScaleFactor", .{});
}
export fn zpugl_mac_grab_focus(native: usize) bool {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (objFromId(@ptrFromInt(native)).msgSend(bool, "isHiddenOrHasHiddenAncestor", .{})) return false;
    focusView(@ptrFromInt(native));
    return true;
}
export fn zpugl_mac_has_focus(native: usize) bool {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const view: c.id = @ptrFromInt(native);
    if (viewWindow(native)) |win| {
        const fr = win.msgSend(c.id, "firstResponder", .{});
        return fr == view or (fr != null and fr == textProxy(view));
    }
    return false;
}

fn extendedCursor(sel_name: [:0]const u8) ?objc.Object {
    const NSCursor = nsClass("NSCursor");
    const sel = objc.sel(sel_name);
    if (NSCursor.msgSend(bool, "respondsToSelector:", .{sel})) {
        const obj = NSCursor.msgSend(c.id, "performSelector:", .{sel});
        if (obj != null) return objc.Object{ .value = obj };
    }
    return null;
}

export fn zpugl_mac_set_cursor(_: usize, cursor_type: u32) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const NSCursor = nsClass("NSCursor");
    var cursor: objc.Object = undefined;
    switch (cursor_type) {
        1 => cursor = NSCursor.msgSend(objc.Object, "IBeamCursor", .{}),
        2 => cursor = NSCursor.msgSend(objc.Object, "crosshairCursor", .{}),
        3 => cursor = NSCursor.msgSend(objc.Object, "pointingHandCursor", .{}),
        4 => cursor = NSCursor.msgSend(objc.Object, "operationNotAllowedCursor", .{}),
        5 => cursor = NSCursor.msgSend(objc.Object, "resizeLeftRightCursor", .{}),
        6 => cursor = NSCursor.msgSend(objc.Object, "resizeUpDownCursor", .{}),
        7 => cursor = extendedCursor("_windowResizeNorthWestSouthEastCursor") orelse NSCursor.msgSend(objc.Object, "arrowCursor", .{}),
        8 => cursor = extendedCursor("_windowResizeNorthEastSouthWestCursor") orelse NSCursor.msgSend(objc.Object, "arrowCursor", .{}),
        9 => cursor = NSCursor.msgSend(objc.Object, "closedHandCursor", .{}),
        else => cursor = NSCursor.msgSend(objc.Object, "arrowCursor", .{}),
    }
    cursor.msgSend(void, "set", .{});
}

export fn zpugl_mac_obscure_view(native: usize) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const view: objc.Object = .{ .value = @ptrFromInt(native) };
    view.msgSend(void, "setNeedsDisplay:", .{true});
}

export fn zpugl_mac_obscure_region(native: usize, x: f64, y: f64, w: f64, h: f64) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const view: objc.Object = .{ .value = @ptrFromInt(native) };
    view.msgSend(void, "setNeedsDisplayInRect:", .{NSRect{
        .origin = .{ .x = x, .y = y },
        .size = .{ .width = w, .height = h },
    }});
}

export fn zpugl_mac_set_transient_parent(child_native: usize, parent_native: usize) u32 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (child_native == 0 or parent_native == 0) return 1;
    const child_win = ownWindow(child_native) orelse return 1;
    const parent_win = viewWindow(parent_native) orelse return 1;
    if (parent_win.value == child_win.value) return 1;
    parent_win.msgSend(void, "addChildWindow:ordered:", .{ child_win, @as(NSInteger, 1) });
    return 0;
}

export fn zpugl_mac_update(timeout: f64) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const NSDate = nsClass("NSDate");
    var until = if (timeout < 0)
        NSDate.msgSend(objc.Object, "distantFuture", .{})
    else if (timeout == 0)
        NSDate.msgSend(objc.Object, "distantPast", .{})
    else
        NSDate.msgSend(objc.Object, "dateWithTimeIntervalSinceNow:", .{@as(NSTimeInterval, timeout)});
    const app = nsApp();
    while (true) {
        const ev = app.msgSend(c.id, "nextEventMatchingMask:untilDate:inMode:dequeue:", .{
            NSEventMaskAny,
            until,
            nsClass("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{@as([*:0]const u8, "kCFRunLoopDefaultMode")}),
            true,
        });
        if (ev == null) break;
        const evo = objFromId(ev);
        app.msgSend(void, "sendEvent:", .{evo});
        until = NSDate.msgSend(objc.Object, "distantPast", .{});
    }
}

const ClientEvent = struct { window: NSInteger, data1: usize, data2: usize };

const CFRunLoopObserverContext = extern struct {
    version: isize = 0,
    info: ?*anyopaque,
    retain: ?*const anyopaque = null,
    release: ?*const fn (?*anyopaque) callconv(.c) void,
    copyDescription: ?*const anyopaque = null,
};
const kCFRunLoopBeforeSources: usize = 1 << 2;
extern "c" const kCFRunLoopCommonModes: *anyopaque;
extern "c" fn CFRunLoopGetMain() *anyopaque;
extern "c" fn CFRunLoopObserverCreate(allocator: ?*anyopaque, activities: usize, repeats: bool, order: isize, callout: *const fn (?*anyopaque, usize, ?*anyopaque) callconv(.c) void, context: *const CFRunLoopObserverContext) ?*anyopaque;
extern "c" fn CFRunLoopAddObserver(rl: *anyopaque, observer: *anyopaque, mode: *anyopaque) void;
extern "c" fn CFRelease(cf: *anyopaque) void;

fn clientFire(_: ?*anyopaque, _: usize, info: ?*anyopaque) callconv(.c) void {
    const ev: *const ClientEvent = @ptrCast(@alignCast(info.?));
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const win = nsApp().msgSend(c.id, "windowWithWindowNumber:", .{ev.window}) orelse return;
    const p = zigViewOfWindow(objFromId(win)) orelse return;
    zpugl_on_client(p, ev.data1, ev.data2);
}

fn clientFree(info: ?*anyopaque) callconv(.c) void {
    std.heap.c_allocator.destroy(@as(*ClientEvent, @ptrCast(@alignCast(info.?))));
}

export fn zpugl_mac_send_client(native: usize, data1: usize, data2: usize) u32 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const win = viewWindow(native) orelse return 1;
    const ev = std.heap.c_allocator.create(ClientEvent) catch return 1;
    ev.* = .{ .window = win.msgSend(NSInteger, "windowNumber", .{}), .data1 = data1, .data2 = data2 };
    const context: CFRunLoopObserverContext = .{ .info = ev, .release = clientFree };
    const observer = CFRunLoopObserverCreate(null, kCFRunLoopBeforeSources, false, 0, clientFire, &context) orelse {
        std.heap.c_allocator.destroy(ev);
        return 1;
    };
    CFRunLoopAddObserver(CFRunLoopGetMain(), observer, kCFRunLoopCommonModes);
    CFRelease(observer);
    return 0;
}

export fn zpugl_mac_get_time() f64 {
    return nsClass("NSDate").msgSend(NSTimeInterval, "timeIntervalSinceReferenceDate", .{});
}

export fn zpugl_mac_set_view_style(native: usize, flags: u32) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const win = ownWindow(native) orelse return;
    const f: ViewStyleFlags = @bitCast(flags);
    var mask = win.msgSend(NSUInteger, "styleMask", .{});
    if (f.resizing) mask |= NSWindowStyleMaskResizable else mask &= ~NSWindowStyleMaskResizable;
    if ((mask & NSWindowStyleMaskFullScreen) == 0) {
        win.msgSend(void, "setStyleMask:", .{mask});
    }
    win.msgSend(void, "setLevel:", .{@as(NSInteger, if (f.above) NSFloatingWindowLevel else NSNormalWindowLevel)});
    if (f.hidden != win.msgSend(bool, "isMiniaturized", .{})) win.msgSend(void, if (f.hidden) "miniaturize:" else "deminiaturize:", .{@as(c.id, null)});
    const is_fs = (win.msgSend(NSUInteger, "styleMask", .{}) & NSWindowStyleMaskFullScreen) != 0;
    if (f.fullscreen != is_fs) win.msgSend(void, "toggleFullScreen:", .{@as(c.id, null)});
    if (f.demanding) _ = nsApp().msgSend(NSInteger, "requestUserAttention:", .{@as(NSUInteger, 10)});
}

export fn zpugl_mac_send_close(native: usize) u32 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const view: objc.Object = .{ .value = @ptrFromInt(native) };
    if (ownWindow(native)) |win| {
        win.msgSend(void, "performClose:", .{@as(c.id, null)});
    } else {
        if (ivarPtr(view.value)) |p| zpugl_on_close(p);
    }
    return 0;
}

// --- Timers ---

const TimerKey = struct { view: usize, id: usize };

// 0.16: std.Thread.Mutex removed (moved under std.Io). Local atomic
// spin-mutex for low-contention timer registry access.
const SpinMutex = struct {
    flag: std.atomic.Value(bool) = .init(false),
    fn lock(self: *@This()) void {
        while (self.flag.cmpxchgWeak(false, true, .acquire, .monotonic) != null) {
            std.atomic.spinLoopHint();
        }
    }
    fn unlock(self: *@This()) void {
        self.flag.store(false, .release);
    }
};
var timers_mutex: SpinMutex = .{};
var timers: std.AutoHashMapUnmanaged(TimerKey, c.id) = .empty;

export fn zpugl_mac_start_timer(zig_view: *anyopaque, timer_id: usize, freq: f64) u32 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (freq <= 0) return 6;
    const cls = ensureTimerClass();
    const tgt = cls.msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "init", .{});
    timerIvarSet(tgt.value, zig_view, timer_id);

    const sel_fire = objc.sel("fire:");
    const t = nsClass("NSTimer").msgSend(objc.Object, "timerWithTimeInterval:target:selector:userInfo:repeats:", .{
        @as(NSTimeInterval, freq),
        tgt,
        sel_fire,
        @as(c.id, null),
        true,
    });
    tgt.release();
    const mode = nsClass("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{@as([*:0]const u8, "kCFRunLoopCommonModes")});
    nsClass("NSRunLoop").msgSend(objc.Object, "currentRunLoop", .{}).msgSend(void, "addTimer:forMode:", .{ t, mode });

    const key = TimerKey{ .view = @intFromPtr(zig_view), .id = timer_id };
    timers_mutex.lock();
    defer timers_mutex.unlock();
    if (timers.get(key)) |old| releaseTimer(old);
    timers.put(std.heap.c_allocator, key, t.retain().value) catch return 1;
    return 0;
}

fn stopViewTimers(view: usize) void {
    timers_mutex.lock();
    defer timers_mutex.unlock();
    var it = timers.iterator();
    while (it.next()) |entry| {
        if (entry.key_ptr.view != view) continue;
        releaseTimer(entry.value_ptr.*);
        timers.removeByPtr(entry.key_ptr);
        it = timers.iterator();
    }
}

export fn zpugl_mac_stop_timer(zig_view: *anyopaque, timer_id: usize) u32 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const key = TimerKey{ .view = @intFromPtr(zig_view), .id = timer_id };
    timers_mutex.lock();
    defer timers_mutex.unlock();
    const entry = timers.fetchRemove(key) orelse return 1;
    releaseTimer(entry.value);
    return 0;
}

fn releaseTimer(t: c.id) void {
    const timer: objc.Object = .{ .value = t };
    timer.msgSend(void, "invalidate", .{});
    timer.release();
}

// --- Clipboard ---

var clip_buf: std.ArrayList(u8) = .empty;

export fn zpugl_mac_set_clipboard(mime: [*:0]const u8, data: [*]const u8, len: usize) u32 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const pb = nsClass("NSPasteboard").msgSend(objc.Object, "generalPasteboard", .{});
    _ = pb.msgSend(NSInteger, "clearContents", .{});
    const mime_slice = std.mem.span(mime);
    if (std.mem.startsWith(u8, mime_slice, "text/")) {
        var s = nsClass("NSString").msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "initWithBytes:length:encoding:", .{
            @as([*]const u8, data),
            len,
            @as(NSUInteger, 4), // NSUTF8StringEncoding
        });
        if (s.value == null) {
            s = nsClass("NSString").msgSend(objc.Object, "string", .{});
        }
        const arr = nsClass("NSArray").msgSend(objc.Object, "arrayWithObject:", .{s});
        const ok = pb.msgSend(bool, "writeObjects:", .{arr});
        return if (ok) 0 else 1;
    }
    const nsdata = nsClass("NSData").msgSend(objc.Object, "dataWithBytes:length:", .{ @as([*]const u8, data), len });
    const ns_type = nsClass("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{mime});
    const arr = nsClass("NSArray").msgSend(objc.Object, "arrayWithObject:", .{ns_type});
    _ = pb.msgSend(NSInteger, "addTypes:owner:", .{ arr, @as(c.id, null) });
    const ok = pb.msgSend(bool, "setData:forType:", .{ nsdata, ns_type });
    return if (ok) 0 else 1;
}

// UTI <-> MIME mapping (subset of pugl mac.m datatypes).
const UtiMimePair = struct { uti: [:0]const u8, mime: [:0]const u8 };
const uti_mime_map = [_]UtiMimePair{
    .{ .uti = "public.utf8-plain-text", .mime = "text/plain" },
    .{ .uti = "public.html", .mime = "text/html" },
    .{ .uti = "public.png", .mime = "image/png" },
    .{ .uti = "public.jpeg", .mime = "image/jpeg" },
    .{ .uti = "public.tiff", .mime = "image/tiff" },
    .{ .uti = "public.rtf", .mime = "text/rtf" },
    .{ .uti = "public.url", .mime = "text/uri-list" },
    .{ .uti = "public.file-url", .mime = "text/uri-list" },
};

fn utiToMime(uti: []const u8) []const u8 {
    for (uti_mime_map) |p| {
        if (std.mem.eql(u8, p.uti, uti)) return p.mime;
    }
    return uti; // pass-through
}

fn mimeToUti(mime: []const u8) ?[]const u8 {
    for (uti_mime_map) |p| {
        if (std.mem.eql(u8, p.mime, mime)) return p.uti;
    }
    return null;
}

var clip_type_buf: [128]u8 = undefined;

fn dragPasteboard(native: usize) ?objc.Object {
    if (native == 0) return null;
    const view: objc.Object = .{ .value = @ptrFromInt(native) };
    const ds_id = c.object_getIvar(view.value, c.object_getInstanceVariable(view.value, "dragSource", null));
    if (ds_id == null) return null;
    const ds: objc.Object = .{ .value = ds_id };
    const pb_id = ds.msgSend(c.id, "draggingPasteboard", .{});
    if (pb_id == null) return null;
    return .{ .value = pb_id };
}

export fn zpugl_mac_get_clipboard(native: usize, clipboard: u32, out_data: *[*]const u8, out_len: *usize, type_index: u32) u32 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const pb = if (clipboard == 1)
        dragPasteboard(native) orelse {
            out_data.* = "";
            out_len.* = 0;
            return 1;
        }
    else
        nsClass("NSPasteboard").msgSend(objc.Object, "generalPasteboard", .{});
    const types = pb.msgSend(objc.Object, "types", .{});
    if (types.value == null) {
        out_data.* = "";
        out_len.* = 0;
        return 1;
    }
    const count = types.msgSend(NSUInteger, "count", .{});
    if (type_index >= count) {
        out_data.* = "";
        out_len.* = 0;
        return 1;
    }
    const uti = types.msgSend(objc.Object, "objectAtIndex:", .{@as(NSUInteger, type_index)});
    // dropped URI list path also handled here; for simplicity just read data/string
    const data = pb.msgSend(objc.Object, "dataForType:", .{uti});
    if (data.value != null) {
        const len = data.msgSend(NSUInteger, "length", .{});
        const bytes = data.msgSend([*]const u8, "bytes", .{});
        clip_buf.clearRetainingCapacity();
        clip_buf.appendSlice(std.heap.c_allocator, bytes[0..len]) catch return 1;
        out_data.* = clip_buf.items.ptr;
        out_len.* = clip_buf.items.len;
        return 0;
    }
    const s_id = pb.msgSend(c.id, "stringForType:", .{uti});
    if (s_id == null) {
        out_data.* = "";
        out_len.* = 0;
        return 1;
    }
    const s: objc.Object = .{ .value = s_id };
    const utf8 = s.msgSend([*:0]const u8, "UTF8String", .{});
    const slice = std.mem.span(utf8);
    clip_buf.clearRetainingCapacity();
    clip_buf.appendSlice(std.heap.c_allocator, slice) catch return 1;
    out_data.* = clip_buf.items.ptr;
    out_len.* = clip_buf.items.len;
    return 0;
}

export fn zpugl_mac_get_num_clipboard_types(native: usize, clipboard: u32) u32 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const pb = if (clipboard == 1)
        dragPasteboard(native) orelse return 0
    else
        nsClass("NSPasteboard").msgSend(objc.Object, "generalPasteboard", .{});
    const types = pb.msgSend(objc.Object, "types", .{});
    if (types.value == null) return 0;
    const count = types.msgSend(NSUInteger, "count", .{});
    return @intCast(count);
}

export fn zpugl_mac_get_clipboard_type(native: usize, clipboard: u32, idx: u32) ?[*:0]const u8 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const pb = if (clipboard == 1)
        dragPasteboard(native) orelse return null
    else
        nsClass("NSPasteboard").msgSend(objc.Object, "generalPasteboard", .{});
    const types = pb.msgSend(objc.Object, "types", .{});
    if (types.value == null) return null;
    const count = types.msgSend(NSUInteger, "count", .{});
    if (idx >= count) return null;
    const uti = types.msgSend(objc.Object, "objectAtIndex:", .{@as(NSUInteger, idx)});
    const utf8 = uti.msgSend([*:0]const u8, "UTF8String", .{});
    const uti_slice = std.mem.span(utf8);
    const mime = utiToMime(uti_slice);
    const n = @min(mime.len, clip_type_buf.len - 1);
    @memcpy(clip_type_buf[0..n], mime[0..n]);
    clip_type_buf[n] = 0;
    return @ptrCast(&clip_type_buf);
}

export fn zpugl_mac_register_drop_type(native: usize, mime: [*:0]const u8) u32 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (native == 0) return 1;
    const view: objc.Object = .{ .value = @ptrFromInt(native) };
    const mime_slice = std.mem.span(mime);

    // Look up internal map first; may yield multiple UTIs.
    var registered_any = false;
    const NSMutableArray = nsClass("NSMutableArray");
    const NSString = nsClass("NSString");

    // Get/create dropTypes ivar storage.
    var arr_id = c.object_getIvar(view.value, c.object_getInstanceVariable(view.value, "dropTypes", null));
    var arr: objc.Object = undefined;
    if (arr_id == null) {
        arr = NSMutableArray.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
        setIvar(view.value, "dropTypes", arr.value);
        arr_id = arr.value;
    } else {
        arr = .{ .value = arr_id };
    }

    for (uti_mime_map) |p| {
        if (std.mem.eql(u8, p.mime, mime_slice)) {
            const ns_uti = NSString.msgSend(objc.Object, "stringWithUTF8String:", .{@as([*:0]const u8, p.uti.ptr)});
            arr.msgSend(void, "addObject:", .{ns_uti});
            registered_any = true;
        }
    }
    if (!registered_any) {
        // Pass through as-is.
        const ns_uti = NSString.msgSend(objc.Object, "stringWithUTF8String:", .{mime});
        arr.msgSend(void, "addObject:", .{ns_uti});
    }
    view.msgSend(void, "registerForDraggedTypes:", .{arr});
    return 0;
}

export fn zpugl_mac_accept_offer(native: usize, type_index: u32, action: u32) u32 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (native == 0) return 1;
    const view: objc.Object = .{ .value = @ptrFromInt(native) };
    const pb = nsClass("NSPasteboard").msgSend(objc.Object, "generalPasteboard", .{});
    const types = pb.msgSend(objc.Object, "types", .{});
    if (types.value == null) return 1;
    const count = types.msgSend(NSUInteger, "count", .{});
    if (type_index >= count) return 1;
    const op: NSUInteger = switch (action) {
        0 => NSDragOperationCopy,
        1 => NSDragOperationLink,
        2 => NSDragOperationMove,
        else => NSDragOperationPrivate,
    };
    setIvarSmall(view.value, "dragOp", op);
    setIvarSmall(view.value, "acceptedDragTypeIndex", @as(usize, type_index) + 1);
    if (dropIvarsGet(view.value).drag_source == null) {
        if (ivarPtr(view.value)) |p| zpugl_on_data(p, zpugl_mac_get_time(), 0, 0, 0, type_index);
    }
    return 0;
}

export fn zpugl_mac_open_url(url: [*:0]const u8) u32 {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const s = nsClass("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{url});
    if (s.value == null) return 1;
    const u = nsClass("NSURL").msgSend(objc.Object, "URLWithString:", .{s});
    if (u.value == null) return 1;
    const ws = nsClass("NSWorkspace").msgSend(objc.Object, "sharedWorkspace", .{});
    return if (ws.msgSend(bool, "openURL:", .{u})) 0 else 1;
}

export fn zpugl_mac_prefers_dark(native: usize) bool {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const target: objc.Object = if (native != 0) .{ .value = @ptrFromInt(native) } else nsApp();
    const appearance = target.msgSend(objc.Object, "effectiveAppearance", .{});
    if (appearance.value == null) return false;
    const aqua = nsClass("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{@as([*:0]const u8, "NSAppearanceNameAqua")});
    const dark = nsClass("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{@as([*:0]const u8, "NSAppearanceNameDarkAqua")});
    const names = nsClass("NSArray").msgSend(objc.Object, "arrayWithObjects:count:", .{ &[_]c.id{ aqua.value, dark.value }, @as(NSUInteger, 2) });
    const best = appearance.msgSend(objc.Object, "bestMatchFromAppearancesWithNames:", .{names});
    if (best.value == null) return false;
    return best.msgSend(bool, "isEqualToString:", .{dark});
}

export fn zpugl_mac_paste(zig_view: *anyopaque) u32 {
    zpugl_on_data_offer(zig_view, zpugl_mac_get_time(), 0);
    return 0;
}

// --- GL ---

const NSOpenGLPFAOpenGLProfile: u32 = 99;
const NSOpenGLPFAColorSize: u32 = 8;
const NSOpenGLPFAAlphaSize: u32 = 11;
const NSOpenGLPFADepthSize: u32 = 12;
const NSOpenGLPFADoubleBuffer: u32 = 5;
const NSOpenGLContextParameterSwapInterval: NSInteger = 222;
const NSOpenGLProfileVersionLegacy: u32 = 0x1000;
const NSOpenGLProfileVersion3_2Core: u32 = 0x3200;

export fn zpugl_mac_gl_create(native: usize, major: i32, minor: i32, profile: i32, double_buf: bool, swap_interval: i32) usize {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    _ = minor;
    const view: objc.Object = .{ .value = @ptrFromInt(native) };
    // Use Core Profile 3.2 when requested; otherwise try legacy then fall back to
    // Core Profile 3.2 (required on macOS 15 where Legacy profile was removed).
    // opengl_core_profile = 4 per root.ViewHintValue enum
    const use_core = major >= 3 and profile == 4;
    var attrs_core = [_]u32{
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        NSOpenGLPFAColorSize,     24,
        NSOpenGLPFAAlphaSize,     8,
        NSOpenGLPFADepthSize,     24,
        NSOpenGLPFADoubleBuffer,  0,
    };
    var attrs_legacy = [_]u32{
        NSOpenGLPFAOpenGLProfile,                                 NSOpenGLProfileVersionLegacy,
        NSOpenGLPFAColorSize,                                     24,
        NSOpenGLPFAAlphaSize,                                     8,
        NSOpenGLPFADepthSize,                                     24,
        if (double_buf) NSOpenGLPFADoubleBuffer else @as(u32, 0), 0,
    };
    const attrs: [*]const u32 = if (use_core) &attrs_core else &attrs_legacy;
    var fmt = nsClass("NSOpenGLPixelFormat")
        .msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithAttributes:", .{attrs});
    // If legacy profile failed (macOS 15+), retry with Core Profile.
    if (fmt.value == null and !use_core) {
        fmt = nsClass("NSOpenGLPixelFormat")
            .msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "initWithAttributes:", .{@as([*]const u32, &attrs_core)});
    }
    if (fmt.value == null) return 0;
    defer fmt.release();
    const ctx = nsClass("NSOpenGLContext")
        .msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithFormat:shareContext:", .{ fmt, @as(c.id, null) });
    if (ctx.value == null) return 0;
    ctx.msgSend(void, "setView:", .{view});
    if (swap_interval != -1) {
        var si = swap_interval;
        ctx.msgSend(void, "setValues:forParameter:", .{ &si, NSOpenGLContextParameterSwapInterval });
    }
    // Required for Retina: GL surface matches physical pixels, not logical points.
    view.msgSend(void, "setWantsBestResolutionOpenGLSurface:", .{true});
    return @intFromPtr(ctx.value);
}

export fn zpugl_mac_gl_destroy(ctx_ptr: usize) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (ctx_ptr == 0) return;
    const ctx: objc.Object = .{ .value = @ptrFromInt(ctx_ptr) };
    ctx.msgSend(void, "clearDrawable", .{});
    ctx.release();
}
export fn zpugl_mac_gl_enter(ctx_ptr: usize) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const ctx: objc.Object = .{ .value = @ptrFromInt(ctx_ptr) };
    ctx.msgSend(void, "makeCurrentContext", .{});
    // Sync context with view's current position/size (needed for plugin subviews).
    ctx.msgSend(void, "update", .{});
}
export fn zpugl_mac_gl_leave(ctx_ptr: usize, swap: bool) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const ctx: objc.Object = .{ .value = @ptrFromInt(ctx_ptr) };
    if (swap) ctx.msgSend(void, "flushBuffer", .{});
    nsClass("NSOpenGLContext").msgSend(void, "clearCurrentContext", .{});
}
export fn zpugl_mac_gl_resize(ctx_ptr: usize) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const ctx: objc.Object = .{ .value = @ptrFromInt(ctx_ptr) };
    ctx.msgSend(void, "update", .{});
}

export fn zpugl_embed_view(parent_nsview: *anyopaque, child_nsview: *anyopaque) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const parent = objc.Object{ .value = @ptrCast(@alignCast(parent_nsview)) };
    const child = objc.Object{ .value = @ptrCast(@alignCast(child_nsview)) };
    parent.msgSend(void, "addSubview:", .{child});
    const bounds = parent.msgSend(NSRect, "bounds", .{});
    child.msgSend(void, "setFrame:", .{bounds});
    const mask: NSUInteger = NSViewWidthSizable | NSViewHeightSizable;
    child.msgSend(void, "setAutoresizingMask:", .{mask});
}

export fn zpugl_remove_view(au_nsview: *anyopaque) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const view = objc.Object{ .value = @ptrCast(@alignCast(au_nsview)) };
    view.msgSend(void, "removeFromSuperview", .{});
    view.msgSend(void, "release", .{});
}

// AudioToolbox C ABI (AudioToolbox linked by host; symbol resolved at runtime)
const AudioUnitPropertyID: type = u32;
const AudioUnitScope: type = u32;
const AudioUnitElement: type = u32;
const kAudioUnitProperty_CocoaUI: AudioUnitPropertyID = 31;
const kAudioUnitScope_Global: AudioUnitScope = 0;

extern "c" fn AudioUnitGetPropertyInfo(
    inUnit: *anyopaque,
    inID: AudioUnitPropertyID,
    inScope: AudioUnitScope,
    inElement: AudioUnitElement,
    outDataSize: *u32,
    outWritable: *u8,
) i32;

extern "c" fn AudioUnitGetProperty(
    inUnit: *anyopaque,
    inID: AudioUnitPropertyID,
    inScope: AudioUnitScope,
    inElement: AudioUnitElement,
    outData: *anyopaque,
    ioDataSize: *u32,
) i32;

const CocoaViewInfo = extern struct {
    bundle_url: objc.c.id,
    view_class: [1]objc.c.id,
};

export fn zpugl_au_create_cocoa_view(au_unit: *anyopaque, w: f32, h: f32) ?*anyopaque {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    var size: u32 = 0;
    var writable: u8 = 0;
    if (AudioUnitGetPropertyInfo(au_unit, kAudioUnitProperty_CocoaUI, kAudioUnitScope_Global, 0, &size, &writable) != 0) return null;
    if (size < @sizeOf(CocoaViewInfo)) return null;

    const info: *CocoaViewInfo = @ptrCast(@alignCast(std.c.malloc(size) orelse return null));
    defer std.c.free(info);

    if (AudioUnitGetProperty(au_unit, kAudioUnitProperty_CocoaUI, kAudioUnitScope_Global, 0, info, &size) != 0) return null;

    const bundle_url = objc.Object{ .value = info.bundle_url };
    const class_name = objc.Object{ .value = info.view_class[0] };

    const NSBundle = objc.getClass("NSBundle") orelse return null;
    const bundle = NSBundle.msgSend(objc.Object, "bundleWithURL:", .{bundle_url});
    if (bundle.value == null) return null;
    if (!bundle.msgSend(bool, "load", .{})) return null;

    const factory_class = bundle.msgSend(objc.Object, "classNamed:", .{class_name});
    if (factory_class.value == null) return null;

    const factory = factory_class.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
    defer factory.release();
    const ns_size = NSSize{ .width = w, .height = h };
    const view = factory.msgSend(objc.Object, "uiViewForAudioUnit:withSize:", .{ au_unit, ns_size });
    if (view.value == null) return null;

    _ = view.msgSend(objc.Object, "retain", .{});
    return view.value;
}

/// Loads the bundle executable at `path`, which causes the AudioUnit component
/// to register itself with AudioComponentFindNext. Call before Au.load().
/// Returns true on success.
export fn zpugl_au_register_bundle(path: [*:0]const u8) bool {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const NSString = objc.getClass("NSString") orelse return false;
    const NSBundle = objc.getClass("NSBundle") orelse return false;

    const ns_path = NSString.msgSend(objc.Object, "stringWithUTF8String:", .{path});
    if (ns_path.value == null) return false;

    const NSURL = objc.getClass("NSURL") orelse return false;
    const url = NSURL.msgSend(objc.Object, "fileURLWithPath:", .{ns_path});
    if (url.value == null) return false;

    const bundle = NSBundle.msgSend(objc.Object, "bundleWithURL:", .{url});
    if (bundle.value == null) return false;

    return bundle.msgSend(bool, "load", .{});
}

// --- Text input activation ---

export fn zpugl_mac_start_text_input(native: usize, x: i32, y: i32, w: u32, h: u32) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (native == 0) return;
    const view = objFromId(@ptrFromInt(native));
    // Store the rect for firstRectForCharacterRange:.
    setIvarSmall(@ptrFromInt(native), "textInputRectX", @as(usize, @intCast(@max(0, x))));
    setIvarSmall(@ptrFromInt(native), "textInputRectY", @as(usize, @intCast(@max(0, y))));
    setIvarSmall(@ptrFromInt(native), "textInputRectW", @as(usize, w));
    setIvarSmall(@ptrFromInt(native), "textInputRectH", @as(usize, h));
    // Get or create NSTextInputContext for this view.
    const ctx_ivar = c.object_getInstanceVariable(@ptrFromInt(native), "textInputContext", null);
    const existing = c.object_getIvar(@ptrFromInt(native), ctx_ivar);
    const ctx: objc.Object = if (existing != null)
        .{ .value = existing }
    else blk: {
        const NSTextInputContext = nsClass("NSTextInputContext");
        const new_ctx = NSTextInputContext.msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "initWithClient:", .{view});
        c.object_setIvar(@ptrFromInt(native), ctx_ivar, new_ctx.value);
        break :blk new_ctx;
    };
    ctx.msgSend(void, "activate", .{});
    ensureTextProxy(view.value);
    if (viewWindow(native)) |win| if (win.msgSend(c.id, "firstResponder", .{}) == view.value) focusView(view.value);
}

export fn zpugl_mac_stop_text_input(native: usize) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (native == 0) return;
    const ctx_ivar = c.object_getInstanceVariable(@ptrFromInt(native), "textInputContext", null);
    const ctx_id = c.object_getIvar(@ptrFromInt(native), ctx_ivar);
    if (ctx_id == null) return;
    const ctx: objc.Object = .{ .value = ctx_id };
    ctx.msgSend(void, "discardMarkedText", .{});
    ctx.msgSend(void, "deactivate", .{});
    ctx.release();
    // Clear the ivar: start_text_input reuses a non-null context, and
    // keyDown: would send handleEvent: to the freed object.
    c.object_setIvar(@ptrFromInt(native), ctx_ivar, null);
    const proxy = textProxy(@ptrFromInt(native));
    if (proxy != null) if (viewWindow(native)) |win| if (win.msgSend(c.id, "firstResponder", .{}) == proxy) focusView(@ptrFromInt(native));
}

export fn zpugl_mac_set_text_input_rect(native: usize, x: i32, y: i32, w: u32, h: u32) void {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    if (native == 0) return;
    setIvarSmall(@ptrFromInt(native), "textInputRectX", @as(usize, @intCast(@max(0, x))));
    setIvarSmall(@ptrFromInt(native), "textInputRectY", @as(usize, @intCast(@max(0, y))));
    setIvarSmall(@ptrFromInt(native), "textInputRectW", @as(usize, w));
    setIvarSmall(@ptrFromInt(native), "textInputRectH", @as(usize, h));
    // Notify the input context that the rect changed.
    const ctx_ivar = c.object_getInstanceVariable(@ptrFromInt(native), "textInputContext", null);
    const ctx_id = c.object_getIvar(@ptrFromInt(native), ctx_ivar);
    if (ctx_id == null) return;
    const ctx: objc.Object = .{ .value = ctx_id };
    ctx.msgSend(void, "invalidateCharacterCoordinates", .{});
}

export fn zpugl_nswindow_content_view(nswindow: *anyopaque) ?*anyopaque {
    const pool = objc.AutoreleasePool.init();
    defer pool.deinit();
    const window = objc.Object{ .value = @ptrCast(@alignCast(nswindow)) };
    const view = window.msgSend(objc.Object, "contentView", .{});
    return view.value;
}

// Force-keep exports.
comptime {
    _ = &zpugl_mac_create_view;
    _ = &zpugl_mac_destroy_view;
}
