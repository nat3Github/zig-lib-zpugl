// triangle.zig — zpugl cross-platform test harness
//
// CLI:
//   --smoke-test=N      run N expose frames then exit 0 (timeout 30s)
//   --smoke-test N      alternate form
//   --backend=NAME      gl|metal|vulkan|stub  (default: gl)
//   --headless          same as --smoke-test=10
//   --help              print usage
//
// Interactive hotkeys:
//   Esc         quit
//   Ctrl+N      open second window (max 4)
//   Ctrl+W      close focused window
//   Ctrl+C      copy frame counter to clipboard
//   Ctrl+V      paste clipboard, log result
//   Ctrl+T      toggle 1 Hz timer
//   R           request redisplay

const std = @import("std");

// 0.16: std.time.milliTimestamp gone. Inline monotonic ms via libc.
fn nowMs() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(std.posix.CLOCK.MONOTONIC, &ts) != 0) return 0;
    const s: i64 = @intCast(ts.sec);
    const ns: i64 = @intCast(ts.nsec);
    return s * 1000 + @divTrunc(ns, 1_000_000);
}
const zpugl = @import("zpugl");

// ---------------------------------------------------------------------------
// OpenGL immediate-mode extern declarations
// ---------------------------------------------------------------------------
extern fn glClear(mask: u32) void;
extern fn glClearColor(r: f32, g: f32, b: f32, a: f32) void;
extern fn glBegin(mode: u32) void;
extern fn glEnd() void;
extern fn glColor3f(r: f32, g: f32, b: f32) void;
extern fn glColor4f(r: f32, g: f32, b: f32, a: f32) void;
extern fn glVertex2f(x: f32, y: f32) void;
extern fn glRectf(x1: f32, y1: f32, x2: f32, y2: f32) void;
extern fn glMatrixMode(mode: u32) void;
extern fn glLoadIdentity() void;
extern fn glOrtho(l: f64, r: f64, b: f64, t: f64, n: f64, f: f64) void;
extern fn glViewport(x: i32, y: i32, w: i32, h: i32) void;
extern fn glPushMatrix() void;
extern fn glPopMatrix() void;
extern fn glScissor(x: i32, y: i32, w: i32, h: i32) void;
extern fn glEnable(cap: u32) void;
extern fn glDisable(cap: u32) void;

const GL_COLOR_BUFFER_BIT: u32 = 0x00004000;
const GL_TRIANGLES: u32 = 0x0004;
const GL_QUADS: u32 = 0x0007;
const GL_MODELVIEW: u32 = 0x1700;
const GL_PROJECTION: u32 = 0x1701;
const GL_SCISSOR_TEST: u32 = 0x0C11;

// ---------------------------------------------------------------------------
// 8x8 bitmap font — minimal ASCII 32..126
// Each glyph is 8 bytes, one byte per row (MSB = left pixel).
// Only printable glyphs that we actually need are hand-coded; the rest are
// spaces.  We encode A-Z (upper), 0-9, space, and common punctuation.
// ---------------------------------------------------------------------------
const FONT_FIRST: u8 = 32;
const FONT_LAST: u8 = 126;
const FONT_COUNT = FONT_LAST - FONT_FIRST + 1;

const font_data: [FONT_COUNT][8]u8 = blk: {
    var d: [FONT_COUNT][8]u8 = std.mem.zeroes([FONT_COUNT][8]u8);
    // helper: index from ASCII
    const i = struct {
        fn f(c: u8) usize {
            return c - FONT_FIRST;
        }
    }.f;

    // SPACE (32) — all zeros, already set

    // 0
    d[i('0')] = .{ 0x3C, 0x66, 0x6E, 0x76, 0x66, 0x66, 0x3C, 0x00 };
    // 1
    d[i('1')] = .{ 0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00 };
    // 2
    d[i('2')] = .{ 0x3C, 0x66, 0x06, 0x0C, 0x18, 0x30, 0x7E, 0x00 };
    // 3
    d[i('3')] = .{ 0x3C, 0x66, 0x06, 0x1C, 0x06, 0x66, 0x3C, 0x00 };
    // 4
    d[i('4')] = .{ 0x06, 0x0E, 0x1E, 0x66, 0x7F, 0x06, 0x06, 0x00 };
    // 5
    d[i('5')] = .{ 0x7E, 0x60, 0x7C, 0x06, 0x06, 0x66, 0x3C, 0x00 };
    // 6
    d[i('6')] = .{ 0x3C, 0x66, 0x60, 0x7C, 0x66, 0x66, 0x3C, 0x00 };
    // 7
    d[i('7')] = .{ 0x7E, 0x06, 0x0C, 0x18, 0x30, 0x30, 0x30, 0x00 };
    // 8
    d[i('8')] = .{ 0x3C, 0x66, 0x66, 0x3C, 0x66, 0x66, 0x3C, 0x00 };
    // 9
    d[i('9')] = .{ 0x3C, 0x66, 0x66, 0x3E, 0x06, 0x66, 0x3C, 0x00 };

    // A-Z
    d[i('A')] = .{ 0x18, 0x3C, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00 };
    d[i('B')] = .{ 0x7C, 0x66, 0x66, 0x7C, 0x66, 0x66, 0x7C, 0x00 };
    d[i('C')] = .{ 0x3C, 0x66, 0x60, 0x60, 0x60, 0x66, 0x3C, 0x00 };
    d[i('D')] = .{ 0x78, 0x6C, 0x66, 0x66, 0x66, 0x6C, 0x78, 0x00 };
    d[i('E')] = .{ 0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x7E, 0x00 };
    d[i('F')] = .{ 0x7E, 0x60, 0x60, 0x7C, 0x60, 0x60, 0x60, 0x00 };
    d[i('G')] = .{ 0x3C, 0x66, 0x60, 0x6E, 0x66, 0x66, 0x3C, 0x00 };
    d[i('H')] = .{ 0x66, 0x66, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00 };
    d[i('I')] = .{ 0x3C, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00 };
    d[i('J')] = .{ 0x1E, 0x0C, 0x0C, 0x0C, 0x0C, 0x6C, 0x38, 0x00 };
    d[i('K')] = .{ 0x66, 0x6C, 0x78, 0x70, 0x78, 0x6C, 0x66, 0x00 };
    d[i('L')] = .{ 0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x7E, 0x00 };
    d[i('M')] = .{ 0x63, 0x77, 0x7F, 0x6B, 0x63, 0x63, 0x63, 0x00 };
    d[i('N')] = .{ 0x66, 0x76, 0x7E, 0x7E, 0x6E, 0x66, 0x66, 0x00 };
    d[i('O')] = .{ 0x3C, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00 };
    d[i('P')] = .{ 0x7C, 0x66, 0x66, 0x7C, 0x60, 0x60, 0x60, 0x00 };
    d[i('Q')] = .{ 0x3C, 0x66, 0x66, 0x66, 0x6E, 0x3C, 0x06, 0x00 };
    d[i('R')] = .{ 0x7C, 0x66, 0x66, 0x7C, 0x78, 0x6C, 0x66, 0x00 };
    d[i('S')] = .{ 0x3C, 0x66, 0x60, 0x3C, 0x06, 0x66, 0x3C, 0x00 };
    d[i('T')] = .{ 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00 };
    d[i('U')] = .{ 0x66, 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x00 };
    d[i('V')] = .{ 0x66, 0x66, 0x66, 0x66, 0x66, 0x3C, 0x18, 0x00 };
    d[i('W')] = .{ 0x63, 0x63, 0x63, 0x6B, 0x7F, 0x77, 0x63, 0x00 };
    d[i('X')] = .{ 0x66, 0x66, 0x3C, 0x18, 0x3C, 0x66, 0x66, 0x00 };
    d[i('Y')] = .{ 0x66, 0x66, 0x66, 0x3C, 0x18, 0x18, 0x18, 0x00 };
    d[i('Z')] = .{ 0x7E, 0x06, 0x0C, 0x18, 0x30, 0x60, 0x7E, 0x00 };

    // a-z (map to uppercase bitmaps for simplicity)
    var c: u8 = 'a';
    while (c <= 'z') : (c += 1) {
        d[i(c)] = d[i(c - 32)];
    }

    // Punctuation
    d[i('.')] = .{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00 };
    d[i(',')] = .{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x30 };
    d[i(':')] = .{ 0x00, 0x18, 0x18, 0x00, 0x18, 0x18, 0x00, 0x00 };
    d[i('=')] = .{ 0x00, 0x00, 0x7E, 0x00, 0x7E, 0x00, 0x00, 0x00 };
    d[i('+')] = .{ 0x00, 0x18, 0x18, 0x7E, 0x18, 0x18, 0x00, 0x00 };
    d[i('-')] = .{ 0x00, 0x00, 0x00, 0x7E, 0x00, 0x00, 0x00, 0x00 };
    d[i('_')] = .{ 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7E, 0x00 };
    d[i('/')] = .{ 0x06, 0x0C, 0x18, 0x30, 0x60, 0x00, 0x00, 0x00 };
    d[i('(')] = .{ 0x0C, 0x18, 0x30, 0x30, 0x30, 0x18, 0x0C, 0x00 };
    d[i(')')] = .{ 0x30, 0x18, 0x0C, 0x0C, 0x0C, 0x18, 0x30, 0x00 };
    d[i('[')] = .{ 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00 };
    d[i(']')] = .{ 0x3C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x3C, 0x00 };
    d[i('!')] = .{ 0x18, 0x18, 0x18, 0x18, 0x00, 0x18, 0x18, 0x00 };
    d[i('<')] = .{ 0x06, 0x0C, 0x18, 0x30, 0x18, 0x0C, 0x06, 0x00 };
    d[i('>')] = .{ 0x60, 0x30, 0x18, 0x0C, 0x18, 0x30, 0x60, 0x00 };
    d[i('"')] = .{ 0x66, 0x66, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00 };
    d[i('\'')] = .{ 0x18, 0x18, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00 };
    d[i('#')] = .{ 0x36, 0x36, 0x7F, 0x36, 0x7F, 0x36, 0x36, 0x00 };
    d[i('@')] = .{ 0x3C, 0x66, 0x6E, 0x6E, 0x60, 0x62, 0x3C, 0x00 };
    d[i('%')] = .{ 0x63, 0x13, 0x18, 0x0C, 0x06, 0x31, 0x63, 0x00 };
    d[i('^')] = .{ 0x08, 0x1C, 0x36, 0x63, 0x00, 0x00, 0x00, 0x00 };
    d[i('&')] = .{ 0x1C, 0x36, 0x1C, 0x3B, 0x6E, 0x66, 0x3B, 0x00 };
    d[i('*')] = .{ 0x00, 0x66, 0x3C, 0xFF, 0x3C, 0x66, 0x00, 0x00 };
    d[i(';')] = .{ 0x00, 0x18, 0x18, 0x00, 0x18, 0x18, 0x10, 0x00 };

    break :blk d;
};

// ---------------------------------------------------------------------------
// Event log ring buffer
// ---------------------------------------------------------------------------
const LOG_COUNT = 8;
const LOG_LINE = 64;

const EventLog = struct {
    lines: [LOG_COUNT][LOG_LINE]u8 = std.mem.zeroes([LOG_COUNT][LOG_LINE]u8),
    lens: [LOG_COUNT]usize = @splat(0),
    head: usize = 0,

    fn push(self: *EventLog, comptime fmt: []const u8, args: anytype) void {
        const idx = self.head % LOG_COUNT;
        const slice = self.lines[idx][0..LOG_LINE];
        const written = std.fmt.bufPrint(slice, fmt, args) catch slice[0..LOG_LINE];
        self.lens[idx] = written.len;
        self.head +%= 1;
    }

    fn get(self: *const EventLog, age: usize) []const u8 {
        if (age >= LOG_COUNT) return "";
        const idx = (self.head +% (LOG_COUNT - age - 1)) % LOG_COUNT;
        return self.lines[idx][0..self.lens[idx]];
    }
};

// ---------------------------------------------------------------------------
// Per-view state (pre-allocated, no heap in expose handler)
// ---------------------------------------------------------------------------
const MAX_VIEWS = 4;
const HUD_LINES = 32;
const HUD_LINE_LEN = 80;

const ViewState = struct {
    view: ?*zpugl.View = null,
    frame: u64 = 0,
    width: u16 = 512,
    height: u16 = 512,
    dpi: f64 = 1.0,
    last_key: [32]u8 = std.mem.zeroes([32]u8),
    last_key_len: usize = 0,
    last_mouse_x: f64 = 0,
    last_mouse_y: f64 = 0,
    last_button: u32 = 0,
    last_scroll_dx: f64 = 0,
    last_scroll_dy: f64 = 0,
    log: EventLog = .{},
    // HUD line buffer (pre-allocated)
    hud: [HUD_LINES][HUD_LINE_LEN]u8 = std.mem.zeroes([HUD_LINES][HUD_LINE_LEN]u8),
    hud_lens: [HUD_LINES]usize = @splat(0),
    hud_count: usize = 0,
    view_id: usize = 0,
    timer_running: bool = false,
    timer_ticks: u64 = 0,
};

// ---------------------------------------------------------------------------
// Global state (static lifetime — no heap in callbacks)
// ---------------------------------------------------------------------------
var g_views: [MAX_VIEWS]ViewState = @splat(.{});
var g_view_count: usize = 0;
var g_world: ?*zpugl.World = null;
var g_backend_tag: zpugl.BackendTag = .gl;
var g_backend_name: []const u8 = "gl";

// Smoke test state
var g_smoke_frames: u64 = 0; // target frames (0 = interactive)
var g_smoke_got_expose: bool = false;
var g_smoke_frame_count: u64 = 0;
var g_smoke_start_time: i64 = 0;
var g_running: bool = true;
var g_test_ime: bool = false;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
fn find_state(view: *zpugl.View) ?*ViewState {
    for (&g_views) |*vs| {
        if (vs.view == view) return vs;
    }
    return null;
}

fn alloc_state() ?*ViewState {
    for (&g_views) |*vs| {
        if (vs.view == null) return vs;
    }
    return null;
}

fn open_window(world: *zpugl.World, id: usize) !void {
    if (g_view_count >= MAX_VIEWS) return;
    const vs = alloc_state() orelse return error.TooManyViews;

    const view = try zpugl.View.init(world, on_event);
    view.setBackend(g_backend_tag);
    _ = view.setSizeHint(.default_size, 512, 512);

    var title_buf: [64]u8 = undefined;
    const title = std.fmt.bufPrint(&title_buf, "zpugl harness [{d}]", .{id}) catch "zpugl harness";
    _ = view.setViewString(.window_title, title);

    try view.realize();
    _ = view.show(.raise);

    vs.* = ViewState{
        .view = view,
        .view_id = id,
    };
    g_view_count += 1;
}

fn close_view(vs: *ViewState) void {
    if (vs.view) |v| {
        v.unrealize() catch {};
        v.deinit();
        vs.view = null;
        if (g_view_count > 0) g_view_count -= 1;
    }
}

// ---------------------------------------------------------------------------
// 8x8 font rendering — pixel = quad, scale=1 means 1px quads
// (x, y) are pixel coords in a coordinate system where (0,0) = top-left
// and width/height are the viewport dimensions passed into ortho.
// ---------------------------------------------------------------------------
fn draw_char(c: u8, px: f32, py: f32, scale: f32) void {
    if (c < FONT_FIRST or c > FONT_LAST) return;
    const glyph = font_data[c - FONT_FIRST];
    const ps = scale; // pixel size
    glBegin(GL_QUADS);
    for (glyph, 0..) |row_bits, ry| {
        var bit: u3 = 7;
        while (true) {
            if (row_bits & (@as(u8, 1) << bit) != 0) {
                const cx = px + @as(f32, @floatFromInt(7 - bit)) * ps;
                const cy = py + @as(f32, @floatFromInt(ry)) * ps;
                glVertex2f(cx, cy);
                glVertex2f(cx + ps, cy);
                glVertex2f(cx + ps, cy + ps);
                glVertex2f(cx, cy + ps);
            }
            if (bit == 0) break;
            bit -= 1;
        }
    }
    glEnd();
}

fn draw_text(text: []const u8, px: f32, py: f32, scale: f32) void {
    var x = px;
    for (text) |c| {
        draw_char(c, x, py, scale);
        x += 9.0 * scale;
    }
}

fn draw_hud(vs: *ViewState) void {
    const w = @as(f32, @floatFromInt(vs.width));
    const h = @as(f32, @floatFromInt(vs.height));

    // Set up 2D orthographic projection in pixel space
    glMatrixMode(GL_PROJECTION);
    glPushMatrix();
    glLoadIdentity();
    glOrtho(0, w, h, 0, -1, 1); // top-left origin

    glMatrixMode(GL_MODELVIEW);
    glPushMatrix();
    glLoadIdentity();

    const scale: f32 = 1.5;
    const ch = 8.0 * scale + 2.0; // char height + padding
    const margin: f32 = 4.0;

    // Background panel
    const panel_w: f32 = 400.0;
    const panel_h: f32 = ch * @as(f32, @floatFromInt(vs.hud_count + 1)) + margin * 2.0;
    glColor4f(0.0, 0.0, 0.0, 0.6);
    glBegin(GL_QUADS);
    glVertex2f(0, 0);
    glVertex2f(panel_w, 0);
    glVertex2f(panel_w, panel_h);
    glVertex2f(0, panel_h);
    glEnd();

    glColor3f(0.0, 1.0, 0.0);
    var y: f32 = margin;
    for (0..vs.hud_count) |row| {
        draw_text(vs.hud[row][0..vs.hud_lens[row]], margin, y, scale);
        y += ch;
    }

    // Event log — right side
    const log_x: f32 = w - 500.0;
    const log_label = "--- event log ---";
    glColor3f(1.0, 1.0, 0.0);
    draw_text(log_label, log_x, margin, scale);
    var ly: f32 = margin + ch;
    for (0..LOG_COUNT) |age| {
        const line = vs.log.get(age);
        if (line.len == 0) continue;
        glColor3f(0.9, 0.9, 0.7);
        draw_text(line, log_x, ly, scale);
        ly += ch;
    }

    glMatrixMode(GL_PROJECTION);
    glPopMatrix();
    glMatrixMode(GL_MODELVIEW);
    glPopMatrix();
}

fn build_hud(vs: *ViewState) void {
    vs.hud_count = 0;

    const add = struct {
        fn f(s: *ViewState, comptime fmt: []const u8, args: anytype) void {
            if (s.hud_count >= HUD_LINES) return;
            const row = s.hud_count;
            const slice = s.hud[row][0..HUD_LINE_LEN];
            const written = std.fmt.bufPrint(slice, fmt, args) catch slice;
            s.hud_lens[row] = written.len;
            s.hud_count += 1;
        }
    }.f;

    add(vs, "View:{d} Frame:{d} Backend:{s}", .{ vs.view_id, vs.frame, g_backend_name });
    add(vs, "Size:{d}x{d} DPI:{d:.2}", .{ vs.width, vs.height, vs.dpi });
    if (vs.last_key_len > 0) {
        add(vs, "Key: {s}", .{vs.last_key[0..vs.last_key_len]});
    } else {
        add(vs, "Key: (none)", .{});
    }
    add(vs, "Mouse: ({d:.0},{d:.0}) btn={d}", .{ vs.last_mouse_x, vs.last_mouse_y, vs.last_button });
    add(vs, "Scroll: dx={d:.2} dy={d:.2}", .{ vs.last_scroll_dx, vs.last_scroll_dy });
    if (vs.timer_ticks > 0) {
        add(vs, "Timer ticks: {d}", .{vs.timer_ticks});
    }
    add(vs, "Ctrl+N=window Ctrl+W=close Ctrl+C=copy Ctrl+V=paste Ctrl+T=timer R=redraw Esc=quit", .{});
}

// ---------------------------------------------------------------------------
// Event handler
// ---------------------------------------------------------------------------
fn on_event(view: *zpugl.View, event: *const zpugl.Event) zpugl.Status {
    const vs = find_state(view) orelse return .success;

    switch (event.*) {
        .expose => |e| {
            vs.frame += 1;
            vs.width = e.width;
            vs.height = e.height;
            vs.dpi = view.getScaleFactor();

            if (g_smoke_frames > 0) {
                g_smoke_got_expose = true;
                g_smoke_frame_count += 1;
                std.debug.print("[smoke] frame={d} backend={s} view={d}\n", .{
                    g_smoke_frame_count, g_backend_name, vs.view_id,
                });
            }

            // GL-only render path. With non-GL backends (vulkan/stub/metal),
            // skip the GL calls — they would crash without a current GL context.
            if (g_backend_tag != .gl) return .success;

            // Draw background + triangle
            glViewport(0, 0, e.width, e.height);
            glClearColor(0.15, 0.15, 0.18, 1.0);
            glClear(GL_COLOR_BUFFER_BIT);

            // Set up simple [-1,1] projection for triangle
            glMatrixMode(GL_PROJECTION);
            glLoadIdentity();
            glOrtho(-1, 1, -1, 1, -1, 1);
            glMatrixMode(GL_MODELVIEW);
            glLoadIdentity();

            glBegin(GL_TRIANGLES);
            glColor3f(1.0, 0.0, 0.0);
            glVertex2f(-0.5, -0.5);
            glColor3f(0.0, 1.0, 0.0);
            glVertex2f(0.5, -0.5);
            glColor3f(0.0, 0.0, 1.0);
            glVertex2f(0.0, 0.5);
            glEnd();

            // HUD (only in interactive mode to avoid spam in smoke tests)
            if (g_smoke_frames == 0) {
                build_hud(vs);
                draw_hud(vs);
            }
        },

        .configure => |e| {
            vs.width = e.width;
            vs.height = e.height;
            vs.dpi = view.getScaleFactor();
        },

        .close => {
            vs.log.push("close view={d}", .{vs.view_id});
            if (vs.timer_running) {
                _ = view.stopTimer(0);
            }
            close_view(vs);
            if (g_view_count == 0) g_running = false;
        },

        .key_press => |e| {
            const key: zpugl.Key = blk: {
                // 0.16: std.meta.intToEnum removed. Match by tag value.
                const ki = @typeInfo(zpugl.Key).@"enum";
                inline for (ki.field_names, ki.field_values) |name, value| {
                    if (e.key == value) break :blk @field(zpugl.Key, name);
                }
                break :blk .none;
            };
            const mods = e.state;

            // Build key name string into last_key.
            // 0.16: std.io.fixedBufferStream gone; track index by hand.
            var buf: [32]u8 = undefined;
            var pos: usize = 0;
            const appendStr = struct {
                fn f(b: []u8, p: *usize, s: []const u8) void {
                    const n = @min(s.len, b.len - p.*);
                    @memcpy(b[p.* .. p.* + n], s[0..n]);
                    p.* += n;
                }
            }.f;
            if (mods.ctrl) appendStr(&buf, &pos, "CTRL+");
            if (mods.shift) appendStr(&buf, &pos, "SHIFT+");
            if (mods.alt) appendStr(&buf, &pos, "ALT+");
            if (e.key >= 32 and e.key < 127) {
                var c: u8 = @intCast(e.key);
                if (c >= 'a' and c <= 'z') c -= 32;
                if (pos < buf.len) {
                    buf[pos] = c;
                    pos += 1;
                }
            } else {
                appendStr(&buf, &pos, @tagName(key));
            }
            const written_len = pos;
            @memcpy(vs.last_key[0..written_len], buf[0..written_len]);
            vs.last_key_len = written_len;

            vs.log.push("key_press view={d} {s}", .{ vs.view_id, vs.last_key[0..vs.last_key_len] });

            // Hotkeys
            if (key == .escape) {
                g_running = false;
            }

            if (mods.ctrl) {
                const k = e.key;
                if (k == 'n' or k == 'N') {
                    // Open new window
                    const world = g_world orelse return .success;
                    open_window(world, g_view_count) catch |err| {
                        vs.log.push("open_window err={s}", .{@errorName(err)});
                    };
                } else if (k == 'w' or k == 'W') {
                    vs.log.push("closing view={d}", .{vs.view_id});
                    if (vs.timer_running) {
                        _ = view.stopTimer(0);
                        vs.timer_running = false;
                    }
                    close_view(vs);
                    if (g_view_count == 0) g_running = false;
                } else if (k == 'c' or k == 'C') {
                    // Copy frame counter
                    var cbuf: [32]u8 = undefined;
                    const ctext = std.fmt.bufPrint(&cbuf, "{d}", .{vs.frame}) catch "0";
                    const st = view.setClipboard(.general, "text/plain", ctext);
                    vs.log.push("copy frame={d} st={s}", .{ vs.frame, @tagName(st) });
                } else if (k == 'v' or k == 'V') {
                    // Paste
                    const st = view.paste();
                    vs.log.push("paste requested st={s}", .{@tagName(st)});
                } else if (k == 't' or k == 'T') {
                    if (vs.timer_running) {
                        _ = view.stopTimer(0);
                        vs.timer_running = false;
                        vs.log.push("timer stopped view={d}", .{vs.view_id});
                    } else {
                        const tst = view.startTimer(0, 1.0);
                        vs.timer_running = tst == .success;
                        vs.log.push("timer start st={s}", .{@tagName(tst)});
                    }
                }
            } else if (e.key == 'r' or e.key == 'R') {
                _ = view.obscureView();
            }
        },

        .button_press => |e| {
            vs.last_button = e.button;
            vs.last_mouse_x = e.x;
            vs.last_mouse_y = e.y;
            vs.log.push("button_press view={d} btn={d} ({d:.0},{d:.0})", .{
                vs.view_id, e.button, e.x, e.y,
            });
        },

        .button_release => |e| {
            vs.last_mouse_x = e.x;
            vs.last_mouse_y = e.y;
        },

        .motion => |e| {
            vs.last_mouse_x = e.x;
            vs.last_mouse_y = e.y;
        },

        .scroll => |e| {
            vs.last_scroll_dx = e.dx;
            vs.last_scroll_dy = e.dy;
            vs.log.push("scroll view={d} dx={d:.2} dy={d:.2}", .{
                vs.view_id, e.dx, e.dy,
            });
        },

        .timer => |e| {
            vs.timer_ticks += 1;
            vs.log.push("timer tick={d} id={d} view={d}", .{
                vs.timer_ticks, e.id, vs.view_id,
            });
        },

        .data => {
            // Clipboard data received
            const data = view.getClipboard(.general, 0) orelse "";
            var truncated: [64]u8 = undefined;
            const len = @min(data.len, 64);
            @memcpy(truncated[0..len], data[0..len]);
            vs.log.push("paste data: {s}", .{truncated[0..len]});
        },

        .realize => {
            vs.log.push("realize view={d}", .{vs.view_id});
        },

        .focus_in => {
            vs.log.push("focus_in view={d}", .{vs.view_id});
        },

        .focus_out => {
            vs.log.push("focus_out view={d}", .{vs.view_id});
        },

        else => {},
    }

    return .success;
}

// ---------------------------------------------------------------------------
// Vulkan loader (runtime dlopen). Returns true on success.
// ---------------------------------------------------------------------------
const builtin = @import("builtin");

var g_vk_loader: ?zpugl.vulkan.PFN_vkGetInstanceProcAddr = null;

// Minimal Vulkan instance bits for the smoke test. We don't need the full
// API — only enough to create an instance with the platform surface
// extension so vkCreateMetalSurfaceEXT/etc resolve.
const VkApplicationInfo = extern struct {
    sType: i32 = 0, // VK_STRUCTURE_TYPE_APPLICATION_INFO
    pNext: ?*const anyopaque = null,
    pApplicationName: ?[*:0]const u8 = null,
    applicationVersion: u32 = 0,
    pEngineName: ?[*:0]const u8 = null,
    engineVersion: u32 = 0,
    apiVersion: u32 = 0,
};
const VkInstanceCreateInfo = extern struct {
    sType: i32 = 1, // VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO
    pNext: ?*const anyopaque = null,
    flags: u32 = 0,
    pApplicationInfo: ?*const VkApplicationInfo = null,
    enabledLayerCount: u32 = 0,
    ppEnabledLayerNames: ?[*]const [*:0]const u8 = null,
    enabledExtensionCount: u32 = 0,
    ppEnabledExtensionNames: ?[*]const [*:0]const u8 = null,
};
const VK_KHR_PORTABILITY_ENUMERATION_EXT_FLAG: u32 = 0x00000001;

const PFN_vkCreateInstance = *const fn (
    pCreateInfo: *const VkInstanceCreateInfo,
    pAllocator: ?*const anyopaque,
    pInstance: *?zpugl.vulkan.VkInstance,
) callconv(.c) i32;
const PFN_vkDestroyInstance = *const fn (
    instance: zpugl.vulkan.VkInstance,
    pAllocator: ?*const anyopaque,
) callconv(.c) void;

fn vk_create_instance() ?zpugl.vulkan.VkInstance {
    const loader = g_vk_loader orelse return null;
    const create_sym = loader(null, "vkCreateInstance") orelse return null;
    const create_fn: PFN_vkCreateInstance = @ptrCast(@alignCast(create_sym));

    const exts = zpugl.vulkan.getInstanceExtensions();

    const app_info = VkApplicationInfo{
        .pApplicationName = "zpugl-triangle-smoke",
        .apiVersion = (1 << 22) | (1 << 12), // VK_API_VERSION_1_1
    };

    const ci = VkInstanceCreateInfo{
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = @intCast(exts.len),
        .ppEnabledExtensionNames = exts.ptr,
    };

    var inst: ?zpugl.vulkan.VkInstance = null;
    const r = create_fn(&ci, null, &inst);
    if (r != 0) {
        std.debug.print("[smoke] vkCreateInstance failed code={d}\n", .{r});
        return null;
    }
    return inst;
}

fn vk_destroy_instance(inst: zpugl.vulkan.VkInstance) void {
    const loader = g_vk_loader orelse return;
    const sym = loader(inst, "vkDestroyInstance") orelse return;
    const destroy_fn: PFN_vkDestroyInstance = @ptrCast(@alignCast(sym));
    destroy_fn(inst, null);
}

// ---------------------------------------------------------------------------
// IME edge-case test suite
// ---------------------------------------------------------------------------
fn run_ime_tests(view: *zpugl.View) void {
    const Case = struct { name: []const u8, passed: bool };
    var results: [7]Case = undefined;
    var n: usize = 0;

    // Helper: record result
    const pass = struct {
        fn f(cases: []Case, idx: *usize, name: []const u8, ok: bool) void {
            cases[idx.*] = .{ .name = name, .passed = ok };
            idx.* += 1;
            const tag: []const u8 = if (ok) "PASS" else "FAIL";
            std.debug.print("[ime-test] case {d}: {s} — {s}\n", .{ idx.*, name, tag });
        }
    }.f;

    // 1. stop-before-start
    {
        const st = view.stopTextInput();
        pass(&results, &n, "stop-before-start", st == .success);
    }

    // 2. set-rect-inactive
    {
        const st = view.setTextInputRect(.{ .x = 0, .y = 0, .width = 10, .height = 10 });
        pass(&results, &n, "set-rect-inactive", st == .success);
    }

    // 3. start-basic
    {
        const st = view.startTextInput(.{ .x = 10, .y = 20, .width = 100, .height = 20 });
        pass(&results, &n, "start-basic", st == .success);
    }

    // 4. set-rect-active
    {
        const st = view.setTextInputRect(.{ .x = 50, .y = 60, .width = 200, .height = 24 });
        pass(&results, &n, "set-rect-active", st == .success);
    }

    // 5. stop-active
    {
        const st = view.stopTextInput();
        pass(&results, &n, "stop-active", st == .success);
    }

    // 6. rapid-cycle (10 start/stop pairs)
    {
        var ok = true;
        for (0..10) |_| {
            const s1 = view.startTextInput(.{ .x = 0, .y = 0, .width = 100, .height = 20 });
            const s2 = view.stopTextInput();
            if (s1 != .success or s2 != .success) ok = false;
        }
        pass(&results, &n, "rapid-cycle", ok);
    }

    // 7. unrealize-while-active
    {
        var ok = true;
        const s1 = view.startTextInput(.{ .x = 5, .y = 5, .width = 80, .height = 20 });
        if (s1 != .success) ok = false;
        // unrealize (and re-realize so the view stays usable after)
        view.unrealize() catch {
            ok = false;
        };
        // re-realize so the rest of the test harness can shut down cleanly
        view.realize() catch {};
        _ = view.show(.raise);
        pass(&results, &n, "unrealize-while-active", ok);
    }

    // Summary
    var passed: usize = 0;
    for (results[0..n]) |c| {
        if (c.passed) passed += 1;
    }
    if (passed == n) {
        std.debug.print("[ime-test] PASS: {d}/{d} cases\n", .{ passed, n });
    } else {
        std.debug.print("[ime-test] FAIL: {d}/{d} cases\n", .{ passed, n });
        for (results[0..n], 1..) |c, idx| {
            if (!c.passed) {
                std.debug.print("[ime-test] FAIL: case {d} - {s}\n", .{ idx, c.name });
            }
        }
    }
}

// ---------------------------------------------------------------------------
// CLI parsing
// ---------------------------------------------------------------------------
const Args = struct {
    smoke_frames: u64 = 0, // 0 = interactive
    backend: []const u8 = "gl",
    headless: bool = false,
    help: bool = false,
    test_ime: bool = false,
};

fn parse_args(allocator: std.mem.Allocator, argv: []const [:0]const u8) !Args {
    const raw = argv;

    var result = Args{};
    var i: usize = 1;
    while (i < raw.len) : (i += 1) {
        const arg = raw[i];
        if (std.mem.startsWith(u8, arg, "--smoke-test=")) {
            result.smoke_frames = try std.fmt.parseInt(u64, arg[13..], 10);
        } else if (std.mem.eql(u8, arg, "--smoke-test")) {
            i += 1;
            if (i >= raw.len) return error.MissingArgValue;
            result.smoke_frames = try std.fmt.parseInt(u64, raw[i], 10);
        } else if (std.mem.startsWith(u8, arg, "--backend=")) {
            result.backend = try allocator.dupe(u8, arg[10..]);
        } else if (std.mem.eql(u8, arg, "--backend")) {
            i += 1;
            if (i >= raw.len) return error.MissingArgValue;
            result.backend = try allocator.dupe(u8, raw[i]);
        } else if (std.mem.eql(u8, arg, "--headless")) {
            result.headless = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            result.help = true;
        } else if (std.mem.eql(u8, arg, "--test-ime")) {
            result.test_ime = true;
        }
    }
    if (result.headless and result.smoke_frames == 0) {
        result.smoke_frames = 10;
    }
    // --test-ime without --smoke-test: run a minimal smoke pass so the view gets realized
    if (result.test_ime and result.smoke_frames == 0) {
        result.smoke_frames = 3;
    }
    return result;
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
pub fn main(init: std.process.Init.Minimal) !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    var arg_arena = std.heap.ArenaAllocator.init(allocator);
    defer arg_arena.deinit();
    const argv = try init.args.toSlice(arg_arena.allocator());

    const args = try parse_args(allocator, argv);

    if (args.help) {
        std.debug.print(
            \\Usage: zpugl-triangle [options]
            \\  --smoke-test=N     Run N expose frames then exit 0 (timeout 30s)
            \\  --smoke-test N     Same, alternate form
            \\  --backend=NAME     gl|metal|vulkan|stub  (default: gl)
            \\  --headless         Same as --smoke-test=10
            \\  --help             This message
            \\
            \\Interactive hotkeys:
            \\  Esc         Quit
            \\  Ctrl+N      Open new window (max 4)
            \\  Ctrl+W      Close focused window
            \\  Ctrl+C      Copy frame counter to clipboard
            \\  Ctrl+V      Paste clipboard
            \\  Ctrl+T      Toggle 1Hz timer
            \\  R           Request redisplay
            \\
        , .{});
        return;
    }

    // Resolve backend
    g_backend_name = args.backend;
    if (std.mem.eql(u8, args.backend, "gl")) {
        g_backend_tag = .gl;
    } else if (std.mem.eql(u8, args.backend, "stub")) {
        g_backend_tag = .stub;
    } else if (std.mem.eql(u8, args.backend, "metal")) {
        g_backend_tag = .metal;
    } else if (std.mem.eql(u8, args.backend, "vulkan")) {
        g_backend_tag = .vulkan;
        // Try to load MoltenVK / vulkan loader so the surface code can resolve
        // vkCreate*Surface*. If unavailable, gracefully skip in smoke mode.

    } else {
        std.debug.print("unknown backend '{s}' — valid: gl|metal|vulkan|stub\n", .{args.backend});
        std.process.exit(2);
    }

    g_smoke_frames = args.smoke_frames;
    g_test_ime = args.test_ime;

    // Init world
    const world = try zpugl.World.init(allocator, .program, .{});
    g_world = world;

    if (g_backend_tag == .vulkan) {
        const loader = zpugl.vulkan.Loader.init(world, null) catch {
            std.debug.print("vulkan: loader not found, skipping\n", .{});
            std.process.exit(0);
        };
        g_vk_loader = loader.getInstanceProcAddrFunc();
    }

    // Open first window
    try open_window(world, 0);

    if (g_view_count == 0) {
        std.debug.print("[smoke] FAIL: no view created\n", .{});
        std.process.exit(1);
    }

    const primary_view = g_views[0].view orelse {
        std.debug.print("[smoke] FAIL: primary view is null\n", .{});
        std.process.exit(1);
    };

    // Vulkan smoke test: end-to-end surface creation. Build a real
    // VkInstance with the platform surface extension, call zpugl's
    // createSurface, verify non-null handle, destroy, then exit.
    if (g_backend_tag == .vulkan and g_smoke_frames > 0) {
        const ctx = primary_view.getContext();
        if (ctx == null) {
            std.debug.print("[smoke] FAIL: vulkan getContext null\n", .{});
            std.process.exit(1);
        }
        std.debug.print("[smoke] vulkan ctx={?*}\n", .{ctx});

        const inst = vk_create_instance() orelse {
            std.debug.print("[smoke] FAIL: vkCreateInstance returned null\n", .{});
            std.process.exit(1);
        };
        std.debug.print("[smoke] vulkan instance created\n", .{});

        var surface: zpugl.vulkan.VkSurfaceKHR = .null_handle;
        const r = zpugl.vulkan.createSurface(g_vk_loader.?, primary_view, inst, null, &surface);
        if (r != zpugl.vulkan.VK_SUCCESS or surface == .null_handle) {
            std.debug.print("[smoke] FAIL: createSurface result={d}\n", .{r});
            vk_destroy_instance(inst);
            std.process.exit(1);
        }
        std.debug.print("[smoke] vulkan surface created handle={x}\n", .{@backingInt(surface)});

        const destroy_surface: *const fn (zpugl.vulkan.VkInstance, zpugl.vulkan.VkSurfaceKHR, ?*const anyopaque) callconv(.c) void = @ptrCast(g_vk_loader.?(inst, "vkDestroySurfaceKHR").?);
        destroy_surface(inst, surface, null);
        vk_destroy_instance(inst);
        std.debug.print("[smoke] PASS: vulkan e2e backend={s}\n", .{g_backend_name});

        if (g_test_ime) run_ime_tests(primary_view);

        for (&g_views) |*vs| {
            if (vs.view) |v| {
                v.unrealize() catch {};
                v.deinit();
                vs.view = null;
            }
        }
        world.deinit();
        std.process.exit(0);
    }

    // Smoke test mode
    if (g_smoke_frames > 0) {
        g_smoke_start_time = nowMs();
        const expose_timeout_ms: i64 = 5000;
        const total_timeout_ms: i64 = 30000;

        // Phase 1: wait for at least one expose. Drive obscureView each iter
        // so layer-hosted backends (Metal/Vulkan on macOS) get a redraw signal
        // — they don't auto-fire drawRect: the way GL views do.
        while (!g_smoke_got_expose) {
            const elapsed = nowMs() - g_smoke_start_time;
            if (elapsed > expose_timeout_ms) {
                std.debug.print("[smoke] FAIL: no expose received within 5s\n", .{});
                _ = primary_view.stopTimer(0);
                world.deinit();
                std.process.exit(1);
            }
            _ = primary_view.obscureView();
            const st = world.update(0.016);
            if (st != .success and st != .failure) {
                std.debug.print("[smoke] FAIL: world.update returned {s}\n", .{@tagName(st)});
                world.deinit();
                std.process.exit(1);
            }
        }

        // Phase 2: pump until N frames
        while (g_smoke_frame_count < g_smoke_frames) {
            const elapsed = nowMs() - g_smoke_start_time;
            if (elapsed > total_timeout_ms) {
                std.debug.print("[smoke] FAIL: only {d}/{d} frames in 30s\n", .{
                    g_smoke_frame_count, g_smoke_frames,
                });
                world.deinit();
                std.process.exit(1);
            }
            const st = world.update(0.016);
            if (st != .success and st != .failure) {
                std.debug.print("[smoke] FAIL: world.update returned {s}\n", .{@tagName(st)});
                world.deinit();
                std.process.exit(1);
            }
            // Request redraw on primary view each iteration to ensure frames keep coming
            _ = primary_view.obscureView();
        }

        // IME edge-case tests (run on the primary view before teardown)
        if (g_test_ime) {
            run_ime_tests(primary_view);
        }

        // Clean shutdown
        for (&g_views) |*vs| {
            if (vs.view) |v| {
                if (vs.timer_running) _ = v.stopTimer(0);
                v.unrealize() catch {};
                v.deinit();
                vs.view = null;
            }
        }
        world.deinit();
        std.debug.print("[smoke] PASS: {d} frames backend={s}\n", .{ g_smoke_frame_count, g_backend_name });
        std.process.exit(0);
    }

    // Interactive mode
    while (g_running) {
        const st = world.update(0.016);
        if (st != .success and st != .failure) break;

        // Request redisplay on all live views
        for (&g_views) |*vs| {
            if (vs.view) |v| {
                _ = v.obscureView();
            }
        }
    }

    // Cleanup
    for (&g_views) |*vs| {
        if (vs.view) |v| {
            if (vs.timer_running) _ = v.stopTimer(0);
            v.unrealize() catch {};
            v.deinit();
            vs.view = null;
        }
    }
    world.deinit();
}
