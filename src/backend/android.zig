const std = @import("std");
const root = @import("../root.zig");
const common = root.common;

pub const ANativeWindow = opaque {};
pub const AInputEvent = opaque {};
pub const ALooper = opaque {};
pub const AConfiguration = opaque {};
pub const AInputQueue = opaque {};

pub const ANativeActivity = extern struct {
    callbacks: ?*anyopaque,
    vm: ?*anyopaque,
    env: ?*anyopaque,
    clazz: ?*anyopaque,
    internal_data_path: ?[*:0]const u8,
    external_data_path: ?[*:0]const u8,
    sdk_version: i32,
    instance: ?*anyopaque,
    asset_manager: ?*anyopaque,
    obb_path: ?[*:0]const u8,
};

pub const ARect = extern struct { left: i32, top: i32, right: i32, bottom: i32 };

pub const PollSource = extern struct {
    id: i32,
    app: *App,
    process: *const fn (*App, *PollSource) callconv(.c) void,
};

pub const App = extern struct {
    user_data: ?*anyopaque,
    on_app_cmd: ?*const fn (*App, i32) callconv(.c) void,
    on_input_event: ?*const fn (*App, *AInputEvent) callconv(.c) i32,
    activity: *ANativeActivity,
    config: ?*AConfiguration,
    saved_state: ?*anyopaque,
    saved_state_size: usize,
    looper: ?*ALooper,
    input_queue: ?*AInputQueue,
    window: ?*ANativeWindow,
    content_rect: ARect,
    activity_state: c_int,
    destroy_requested: c_int,
};

const Cmd = enum(i32) {
    input_changed,
    init_window,
    term_window,
    window_resized,
    window_redraw_needed,
    content_rect_changed,
    gained_focus,
    lost_focus,
    config_changed,
    low_memory,
    start,
    @"resume",
    save_state,
    pause,
    stop,
    destroy,
    _,
};

extern fn ALooper_pollOnce(timeout_ms: c_int, out_fd: ?*c_int, out_events: ?*c_int, out_data: ?*?*anyopaque) c_int;
extern fn ANativeWindow_getWidth(window: *ANativeWindow) i32;
extern fn ANativeWindow_getHeight(window: *ANativeWindow) i32;
extern fn AConfiguration_getDensity(config: *AConfiguration) i32;
extern fn AConfiguration_getUiModeNight(config: *AConfiguration) i32;
extern fn ANativeActivity_showSoftInput(activity: *ANativeActivity, flags: u32) void;
extern fn ANativeActivity_hideSoftInput(activity: *ANativeActivity, flags: u32) void;
extern fn AInputEvent_getType(event: *const AInputEvent) i32;
extern fn AMotionEvent_getAction(event: *const AInputEvent) i32;
extern fn AMotionEvent_getX(event: *const AInputEvent, pointer_index: usize) f32;
extern fn AMotionEvent_getY(event: *const AInputEvent, pointer_index: usize) f32;
extern fn AMotionEvent_getPointerCount(event: *const AInputEvent) usize;
extern fn AMotionEvent_getPointerId(event: *const AInputEvent, pointer_index: usize) i32;
extern fn AMotionEvent_getAxisValue(event: *const AInputEvent, axis: i32, pointer_index: usize) f32;
extern fn AKeyEvent_getAction(event: *const AInputEvent) i32;
extern fn AKeyEvent_getKeyCode(event: *const AInputEvent) i32;
extern fn AKeyEvent_getMetaState(event: *const AInputEvent) i32;

const EGLDisplay = ?*anyopaque;
const EGLConfig = ?*anyopaque;
const EGLContext = ?*anyopaque;
const EGLSurface = ?*anyopaque;
extern fn eglGetDisplay(native: ?*anyopaque) EGLDisplay;
extern fn eglInitialize(dpy: EGLDisplay, major: ?*i32, minor: ?*i32) u32;
extern fn eglChooseConfig(dpy: EGLDisplay, attribs: [*]const i32, configs: *EGLConfig, size: i32, num: *i32) u32;
extern fn eglCreateContext(dpy: EGLDisplay, config: EGLConfig, share: EGLContext, attribs: [*]const i32) EGLContext;
extern fn eglCreateWindowSurface(dpy: EGLDisplay, config: EGLConfig, win: *ANativeWindow, attribs: ?[*]const i32) EGLSurface;
extern fn eglMakeCurrent(dpy: EGLDisplay, draw: EGLSurface, read: EGLSurface, ctx: EGLContext) u32;
extern fn eglSwapBuffers(dpy: EGLDisplay, surface: EGLSurface) u32;
extern fn eglDestroySurface(dpy: EGLDisplay, surface: EGLSurface) u32;
extern fn eglDestroyContext(dpy: EGLDisplay, ctx: EGLContext) u32;
extern fn eglTerminate(dpy: EGLDisplay) u32;
extern fn eglSwapInterval(dpy: EGLDisplay, interval: i32) u32;

const EGL_NONE = 0x3038;

pub var app: ?*App = null;

const Egl = struct {
    display: EGLDisplay = null,
    config: EGLConfig = null,
    context: EGLContext = null,
    surface: EGLSurface = null,
};

var egl: Egl = .{};
var current_view: ?*root.View = null;
var last_size: [2]i32 = .{ 0, 0 };
var client_queue: std.ArrayList([2]usize) = .empty;
var redraw_pending = false;
var destroyed = false;

fn theApp() *App {
    return app orelse @panic("zpugl android: set backend_impl.app in android_main before creating a world");
}

fn nowNs() u64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}

fn scale() f64 {
    const config = theApp().config orelse return 1.0;
    const dpi = AConfiguration_getDensity(config);
    return if (dpi <= 0) 1.0 else @as(f64, @floatFromInt(dpi)) / 160.0;
}

fn createSurface(window: *ANativeWindow) void {
    if (egl.context == null or egl.surface != null) return;
    egl.surface = eglCreateWindowSurface(egl.display, egl.config, window, null);
}

fn destroySurface() void {
    if (egl.surface == null) return;
    _ = eglMakeCurrent(egl.display, null, null, null);
    _ = eglDestroySurface(egl.display, egl.surface);
    egl.surface = null;
}

fn sendConfigure(view: *root.View) void {
    const window = theApp().window orelse return;
    const w = ANativeWindow_getWidth(window);
    const h = ANativeWindow_getHeight(window);
    if (w <= 0 or h <= 0) return;
    last_size = .{ w, h };
    const width: u16 = @intCast(@min(w, std.math.maxInt(u16)));
    const height: u16 = @intCast(@min(h, std.math.maxInt(u16)));
    view.size_hints[@backingInt(root.SizeHint.current_size)] = .{ .width = width, .height = height };
    _ = common.dispatchEvent(view, &.{ .configure = .{ .x = 0, .y = 0, .width = width, .height = height, .style = view.style } });
    _ = common.dispatchEvent(view, &.{ .expose = .{ .x = 0, .y = 0, .width = width, .height = height } });
}

fn onAppCmd(a: *App, cmd_raw: i32) callconv(.c) void {
    const cmd: Cmd = @fromBackingInt(@intCast(cmd_raw));
    switch (cmd) {
        .init_window => if (a.window) |window| {
            createSurface(window);
            if (current_view) |v| {
                v.handle = window;
                sendConfigure(v);
            }
        },
        .term_window => {
            destroySurface();
            if (current_view) |v| v.handle = null;
        },
        .window_resized, .config_changed, .content_rect_changed, .window_redraw_needed => if (current_view) |v| sendConfigure(v),
        .gained_focus => if (current_view) |v| {
            _ = common.dispatchEvent(v, &.{ .focus_in = .{ .mode = .normal } });
        },
        .lost_focus => if (current_view) |v| {
            _ = common.dispatchEvent(v, &.{ .focus_out = .{ .mode = .normal } });
        },
        .destroy => {
            destroyed = true;
            if (current_view) |v| _ = common.dispatchSimpleEvent(v, .close);
        },
        else => {},
    }
}

const AMOTION_EVENT_ACTION_MASK = 0xff;
const AMOTION_EVENT_ACTION_POINTER_INDEX_MASK = 0xff00;
const AINPUT_EVENT_TYPE_KEY = 1;
const AINPUT_EVENT_TYPE_MOTION = 2;
const AMOTION_EVENT_AXIS_VSCROLL = 9;
const AMOTION_EVENT_AXIS_HSCROLL = 10;
const AMETA_SHIFT_ON = 0x01;
const AMETA_ALT_ON = 0x02;
const AMETA_CTRL_ON = 0x1000;
const AMETA_META_ON = 0x10000;
const AKEYCODE_BACK = 4;

fn onInputEvent(_: *App, event: *AInputEvent) callconv(.c) i32 {
    const view = current_view orelse return 0;
    const t = @as(f64, @floatFromInt(nowNs())) / std.time.ns_per_s;
    switch (AInputEvent_getType(event)) {
        AINPUT_EVENT_TYPE_MOTION => {
            const s = scale();
            const action = AMotionEvent_getAction(event);
            const masked = action & AMOTION_EVENT_ACTION_MASK;
            const idx: usize = @intCast((action & AMOTION_EVENT_ACTION_POINTER_INDEX_MASK) >> 8);
            switch (masked) {
                3 => for (0..AMotionEvent_getPointerCount(event)) |i| {
                    const x = @as(f64, AMotionEvent_getX(event, i)) / s;
                    const y = @as(f64, AMotionEvent_getY(event, i)) / s;
                    _ = common.dispatchEvent(view, &.{ .touch_end = .{ .time = t, .id = @intCast(AMotionEvent_getPointerId(event, i)), .x = x, .y = y } });
                },
                0, 1, 5, 6 => {
                    const x = @as(f64, AMotionEvent_getX(event, idx)) / s;
                    const y = @as(f64, AMotionEvent_getY(event, idx)) / s;
                    const te: root.TouchEvent = .{ .time = t, .id = @intCast(AMotionEvent_getPointerId(event, idx)), .x = x, .y = y };
                    _ = common.dispatchEvent(view, &switch (masked) {
                        0, 5 => root.Event{ .touch_begin = te },
                        else => root.Event{ .touch_end = te },
                    });
                },
                2 => for (0..AMotionEvent_getPointerCount(event)) |i| {
                    const x = @as(f64, AMotionEvent_getX(event, i)) / s;
                    const y = @as(f64, AMotionEvent_getY(event, i)) / s;
                    _ = common.dispatchEvent(view, &.{ .touch_update = .{ .time = t, .id = @intCast(AMotionEvent_getPointerId(event, i)), .x = x, .y = y } });
                },
                7 => {
                    const x = @as(f64, AMotionEvent_getX(event, 0)) / s;
                    const y = @as(f64, AMotionEvent_getY(event, 0)) / s;
                    _ = common.dispatchEvent(view, &.{ .motion = .{ .time = t, .x = x, .y = y, .root_x = x, .root_y = y, .state = .{} } });
                },
                8 => {
                    const x = @as(f64, AMotionEvent_getX(event, 0)) / s;
                    const y = @as(f64, AMotionEvent_getY(event, 0)) / s;
                    _ = common.dispatchEvent(view, &.{ .scroll = .{
                        .time = t,
                        .x = x,
                        .y = y,
                        .root_x = x,
                        .root_y = y,
                        .state = .{},
                        .direction = .smooth,
                        .dx = AMotionEvent_getAxisValue(event, AMOTION_EVENT_AXIS_HSCROLL, 0),
                        .dy = AMotionEvent_getAxisValue(event, AMOTION_EVENT_AXIS_VSCROLL, 0),
                    } });
                },
                else => {},
            }
            return 1;
        },
        AINPUT_EVENT_TYPE_KEY => {
            const code = AKeyEvent_getKeyCode(event);
            if (code == AKEYCODE_BACK) return 0;
            const meta = AKeyEvent_getMetaState(event);
            const mods: root.Mods = .{
                .shift = meta & AMETA_SHIFT_ON != 0,
                .alt = meta & AMETA_ALT_ON != 0,
                .ctrl = meta & AMETA_CTRL_ON != 0,
                .super = meta & AMETA_META_ON != 0,
            };
            const key = mapKey(code);
            if (key == 0) return 0;
            const press = AKeyEvent_getAction(event) == 0;
            const kc: u32 = @intCast(code);
            const kev: root.KeyEvent = .{ .time = t, .x = 0, .y = 0, .root_x = 0, .root_y = 0, .state = mods, .keycode = kc, .key = key };
            _ = common.dispatchEvent(view, &if (press) root.Event{ .key_press = kev } else root.Event{ .key_release = kev });
            if (press and !mods.ctrl and !mods.alt and !mods.super) {
                if (textFor(key, mods.shift)) |ch| {
                    var tev: root.TextEvent = .{ .time = t, .x = 0, .y = 0, .root_x = 0, .root_y = 0, .state = mods, .keycode = kc, .character = ch, .string = @splat(0) };
                    tev.string[0] = @intCast(ch);
                    _ = common.dispatchEvent(view, &.{ .text = tev });
                }
            }
            return 1;
        },
        else => return 0,
    }
}

fn mapKey(code: i32) u32 {
    const K = root.Key;
    return switch (code) {
        29...54 => 'a' + @as(u32, @intCast(code - 29)),
        7...16 => '0' + @as(u32, @intCast(code - 7)),
        62 => ' ',
        55 => ',',
        56 => '.',
        69 => '-',
        70 => '=',
        71 => '[',
        72 => ']',
        73 => '\\',
        74 => ';',
        75 => '\'',
        76 => '/',
        68 => '`',
        67 => @backingInt(K.backspace),
        112 => @backingInt(K.delete),
        66 => @backingInt(K.enter),
        61 => @backingInt(K.tab),
        111 => @backingInt(K.escape),
        19 => @backingInt(K.up),
        20 => @backingInt(K.down),
        21 => @backingInt(K.left),
        22 => @backingInt(K.right),
        122 => @backingInt(K.home),
        123 => @backingInt(K.end),
        92 => @backingInt(K.page_up),
        93 => @backingInt(K.page_down),
        59 => @backingInt(K.shift_l),
        60 => @backingInt(K.shift_r),
        113 => @backingInt(K.ctrl_l),
        114 => @backingInt(K.ctrl_r),
        57 => @backingInt(K.alt_l),
        58 => @backingInt(K.alt_r),
        else => 0,
    };
}

fn textFor(key: u32, shift: bool) ?u32 {
    if (key >= 0x7f) return null;
    if (key < ' ') return null;
    if (!shift) return key;
    if (key >= 'a' and key <= 'z') return key - 'a' + 'A';
    const plain = "1234567890-=[]\\;',./`";
    const shifted = "!@#$%^&*()_+{}|:\"<>?~";
    const i = std.mem.indexOfScalar(u8, plain, @intCast(key)) orelse return key;
    return shifted[i];
}

pub fn createView(view: *root.View) root.Status {
    const a = theApp();
    if (current_view != null) return .bad_call;
    current_view = view;
    destroyed = false;
    last_size = .{ 0, 0 };
    a.on_app_cmd = onAppCmd;
    a.on_input_event = onInputEvent;
    while (a.window == null) {
        if (a.destroy_requested != 0) {
            current_view = null;
            return .realize_failed;
        }
        pollOnce(-1);
    }
    view.handle = a.window;
    return .success;
}

pub fn destroyView(view: *root.View) void {
    if (current_view == view) {
        current_view = null;
        client_queue.clearRetainingCapacity();
        redraw_pending = false;
    }
    view.handle = null;
}

pub fn glCreate(view: *root.View) usize {
    const window: *ANativeWindow = @ptrCast(view.handle orelse return 0);
    if (egl.context == null) {
        egl.display = eglGetDisplay(null);
        if (eglInitialize(egl.display, null, null) == 0) return 0;
        const attribs = [_]i32{
            0x3040,   0x40,
            0x3033,   0x4,
            0x3024,   8,
            0x3023,   8,
            0x3022,   8,
            0x3021,   8,
            EGL_NONE,
        };
        var n: i32 = 0;
        if (eglChooseConfig(egl.display, &attribs, &egl.config, 1, &n) == 0 or n == 0) return 0;
        const ctx_attribs = [_]i32{ 0x3098, 3, EGL_NONE };
        egl.context = eglCreateContext(egl.display, egl.config, null, &ctx_attribs);
        if (egl.context == null) return 0;
    }
    createSurface(window);
    if (egl.surface == null) return 0;
    _ = eglMakeCurrent(egl.display, egl.surface, egl.surface, egl.context);
    _ = eglSwapInterval(egl.display, 1);
    _ = eglMakeCurrent(egl.display, null, null, null);
    return @intFromPtr(&egl);
}

pub fn glDestroy() void {
    destroySurface();
    if (egl.context != null) _ = eglDestroyContext(egl.display, egl.context);
    if (egl.display != null) _ = eglTerminate(egl.display);
    egl = .{};
}

pub fn glEnter() bool {
    if (egl.surface == null) return false;
    return eglMakeCurrent(egl.display, egl.surface, egl.surface, egl.context) != 0;
}

pub fn glLeave(swap: bool) void {
    if (egl.surface == null) return;
    if (swap) _ = eglSwapBuffers(egl.display, egl.surface);
    _ = eglMakeCurrent(egl.display, null, null, null);
}

fn pollOnce(timeout_ms: c_int) void {
    var data: ?*anyopaque = null;
    const ident = ALooper_pollOnce(timeout_ms, null, null, &data);
    if (ident >= 0) if (data) |d| {
        const src: *PollSource = @ptrCast(@alignCast(d));
        src.process(theApp(), src);
    };
}

pub fn update(world: *root.World, timeout: f64) root.Status {
    _ = world;
    const a = theApp();
    const ms: c_int = if (client_queue.items.len > 0 or redraw_pending) 0 else if (timeout < 0) -1 else @intFromFloat(@min(timeout * 1000.0, std.math.maxInt(c_int)));
    pollOnce(ms);
    for (0..64) |_| {
        var data: ?*anyopaque = null;
        const ident = ALooper_pollOnce(0, null, null, &data);
        if (ident < 0) break;
        if (data) |d| {
            const src: *PollSource = @ptrCast(@alignCast(d));
            src.process(a, src);
        }
    }
    if (a.window) |window| if (current_view) |v| {
        if (ANativeWindow_getWidth(window) != last_size[0] or ANativeWindow_getHeight(window) != last_size[1]) sendConfigure(v);
    };
    var n = client_queue.items.len;
    while (n > 0 and client_queue.items.len > 0) : (n -= 1) {
        const d = client_queue.orderedRemove(0);
        if (current_view) |v| _ = common.dispatchEvent(v, &.{ .client = .{ .data1 = d[0], .data2 = d[1] } });
    }
    if (redraw_pending) if (current_view) |v| if (a.window != null) {
        redraw_pending = false;
        _ = common.dispatchEvent(v, &.{ .expose = .{ .x = 0, .y = 0, .width = @intCast(@min(last_size[0], std.math.maxInt(u16))), .height = @intCast(@min(last_size[1], std.math.maxInt(u16))) } });
    };
    return .success;
}

pub fn getTime(world: *root.World) f64 {
    _ = world;
    return @as(f64, @floatFromInt(nowNs())) / std.time.ns_per_s;
}

pub fn getScaleFactor(view: *root.View) f64 {
    _ = view;
    return scale();
}

pub fn showView(view: *root.View, command: root.ShowCommand) root.Status {
    _ = command;
    view.visible = true;
    return .success;
}

pub fn hideView(view: *root.View) root.Status {
    _ = view;
    return .unsupported;
}

pub fn obscureView(view: *root.View) root.Status {
    if (view != current_view) return .bad_call;
    redraw_pending = true;
    return .success;
}

pub fn obscureRegion(view: *root.View, x: i32, y: i32, w: u32, h: u32) root.Status {
    _ = .{ x, y, w, h };
    return obscureView(view);
}

pub fn sendEvent(view: *root.View, event: *const root.Event) root.Status {
    return switch (event.*) {
        .client => |cl| {
            if (view != current_view) return .bad_call;
            client_queue.append(view.world.allocator, .{ cl.data1, cl.data2 }) catch return .no_memory;
            return .success;
        },
        else => .unsupported,
    };
}

pub fn grabFocus(view: *root.View) root.Status {
    _ = view;
    return .success;
}

pub fn hasFocus(view: *root.View) bool {
    return view == current_view;
}

pub fn setCursor(view: *root.View, cursor: root.Cursor) root.Status {
    _ = .{ view, cursor };
    return .unsupported;
}

pub fn deinitWorld(world: *root.World) void {
    client_queue.deinit(world.allocator);
    client_queue = .empty;
}

pub fn getNativeWorld(world: *root.World) ?*anyopaque {
    _ = world;
    return theApp().activity;
}

pub fn startTimer(world: *root.World, view: *root.View, id: usize, freq: f64) root.Status {
    _ = .{ world, view, id, freq };
    return .unsupported;
}

pub fn stopTimer(world: *root.World, view: *root.View, id: usize) root.Status {
    _ = .{ world, view, id };
    return .unsupported;
}

pub fn setViewStyle(view: *root.View, flags: root.ViewStyleFlags) root.Status {
    view.style = flags;
    return .success;
}

pub fn applySizeHints(view: *root.View) root.Status {
    _ = view;
    return .success;
}

pub fn setViewSize(view: *root.View, w: u32, h: u32) root.Status {
    _ = .{ view, w, h };
    return .unsupported;
}

pub fn setViewPosition(view: *root.View, x: i32, y: i32) root.Status {
    _ = .{ view, x, y };
    return .unsupported;
}

pub fn paste(view: *root.View) root.Status {
    _ = view;
    return .unsupported;
}

pub fn getNumClipboardTypes(view: *root.View, clipboard: root.Clipboard) u32 {
    _ = .{ view, clipboard };
    return 0;
}

pub fn getClipboardType(view: *root.View, clipboard: root.Clipboard, type_index: u32) ?[]const u8 {
    _ = .{ view, clipboard, type_index };
    return null;
}

pub fn rejectOffer(view: *root.View, offer: *const root.DataOfferEvent, rx: i32, ry: i32, rw: u32, rh: u32) root.Status {
    _ = .{ view, offer, rx, ry, rw, rh };
    return .unsupported;
}

pub fn setClipboard(view: *root.View, clipboard: root.Clipboard, mime_type: []const u8, data: []const u8) root.Status {
    _ = .{ view, clipboard, mime_type, data };
    return .unsupported;
}

pub fn getClipboard(view: *root.View, clipboard: root.Clipboard, type_index: u32) ?[]const u8 {
    _ = .{ view, clipboard, type_index };
    return null;
}

pub fn startTextInput(view: *root.View, rect: root.TextInputRect) root.Status {
    _ = .{ view, rect };
    ANativeActivity_showSoftInput(theApp().activity, 0);
    return .success;
}

pub fn stopTextInput(view: *root.View) root.Status {
    _ = view;
    ANativeActivity_hideSoftInput(theApp().activity, 0);
    return .success;
}

pub fn setTextInputRect(view: *root.View, rect: root.TextInputRect) root.Status {
    _ = .{ view, rect };
    return .success;
}

pub fn openUrl(url: [:0]const u8) root.Status {
    _ = url;
    return .unsupported;
}

pub fn prefersDark(view: *root.View) ?bool {
    _ = view;
    const config = theApp().config orelse return null;
    return switch (AConfiguration_getUiModeNight(config)) {
        1 => false,
        2 => true,
        else => null,
    };
}
