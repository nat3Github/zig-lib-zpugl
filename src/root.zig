const std = @import("std");
const builtin = @import("builtin");
const backend = if (builtin.abi.isAndroid()) @import("backend/android.zig") else switch (builtin.os.tag) {
    .macos => @import("backend/macos.zig"),
    .ios => @import("backend/uikit.zig"),
    .windows => @import("backend/win32.zig"),
    else => @import("backend/x11.zig"),
};

pub const gl = @import("backend/gl.zig");
pub const objc = if (builtin.os.tag.isDarwin()) @import("objc") else void;

pub const backend_impl = backend;

// --- Types ---

pub const Coord = i16;
pub const Span = u16;

pub const Point = struct {
    x: Coord,
    y: Coord,
};

pub const Area = struct {
    width: Span,
    height: Span,
};

pub const EventType = enum(u32) {
    nothing,
    realize,
    unrealize,
    configure,
    update,
    expose,
    close,
    focus_in,
    focus_out,
    key_press,
    key_release,
    text,
    pointer_in,
    pointer_out,
    button_press,
    button_release,
    motion,
    scroll,
    client,
    timer,
    loop_enter,
    loop_leave,
    data_offer,
    data,
    touch_begin,
    touch_update,
    touch_end,
};

pub const EventFlags = packed struct(u32) {
    is_send_event: bool = false,
    is_hint: bool = false,
    _reserved: u30 = 0,
};

pub const ViewStyleFlags = packed struct(u32) {
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

pub const ConfigureEvent = struct {
    flags: EventFlags = .{},
    x: Coord,
    y: Coord,
    width: Span,
    height: Span,
    style: ViewStyleFlags,
};

pub const ExposeEvent = struct {
    flags: EventFlags = .{},
    x: Coord,
    y: Coord,
    width: Span,
    height: Span,
};

pub const Key = enum(u32) {
    none = 0,
    backspace = 0x0008,
    tab = 0x0009,
    enter = 0x000D,
    escape = 0x001B,
    delete = 0x007F,
    space = 0x0020,
    f1 = 0xE000,
    f2 = 0xE001,
    f3 = 0xE002,
    f4 = 0xE003,
    f5 = 0xE004,
    f6 = 0xE005,
    f7 = 0xE006,
    f8 = 0xE007,
    f9 = 0xE008,
    f10 = 0xE009,
    f11 = 0xE00A,
    f12 = 0xE00B,
    page_up = 0xE031,
    page_down = 0xE032,
    end = 0xE033,
    home = 0xE034,
    left = 0xE035,
    up = 0xE036,
    right = 0xE037,
    down = 0xE038,
    print_screen = 0xE041,
    insert = 0xE042,
    pause = 0xE043,
    menu = 0xE044,
    num_lock = 0xE045,
    scroll_lock = 0xE046,
    caps_lock = 0xE047,
    shift_l = 0xE051,
    shift_r = 0xE052,
    ctrl_l = 0xE053,
    ctrl_r = 0xE054,
    alt_l = 0xE055,
    alt_r = 0xE056,
    super_l = 0xE057,
    super_r = 0xE058,
    pad_0 = 0xE060,
    pad_1 = 0xE061,
    pad_2 = 0xE062,
    pad_3 = 0xE063,
    pad_4 = 0xE064,
    pad_5 = 0xE065,
    pad_6 = 0xE066,
    pad_7 = 0xE067,
    pad_8 = 0xE068,
    pad_9 = 0xE069,
    pad_enter = 0xE070,
    pad_multiply = 0xE0AA,
    pad_add = 0xE0AB,
    pad_separator = 0xE0AC,
    pad_subtract = 0xE0AD,
    pad_decimal = 0xE0AE,
    pad_divide = 0xE0AF,
    pad_page_up = 0xE071,
    pad_page_down = 0xE072,
    pad_end = 0xE073,
    pad_home = 0xE074,
    pad_left = 0xE075,
    pad_up = 0xE076,
    pad_right = 0xE077,
    pad_down = 0xE078,
    pad_clear = 0xE09D,
    pad_insert = 0xE09E,
    pad_delete = 0xE09F,
    pad_equal = 0xE0A0,
};

pub const Mods = packed struct(u32) {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    super: bool = false,
    num_lock: bool = false,
    scroll_lock: bool = false,
    caps_lock: bool = false,
    _reserved: u25 = 0,
};

pub const CrossingMode = enum(u32) {
    normal,
    grab,
    ungrab,
};

pub const FocusEvent = struct {
    flags: EventFlags = .{},
    mode: CrossingMode,
};

pub const KeyEvent = struct {
    flags: EventFlags = .{},
    time: f64,
    x: f64,
    y: f64,
    root_x: f64,
    root_y: f64,
    state: Mods,
    keycode: u32,
    key: u32,
};

pub const TextEvent = struct {
    flags: EventFlags = .{},
    time: f64,
    x: f64,
    y: f64,
    root_x: f64,
    root_y: f64,
    state: Mods,
    keycode: u32,
    character: u32,
    string: [8]u8,
};

pub const ScrollDirection = enum(u32) {
    up,
    down,
    left,
    right,
    smooth,
};

pub const CrossingEvent = struct {
    flags: EventFlags = .{},
    time: f64,
    x: f64,
    y: f64,
    root_x: f64,
    root_y: f64,
    state: Mods,
    mode: CrossingMode,
};

pub const ButtonEvent = struct {
    flags: EventFlags = .{},
    time: f64,
    x: f64,
    y: f64,
    root_x: f64,
    root_y: f64,
    state: Mods,
    button: u32,
};

pub const MotionEvent = struct {
    flags: EventFlags = .{},
    time: f64,
    x: f64,
    y: f64,
    root_x: f64,
    root_y: f64,
    state: Mods,
};

pub const ScrollEvent = struct {
    flags: EventFlags = .{},
    time: f64,
    x: f64,
    y: f64,
    root_x: f64,
    root_y: f64,
    state: Mods,
    direction: ScrollDirection,
    dx: f64,
    dy: f64,
};

pub const ClientEvent = struct {
    flags: EventFlags = .{},
    data1: usize,
    data2: usize,
};

pub const TimerEvent = struct {
    flags: EventFlags = .{},
    id: usize,
};

pub const TextInputRect = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
};

pub const Clipboard = enum(u32) {
    general,
    drag,
};

pub const DataAction = enum(u32) {
    copy,
    link,
    move,
    private,
};

pub const DataOfferEvent = struct {
    flags: EventFlags = .{},
    time: f64,
    x: f64,
    y: f64,
    clipboard: Clipboard,
};

pub const DataEvent = struct {
    flags: EventFlags = .{},
    time: f64,
    x: f64,
    y: f64,
    clipboard: Clipboard,
    type_index: u32,
};

pub const TouchEvent = struct {
    flags: EventFlags = .{},
    time: f64,
    id: u32,
    x: f64,
    y: f64,
};

pub const Event = union(EventType) {
    nothing: void,
    realize: void,
    unrealize: void,
    configure: ConfigureEvent,
    update: void,
    expose: ExposeEvent,
    close: void,
    focus_in: FocusEvent,
    focus_out: FocusEvent,
    key_press: KeyEvent,
    key_release: KeyEvent,
    text: TextEvent,
    pointer_in: CrossingEvent,
    pointer_out: CrossingEvent,
    button_press: ButtonEvent,
    button_release: ButtonEvent,
    motion: MotionEvent,
    scroll: ScrollEvent,
    client: ClientEvent,
    timer: TimerEvent,
    loop_enter: void,
    loop_leave: void,
    data_offer: DataOfferEvent,
    data: DataEvent,
    touch_begin: TouchEvent,
    touch_update: TouchEvent,
    touch_end: TouchEvent,
};

pub const Status = enum(u32) {
    success,
    failure,
    unknown_error,
    bad_backend,
    bad_configuration,
    bad_parameter,
    bad_call,
    backend_failed,
    registration_failed,
    realize_failed,
    set_format_failed,
    create_context_failed,
    unsupported,
    no_memory,
};

pub const WorldType = enum(u32) {
    program,
    module,
};

pub const WorldFlags = packed struct(u32) {
    threads: bool = false,
    _reserved: u31 = 0,
};

pub const StringHint = enum(u32) {
    application_name,
    class_name,
    window_title,
};

pub const ViewHint = enum(u32) {
    context_api,
    context_version_major,
    context_version_minor,
    context_profile,
    context_debug,
    red_bits,
    green_bits,
    blue_bits,
    alpha_bits,
    depth_bits,
    stencil_bits,
    sample_buffers,
    samples,
    double_buffer,
    swap_interval,
    resizable,
    ignore_key_repeat,
    refresh_rate,
    view_type,
    dark_frame,
    accept_drop,
};

pub const ViewHintValue = enum(i32) {
    dont_care = -1,
    false = 0,
    true = 1,
    opengl_api = 2,
    opengl_es_api = 3,
    opengl_core_profile = 4,
    opengl_compatibility_profile = 5,
};

pub const ViewType = enum(u32) {
    normal,
    utility,
    dialog,
};

pub const SizeHint = enum(u32) {
    default_size,
    current_size,
    min_size,
    max_size,
    fixed_aspect,
    min_aspect,
    max_aspect,
};

pub const PositionHint = enum(u32) {
    default_position,
    current_position,
};

pub const ShowCommand = enum(u32) {
    passive,
    raise,
    force_raise,
};

pub const Cursor = enum(u32) {
    arrow,
    caret,
    crosshair,
    hand,
    no,
    left_right,
    up_down,
    up_left_down_right,
    up_right_down_left,
    all_scroll,
};

pub const BackendTag = enum { gl, stub, metal, vulkan };

pub const vulkan = @import("backend/vulkan.zig");

pub const GraphicsBackend = struct {
    configure: *const fn (view: ?*anyopaque) Status,
    create: *const fn (view: ?*anyopaque) Status,
    destroy: *const fn (view: ?*anyopaque) void,
    enter: *const fn (view: ?*anyopaque, expose: ?*const ExposeEvent) Status,
    leave: *const fn (view: ?*anyopaque, expose: ?*const ExposeEvent) Status,
    get_context: *const fn (view: ?*anyopaque) ?*anyopaque,
};

pub const EventFunc = *const fn (*View, *const Event) Status;

// --- World ---

const ViewList = std.ArrayListUnmanaged(*View);
const ViewMap = std.AutoHashMapUnmanaged(usize, *View);
const string_hint_count = 3;

pub const World = struct {
    allocator: std.mem.Allocator,
    impl: ?*anyopaque = null,
    handle: ?*anyopaque = null,
    user_data: ?*anyopaque = null,
    start_time: f64 = 0,
    views: ViewList = .empty,
    view_map: ViewMap = .empty,
    type: WorldType,
    flags: WorldFlags = .{},
    strings: [string_hint_count]?[]u8 = @splat(null),

    pub fn init(allocator: std.mem.Allocator, world_type: WorldType, flags: WorldFlags) !*World {
        const self = try allocator.create(World);
        self.* = .{
            .allocator = allocator,
            .type = world_type,
            .flags = flags,
        };
        return self;
    }

    pub fn deinit(self: *World) void {
        const allocator = self.allocator;
        for (self.strings) |s| {
            if (s) |str| allocator.free(str);
        }
        self.views.deinit(allocator);
        self.view_map.deinit(allocator);
        backend.deinitWorld(self);
        allocator.destroy(self);
    }

    pub fn setHandle(self: *World, handle: *anyopaque) void {
        self.handle = handle;
    }

    pub fn getHandle(self: *World) ?*anyopaque {
        return self.handle;
    }

    pub fn getNativeWorld(self: *World) ?*anyopaque {
        return backend.getNativeWorld(self);
    }

    pub fn setString(self: *World, key: StringHint, value: []const u8) Status {
        const allocator = self.allocator;
        const idx = @backingInt(key);
        if (self.strings[idx]) |old| allocator.free(old);
        self.strings[idx] = allocator.dupe(u8, value) catch return .no_memory;
        return .success;
    }

    pub fn getString(self: *World, key: StringHint) []const u8 {
        const idx = @backingInt(key);
        return self.strings[idx] orelse "";
    }

    pub fn getTime(self: *World) f64 {
        return backend.getTime(self);
    }

    pub fn update(self: *World, timeout: f64) Status {
        return backend.update(self, timeout);
    }

    pub fn startTimer(self: *World, view: *View, id: usize, timeout: f64) Status {
        return backend.startTimer(self, view, id, timeout);
    }

    pub fn stopTimer(self: *World, view: *View, id: usize) Status {
        return backend.stopTimer(self, view, id);
    }

    pub fn watchFile(self: *World, fd: i32, user_data: ?*anyopaque, callback: *const fn (fd: c_int, user_data: ?*anyopaque) void) Status {
        if (@hasDecl(backend, "watchFD")) {
            return backend.watchFD(self, fd, user_data, callback);
        }
        return .unsupported;
    }

    pub fn unwatchFile(self: *World, fd: i32) Status {
        if (@hasDecl(backend, "watchFD")) {
            return backend.unwatchFD(self, fd);
        }
        return .unsupported;
    }
};

// --- View ---

pub const hint_count = 21;
pub const hint_dont_care: i32 = -1;
pub const size_hint_count = 7;
pub const pos_hint_count = 2;

pub const NativeView = usize;

pub const View = struct {
    world: *World,
    handle: ?*anyopaque = null,
    parent: NativeView = 0,
    transient_parent: NativeView = 0,
    user_data: ?*anyopaque = null,
    event_func: ?EventFunc = null,
    graphics_backend: BackendTag = .stub,
    hints: [hint_count]i32 = @splat(hint_dont_care),
    size_hints: [size_hint_count]Area = @splat(.{ .width = 0, .height = 0 }),
    pos_hints: [pos_hint_count]Point = @splat(.{ .x = std.math.minInt(i16), .y = std.math.minInt(i16) }),
    strings: [string_hint_count]?[]u8 = @splat(null),
    style: ViewStyleFlags = .{},
    visible: bool = false,
    gl_context: usize = 0,
    impl: ?*anyopaque = null, // backend-private state (e.g. win32 ViewImpl)

    pub fn init(world: *World, event_func: EventFunc) !*View {
        const allocator = world.allocator;
        const self = try allocator.create(View);
        self.* = .{
            .world = world,
            .event_func = event_func,
        };
        try world.views.append(allocator, self);
        return self;
    }

    pub fn deinit(self: *View) void {
        const allocator = self.world.allocator;
        if (self.handle != null) {
            self.unrealize() catch {};
        }
        for (self.strings) |s| {
            if (s) |str| allocator.free(str);
        }
        for (self.world.views.items, 0..) |v, i| {
            if (v == self) {
                _ = self.world.views.orderedRemove(i);
                break;
            }
        }
        allocator.destroy(self);
    }

    pub fn setHandle(self: *View, handle: *anyopaque) void {
        self.user_data = handle;
    }

    pub fn getHandle(self: *View) ?*anyopaque {
        return self.user_data;
    }

    pub fn setBackend(self: *View, tag: BackendTag) void {
        self.graphics_backend = tag;
    }

    pub fn setHint(self: *View, hint: ViewHint, value: i32) Status {
        self.hints[@backingInt(hint)] = value;
        return .success;
    }

    pub fn getHint(self: *View, hint: ViewHint) i32 {
        return self.hints[@backingInt(hint)];
    }

    pub fn setParent(self: *View, parent: NativeView) void {
        self.parent = parent;
    }

    pub fn getParent(self: *View) NativeView {
        return self.parent;
    }

    pub fn setTransientParent(self: *View, parent: NativeView) Status {
        if (self.parent != 0) return .failure;
        self.transient_parent = parent;
        if (self.handle == null) return .success;
        if (@hasDecl(backend, "setTransientParent")) {
            return backend.setTransientParent(self, parent);
        }
        return .success;
    }

    pub fn getTransientParent(self: *View) NativeView {
        return self.transient_parent;
    }

    pub fn realize(self: *View) !void {
        if (self.handle != null) return error.AlreadyRealized;
        const s = backend.createView(self);
        if (s != .success) return error.RealizeFailed;
        errdefer {
            backend.destroyView(self);
            self.handle = null;
        }

        switch (self.graphics_backend) {
            .gl => {
                const s_gl = gl.create(self);
                if (s_gl != .success) return error.CreateContextFailed;
            },
            .metal => {
                const s_m = @import("backend/metal.zig").get_backend().create(self);
                if (s_m != .success) return error.CreateContextFailed;
            },
            .vulkan => {
                const s_v = vulkan.get_backend().create(self);
                if (s_v != .success) return error.CreateContextFailed;
            },
            .stub => {},
        }

        try self.world.view_map.put(self.world.allocator, @intFromPtr(self.handle.?), self);
        _ = common.dispatchSimpleEvent(self, .realize);
        if (@hasDecl(backend, "realized")) backend.realized(self);
    }

    pub fn unrealize(self: *View) !void {
        if (self.handle == null) return error.NotRealized;
        _ = common.dispatchSimpleEvent(self, .unrealize);
        if (self.handle) |h| {
            _ = self.world.view_map.remove(@intFromPtr(h));
        }
        if (self.graphics_backend == .gl) gl.destroy(self);
        if (self.graphics_backend == .metal) @import("backend/metal.zig").get_backend().destroy(self);
        if (self.graphics_backend == .vulkan) vulkan.get_backend().destroy(self);
        backend.destroyView(self);
        self.handle = null;
        self.visible = false;
    }

    pub fn show(self: *View, command: ShowCommand) Status {
        if (self.handle == null) return .bad_call;
        return backend.showView(self, command);
    }

    pub fn hide(self: *View) Status {
        if (self.handle == null) return .bad_call;
        return backend.hideView(self);
    }

    pub fn setSize(self: *View, width: u32, height: u32) Status {
        self.size_hints[@backingInt(SizeHint.default_size)] = .{
            .width = @intCast(@min(width, std.math.maxInt(u16))),
            .height = @intCast(@min(height, std.math.maxInt(u16))),
        };
        if (self.handle == null) return .bad_call;
        return backend.setViewSize(self, width, height);
    }

    /// Move a realized view to (x, y) within its parent. For embedded child
    /// views; top-left coordinates.
    pub fn setPosition(self: *View, x: i32, y: i32) Status {
        if (self.handle == null) return .bad_call;
        return backend.setViewPosition(self, x, y);
    }

    pub fn getWindowPosition(self: *View) ?Point {
        if (self.handle == null or self.parent != 0) return null;
        if (@hasDecl(backend, "getWindowPosition")) return backend.getWindowPosition(self);
        return null;
    }

    pub fn getSizeHint(self: *View, hint: SizeHint) Area {
        return self.size_hints[@backingInt(hint)];
    }

    pub fn setSizeHint(self: *View, hint: SizeHint, width: u32, height: u32) Status {
        if (hint == .current_size) return if (self.handle == null) .failure else backend.setViewSize(self, width, height);
        self.size_hints[@backingInt(hint)] = .{
            .width = @intCast(@min(width, std.math.maxInt(u16))),
            .height = @intCast(@min(height, std.math.maxInt(u16))),
        };
        if (self.handle != null) return backend.applySizeHints(self);
        return .success;
    }

    pub fn getPositionHint(self: *View, hint: PositionHint) Point {
        return self.pos_hints[@backingInt(hint)];
    }

    pub fn setPositionHint(self: *View, hint: PositionHint, x: i32, y: i32) Status {
        if (hint == .current_position) return if (self.handle == null) .failure else backend.setViewPosition(self, x, y);
        self.pos_hints[@backingInt(hint)] = .{
            .x = @intCast(std.math.clamp(x, std.math.minInt(i16), std.math.maxInt(i16))),
            .y = @intCast(std.math.clamp(y, std.math.minInt(i16), std.math.maxInt(i16))),
        };
        return .success;
    }

    pub fn setViewString(self: *View, key: StringHint, value: []const u8) Status {
        const allocator = self.world.allocator;
        const idx = @backingInt(key);
        if (self.strings[idx]) |old| allocator.free(old);
        self.strings[idx] = allocator.dupe(u8, value) catch return .no_memory;
        return .success;
    }

    pub fn getViewString(self: *View, key: StringHint) []const u8 {
        return self.strings[@backingInt(key)] orelse "";
    }

    pub fn getScaleFactor(self: *View) f64 {
        return backend.getScaleFactor(self);
    }

    pub fn setViewStyle(self: *View, flags: ViewStyleFlags) Status {
        if (self.handle == null) return .bad_call;
        return backend.setViewStyle(self, flags);
    }

    pub fn getViewStyle(self: *View) ViewStyleFlags {
        return self.style;
    }

    pub fn getVisible(self: *View) bool {
        return self.visible;
    }

    pub fn getNativeView(self: *View) NativeView {
        return @intFromPtr(self.handle orelse return 0);
    }

    pub fn getContext(self: *View) ?*anyopaque {
        return switch (self.graphics_backend) {
            .gl => gl.get_backend().get_context(self),
            .metal => @import("backend/metal.zig").get_backend().get_context(self),
            .vulkan => vulkan.get_backend().get_context(self),
            .stub => null,
        };
    }

    pub fn obscureView(self: *View) Status {
        if (self.handle == null) return .bad_call;
        return backend.obscureView(self);
    }

    pub fn obscureRegion(self: *View, x: i32, y: i32, width: u32, height: u32) Status {
        if (self.handle == null) return .bad_call;
        return backend.obscureRegion(self, x, y, width, height);
    }

    pub fn grabFocus(self: *View) Status {
        if (self.handle == null) return .bad_call;
        return backend.grabFocus(self);
    }

    pub fn hasFocus(self: *View) bool {
        return backend.hasFocus(self);
    }

    pub fn setCursor(self: *View, cursor: Cursor) Status {
        if (self.handle == null) return .bad_call;
        return backend.setCursor(self, cursor);
    }

    pub fn startTimer(self: *View, id: usize, timeout: f64) Status {
        if (self.handle == null) return .bad_call;
        return self.world.startTimer(self, id, timeout);
    }

    pub fn stopTimer(self: *View, id: usize) Status {
        if (self.handle == null) return .bad_call;
        return self.world.stopTimer(self, id);
    }

    pub fn startTextInput(self: *View, rect: TextInputRect) Status {
        if (self.handle == null) return .bad_call;
        return backend.startTextInput(self, rect);
    }

    pub fn stopTextInput(self: *View) Status {
        if (self.handle == null) return .bad_call;
        return backend.stopTextInput(self);
    }

    pub fn setTextInputRect(self: *View, rect: TextInputRect) Status {
        if (self.handle == null) return .bad_call;
        return backend.setTextInputRect(self, rect);
    }

    pub fn sendEvent(self: *View, event: *const Event) Status {
        if (self.handle == null) return .bad_call;
        return backend.sendEvent(self, event);
    }

    pub fn registerDropType(self: *View, mime_type: []const u8) Status {
        if (self.handle == null) return .bad_call;
        if (@hasDecl(backend, "registerDropType")) {
            return backend.registerDropType(self, mime_type);
        }
        return .unsupported;
    }

    pub fn paste(self: *View) Status {
        if (self.handle == null) return .bad_call;
        return backend.paste(self);
    }

    pub fn getNumClipboardTypes(self: *View, clipboard: Clipboard) u32 {
        return backend.getNumClipboardTypes(self, clipboard);
    }

    pub fn getClipboardType(self: *View, clipboard: Clipboard, type_index: u32) ?[]const u8 {
        return backend.getClipboardType(self, clipboard, type_index);
    }

    pub fn acceptOffer(
        self: *View,
        offer: *const DataOfferEvent,
        type_index: u32,
        action: DataAction,
        region_x: i32,
        region_y: i32,
        region_width: u32,
        region_height: u32,
    ) Status {
        if (@hasDecl(backend, "acceptOffer")) {
            return backend.acceptOffer(self, offer, type_index, action, region_x, region_y, region_width, region_height);
        }
        return .unsupported;
    }

    pub fn rejectOffer(
        self: *View,
        offer: *const DataOfferEvent,
        region_x: i32,
        region_y: i32,
        region_width: u32,
        region_height: u32,
    ) Status {
        if (self.handle == null) return .bad_call;
        return backend.rejectOffer(self, offer, region_x, region_y, region_width, region_height);
    }

    pub fn setClipboard(
        self: *View,
        clipboard: Clipboard,
        mime_type: []const u8,
        data: []const u8,
    ) Status {
        if (self.handle == null) return .bad_call;
        return backend.setClipboard(self, clipboard, mime_type, data);
    }

    pub fn getClipboard(self: *View, clipboard: Clipboard, type_index: u32) ?[]const u8 {
        return backend.getClipboard(self, clipboard, type_index);
    }

    pub fn update(self: *View, timeout: f64) !Status {
        return self.world.update(timeout);
    }
};

pub const common = struct {
    fn filterMods(state: Mods, key: u32) Mods {
        var m = state;
        switch (key) {
            0xE051, 0xE052 => m.shift = false,
            0xE053, 0xE054 => m.ctrl = false,
            0xE055, 0xE056 => m.alt = false,
            0xE057, 0xE058 => m.super = false,
            0xE045 => m.num_lock = false,
            0xE046 => m.scroll_lock = false,
            0xE047 => m.caps_lock = false,
            else => {},
        }
        return m;
    }

    pub fn dispatchEvent(view: *View, event: *const Event) Status {
        switch (event.*) {
            inline .key_press, .key_release => |k, tag| {
                const state = filterMods(k.state, k.key);
                if (state != k.state) {
                    var e = k;
                    e.state = state;
                    return dispatchEvent(view, &@unionInit(Event, @tagName(tag), e));
                }
            },
            else => {},
        }
        if (view.event_func) |f| {
            const t = @as(EventType, event.*);
            const needs_enter = (t == .expose or t == .configure or t == .update);
            if (needs_enter and view.graphics_backend != .stub and view.gl_context != 0) {
                const gb: ?GraphicsBackend = switch (view.graphics_backend) {
                    .gl => gl.get_backend(),
                    .vulkan => vulkan.get_backend(),
                    .metal => @import("backend/metal.zig").get_backend(),
                    .stub => null,
                };
                if (gb) |g| {
                    const expose_ptr: ?*const ExposeEvent = if (t == .expose) &event.expose else null;
                    const enter_st = g.enter(view, expose_ptr);
                    if (enter_st != .success) {
                        std.log.scoped(.zpugl).warn("{s}.enter failed: {s}", .{ @tagName(view.graphics_backend), @tagName(enter_st) });
                        return enter_st;
                    }
                    defer _ = g.leave(view, expose_ptr);
                    return f(view, event);
                }
            }
            return f(view, event);
        }
        return .success;
    }

    pub fn dispatchSimpleEvent(view: *View, event_type: EventType) Status {
        const event = switch (event_type) {
            .realize => Event{ .realize = {} },
            .unrealize => Event{ .unrealize = {} },
            .close => Event{ .close = {} },
            .loop_enter => Event{ .loop_enter = {} },
            .loop_leave => Event{ .loop_leave = {} },
            else => return .success,
        };
        return dispatchEvent(view, &event);
    }
};

fn testEvent(view: *View, event: *const Event) Status {
    const count: *u32 = @ptrCast(@alignCast(view.getHandle() orelse return .success));
    _ = event;
    count.* += 1;
    return .success;
}

test "world and view accessors" {
    const world = try World.init(std.testing.allocator, .program, .{});
    defer world.deinit();
    var tag: u32 = 0;
    world.setHandle(&tag);
    try std.testing.expectEqual(@as(?*anyopaque, &tag), world.getHandle());
    try std.testing.expectEqualStrings("", world.getString(.class_name));
    try std.testing.expectEqual(Status.success, world.setString(.class_name, "zpugl"));
    try std.testing.expectEqualStrings("zpugl", world.getString(.class_name));
    try std.testing.expect(world.getTime() >= 0);

    const view = try View.init(world, testEvent);
    defer view.deinit();
    try std.testing.expectEqual(@as(?*anyopaque, null), view.getHandle());
    view.setHandle(&tag);
    try std.testing.expectEqual(@as(?*anyopaque, &tag), view.getHandle());
    for (std.enums.values(ViewHint)) |hint| try std.testing.expectEqual(hint_dont_care, view.getHint(hint));
    try std.testing.expectEqual(Status.success, view.setHint(.samples, 4));
    try std.testing.expectEqual(@as(i32, 4), view.getHint(.samples));
    try std.testing.expectEqual(@as(NativeView, 0), view.getParent());
    view.setParent(42);
    try std.testing.expectEqual(@as(NativeView, 42), view.getParent());
    try std.testing.expectEqual(Status.failure, view.setTransientParent(7));
    view.setParent(0);
    try std.testing.expectEqual(Status.success, view.setTransientParent(7));
    try std.testing.expectEqual(@as(NativeView, 7), view.getTransientParent());
    try std.testing.expectEqual(Status.success, view.setViewString(.window_title, "title"));
    try std.testing.expectEqualStrings("title", view.getViewString(.window_title));
    try std.testing.expect(!view.getVisible());
    try std.testing.expectEqual(@as(NativeView, 0), view.getNativeView());
    try std.testing.expectEqual(@as(?*anyopaque, null), view.getContext());
    try std.testing.expectEqual(@as(f64, 1.0), view.getScaleFactor());
    try std.testing.expectEqual(ViewStyleFlags{}, view.getViewStyle());
    try std.testing.expectEqual(@as(?Point, null), view.getWindowPosition());
    try std.testing.expectEqual(@as(u32, 0), tag);
}

test "position and size are clamped" {
    const world = try World.init(std.testing.allocator, .program, .{});
    defer world.deinit();
    const view = try View.init(world, testEvent);
    defer view.deinit();
    try std.testing.expectEqual(Point{ .x = std.math.minInt(i16), .y = std.math.minInt(i16) }, view.getPositionHint(.default_position));
    try std.testing.expectEqual(Status.success, view.setPositionHint(.default_position, 100000, -100000));
    try std.testing.expectEqual(Point{ .x = std.math.maxInt(i16), .y = std.math.minInt(i16) }, view.getPositionHint(.default_position));
    try std.testing.expectEqual(Status.success, view.setSizeHint(.min_size, 1 << 20, 7));
    try std.testing.expectEqual(Area{ .width = std.math.maxInt(u16), .height = 7 }, view.getSizeHint(.min_size));
    _ = view.setSize(1 << 20, 1 << 17);
    try std.testing.expectEqual(Area{ .width = std.math.maxInt(u16), .height = std.math.maxInt(u16) }, view.getSizeHint(.default_size));
}

test "unrealized views return bad_call" {
    const world = try World.init(std.testing.allocator, .program, .{});
    defer world.deinit();
    const view = try View.init(world, testEvent);
    defer view.deinit();
    const offer: DataOfferEvent = .{ .time = 0, .x = 0, .y = 0, .clipboard = .general };
    const rect: TextInputRect = .{ .x = 0, .y = 0, .width = 1, .height = 1 };
    const results = [_]Status{
        view.show(.passive),
        view.hide(),
        view.setSize(10, 10),
        view.setPosition(1, 1),
        view.setViewStyle(.{}),
        view.obscureView(),
        view.obscureRegion(0, 0, 1, 1),
        view.grabFocus(),
        view.setCursor(.hand),
        view.startTimer(1, 0.01),
        view.stopTimer(1),
        view.startTextInput(rect),
        view.stopTextInput(),
        view.setTextInputRect(rect),
        view.sendEvent(&.{ .client = .{ .data1 = 1, .data2 = 2 } }),
        view.registerDropType("text/plain"),
        view.paste(),
        view.setClipboard(.general, "text/plain", "x"),
        view.rejectOffer(&offer, 0, 0, 0, 0),
    };
    for (results) |s| try std.testing.expectEqual(Status.bad_call, s);
    try std.testing.expect(!view.hasFocus());
    try std.testing.expectEqual(Status.failure, view.setSizeHint(.current_size, 10, 10));
    try std.testing.expectEqual(Area{ .width = 0, .height = 0 }, view.getSizeHint(.current_size));
    try std.testing.expectEqual(Status.failure, view.setPositionHint(.current_position, 10, 10));
    try std.testing.expectEqual(view.getPositionHint(.default_position), view.getPositionHint(.current_position));
}

test "unrealize without realize" {
    const world = try World.init(std.testing.allocator, .program, .{});
    defer world.deinit();
    const view = try View.init(world, testEvent);
    defer view.deinit();
    var events: u32 = 0;
    view.setHandle(&events);
    try std.testing.expectError(error.NotRealized, view.unrealize());
    try std.testing.expectEqual(@as(u32, 0), events);
}

test "free a never realized gl view" {
    const world = try World.init(std.testing.allocator, .program, .{});
    defer world.deinit();
    const view = try View.init(world, testEvent);
    view.setBackend(.gl);
    try std.testing.expectEqual(@as(?*anyopaque, null), view.getContext());
    view.deinit();
}
