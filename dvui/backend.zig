const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
pub const zpugl = @import("zpugl");
const use_metal = builtin.os.tag.isDarwin();
const opengl = if (use_metal) struct {} else @import("opengl.zig");
const c = if (use_metal) struct {} else opengl.c;
const metal = if (use_metal) @import("metal.zig") else struct {};
const vulkan = @import("vulkan.zig");

const Core = @This();
pub const kind: dvui.enums.Backend = .custom;

pub const Native = if (use_metal) metal.Renderer else opengl.GLState;
pub const Renderer = union(enum) {
    native: Native,
    vulkan: *vulkan.Renderer,

    fn deinit(self: *Renderer) void {
        switch (self.*) {
            .native => |*n| n.deinit(),
            .vulkan => |r| r.deinit(),
        }
    }
};

const TextChunk = struct { bytes: [8]u8, len: usize, at: usize = 0 };
pub const default_wait_step_us = 150_000;
pub const pointer_physical = builtin.os.tag == .windows or (builtin.os.tag == .linux and !builtin.abi.isAndroid());

pub const Repaint = struct { ctx: *anyopaque, f: *const fn (*anyopaque) void };

pub const Parts = struct {
    world: *zpugl.World,
    view: *zpugl.View,
    gl: Renderer,

    pub fn deinit(p: *Parts) void {
        p.gl.deinit();
        p.view.deinit();
        p.world.deinit();
    }
};

pub const Options = struct {
    parent: ?*anyopaque = null,
    title: []const u8 = "",
    width: u32,
    height: u32,
    position: ?zpugl.Point = null,
    headless: bool = false,
    parts: ?Parts = null,
    world_allocator: ?std.mem.Allocator = null,
    vulkan: bool = !use_metal,
};

world: *zpugl.World,
view: *zpugl.View,
gl: Renderer,
size: dvui.Size.Physical,
natural: dvui.Size.Natural,
scale: f32 = 1.0,
scale_override: ?f32 = null,
headless: bool = false,
events: std.ArrayList(dvui.Event) = .empty,
text_queue: std.ArrayList(TextChunk) = .empty,
key_num: ?u16 = null,
key_handled: bool = false,
allocator: std.mem.Allocator,
mouse_x: f32 = 0,
mouse_y: f32 = 0,
touch_pts: [10]dvui.Point = @splat(.{}),
win: ?dvui.Window = null,
impl: ?*dvui.backend = null,
event_hook: ?*const fn (*dvui.backend, *const zpugl.Event) bool = null,
arena: std.mem.Allocator = undefined,
cursor_last: ?zpugl.Cursor = null,
text_input_rect_last: ?dvui.Rect.Natural = null,
pasted: std.ArrayList(u8) = .empty,
paste_pending: bool = false,
closed: bool = false,
woken: bool = false,
dirty: ?*std.atomic.Value(bool) = null,
wait_step_us: u32 = default_wait_step_us,
repaint: ?Repaint = null,
in_frame: bool = false,
in_expose: bool = false,
gl_entered: bool = false,

pub fn init(allocator: std.mem.Allocator, parent: ?*anyopaque, w: u32, h: u32) !*Core {
    return open(allocator, .{ .parent = parent, .width = w, .height = h, .position = .{ .x = 0, .y = 0 } });
}

pub fn initWindow(allocator: std.mem.Allocator, title: []const u8, w: u32, h: u32, pos: ?zpugl.Point) !*Core {
    return open(allocator, .{ .title = title, .width = w, .height = h, .position = pos });
}

fn open(allocator: std.mem.Allocator, opts: Options) !*Core {
    const self = try create(allocator, opts);
    errdefer self.deinit();
    try self.openWindow(self);
    return self;
}

pub fn create(allocator: std.mem.Allocator, opts: Options) !*Core {
    std.debug.assert(opts.parts == null or (use_metal and opts.parent == null));
    std.debug.assert(!opts.vulkan or builtin.os.tag != .ios);
    const self = try allocator.create(Core);
    errdefer allocator.destroy(self);
    const natural: dvui.Size.Natural = .{ .w = @floatFromInt(opts.width), .h = @floatFromInt(opts.height) };
    if (opts.parts) |p| {
        self.* = .{ .world = p.world, .view = p.view, .gl = p.gl, .natural = natural, .size = .{ .w = natural.w, .h = natural.h }, .allocator = allocator, .headless = opts.headless };
        p.view.user_data = self;
        self.finishCreate();
        return self;
    }
    const world = try zpugl.World.init(opts.world_allocator orelse allocator, if (opts.parent == null) .program else .module, .{});
    errdefer world.deinit();
    self.* = .{ .world = world, .view = undefined, .gl = undefined, .natural = natural, .size = .{ .w = natural.w, .h = natural.h }, .allocator = allocator, .headless = opts.headless };

    if (opts.vulkan) vk: {
        const inst = vulkan.Instance.init(world) catch {
            std.log.info("zpugl: Vulkan unavailable, using the native renderer", .{});
            break :vk;
        };
        const view = self.openView(opts, .vulkan) catch |err| {
            var i = inst;
            i.deinit();
            return err;
        };
        const r = vulkan.Renderer.init(allocator, inst, view) catch {
            var i = inst;
            i.deinit();
            view.deinit();
            std.log.info("zpugl: Vulkan setup failed, using the native renderer", .{});
            break :vk;
        };
        self.gl = .{ .vulkan = r };
        self.finishCreate();
        return self;
    }

    const view = try self.openView(opts, if (use_metal) .metal else .gl);
    errdefer view.deinit();
    if (use_metal) {
        self.gl = .{ .native = try metal.Renderer.init(allocator, view) };
    } else {
        const gb = zpugl.gl.get_backend();
        _ = gb.enter(view, null);
        defer _ = gb.leave(view, null);
        self.gl = .{ .native = try opengl.GLState.init() };
    }
    self.finishCreate();
    return self;
}

fn openView(self: *Core, opts: Options, backend_tag: zpugl.BackendTag) !*zpugl.View {
    const view = try zpugl.View.init(self.world, onEvent);
    errdefer view.deinit();
    self.view = view;
    if (opts.parent) |p| view.setParent(@intFromPtr(p)) else {
        _ = view.setHint(.resizable, @backingInt(zpugl.ViewHintValue.true));
        _ = view.setViewString(.window_title, opts.title);
    }
    view.user_data = self;
    view.setBackend(backend_tag);
    if (backend_tag == .gl) {
        _ = view.setHint(.context_version_major, 3);
        _ = view.setHint(.context_version_minor, 3);
        _ = view.setHint(.context_profile, @backingInt(zpugl.ViewHintValue.opengl_core_profile));
        _ = view.setHint(.swap_interval, 0);
    }
    _ = view.setSizeHint(.default_size, opts.width, opts.height);
    if (opts.position) |p| _ = view.setPositionHint(.default_position, p.x, p.y);
    try view.realize();
    return view;
}

fn isGl(self: *const Core) bool {
    return self.view.graphics_backend == .gl;
}

fn readScale(self: *Core) void {
    const s: f32 = self.scale_override orelse @floatCast(zpugl.backend_impl.getScaleFactor(self.view));
    if (s > 0) self.scale = s;
    self.size = self.natural.scale(self.scale, dvui.Size.Physical);
}

fn finishCreate(self: *Core) void {
    self.readScale();
    if (self.view.getParent() != 0) self.fitChildView();
}

pub fn openWindow(self: *Core, impl: *dvui.backend) !void {
    std.debug.assert(self.win == null);
    self.impl = impl;
    self.win = try dvui.Window.init(@src(), self.allocator, dvui.Backend.init(impl), .{ .theme = dvui.Theme.builtin.adwaita_dark });
}

pub fn deinit(self: *Core) void {
    const gl_ctx = self.isGl();
    if (gl_ctx) _ = zpugl.gl.get_backend().enter(self.view, null);
    self.deinitState();
    self.gl.deinit();
    if (gl_ctx) _ = zpugl.gl.get_backend().leave(self.view, null);
    self.view.deinit();
    self.world.deinit();
    self.allocator.destroy(self);
}

pub fn release(self: *Core) Parts {
    std.debug.assert(use_metal and self.gl == .native);
    self.deinitState();
    if (self.gl.native.cmd != null) self.gl.native.end();
    std.debug.assert(self.gl.native.target == null);
    if (self.textInputActive()) _ = self.view.stopTextInput();
    self.view.user_data = null;
    const parts: Parts = .{ .world = self.world, .view = self.view, .gl = self.gl };
    self.allocator.destroy(self);
    return parts;
}

fn deinitState(self: *Core) void {
    if (self.win) |*w| w.deinit();
    self.events.deinit(self.allocator);
    self.text_queue.deinit(self.allocator);
    self.pasted.deinit(self.allocator);
}

pub fn windowPosition(self: *Core) ?zpugl.Point {
    return self.view.getWindowPosition();
}

pub fn pointerPoint(self: *const Core, x: f64, y: f64) dvui.Point.Physical {
    const k: f32 = if (pointer_physical) 1 else self.scale;
    return .{ .x = @as(f32, @floatCast(x)) * k, .y = @as(f32, @floatCast(y)) * k };
}

fn setMouse(self: *Core, x: f64, y: f64) void {
    const p = self.pointerPoint(x, y);
    self.mouse_x = p.x;
    self.mouse_y = p.y;
}

fn mapMods(m: zpugl.Mods) dvui.enums.Mod {
    var r: dvui.enums.Mod = .none;
    if (m.shift) r.combine(.lshift);
    if (m.ctrl) r.combine(.lcontrol);
    if (m.alt) r.combine(.lalt);
    if (m.super) r.combine(.lcommand);
    return r;
}

pub fn mapKey(zk: u32) dvui.enums.Key {
    const K = dvui.enums.Key;
    return switch (zk) {
        'a'...'z' => @fromBackingInt(@intCast(@as(u32, @backingInt(K.a)) + (zk - 'a'))),
        'A'...'Z' => @fromBackingInt(@intCast(@as(u32, @backingInt(K.a)) + (zk - 'A'))),
        '0'...'9' => @fromBackingInt(@intCast(@as(u32, @backingInt(K.zero)) + (zk - '0'))),
        ' ' => .space,
        '-' => .minus,
        '=' => .equal,
        '[' => .left_bracket,
        ']' => .right_bracket,
        '\\' => .backslash,
        ';' => .semicolon,
        '\'' => .apostrophe,
        ',' => .comma,
        '.' => .period,
        '/' => .slash,
        '`' => .grave,
        0x0008 => .backspace,
        0x0009 => .tab,
        0x000D => .enter,
        0x001B => .escape,
        0x007F => .delete,
        0xE000...0xE00B => @fromBackingInt(@intCast(@as(u32, @backingInt(K.f1)) + (zk - 0xE000))),
        0xE031 => .page_up,
        0xE032 => .page_down,
        0xE033 => .end,
        0xE034 => .home,
        0xE035 => .left,
        0xE036 => .up,
        0xE037 => .right,
        0xE038 => .down,
        0xE041 => .print,
        0xE042 => .insert,
        0xE043 => .pause,
        0xE044 => .menu,
        0xE045 => .num_lock,
        0xE046 => .scroll_lock,
        0xE047 => .caps_lock,
        0xE051 => .left_shift,
        0xE052 => .right_shift,
        0xE053 => .left_control,
        0xE054 => .right_control,
        0xE055 => .left_alt,
        0xE056 => .right_alt,
        0xE057 => .left_command,
        0xE058 => .right_command,
        0xE060...0xE069 => @fromBackingInt(@intCast(@as(u32, @backingInt(K.kp_0)) + (zk - 0xE060))),
        0xE070 => .kp_enter,
        0xE0AA => .kp_multiply,
        0xE0AB => .kp_add,
        0xE0AD => .kp_subtract,
        0xE0AE => .kp_decimal,
        0xE0AF => .kp_divide,
        else => .unknown,
    };
}

fn onEvent(view: *zpugl.View, event: *const zpugl.Event) zpugl.Status {
    const self: *Core = @ptrCast(@alignCast(view.user_data orelse return .success));
    if (event.* != .expose) self.woken = true;
    if (self.event_hook) |hook| if (hook(self.impl.?, event)) return .success;

    switch (event.*) {
        .expose => {
            self.readScale();
            if (view.graphics_backend == .gl) zpugl.gl.resize(view);
            if (self.repaint != null and !self.in_frame) {
                self.in_expose = true;
                defer self.in_expose = false;
                self.repaint.?.f(self.repaint.?.ctx);
            } else self.woken = true;
        },
        .configure => |ev| if (view.getParent() == 0) {
            self.readScale();
            const div: f32 = if (builtin.os.tag.isDarwin()) 1 else self.scale;
            self.natural = .{ .w = @as(f32, @floatFromInt(ev.width)) / div, .h = @as(f32, @floatFromInt(ev.height)) / div };
            self.size = self.natural.scale(self.scale, dvui.Size.Physical);
        },
        .close => self.closed = true,
        .motion => |ev| {
            self.setMouse(ev.x, ev.y);
            self.events.append(self.allocator, .{ .evt = .{ .mouse = .{
                .action = .position,
                .button = .none,
                .mod = mapMods(ev.state),
                .p = .{ .x = self.mouse_x, .y = self.mouse_y },
                .floating_win = .zero,
            } } }) catch {};
        },
        .button_press, .button_release => |ev| {
            self.setMouse(ev.x, ev.y);
            self.events.append(self.allocator, .{ .evt = .{ .mouse = .{
                .action = if (event.* == .button_press) .press else .release,
                .button = switch (ev.button) {
                    0 => .left,
                    1 => .right,
                    2 => .middle,
                    3 => .four,
                    4 => .five,
                    5 => .six,
                    6 => .seven,
                    else => .eight,
                },
                .mod = mapMods(ev.state),
                .p = .{ .x = self.mouse_x, .y = self.mouse_y },
                .floating_win = .zero,
            } } }) catch {};
        },
        .scroll => |ev| {
            self.setMouse(ev.x, ev.y);
            const mod = mapMods(ev.state);
            const p: dvui.Point.Physical = .{ .x = self.mouse_x, .y = self.mouse_y };
            if (ev.dy != 0) self.events.append(self.allocator, .{ .evt = .{ .mouse = .{
                .action = .{ .wheel_y = @floatCast(ev.dy * dvui.scroll_speed) },
                .button = .none,
                .mod = mod,
                .p = p,
                .floating_win = .zero,
            } } }) catch {};
            if (ev.dx != 0) self.events.append(self.allocator, .{ .evt = .{ .mouse = .{
                .action = .{ .wheel_x = @floatCast(-ev.dx * dvui.scroll_speed) },
                .button = .none,
                .mod = mod,
                .p = p,
                .floating_win = .zero,
            } } }) catch {};
        },
        .key_press => |ev| {
            const active = self.textInputActive();
            self.events.append(self.allocator, .{ .evt = .{ .key = .{
                .code = mapKey(ev.key),
                .action = .down,
                .mod = mapMods(ev.state),
            } } }) catch return .no_memory;
            const r = self.repaint orelse return .success;
            if (self.in_frame) return .success;
            self.key_handled = false;
            r.f(r.ctx);
            return if (self.key_handled or active) .success else .failure;
        },
        .key_release => |ev| {
            self.events.append(self.allocator, .{ .evt = .{ .key = .{
                .code = mapKey(ev.key),
                .action = .up,
                .mod = mapMods(ev.state),
            } } }) catch {};
        },
        .text => |ev| {
            const len = std.mem.indexOfScalar(u8, &ev.string, 0) orelse ev.string.len;
            self.text_queue.append(self.allocator, .{ .bytes = ev.string, .len = len, .at = self.events.items.len }) catch {};
        },
        .touch_begin, .touch_update, .touch_end => |ev| {
            const p = self.pointerPoint(ev.x, ev.y);
            const slot = @min(ev.id, 9);
            const finger: dvui.enums.Button = @fromBackingInt(@intCast(@backingInt(dvui.enums.Button.touch0) + slot));
            const last = self.touch_pts[slot];
            const action: dvui.Event.Mouse.Action = switch (event.*) {
                .touch_begin => .press,
                .touch_end => .release,
                else => .{ .motion = .{ .x = p.x - last.x, .y = p.y - last.y } },
            };
            self.touch_pts[slot] = .{ .x = p.x, .y = p.y };
            self.events.append(self.allocator, .{ .evt = .{ .mouse = .{
                .action = action,
                .button = finger,
                .mod = .none,
                .p = p,
                .floating_win = .zero,
            } } }) catch {};
        },
        .pointer_in => self.cursor_last = null,
        .data_offer => |*offer| {
            if (!self.paste_pending or offer.clipboard != .general) return .success;
            var i: u32 = 0;
            while (i < view.getNumClipboardTypes(.general)) : (i += 1) {
                const mime = view.getClipboardType(.general, i) orelse continue;
                if (!std.mem.eql(u8, mime, "text/plain")) continue;
                if (view.acceptOffer(offer, i, .copy, 0, 0, 0, 0) == .success) return .success;
            }
            self.paste_pending = false;
        },
        .data => |ev| {
            if (!self.paste_pending or ev.clipboard != .general) return .success;
            self.paste_pending = false;
            const text = view.getClipboard(.general, ev.type_index) orelse return .success;
            self.pasted.appendSlice(self.allocator, text) catch {};
        },
        else => {},
    }
    return .success;
}

pub fn injectEvent(self: *Core, event: zpugl.Event) zpugl.Status {
    return onEvent(self.view, &event);
}

pub fn textInputActive(self: *const Core) bool {
    return self.text_input_rect_last != null;
}

var quit_requested: std.atomic.Value(bool) = .init(false);

fn onQuitSignal(_: std.posix.SIG) callconv(.c) void {
    quit_requested.store(true, .release);
}

pub fn installQuitSignals() void {
    if (builtin.os.tag != .windows) {
        const act: std.posix.Sigaction = .{ .handler = .{ .handler = onQuitSignal }, .mask = std.posix.sigemptyset(), .flags = 0 };
        std.posix.sigaction(.INT, &act, null);
        std.posix.sigaction(.TERM, &act, null);
    }
}

pub fn frameOnce(self: *Core, ctx: anytype, comptime frameFn: fn (@TypeOf(ctx)) anyerror!bool) !?u32 {
    const win = &self.win.?;
    self.in_frame = true;
    defer self.in_frame = false;
    try win.begin(win.beginWait(self.hasEvent()));
    const keep = try frameFn(ctx);
    const end_us = try win.end(.{});
    if (!keep) self.closed = true;
    return end_us;
}

pub fn run(self: *Core, ctx: anytype, comptime frameFn: fn (@TypeOf(ctx)) anyerror!bool) !void {
    const win = &self.win.?;
    const R = struct {
        var saved: @TypeOf(ctx) = undefined;
        fn paint(core: *anyopaque) void {
            _ = @as(*Core, @ptrCast(@alignCast(core))).frameOnce(saved, frameFn) catch |err| std.log.err("repaint failed: {s}", .{@errorName(err)});
        }
    };
    R.saved = ctx;
    self.repaint = .{ .ctx = self, .f = R.paint };
    defer self.repaint = null;
    while (!self.closed and !quit_requested.load(.acquire)) {
        const end_us = try self.frameOnce(ctx, frameFn);
        self.woken = false;
        const wait_us = win.waitTime(end_us);
        if (self.closed) return;
        var left = wait_us;
        while (!self.woken and !quit_requested.load(.acquire)) {
            if (self.dirty) |d| if (d.swap(false, .acquire)) break;
            const step = @min(left, self.wait_step_us);
            _ = self.world.update(@as(f64, @floatFromInt(step)) / std.time.us_per_s);
            if (wait_us == std.math.maxInt(u32)) continue;
            left -= step;
            if (left == 0) break;
        }
    }
}

pub fn runApp(main_init: std.process.Init, comptime appMain: fn (std.process.Init) anyerror!void) !void {
    if (builtin.os.tag != .ios) return appMain(main_init);
    const S = struct {
        var saved: std.process.Init = undefined;
        fn entry() void {
            appMain(saved) catch |err| {
                std.log.err("app failed: {s}", .{@errorName(err)});
                std.process.exit(1);
            };
        }
    };
    S.saved = main_init;
    zpugl.backend_impl.runApplication(S.entry);
}

pub fn main(main_init: std.process.Init) !void {
    return runApp(main_init, dvuiAppMain);
}

fn dvuiAppMain(main_init: std.process.Init) !void {
    dvui.App.main_init = main_init;
    const app = dvui.App.get() orelse return error.DvuiAppNotDefined;
    const opts = app.config.get();
    installQuitSignals();
    const bk = try dvui.backend.initWindow(opts.gpa orelse main_init.gpa, opts.title, @intFromFloat(opts.size.w), @intFromFloat(opts.size.h), null);
    defer bk.deinit();
    const core: *Core = if (comptime dvui.backend == Core) bk else bk.core;
    _ = core.view.show(.raise);
    const win = &core.win.?;
    win.max_fps = 60;
    if (app.initFn) |initFn| {
        try win.begin(win.frame_time_ns);
        try initFn(win);
        _ = try win.end(.{});
    }
    defer if (app.deinitFn) |deinitFn| deinitFn(win);
    try bk.run({}, struct {
        fn frame(_: void) !bool {
            return try dvui.App.get().?.frameFn() == .ok;
        }
    }.frame);
}

pub fn nanoTime(self: *Core) i128 {
    return @intFromFloat(self.world.getTime() * std.time.ns_per_s);
}

pub fn realTime(_: *Core) i128 {
    return std.Io.Clock.real.now(std.Io.Threaded.global_single_threaded.io()).nanoseconds;
}

pub fn sleep(self: *Core, ns: u64) void {
    _ = self.world.update(@as(f64, @floatFromInt(ns)) / std.time.ns_per_s);
}

pub fn eventFd(self: *Core) c_int {
    if (builtin.os.tag != .linux or builtin.abi.isAndroid()) return -1;
    const display = self.world.getNativeWorld() orelse return -1;
    return zpugl.backend_impl.XConnectionNumber(@ptrCast(@alignCast(display)));
}

pub fn pollEvents(self: *Core) void {
    _ = self.world.update(0);
}

pub fn begin(self: *Core, arena: std.mem.Allocator) !void {
    self.arena = arena;
    if (!self.in_expose and !self.headless) _ = self.world.update(0);
    const w: u32 = if (self.headless) 0 else @intFromFloat(self.size.w);
    const h: u32 = if (self.headless) 0 else @intFromFloat(self.size.h);
    if (self.gl == .vulkan) {
        try self.gl.vulkan.begin(w, h);
        return self.feedEvents();
    }
    if (use_metal) {
        self.gl.native.begin(w, h);
        return self.feedEvents();
    }
    const gb = zpugl.gl.get_backend();
    if (!self.in_expose) _ = gb.enter(self.view, null);
    self.gl_entered = true;
    self.gl.native.begin(w, h);
    zpugl.gl.resize(self.view);
    c.glViewport(0, 0, @intCast(w), @intCast(h));
    c.glClearColor(0.0, 0.6, 0.8, 1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT);
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_ONE, c.GL_ONE_MINUS_SRC_ALPHA);
    self.feedEvents();
}

pub fn hasEvent(self: *Core) bool {
    return self.events.items.len > 0;
}

fn nextEvent(self: *Core) ?dvui.Event {
    if (self.events.items.len == 0) return null;
    return self.events.orderedRemove(0);
}

fn feedEvents(self: *Core) void {
    const win = &self.win.?;
    const tq = self.text_queue.items;
    var ti: usize = 0;
    var queued: usize = 0;
    while (self.nextEvent()) |ev| : (queued += 1) {
        while (ti < tq.len and tq[ti].at <= queued) : (ti += 1) _ = win.addEventText(.{ .text = tq[ti].bytes[0..tq[ti].len] }) catch {};
        switch (ev.evt) {
            .mouse => |m| if (m.button.touch()) {
                const n: dvui.Point = .{ .x = m.p.x / self.size.w, .y = m.p.y / self.size.h };
                switch (m.action) {
                    .press, .release => _ = win.addEventPointer(.{ .button = m.button, .action = m.action, .xynorm = n }) catch {},
                    .motion => |d| _ = win.addEventTouchMotion(m.button, n.x, n.y, d.x / self.size.w, d.y / self.size.h) catch {},
                    else => {},
                }
            } else switch (m.action) {
                .position, .press, .release => {
                    win.modifiers = m.mod;
                    if (!m.p.equals(win.mouse_pt)) _ = win.addEventMouseMotion(.{ .pt = m.p }) catch {};
                    if (m.action != .position) _ = win.addEventMouseButton(m.button, m.action) catch {};
                },
                .wheel_y, .wheel_x => |d| {
                    win.modifiers = m.mod;
                    if (!m.p.equals(win.mouse_pt)) _ = win.addEventMouseMotion(.{ .pt = m.p }) catch {};
                    _ = win.addEventMouseWheel(d, if (m.action == .wheel_y) .vertical else .horizontal, null) catch {};
                },
                else => {},
            },
            .key => |k| {
                const num = win.event_num;
                _ = win.addEventKey(k) catch {};
                if (k.action == .down) self.key_num = if (win.event_num == num) null else win.event_num;
            },
            else => {},
        }
    }
    for (tq[ti..]) |chunk| _ = win.addEventText(.{ .text = chunk.bytes[0..chunk.len] }) catch {};
    self.text_queue.clearRetainingCapacity();
    if (self.pasted.items.len > 0) _ = win.addEventText(.{ .text = self.pasted.items }) catch {};
    self.pasted.clearRetainingCapacity();
}

pub fn end(self: *Core) !void {
    if (self.key_num) |num| self.key_handled = for (self.win.?.events.items) |e| {
        if (e.num == num) break e.handled;
    } else false;
    self.key_num = null;
    if (self.gl == .vulkan) return self.gl.vulkan.end();
    if (use_metal) return self.gl.native.end();
    self.gl_entered = false;
    if (self.in_expose) return;
    const expose = zpugl.ExposeEvent{ .x = 0, .y = 0, .width = @intFromFloat(self.size.w), .height = @intFromFloat(self.size.h) };
    _ = zpugl.gl.get_backend().leave(self.view, &expose);
}

pub fn pixelSize(self: *Core) dvui.Size.Physical {
    return self.size;
}

pub fn windowSize(self: *Core) dvui.Size.Natural {
    return self.natural;
}

pub fn contentScale(_: *Core) f32 {
    return 1.0;
}

pub fn drawClippedTriangles(self: *Core, texture: ?dvui.Texture, vtx: []const dvui.Vertex, idx: []const u16, clipr: ?dvui.Rect.Physical) !void {
    switch (self.gl) {
        .vulkan => |r| try r.drawClippedTriangles(texture, vtx, idx, clipr),
        .native => |*n| try n.drawClippedTriangles(texture, vtx, idx, clipr),
    }
}

pub fn textureCreate(self: *Core, pixels: [*]const u8, options: dvui.Texture.CreateOptions) !dvui.Texture {
    if (options.width == 0 or options.height == 0) return error.TextureCreate;
    if (self.gl == .vulkan) return self.gl.vulkan.textureCreate(pixels, options);
    if (use_metal) return self.gl.native.textureCreate(pixels, options);
    return opengl.createTexture(pixels, options);
}

pub fn textureDestroy(self: *Core, texture: dvui.Texture) void {
    if (self.gl == .vulkan) return self.gl.vulkan.textureDestroy(texture);
    if (use_metal) return self.gl.native.textureDestroy(texture);
    const tex: c.GLuint = @intCast(@intFromPtr(texture.ptr));
    c.glDeleteTextures(1, &tex);
}

pub fn textureUpdate(self: *Core, texture: dvui.Texture, pixels: [*]const u8) !void {
    if (self.gl == .vulkan) return self.gl.vulkan.textureUpdate(texture, pixels);
    if (use_metal) return self.gl.native.textureUpdate(texture, pixels);
    const tex: c.GLuint = @intCast(@intFromPtr(texture.ptr));
    c.glBindTexture(c.GL_TEXTURE_2D, tex);
    c.glTexSubImage2D(c.GL_TEXTURE_2D, 0, 0, 0, @intCast(texture.width), @intCast(texture.height), c.GL_RGBA, c.GL_UNSIGNED_BYTE, pixels);
}

pub fn textureUpdateSubRect(self: *Core, texture: dvui.Texture, pixels: [*]const u8, x: u32, y: u32, w: u32, h: u32) !void {
    if (self.gl == .vulkan) return self.gl.vulkan.textureUpdateSubRect(texture, pixels, x, y, w, h);
    return error.NotImplemented;
}

pub fn textureCreateTarget(self: *Core, options: dvui.Texture.CreateOptions) !dvui.TextureTarget {
    if (options.width == 0 or options.height == 0) return error.TextureCreate;
    if (self.gl == .vulkan) return self.gl.vulkan.targetCreate(options);
    if (use_metal) return self.gl.native.targetCreate(options);
    return opengl.createTarget(options);
}

pub fn textureDestroyTarget(self: *Core, texture: dvui.Texture.Target) void {
    self.textureDestroy(.cast(texture));
}

pub fn textureReadTarget(self: *Core, texture: dvui.TextureTarget, pixels_out: [*]u8) !void {
    if (self.gl == .vulkan) return self.gl.vulkan.targetRead(texture, pixels_out);
    if (use_metal) return self.gl.native.targetRead(texture, pixels_out);
    opengl.readTarget(texture, pixels_out);
}

pub fn textureFromTarget(_: *Core, texture: dvui.TextureTarget) !dvui.Texture {
    return .cast(texture);
}

pub fn textureFromTargetTemp(_: *Core, texture: dvui.TextureTarget) !dvui.Texture {
    return .cast(texture);
}

pub fn textureClearTarget(self: *Core, texture: dvui.TextureTarget) void {
    if (self.gl == .vulkan) return self.gl.vulkan.targetClear(texture);
    if (use_metal) return self.gl.native.targetClear(texture);
    opengl.clearTarget(texture);
}

pub fn renderTarget(self: *Core, texture: ?dvui.TextureTarget) !void {
    switch (self.gl) {
        .vulkan => |r| r.renderTarget(texture),
        .native => |*n| n.renderTarget(texture),
    }
}

pub fn clipboardPasteRequest(self: *Core) !void {
    self.paste_pending = true;
    if (self.view.paste() != .success) {
        self.paste_pending = false;
        return error.BackendError;
    }
}

pub fn clipboardTextSet(self: *Core, text: []const u8) !void {
    if (self.view.setClipboard(.general, "text/plain", text) != .success) return error.BackendError;
}

pub fn openURL(self: *Core, url: []const u8, _: bool) !void {
    const url_z = try self.arena.dupeSentinel(u8, url, 0);
    if (zpugl.backend_impl.openUrl(url_z) != .success) return error.BackendError;
}

pub fn setCursor(self: *Core, cursor: dvui.enums.Cursor) void {
    const pugl_cursor: zpugl.Cursor = switch (cursor) {
        .arrow, .wait, .wait_arrow, .hidden => .arrow,
        .ibeam => .caret,
        .crosshair => .crosshair,
        .arrow_nw_se => .up_left_down_right,
        .arrow_ne_sw => .up_right_down_left,
        .arrow_w_e => .left_right,
        .arrow_n_s => .up_down,
        .arrow_all => .all_scroll,
        .bad => .no,
        .hand => .hand,
    };
    if (self.cursor_last == pugl_cursor) return;
    self.cursor_last = pugl_cursor;
    _ = self.view.setCursor(pugl_cursor);
}

pub fn textInputRect(self: *Core, rect: ?dvui.Rect.Natural) void {
    if (std.meta.eql(rect, self.text_input_rect_last)) return;
    const was_active = self.text_input_rect_last != null;
    self.text_input_rect_last = rect;
    const r = rect orelse {
        _ = self.view.stopTextInput();
        return;
    };
    const k: f32 = if (pointer_physical) self.scale else 1;
    const area: zpugl.TextInputRect = .{
        .x = @intFromFloat(r.x * k),
        .y = @intFromFloat(r.y * k),
        .width = @intFromFloat(@max(r.w * k, 0)),
        .height = @intFromFloat(@max(r.h * k, 0)),
    };
    _ = if (was_active) self.view.setTextInputRect(area) else self.view.startTextInput(area);
}

pub fn renderPresent(_: *Core) void {}

pub fn preferredColorScheme(self: *Core) ?dvui.enums.ColorScheme {
    if (builtin.os.tag == .windows) return dvui.Backend.Common.windowsGetPreferredColorScheme();
    const dark = zpugl.backend_impl.prefersDark(self.view) orelse return null;
    return if (dark) .dark else .light;
}

pub fn prefersReducedMotion(_: *Core) bool {
    return false;
}

pub fn refresh(self: *Core) void {
    const wake: zpugl.Event = .{ .client = .{ .data1 = 0, .data2 = 0 } };
    if (self.view.sendEvent(&wake) == .unsupported) _ = self.view.obscureView();
}

pub fn resize(self: *Core, w: u32, h: u32) void {
    self.natural = .{ .w = @floatFromInt(w), .h = @floatFromInt(h) };
    self.size = self.natural.scale(self.scale, dvui.Size.Physical);
    self.fitChildView();
    if (self.gl_entered) _ = zpugl.gl.get_backend().enter(self.view, null);
}

fn fitChildView(self: *Core) void {
    const k: f32 = if (builtin.os.tag == .windows) self.scale else 1;
    _ = self.view.setSize(@intFromFloat(@round(self.natural.w * k)), @intFromFloat(@round(self.natural.h * k)));
}

pub fn backend(self: *Core) dvui.Backend {
    return dvui.Backend.init(self);
}
