const std = @import("std");
const root = @import("../root.zig");
const objc = @import("objc");
const c = objc.c;
const common = root.common;

const CGFloat = f64;
const CGPoint = extern struct { x: CGFloat, y: CGFloat };
const CGSize = extern struct { width: CGFloat, height: CGFloat };
const CGRect = extern struct { origin: CGPoint, size: CGSize };
const UIEdgeInsets = extern struct { top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat };
const NSUInteger = usize;
const NSInteger = isize;

extern "c" fn UIApplicationMain(argc: c_int, argv: ?[*]?[*:0]u8, principal: c.id, delegate: c.id) c_int;
extern "c" fn CFRunLoopRunInMode(mode: ?*const anyopaque, seconds: f64, return_after_source_handled: u8) i32;
extern "c" const kCFRunLoopDefaultMode: ?*const anyopaque;
extern "c" fn CACurrentMediaTime() f64;
extern "c" fn objc_autoreleasePoolPush() ?*anyopaque;
extern "c" fn objc_autoreleasePoolPop(pool: ?*anyopaque) void;
extern "c" fn dispatch_async_f(queue: *anyopaque, context: ?*anyopaque, work: *const fn (?*anyopaque) callconv(.c) void) void;
extern "c" var _dispatch_main_q: anyopaque;

const kCFRunLoopRunHandledSource: i32 = 4;

export fn _dyld_get_image_header_containing_address(addr: *const anyopaque) ?*anyopaque {
    var info: std.c.dl_info = undefined;
    if (std.c.dladdr(addr, &info) == 0) return null;
    return info.fbase;
}

var entry_fn: ?*const fn () void = null;
var window_scene: c.id = null;
var world_ref: ?*root.World = null;
var start_time: f64 = 0;
var touch_slots: [10]c.id = @splat(null);
var clipboard_buf: std.ArrayList(u8) = .empty;

var view_class: ?objc.Class = null;
var container_class: ?objc.Class = null;
var app_delegate_class: ?objc.Class = null;
var scene_delegate_class: ?objc.Class = null;
var name_bufs: [4][64]u8 = undefined;

fn dylibSuffix() u64 {
    var info: std.c.dl_info = undefined;
    const probe: *const fn () u64 = &dylibSuffix;
    if (std.c.dladdr(@ptrCast(probe), &info) != 0) return std.hash.Wyhash.hash(0, std.mem.span(info.fname));
    return 0xDEADBEEF;
}

fn className(slot: usize, base: []const u8) [:0]const u8 {
    return std.fmt.bufPrintSentinel(&name_bufs[slot], "{s}_{x}", .{ base, dylibSuffix() }, 0) catch unreachable;
}

inline fn cls(name: [:0]const u8) objc.Class {
    return objc.getClass(name).?;
}

inline fn obj(id: c.id) objc.Object {
    return .{ .value = id };
}

fn nsString(s: [*:0]const u8) objc.Object {
    return cls("NSString").msgSend(objc.Object, "stringWithUTF8String:", .{s});
}

fn zigView(self: c.id) ?*root.View {
    const ivar = c.object_getInstanceVariable(self, "zigView", null);
    return @ptrCast(@alignCast(c.object_getIvar(self, ivar)));
}

fn setZigView(self: c.id, view: ?*root.View) void {
    const ivar = c.object_getInstanceVariable(self, "zigView", null);
    c.object_setIvar(self, ivar, @ptrCast(@alignCast(view)));
}

fn dispatch(view: *root.View, ev: root.Event) void {
    _ = common.dispatchEvent(view, &ev);
}

fn impLayerClass(_: c.id, _: c.SEL) callconv(.c) c.id {
    return @ptrCast(@alignCast(cls("CAMetalLayer").value));
}

fn impYes(_: c.id, _: c.SEL) callconv(.c) bool {
    return true;
}

fn impLayoutSubviews(self: c.id, sel: c.SEL) callconv(.c) void {
    _ = sel;
    const view = zigView(self) orelse return;
    const b = obj(self).msgSend(CGRect, "bounds", .{});
    const w: u16 = @intFromFloat(@max(0, b.size.width));
    const h: u16 = @intFromFloat(@max(0, b.size.height));
    view.size_hints[@backingInt(root.SizeHint.current_size)] = .{ .width = w, .height = h };
    dispatch(view, .{ .configure = .{ .x = 0, .y = 0, .width = w, .height = h, .style = view.style } });
    dispatch(view, .{ .expose = .{ .x = 0, .y = 0, .width = w, .height = h } });
}

fn impContainerLayoutSubviews(self: c.id, _: c.SEL) callconv(.c) void {
    const container = obj(self);
    const b = container.msgSend(CGRect, "bounds", .{});
    const in = container.msgSend(UIEdgeInsets, "safeAreaInsets", .{});
    const subviews = container.msgSend(objc.Object, "subviews", .{});
    const n = subviews.msgSend(NSUInteger, "count", .{});
    var i: NSUInteger = 0;
    while (i < n) : (i += 1) {
        subviews.msgSend(objc.Object, "objectAtIndex:", .{i}).msgSend(void, "setFrame:", .{CGRect{
            .origin = .{ .x = b.origin.x + in.left, .y = b.origin.y + in.top },
            .size = .{ .width = b.size.width - in.left - in.right, .height = b.size.height - in.top - in.bottom },
        }});
    }
}

fn impSetNeedsLayout(self: c.id, _: c.SEL) callconv(.c) void {
    obj(self).msgSend(void, "setNeedsLayout", .{});
}

const Phase = enum { begin, update, end };

fn touchSlot(touch: c.id, phase: Phase) ?u32 {
    for (touch_slots, 0..) |t, i| if (t == touch) {
        if (phase == .end) touch_slots[i] = null;
        return @intCast(i);
    };
    if (phase != .begin) return null;
    for (&touch_slots, 0..) |*t, i| if (t.* == null) {
        t.* = touch;
        return @intCast(i);
    };
    return null;
}

fn touches(self: c.id, set: c.id, phase: Phase) void {
    const view = zigView(self) orelse return;
    const all = obj(set).msgSend(objc.Object, "allObjects", .{});
    const n = all.msgSend(NSUInteger, "count", .{});
    var i: NSUInteger = 0;
    while (i < n) : (i += 1) {
        const touch = all.msgSend(objc.Object, "objectAtIndex:", .{i});
        const id = touchSlot(touch.value, phase) orelse continue;
        const p = touch.msgSend(CGPoint, "locationInView:", .{self});
        const te: root.TouchEvent = .{ .time = touch.msgSend(f64, "timestamp", .{}) - start_time, .id = id, .x = p.x, .y = p.y };
        dispatch(view, switch (phase) {
            .begin => .{ .touch_begin = te },
            .update => .{ .touch_update = te },
            .end => .{ .touch_end = te },
        });
    }
}

fn impTouchesBegan(self: c.id, _: c.SEL, set: c.id, _: c.id) callconv(.c) void {
    touches(self, set, .begin);
}
fn impTouchesMoved(self: c.id, _: c.SEL, set: c.id, _: c.id) callconv(.c) void {
    touches(self, set, .update);
}
fn impTouchesEnded(self: c.id, _: c.SEL, set: c.id, _: c.id) callconv(.c) void {
    touches(self, set, .end);
}

fn keyTap(view: *root.View, key: root.Key) void {
    const ke: root.KeyEvent = .{ .time = getTime(view.world), .x = 0, .y = 0, .root_x = 0, .root_y = 0, .state = .{}, .keycode = 0, .key = @backingInt(key) };
    dispatch(view, .{ .key_press = ke });
    dispatch(view, .{ .key_release = ke });
}

fn impInsertText(self: c.id, _: c.SEL, text: c.id) callconv(.c) void {
    const view = zigView(self) orelse return;
    const utf8 = std.mem.span(obj(text).msgSend([*:0]const u8, "UTF8String", .{}));
    var it = (std.unicode.Utf8View.init(utf8) catch return).iterator();
    while (it.nextCodepointSlice()) |cp| {
        if (std.mem.eql(u8, cp, "\n")) {
            keyTap(view, .enter);
            continue;
        }
        var string: [8]u8 = @splat(0);
        @memcpy(string[0..cp.len], cp);
        dispatch(view, .{ .text = .{
            .time = getTime(view.world),
            .x = 0,
            .y = 0,
            .root_x = 0,
            .root_y = 0,
            .state = .{},
            .keycode = 0,
            .character = std.unicode.utf8Decode(cp) catch 0,
            .string = string,
        } });
    }
}

fn impDeleteBackward(self: c.id, _: c.SEL) callconv(.c) void {
    if (zigView(self)) |view| keyTap(view, .backspace);
}

fn setWorldVisible(visible: bool) void {
    const world = world_ref orelse return;
    for (world.views.items) |view| {
        if (view.handle == null) continue;
        view.visible = visible;
        if (visible) {
            dispatch(view, .{ .focus_in = .{ .mode = .normal } });
            dispatch(view, .{ .expose = .{ .x = 0, .y = 0, .width = 0, .height = 0 } });
        } else dispatch(view, .{ .focus_out = .{ .mode = .normal } });
    }
}

fn impDidFinishLaunching(_: c.id, _: c.SEL, _: c.id, _: c.id) callconv(.c) bool {
    return true;
}

fn impConfigurationForScene(_: c.id, _: c.SEL, _: c.id, session: c.id, _: c.id) callconv(.c) c.id {
    const role = obj(session).msgSend(c.id, "role", .{});
    const config = cls("UISceneConfiguration").msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithName:sessionRole:", .{ @as(c.id, null), role });
    config.msgSend(void, "setDelegateClass:", .{scene_delegate_class.?});
    return config.msgSend(c.id, "autorelease", .{});
}

fn impSceneWillConnect(self: c.id, _: c.SEL, scene: c.id, _: c.id, _: c.id) callconv(.c) void {
    window_scene = obj(scene).retain().value;
    obj(self).msgSend(void, "performSelector:withObject:afterDelay:", .{ objc.sel("zpuglRun:").value, @as(c.id, null), @as(f64, 0) });
}

fn impRun(_: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    if (entry_fn) |f| f();
    std.process.exit(0);
}

fn impSceneBackground(_: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    setWorldVisible(false);
}

fn impSceneForeground(_: c.id, _: c.SEL, _: c.id) callconv(.c) void {
    setWorldVisible(true);
}

fn subclass(slot: usize, super: [:0]const u8, base: []const u8) objc.Class {
    return objc.allocateClassPair(cls(super), className(slot, base)).?;
}

fn registerClasses() void {
    if (view_class != null) return;

    const v = subclass(0, "UIView", "ZpuglUIView");
    _ = v.addIvar("zigView");
    _ = v.addIvar("ownedWindow");
    const meta: objc.Class = .{ .value = c.object_getClass(@ptrCast(@alignCast(v.value))) };
    std.debug.assert(meta.addMethod("layerClass", impLayerClass));
    std.debug.assert(v.addMethod("layoutSubviews", impLayoutSubviews));
    std.debug.assert(v.addMethod("canBecomeFirstResponder", impYes));
    std.debug.assert(v.addMethod("hasText", impYes));
    std.debug.assert(v.addMethod("insertText:", impInsertText));
    std.debug.assert(v.addMethod("deleteBackward", impDeleteBackward));
    std.debug.assert(v.addMethod("touchesBegan:withEvent:", impTouchesBegan));
    std.debug.assert(v.addMethod("touchesMoved:withEvent:", impTouchesMoved));
    std.debug.assert(v.addMethod("touchesEnded:withEvent:", impTouchesEnded));
    std.debug.assert(v.addMethod("touchesCancelled:withEvent:", impTouchesEnded));
    if (c.objc_getProtocol("UIKeyInput")) |p| _ = c.class_addProtocol(v.value, p);
    objc.registerClassPair(v);
    view_class = v;

    const ct = subclass(1, "UIView", "ZpuglUIContainer");
    std.debug.assert(ct.addMethod("layoutSubviews", impContainerLayoutSubviews));
    std.debug.assert(ct.addMethod("safeAreaInsetsDidChange", impSetNeedsLayout));
    objc.registerClassPair(ct);
    container_class = ct;

    const sd = subclass(2, "UIResponder", "ZpuglSceneDelegate");
    std.debug.assert(sd.addMethod("scene:willConnectToSession:options:", impSceneWillConnect));
    std.debug.assert(sd.addMethod("sceneDidEnterBackground:", impSceneBackground));
    std.debug.assert(sd.addMethod("sceneWillEnterForeground:", impSceneForeground));
    std.debug.assert(sd.addMethod("zpuglRun:", impRun));
    if (c.objc_getProtocol("UIWindowSceneDelegate")) |p| _ = c.class_addProtocol(sd.value, p);
    objc.registerClassPair(sd);
    scene_delegate_class = sd;

    const ad = subclass(3, "UIResponder", "ZpuglAppDelegate");
    std.debug.assert(ad.addMethod("application:didFinishLaunchingWithOptions:", impDidFinishLaunching));
    std.debug.assert(ad.addMethod("application:configurationForConnectingSceneSession:options:", impConfigurationForScene));
    if (c.objc_getProtocol("UIApplicationDelegate")) |p| _ = c.class_addProtocol(ad.value, p);
    objc.registerClassPair(ad);
    app_delegate_class = ad;
}

pub fn runApplication(entry: *const fn () void) noreturn {
    entry_fn = entry;
    start_time = CACurrentMediaTime();
    registerClasses();
    const name = c.class_getName(app_delegate_class.?.value);
    std.process.exit(@intCast(UIApplicationMain(0, null, null, nsString(name).value) & 0xff));
}

pub fn createView(view: *root.View) root.Status {
    registerClasses();
    world_ref = view.world;
    const size = view.size_hints[@backingInt(root.SizeHint.default_size)];
    const frame: CGRect = .{ .origin = .{ .x = 0, .y = 0 }, .size = .{ .width = @floatFromInt(size.width), .height = @floatFromInt(size.height) } };
    const uiview = view_class.?.msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "initWithFrame:", .{frame});
    setZigView(uiview.value, view);
    uiview.msgSend(void, "setMultipleTouchEnabled:", .{true});

    if (view.parent != 0) {
        obj(@ptrFromInt(view.parent)).msgSend(void, "addSubview:", .{uiview});
    } else {
        const scene = obj(window_scene orelse return .realize_failed);
        const scale = scene.msgSend(objc.Object, "screen", .{}).msgSend(CGFloat, "nativeScale", .{});
        uiview.msgSend(void, "setContentScaleFactor:", .{scale});
        const window = cls("UIWindow").msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "initWithWindowScene:", .{scene});
        const container = container_class.?.msgSend(objc.Object, "alloc", .{})
            .msgSend(objc.Object, "initWithFrame:", .{window.msgSend(CGRect, "bounds", .{})});
        container.msgSend(void, "setBackgroundColor:", .{cls("UIColor").msgSend(objc.Object, "blackColor", .{})});
        container.msgSend(void, "addSubview:", .{uiview});
        const vc = cls("UIViewController").msgSend(objc.Object, "alloc", .{}).msgSend(objc.Object, "init", .{});
        vc.msgSend(void, "setView:", .{container});
        window.msgSend(void, "setRootViewController:", .{vc});
        c.object_setIvar(uiview.value, c.object_getInstanceVariable(uiview.value, "ownedWindow", null), window.value);
        container.release();
        vc.release();
    }
    view.handle = uiview.value;
    view.visible = false;
    return .success;
}

fn uiView(view: *root.View) ?objc.Object {
    return obj(@ptrCast(@alignCast(view.handle orelse return null)));
}

fn ownedWindow(view: *root.View) ?objc.Object {
    const v = uiView(view) orelse return null;
    return obj(c.object_getIvar(v.value, c.object_getInstanceVariable(v.value, "ownedWindow", null)) orelse return null);
}

pub fn destroyView(view: *root.View) void {
    const v = uiView(view) orelse return;
    const window = ownedWindow(view);
    setZigView(v.value, null);
    v.msgSend(void, "removeFromSuperview", .{});
    v.release();
    if (window) |w| {
        w.msgSend(void, "setHidden:", .{true});
        w.release();
    }
    view.handle = null;
}

pub fn showView(view: *root.View, _: root.ShowCommand) root.Status {
    const v = uiView(view) orelse return .bad_call;
    if (ownedWindow(view)) |w| w.msgSend(void, "makeKeyAndVisible", .{});
    v.msgSend(void, "setHidden:", .{false});
    view.visible = true;
    return .success;
}

pub fn hideView(view: *root.View) root.Status {
    const v = uiView(view) orelse return .bad_call;
    v.msgSend(void, "setHidden:", .{true});
    view.visible = false;
    return .success;
}

pub fn update(world: *root.World, timeout: f64) root.Status {
    if (world.type == .module) return .success;
    const pool = objc_autoreleasePoolPush();
    defer objc_autoreleasePoolPop(pool);
    if (CFRunLoopRunInMode(kCFRunLoopDefaultMode, timeout, 1) == kCFRunLoopRunHandledSource) {
        while (CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, 1) == kCFRunLoopRunHandledSource) {}
    }
    return .success;
}

pub fn getTime(_: *root.World) f64 {
    return CACurrentMediaTime() - start_time;
}

pub fn getScaleFactor(view: *root.View) f64 {
    const v = uiView(view) orelse return 1.0;
    return v.msgSend(CGFloat, "contentScaleFactor", .{});
}

fn wakeMain(ctx: ?*anyopaque) callconv(.c) void {
    const view: *root.View = @ptrCast(@alignCast(ctx orelse return));
    if (view.handle == null) return;
    dispatch(view, .{ .client = .{ .data1 = 0, .data2 = 0 } });
}

pub fn sendEvent(view: *root.View, event: *const root.Event) root.Status {
    if (view.handle == null) return .bad_call;
    switch (event.*) {
        .client => dispatch_async_f(&_dispatch_main_q, view, wakeMain),
        else => return .unsupported,
    }
    return .success;
}

pub fn obscureView(view: *root.View) root.Status {
    if (view.handle == null) return .bad_call;
    dispatch_async_f(&_dispatch_main_q, view, wakeMain);
    return .success;
}

pub fn obscureRegion(view: *root.View, _: i32, _: i32, _: u32, _: u32) root.Status {
    return obscureView(view);
}

pub fn grabFocus(view: *root.View) root.Status {
    const v = uiView(view) orelse return .bad_call;
    _ = v.msgSend(bool, "becomeFirstResponder", .{});
    return .success;
}

pub fn hasFocus(view: *root.View) bool {
    const v = uiView(view) orelse return false;
    return v.msgSend(bool, "isFirstResponder", .{});
}

pub fn startTextInput(view: *root.View, _: root.TextInputRect) root.Status {
    return grabFocus(view);
}

pub fn stopTextInput(view: *root.View) root.Status {
    const v = uiView(view) orelse return .bad_call;
    _ = v.msgSend(bool, "resignFirstResponder", .{});
    return .success;
}

pub fn setTextInputRect(_: *root.View, _: root.TextInputRect) root.Status {
    return .success;
}

pub fn setCursor(_: *root.View, _: root.Cursor) root.Status {
    return .success;
}

pub fn setViewStyle(view: *root.View, flags: root.ViewStyleFlags) root.Status {
    view.style = flags;
    return .success;
}

pub fn applySizeHints(_: *root.View) root.Status {
    return .success;
}

pub fn setViewSize(view: *root.View, w: u32, h: u32) root.Status {
    const v = uiView(view) orelse return .bad_call;
    if (view.parent == 0) return .success;
    var f = v.msgSend(CGRect, "frame", .{});
    f.size = .{ .width = @floatFromInt(w), .height = @floatFromInt(h) };
    v.msgSend(void, "setFrame:", .{f});
    return .success;
}

pub fn setViewPosition(view: *root.View, x: i32, y: i32) root.Status {
    const v = uiView(view) orelse return .bad_call;
    if (view.parent == 0) return .success;
    var f = v.msgSend(CGRect, "frame", .{});
    f.origin = .{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
    v.msgSend(void, "setFrame:", .{f});
    return .success;
}

pub fn startTimer(_: *root.World, _: *root.View, _: usize, _: f64) root.Status {
    return .unsupported;
}

pub fn stopTimer(_: *root.World, _: *root.View, _: usize) root.Status {
    return .unsupported;
}

pub fn deinitWorld(world: *root.World) void {
    if (world_ref == world) world_ref = null;
    clipboard_buf.deinit(world.allocator);
    clipboard_buf = .empty;
}

pub fn getNativeWorld(_: *root.World) ?*anyopaque {
    return null;
}

fn pasteboard() objc.Object {
    return cls("UIPasteboard").msgSend(objc.Object, "generalPasteboard", .{});
}

pub fn paste(view: *root.View) root.Status {
    if (view.handle == null) return .bad_call;
    dispatch(view, .{ .data_offer = .{ .time = getTime(view.world), .x = 0, .y = 0, .clipboard = .general } });
    return .success;
}

pub fn getNumClipboardTypes(_: *root.View, clipboard: root.Clipboard) u32 {
    if (clipboard != .general) return 0;
    return if (pasteboard().msgSend(bool, "hasStrings", .{})) 1 else 0;
}

pub fn getClipboardType(_: *root.View, clipboard: root.Clipboard, type_index: u32) ?[]const u8 {
    if (clipboard != .general or type_index != 0) return null;
    return "text/plain";
}

pub fn acceptOffer(view: *root.View, offer: *const root.DataOfferEvent, type_index: u32, _: root.DataAction, _: i32, _: i32, _: u32, _: u32) root.Status {
    dispatch(view, .{ .data = .{ .time = offer.time, .x = 0, .y = 0, .clipboard = offer.clipboard, .type_index = type_index } });
    return .success;
}

pub fn rejectOffer(_: *root.View, _: *const root.DataOfferEvent, _: i32, _: i32, _: u32, _: u32) root.Status {
    return .unsupported;
}

pub fn getClipboard(view: *root.View, clipboard: root.Clipboard, type_index: u32) ?[]const u8 {
    if (clipboard != .general or type_index != 0) return null;
    const s = pasteboard().msgSend(c.id, "string", .{}) orelse return null;
    const utf8 = std.mem.span(obj(s).msgSend([*:0]const u8, "UTF8String", .{}));
    clipboard_buf.clearRetainingCapacity();
    clipboard_buf.appendSlice(view.world.allocator, utf8) catch return null;
    return clipboard_buf.items;
}

pub fn setClipboard(_: *root.View, clipboard: root.Clipboard, _: []const u8, data: []const u8) root.Status {
    if (clipboard != .general) return .unsupported;
    const s = cls("NSString").msgSend(objc.Object, "alloc", .{})
        .msgSend(objc.Object, "initWithBytes:length:encoding:", .{ data.ptr, data.len, @as(NSUInteger, 4) });
    defer s.release();
    pasteboard().msgSend(void, "setString:", .{s});
    return .success;
}

pub fn openUrl(url: [:0]const u8) root.Status {
    const nsurl = cls("NSURL").msgSend(c.id, "URLWithString:", .{nsString(url.ptr)}) orelse return .bad_parameter;
    const app = cls("UIApplication").msgSend(objc.Object, "sharedApplication", .{});
    const opts = cls("NSDictionary").msgSend(objc.Object, "dictionary", .{});
    app.msgSend(void, "openURL:options:completionHandler:", .{ nsurl, opts, @as(?*anyopaque, null) });
    return .success;
}

pub fn prefersDark(view: *root.View) ?bool {
    const v = uiView(view) orelse return null;
    return v.msgSend(objc.Object, "traitCollection", .{}).msgSend(NSInteger, "userInterfaceStyle", .{}) == 2;
}
