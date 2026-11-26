const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
pub const Core = @import("zpugl_dvui");
pub const rules = @import("layout_rules.zig");
const zpugl = Core.zpugl;

pub const LayoutOptions = rules.Options;
pub const frame_seconds = 1.0 / 60.0;
pub const frame_ns: i128 = std.time.ns_per_s / 60;

pub const Stream = struct {
    data: []const u8,
    pos: usize = 0,
    tail: std.Random.DefaultPrng,

    pub fn init(data: []const u8) Stream {
        return .{ .data = data, .tail = .init(std.hash.Wyhash.hash(0, data)) };
    }

    fn fill(self: *Stream, buf: []u8) void {
        for (buf) |*b| {
            if (self.pos < self.data.len) {
                b.* = self.data[self.pos];
                self.pos += 1;
            } else b.* = self.tail.random().int(u8);
        }
    }

    pub fn random(self: *Stream) std.Random {
        return .init(self, fill);
    }

    pub fn done(self: *const Stream) bool {
        return self.pos >= self.data.len;
    }

    pub fn rest(self: *Stream, max: usize) []const u8 {
        const n = @min(max, self.data.len - self.pos);
        defer self.pos += n;
        return self.data[self.pos..][0..n];
    }
};

pub const FuzzOptions = struct {
    max_steps: usize = 48,
    layout: ?LayoutOptions = .{},
};

pub fn fuzz(t: anytype, input: []const u8, opts: FuzzOptions) !void {
    var stream: Stream = .init(input);
    const r = stream.random();
    var steps: usize = 0;
    while (!stream.done() and steps < opts.max_steps) : (steps += 1) {
        try fuzzStep(t, r);
        if (opts.layout) |l| try expectLayoutOk(t, l);
        try waitMs(t, randomGapMs(r));
    }
}

const max_gap_bits = 11;

pub fn randomGapMs(r: std.Random) u32 {
    const bits: u5 = r.uintAtMost(u4, max_gap_bits);
    return r.uintLessThan(u32, @as(u32, 1) << bits);
}

pub fn waitMs(t: anytype, ms: u32) !void {
    const c: *Core = t.core();
    const deadline = c.nanoTime() + @as(i128, ms) * std.time.ns_per_ms;
    try t.frame();
    while (true) {
        const left = deadline - c.nanoTime();
        if (left <= 0) return;
        if (c.sim_ns) |*ns| {
            const idle: i128 = if (c.sim_next_us) |us| @as(i128, us) * std.time.ns_per_us else left;
            if (idle > frame_ns) ns.* += @min(left, idle) - frame_ns;
        } else {
            const seconds = @as(f64, @floatFromInt(left)) / std.time.ns_per_s;
            _ = c.world.update(@min(seconds, frame_seconds));
        }
        try t.frame();
    }
}

pub fn center(t: anytype, tag: []const u8) !dvui.Point.Physical {
    const data = t.core().win.?.tags.get(tag) orelse return error.TagNotFound;
    if (!data.visible) return error.WidgetNotVisible;
    return data.rect.center();
}

fn pointerScale(t: anytype) f32 {
    return if (Core.pointer_physical) 1 else t.core().scale;
}

pub fn pointer(t: anytype, kind: enum { motion, press, release }, at: dvui.Point.Physical) void {
    const k = pointerScale(t);
    const x = at.x / k;
    const y = at.y / k;
    const b: zpugl.ButtonEvent = .{ .time = 0, .x = x, .y = y, .root_x = x, .root_y = y, .state = .{}, .button = 0 };
    _ = t.core().injectEvent(switch (kind) {
        .motion => .{ .motion = .{ .time = 0, .x = x, .y = y, .root_x = x, .root_y = y, .state = .{} } },
        .press => .{ .button_press = b },
        .release => .{ .button_release = b },
    });
}

pub fn click(t: anytype, tag: []const u8) !void {
    const at = try center(t, tag);
    pointer(t, .motion, at);
    try t.frame();
    pointer(t, .press, at);
    try t.frame();
    pointer(t, .release, at);
    try t.frame();
}

pub fn drag(t: anytype, tag: []const u8, dx: f32, dy: f32) !void {
    const from = try center(t, tag);
    const s = t.core().scale;
    const to: dvui.Point.Physical = .{ .x = from.x + dx * s, .y = from.y + dy * s };
    pointer(t, .motion, from);
    try t.frame();
    pointer(t, .press, from);
    try t.frame();
    pointer(t, .motion, to);
    try t.frame();
    pointer(t, .release, to);
    try t.frame();
}

pub fn key(t: anytype, code: dvui.enums.Key, mod: dvui.enums.Mod) !void {
    const e: zpugl.KeyEvent = .{
        .time = 0,
        .x = 0,
        .y = 0,
        .root_x = 0,
        .root_y = 0,
        .state = .{ .shift = mod.shift(), .ctrl = mod.control(), .alt = mod.alt(), .super = mod.command() },
        .keycode = 0,
        .key = keyValue(code) orelse return error.UnmappedKey,
    };
    _ = t.core().injectEvent(.{ .key_press = e });
    try t.frame();
    _ = t.core().injectEvent(.{ .key_release = e });
    try t.frame();
}

pub fn text(t: anytype, s: []const u8) !void {
    var it = (try std.unicode.Utf8View.init(s)).iterator();
    while (it.nextCodepointSlice()) |cp| {
        var e: zpugl.TextEvent = .{ .time = 0, .x = 0, .y = 0, .root_x = 0, .root_y = 0, .state = .{}, .keycode = 0, .character = 0, .string = @splat(0) };
        @memcpy(e.string[0..cp.len], cp);
        _ = t.core().injectEvent(.{ .text = e });
    }
    try t.frame();
}

pub fn scale(t: anytype, s: f32) !void {
    t.core().scale_override = s;
    _ = t.core().injectEvent(.{ .expose = .{ .x = 0, .y = 0, .width = 0, .height = 0 } });
    try t.frame();
    try t.frame();
}

pub fn focusOut(t: anytype) !void {
    _ = t.core().injectEvent(.{ .focus_out = .{ .mode = .normal } });
    try t.frame();
}

fn fuzzPoint(t: anytype, r: std.Random) dvui.Point.Physical {
    const win = &t.core().win.?;
    const size = t.core().size;
    const count = win.tags.map.count();
    if (count > 0 and r.boolean()) {
        var it = win.tags.map.valueIterator();
        var skip = r.uintLessThan(u32, count);
        while (it.next()) |tag| {
            if (skip == 0) return tag.inner.rect.center();
            skip -= 1;
        }
    }
    return .{ .x = r.float(f32) * size.w, .y = r.float(f32) * size.h };
}

pub fn fuzzStep(t: anytype, r: std.Random) !void {
    const c: *Core = t.core();
    const at = fuzzPoint(t, r);
    const k = pointerScale(t);
    const x: f64 = at.x / k;
    const y: f64 = at.y / k;
    switch (r.uintLessThan(u8, 12)) {
        0 => pointer(t, .motion, at),
        1 => pointer(t, .press, at),
        2 => pointer(t, .release, at),
        3 => _ = c.injectEvent(.{ .scroll = .{ .time = 0, .x = x, .y = y, .root_x = x, .root_y = y, .state = .{}, .direction = .smooth, .dx = r.float(f64) * 20 - 10, .dy = r.float(f64) * 20 - 10 } }),
        4 => {
            const touch: zpugl.TouchEvent = .{ .time = 0, .id = r.uintLessThan(u32, 12), .x = x, .y = y };
            _ = c.injectEvent(switch (r.uintLessThan(u8, 3)) {
                0 => .{ .touch_begin = touch },
                1 => .{ .touch_update = touch },
                else => .{ .touch_end = touch },
            });
        },
        5 => {
            const keys = comptime std.enums.values(dvui.enums.Key);
            key(t, keys[r.uintLessThan(usize, keys.len)], if (r.boolean()) .none else .lshift) catch |e| if (e != error.UnmappedKey) return e;
        },
        6 => {
            var e: zpugl.TextEvent = .{ .time = 0, .x = 0, .y = 0, .root_x = 0, .root_y = 0, .state = .{}, .keycode = 0, .character = 0, .string = @splat(0) };
            r.bytes(e.string[0..r.uintAtMost(usize, e.string.len)]);
            _ = c.injectEvent(.{ .text = e });
        },
        7 => try focusOut(t),
        8 => _ = c.injectEvent(.{ .focus_in = .{ .mode = .normal } }),
        9 => try scale(t, ([_]f32{ 1, 1.5, 2 })[r.uintLessThan(usize, 3)]),
        10 => {
            const max_w: u32 = if (c.sim_ns != null) 1280 else @intFromFloat(960 / c.scale);
            const max_h: u32 = if (c.sim_ns != null) 960 else @intFromFloat(640 / c.scale);
            std.debug.assert(max_w >= 320 and max_h >= 240);
            try t.resize(320 + r.uintAtMost(u32, max_w - 320), 240 + r.uintAtMost(u32, max_h - 240));
        },
        else => try waitMs(t, r.uintAtMost(u32, 40)),
    }
    try t.frame();
}

pub fn keyValue(code: dvui.enums.Key) ?u32 {
    if (code == .unknown) return null;
    for ([_][2]u32{ .{ 0, 0x80 }, .{ 0xE000, 0xE0B0 } }) |range| {
        for (range[0]..range[1]) |value| {
            if (Core.mapKey(@intCast(value)) == code) return @intCast(value);
        }
    }
    return null;
}

pub fn expectLayoutOk(t: anytype, opts: LayoutOptions) !void {
    const c: *Core = t.core();
    const gpa = c.allocator;
    dvui.debug.clearCaptures(gpa);
    defer dvui.debug.clearCaptures(gpa);
    dvui.debug.captureFrames(2);
    try t.frame();
    try t.frame();
    const frames = dvui.debug.frames.items;
    if (frames.len == 0) return error.NoCapturedFrame;

    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var o = opts;
    o.floor *= c.scale;
    const sizes = [_]rules.Size{.{ .w = c.size.w, .h = c.size.h, .sweep = .fixed }};
    var check: rules.Check = .{ .gpa = gpa, .arena = arena, .opts = o, .sizes = &sizes };
    defer check.deinit();
    try check.analyze(0, frames[frames.len - 1].widgets.items, &.{}, c.win.?.tab_index_prev.items);
    if (check.findings.count() == 0) return;

    var out: std.Io.Writer.Allocating = .init(arena);
    try check.print(&out.writer);
    std.debug.print("{s}", .{out.written()});
    return error.LayoutFindings;
}

pub fn screenshot(c: *Core, io: std.Io, now_ns: i128, ctx: anytype, comptime draw: fn (@TypeOf(ctx)) anyerror!void, path: []const u8) !void {
    const win = &c.win.?;
    c.in_frame = true;
    defer c.in_frame = false;
    try win.begin(now_ns);
    var picture = dvui.Picture.start(dvui.windowRectPixels()) orelse {
        _ = try win.end(.{});
        return error.Unsupported;
    };
    try draw(ctx);
    _ = win.endRendering(.{});
    picture.stop();
    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var buf: [4096]u8 = undefined;
    var w = file.writer(io, &buf);
    const lifo = dvui.currentWindow().lifo();
    const pixels = dvui.Color.PMA.sliceToRGBA(try dvui.textureReadTarget(lifo, picture.texture));
    const uniform = pixels.len < 8 or std.mem.eql(u8, pixels[4..], pixels[0 .. pixels.len - 4]);
    {
        defer lifo.free(pixels);
        try dvui.PNGEncoder.write(&w.interface, pixels, picture.texture.width, picture.texture.height);
    }
    try w.end();
    picture.deinit();
    _ = try win.end(.{});
    if (uniform) return error.ScreenshotUniform;
}
