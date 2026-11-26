const std = @import("std");
const dvui = @import("dvui");

const Allocator = std.mem.Allocator;
pub const Widget = dvui.Debug.CapturedWidget;
const Rect = dvui.Rect.Physical;
pub const Draw = if (@hasDecl(dvui.backend, "Draw")) dvui.backend.Draw else struct { bounds: Rect, clip: ?Rect, registered: u32, parent: dvui.Id };

pub const Sweep = enum { fixed, width, height };
pub const Size = struct { w: f32, h: f32, sweep: Sweep };

const Kind = enum { unsettled, squeezed, overlap, protrusion, viewport, hit_box, paint_overflow, paint_clipped, small_range };
const Rel = enum { none, left, right, above, below, overlap };

const Loc = struct {
    file: []const u8,
    line: u32,
    name: []const u8,
    inner: []const u8 = "",

    fn dupe(l: Loc, arena: Allocator) !Loc {
        return .{ .file = l.file, .line = l.line, .name = try arena.dupe(u8, l.name), .inner = try arena.dupe(u8, l.inner) };
    }

    pub fn format(l: Loc, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.print("{s}:{d} {s}", .{ l.file, l.line, l.name });
        if (l.inner.len > 0) try w.print(" ({s})", .{l.inner});
    }
};

fn internal(file: []const u8) bool {
    return std.mem.startsWith(u8, file, "widgets/") or std.mem.eql(u8, file, "dvui.zig");
}

const Finding = struct {
    kind: Kind,
    a: Loc,
    b: ?Loc,
    detail: []const u8,
    sizes: std.ArrayList(u32) = .empty,
};

const Pair = struct { a: Loc, b: Loc, rels: []Rel };

pub const Options = struct {
    min: ?dvui.Size = null,
    max: ?dvui.Size = null,
    step: f32 = 8,
    floor: f32 = 44,
    span: f32 = 32,
    tolerance: f32 = 1,
    frames: u32 = 12,
    ignore: std.ArrayList([]const u8) = .empty,

    pub fn parse(arena: Allocator, args: []const []const u8) !Options {
        var o: Options = .{};
        var i: usize = 1;
        while (i + 1 < args.len) : (i += 1) {
            const key = args[i];
            const val = args[i + 1];
            if (std.mem.eql(u8, key, "--min")) {
                o.min = try parseSize(val);
            } else if (std.mem.eql(u8, key, "--max")) {
                o.max = try parseSize(val);
            } else if (std.mem.eql(u8, key, "--step")) {
                o.step = try std.fmt.parseFloat(f32, val);
            } else if (std.mem.eql(u8, key, "--floor")) {
                o.floor = try std.fmt.parseFloat(f32, val);
            } else if (std.mem.eql(u8, key, "--span")) {
                o.span = try std.fmt.parseFloat(f32, val);
            } else if (std.mem.eql(u8, key, "--tolerance")) {
                o.tolerance = try std.fmt.parseFloat(f32, val);
            } else if (std.mem.eql(u8, key, "--ignore")) {
                try o.ignore.append(arena, val);
            } else continue;
            i += 1;
        }
        return o;
    }

    fn parseSize(s: []const u8) !dvui.Size {
        const x = std.mem.indexOfScalar(u8, s, 'x') orelse return error.InvalidSize;
        return .{ .w = try std.fmt.parseFloat(f32, s[0..x]), .h = try std.fmt.parseFloat(f32, s[x + 1 ..]) };
    }

    fn ignored(o: Options, loc: Loc) bool {
        for (o.ignore.items) |pattern| {
            const colon = std.mem.lastIndexOfScalar(u8, pattern, ':');
            const file = if (colon) |c| pattern[0..c] else pattern;
            if (!std.mem.endsWith(u8, loc.file, file)) continue;
            const line = if (colon) |c| std.fmt.parseInt(u32, pattern[c + 1 ..], 10) catch continue else return true;
            if (line == loc.line) return true;
        }
        return false;
    }
};

pub const R = struct {
    r: Rect,
    pub fn format(s: R, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.print("[{d:.0},{d:.0} {d:.0}x{d:.0}]", .{ s.r.x, s.r.y, s.r.w, s.r.h });
    }
};

fn excess(inner: Rect, outer: Rect) f32 {
    return @max(@max(outer.x - inner.x, outer.y - inner.y), @max(inner.x + inner.w - (outer.x + outer.w), inner.y + inner.h - (outer.y + outer.h)));
}

fn intersect(a: Rect, b: Rect) Rect {
    const x = @max(a.x, b.x);
    const y = @max(a.y, b.y);
    return .{ .x = x, .y = y, .w = @max(0, @min(a.x + a.w, b.x + b.w) - x), .h = @max(0, @min(a.y + a.h, b.y + b.h) - y) };
}

fn empty(r: Rect) bool {
    return r.w <= 0 or r.h <= 0;
}

fn named(w: *const Widget, name: []const u8) bool {
    return std.mem.eql(u8, w.name orelse "", name);
}

pub const Check = struct {
    gpa: Allocator,
    arena: Allocator,
    opts: Options,
    sizes: []const Size,
    findings: std.StringArrayHashMapUnmanaged(Finding) = .empty,
    pairs: std.AutoArrayHashMapUnmanaged([2]dvui.Id, Pair) = .empty,
    reference: std.AutoHashMapUnmanaged(dvui.Id, dvui.Size) = .empty,
    index: std.AutoHashMapUnmanaged(dvui.Id, u32) = .empty,
    widgets: []const Widget = &.{},
    in_scroll: std.ArrayList(bool) = .empty,
    order: std.ArrayList(u32) = .empty,

    pub fn deinit(c: *Check) void {
        c.index.deinit(c.gpa);
        c.reference.deinit(c.gpa);
        c.in_scroll.deinit(c.gpa);
        c.order.deinit(c.gpa);
    }

    pub fn report(c: *Check, kind: Kind, size: u32, a: Loc, b: ?Loc, comptime fmt: []const u8, args: anytype) !void {
        if (c.opts.ignored(a) or (b != null and c.opts.ignored(b.?))) return;
        var buf: [1024]u8 = undefined;
        const bl: Loc = if (kind == .paint_overflow or b == null) .{ .file = "", .line = 0, .name = "" } else b.?;
        const key = std.fmt.bufPrint(&buf, "{s}|{s}:{d}|{s}:{d}", .{ @tagName(kind), a.file, a.line, bl.file, bl.line }) catch return error.KeyTooLong;
        const gop = try c.findings.getOrPut(c.arena, key);
        if (!gop.found_existing) {
            gop.key_ptr.* = try c.arena.dupe(u8, key);
            gop.value_ptr.* = .{
                .kind = kind,
                .a = try a.dupe(c.arena),
                .b = if (b) |l| try l.dupe(c.arena) else null,
                .detail = try std.fmt.allocPrint(c.arena, fmt, args),
            };
        }
        const list = &gop.value_ptr.sizes;
        if (list.items.len == 0 or list.items[list.items.len - 1] != size) try list.append(c.arena, size);
    }

    fn parentOf(c: *Check, widgets: []const Widget, i: usize) ?u32 {
        if (widgets[i].parent_id == widgets[i].id) return null;
        return c.index.get(widgets[i].parent_id);
    }

    pub fn loc(c: *Check, i: usize) Loc {
        const w = &c.widgets[i];
        var at = i;
        while (internal(c.widgets[at].src_file)) at = c.parentOf(c.widgets, at) orelse break;
        const u = &c.widgets[at];
        return .{ .file = u.src_file, .line = u.src_line, .name = u.name orelse "", .inner = if (at == i) "" else w.name orelse "" };
    }

    pub fn analyze(c: *Check, si: u32, widgets: []const Widget, draws: []const Draw, tabs: []const dvui.TabIndex) !void {
        const size = c.sizes[si];
        const tol = c.opts.tolerance;
        c.widgets = widgets;
        c.index.clearRetainingCapacity();
        c.in_scroll.clearRetainingCapacity();
        for (widgets, 0..) |w, i| {
            try c.index.put(c.gpa, w.id, @intCast(i));
            const p = c.parentOf(widgets, i);
            try c.in_scroll.append(c.gpa, if (p) |pi| c.in_scroll.items[pi] or named(&widgets[pi], "ScrollContainer") else false);
        }

        const view: Rect = .{ .x = 0, .y = 0, .w = size.w, .h = size.h };
        const first = c.reference.count() == 0;
        for (widgets, 0..) |*w, i| {
            const r = w.rect_border;
            if (first) {
                try c.reference.put(c.gpa, w.id, .{ .w = r.w, .h = r.h });
            } else if (!c.in_scroll.items[i] and w.parent_id != w.id) if (c.reference.get(w.id)) |ref| {
                const narrower = !w.expand.isHorizontal() and w.expand != .ratio and ref.w - r.w > tol and r.h <= ref.h + tol;
                const shorter = !w.expand.isVertical() and w.expand != .ratio and ref.h - r.h > tol and r.w <= ref.w + tol;
                if (narrower or shorter)
                    try c.report(.squeezed, si, c.loc(i), null, "{d:.0}x{d:.0}, {d:.0}x{d:.0} at the default size", .{ r.w, r.h, ref.w, ref.h });
            };
            if (empty(w.rect_border)) continue;
            if (!c.in_scroll.items[i] and excess(w.rect_border, view) > tol)
                try c.report(.viewport, si, c.loc(i), null, "{f} outside the {d}x{d} window", .{ R{ .r = w.rect_border }, size.w, size.h });
            const pi = c.parentOf(widgets, i) orelse continue;
            const p = &widgets[pi];
            if (named(p, "ScrollContainer") or p.subwindow_id != w.subwindow_id) continue;
            if (excess(w.rect_border, p.rect_content) > tol)
                try c.report(.protrusion, si, c.loc(i), c.loc(pi), "child {f} outside parent content {f}", .{ R{ .r = w.rect_border }, R{ .r = p.rect_content } });
        }

        c.order.clearRetainingCapacity();
        for (0..widgets.len) |i| try c.order.append(c.gpa, @intCast(i));
        std.mem.sort(u32, c.order.items, widgets, struct {
            fn less(ws: []const Widget, a: u32, b: u32) bool {
                const pa = @backingInt(ws[a].parent_id);
                const pb = @backingInt(ws[b].parent_id);
                return if (pa != pb) pa < pb else a < b;
            }
        }.less);
        var start: usize = 0;
        while (start < c.order.items.len) {
            var end = start + 1;
            const parent = widgets[c.order.items[start]].parent_id;
            while (end < c.order.items.len and widgets[c.order.items[end]].parent_id == parent) end += 1;
            const group = c.order.items[start..end];
            start = end;
            const stacked = if (c.index.get(parent)) |pi| named(&widgets[pi], "Overlay") else false;
            for (group, 0..) |ai, gi| for (group[gi + 1 ..]) |bi| {
                const a = &widgets[ai];
                const b = &widgets[bi];
                if (a.id == parent or b.id == parent) continue;
                if (empty(a.rect_border) or empty(b.rect_border) or a.subwindow_id != b.subwindow_id) continue;
                if (size.sweep != .fixed) try c.relate(si, ai, bi);
                if (stacked) continue;
                const ov = intersect(a.rect_border, b.rect_border);
                if (ov.w > tol and ov.h > tol)
                    try c.report(.overlap, si, c.loc(ai), c.loc(bi), "{f} and {f} share {d:.0}x{d:.0}", .{ R{ .r = a.rect_border }, R{ .r = b.rect_border }, ov.w, ov.h });
            };
        }

        for (draws) |d| {
            const pi = c.index.get(d.parent) orelse continue;
            const vis = if (d.clip) |cl| intersect(d.bounds, cl) else d.bounds;
            if (empty(vis)) continue;
            var owner = pi;
            if (d.registered > 0) {
                const li = d.registered - 1;
                const l = &widgets[li];
                const touches = !empty(intersect(vis, l.rect_border));
                const encloses = excess(l.rect_border, vis) <= 0;
                if (l.id == d.parent or (l.parent_id == d.parent and touches and !encloses)) owner = li;
            }
            const o = &widgets[owner];
            if (excess(d.bounds, o.rect_border) <= tol) continue;
            if (excess(vis, o.rect_border) <= tol) {
                try c.report(.paint_clipped, si, c.loc(owner), null, "paints {f}, rect {f}, clipped to {f}", .{ R{ .r = d.bounds }, R{ .r = o.rect_border }, R{ .r = d.clip.? } });
                continue;
            }
            var onto: ?Loc = null;
            for (widgets, 0..) |*s, i| {
                if (i == owner or s.parent_id != o.parent_id or s.subwindow_id != o.subwindow_id) continue;
                const hit = intersect(vis, s.rect_border);
                if (hit.w > tol and hit.h > tol) {
                    onto = c.loc(i);
                    break;
                }
            }
            try c.report(.paint_overflow, si, c.loc(owner), onto, "paints {f} outside its rect {f}", .{ R{ .r = vis }, R{ .r = o.rect_border } });
        }

        for (tabs) |ti| {
            if (ti.tab_group) continue;
            const wi = c.index.get(ti.widgetId) orelse continue;
            const w = &widgets[wi];
            if (!w.visible) continue;
            const r = ti.rect orelse w.rect_border;
            if (r.w + 0.01 < c.opts.floor or r.h + 0.01 < c.opts.floor)
                try c.report(.hit_box, si, c.loc(wi), null, "hit box {d:.0}x{d:.0} below the {d}px floor", .{ r.w, r.h, c.opts.floor });
        }
    }

    fn relate(c: *Check, si: u32, ai: u32, bi: u32) !void {
        const a = &c.widgets[ai];
        const b = &c.widgets[bi];
        const tol = c.opts.tolerance;
        const ra = a.rect_border;
        const rb = b.rect_border;
        const rel: Rel = if (ra.x + ra.w <= rb.x + tol) .left else if (rb.x + rb.w <= ra.x + tol) .right else if (ra.y + ra.h <= rb.y + tol) .above else if (rb.y + rb.h <= ra.y + tol) .below else .overlap;
        const gop = try c.pairs.getOrPut(c.arena, .{ a.id, b.id });
        if (!gop.found_existing) {
            const rels = try c.arena.alloc(Rel, c.sizes.len);
            @memset(rels, .none);
            gop.value_ptr.* = .{ .a = try c.loc(ai).dupe(c.arena), .b = try c.loc(bi).dupe(c.arena), .rels = rels };
        }
        gop.value_ptr.rels[si] = rel;
    }

    pub fn smallRanges(c: *Check) !void {
        for (c.pairs.values()) |pair| {
            var i: usize = 0;
            while (i < c.sizes.len) {
                var j = i;
                while (j + 1 < c.sizes.len and c.sizes[j + 1].sweep == c.sizes[i].sweep and pair.rels[j + 1] == pair.rels[i]) j += 1;
                defer i = j + 1;
                const v = pair.rels[i];
                const sweep = c.sizes[i].sweep;
                if (v == .none or sweep == .fixed) continue;
                if (i == 0 or c.sizes[i - 1].sweep != sweep or j + 1 >= c.sizes.len or c.sizes[j + 1].sweep != sweep) continue;
                if (pair.rels[i - 1] == .none or pair.rels[j + 1] == .none) continue;
                const span = c.dim(j) - c.dim(i) + c.opts.step;
                if (span >= c.opts.span) continue;
                for (i..j + 1) |k| try c.report(.small_range, @intCast(k), pair.a, pair.b, "\"{s} is {s} {s}\" holds for {d}px only ({s} → {s} around it)", .{ pair.a.name, @tagName(v), pair.b.name, span, @tagName(pair.rels[i - 1]), @tagName(pair.rels[j + 1]) });
            }
        }
    }

    fn dim(c: *Check, i: usize) f32 {
        return if (c.sizes[i].sweep == .height) c.sizes[i].h else c.sizes[i].w;
    }

    pub fn print(c: *Check, out: *std.Io.Writer) !void {
        const Sort = struct {
            map: *std.StringArrayHashMapUnmanaged(Finding),
            pub fn lessThan(s: @This(), a: usize, b: usize) bool {
                const fa = s.map.values()[a];
                const fb = s.map.values()[b];
                if (fa.kind != fb.kind) return @backingInt(fa.kind) < @backingInt(fb.kind);
                return fa.sizes.items[0] < fb.sizes.items[0];
            }
        };
        c.findings.sort(Sort{ .map = &c.findings });
        for (c.findings.values()) |f| {
            try out.print("{s:<15}{f}", .{ @tagName(f.kind), f.a });
            if (f.b) |b| try out.print("  ×  {f}", .{b});
            try out.print("\n               {d} size(s): ", .{f.sizes.items.len});
            try c.printSizes(out, f.sizes.items);
            const first = c.sizes[f.sizes.items[0]];
            try out.print("\n               at {d}x{d}: {s}\n", .{ first.w, first.h, f.detail });
        }
    }

    fn printSizes(c: *Check, out: *std.Io.Writer, list: []const u32) !void {
        var i: usize = 0;
        var ranges: usize = 0;
        while (i < list.len) : (ranges += 1) {
            var j = i;
            const s = c.sizes[list[i]];
            while (j + 1 < list.len and s.sweep != .fixed and list[j + 1] == list[j] + 1 and c.sizes[list[j + 1]].sweep == s.sweep) j += 1;
            defer i = j + 1;
            if (ranges == 8) {
                try out.print(", …", .{});
                return;
            }
            if (ranges > 0) try out.writeAll(", ");
            const e = c.sizes[list[j]];
            if (i == j) {
                try out.print("{d}x{d}", .{ s.w, s.h });
            } else if (s.sweep == .width) {
                try out.print("{d}..{d}x{d}", .{ s.w, e.w, s.h });
            } else {
                try out.print("{d}x{d}..{d}", .{ s.w, s.h, e.h });
            }
        }
    }
};

pub fn sameLayout(a: []const Widget, b: []const Widget) ?usize {
    if (a.len != b.len) return @min(a.len, b.len);
    for (a, b, 0..) |x, y, i| {
        if (x.id != y.id or !std.meta.eql(x.rect_border, y.rect_border)) return i;
    }
    return null;
}
