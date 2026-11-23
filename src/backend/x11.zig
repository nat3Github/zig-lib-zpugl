const std = @import("std");
const root = @import("../root.zig");
const common = root.common;

// --- X11 types ---

pub const Display = opaque {};
pub const Visual = opaque {};
pub const Window = c_ulong;
pub const Atom = c_ulong;
pub const Time = c_ulong;
pub const KeySym = c_ulong;
pub const XID = c_ulong;
pub const Bool_x = c_int;
pub const Cursor_x = c_ulong;
pub const Colormap = c_ulong;

// Event type constants
const KeyPress = 2;
const KeyRelease = 3;
const ButtonPress = 4;
const ButtonRelease = 5;
const MotionNotify = 6;
const EnterNotify = 7;
const LeaveNotify = 8;
const FocusIn = 9;
const FocusOut = 10;
const Expose_ev = 12;
const ConfigureNotify = 22;
const ClientMessage_ev = 33;
const SelectionClear_ev = 29;
const SelectionRequest_ev = 30;
const SelectionNotify_ev = 31;
const PropertyNotify_ev = 28;

// Event masks
const KeyPressMask: c_long = 1 << 0;
const KeyReleaseMask: c_long = 1 << 1;
const ButtonPressMask: c_long = 1 << 2;
const ButtonReleaseMask: c_long = 1 << 3;
const EnterWindowMask: c_long = 1 << 4;
const LeaveWindowMask: c_long = 1 << 5;
const PointerMotionMask: c_long = 1 << 6;
const ExposureMask: c_long = 1 << 15;
const StructureNotifyMask: c_long = 1 << 17;
const FocusChangeMask: c_long = 1 << 21;
const PropertyChangeMask: c_long = 1 << 22;
const PropModeReplace: c_int = 0;
const AnyPropertyType: Atom = 0;
const SubstructureNotifyMask: c_long = 1 << 19;
const SubstructureRedirectMask: c_long = 1 << 20;
const NoEventMask: c_long = 0;
const XA_ATOM: Atom = 4;
const XA_STRING: Atom = 31;
const XA_WM_NAME: Atom = 39;

// _NET_WM_STATE actions
const WM_STATE_REMOVE: c_long = 0;
const WM_STATE_ADD: c_long = 1;

// Modifier masks
const ShiftMask: c_uint = 1 << 0;
const LockMask: c_uint = 1 << 1;
const ControlMask: c_uint = 1 << 2;
const Mod1Mask: c_uint = 1 << 3; // Alt
const Mod2Mask: c_uint = 1 << 4; // NumLock
const Mod4Mask: c_uint = 1 << 6; // Super

const RevertToParent = 2;
const CurrentTime: Time = 0;

// XEvent structs
const XAnyEvent = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    window: Window,
};

const XKeyEvent_t = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    state: c_uint,
    keycode: c_uint,
    same_screen: Bool_x,
};

const XButtonEvent_t = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    state: c_uint,
    button: c_uint,
    same_screen: Bool_x,
};

const XMotionEvent_t = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    state: c_uint,
    is_hint: u8,
    same_screen: Bool_x,
};

const XCrossingEvent_t = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    window: Window,
    root: Window,
    subwindow: Window,
    time: Time,
    x: c_int,
    y: c_int,
    x_root: c_int,
    y_root: c_int,
    mode: c_int,
    detail: c_int,
    same_screen: Bool_x,
    focus: Bool_x,
    state: c_uint,
};

const XExposeEvent_t = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    count: c_int,
};

const XConfigureEvent_t = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    event: Window,
    window: Window,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    border_width: c_int,
    above: Window,
    override_redirect: Bool_x,
};

const XFocusChangeEvent_t = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    window: Window,
    mode: c_int,
    detail: c_int,
};

const XClientMessageData = extern union {
    b: [20]u8,
    s: [10]c_short,
    l: [5]c_long,
};

const XClientMessageEvent_t = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    window: Window,
    message_type: Atom,
    format: c_int,
    data: XClientMessageData,
};

const XSelectionRequestEvent_t = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    owner: Window,
    requestor: Window,
    selection: Atom,
    target: Atom,
    property: Atom,
    time: Time,
};

const XSelectionEvent_t = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    requestor: Window,
    selection: Atom,
    target: Atom,
    property: Atom,
    time: Time,
};

const XSelectionClearEvent_t = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    window: Window,
    selection: Atom,
    time: Time,
};

const XPropertyEvent_t = extern struct {
    type: c_int,
    serial: c_ulong,
    send_event: Bool_x,
    display: *Display,
    window: Window,
    atom: Atom,
    time: Time,
    state: c_int,
};

pub const XEvent = extern union {
    type: c_int,
    any: XAnyEvent,
    key: XKeyEvent_t,
    button: XButtonEvent_t,
    motion: XMotionEvent_t,
    crossing: XCrossingEvent_t,
    expose: XExposeEvent_t,
    configure: XConfigureEvent_t,
    focus: XFocusChangeEvent_t,
    client: XClientMessageEvent_t,
    selection_request: XSelectionRequestEvent_t,
    selection: XSelectionEvent_t,
    selection_clear: XSelectionClearEvent_t,
    property: XPropertyEvent_t,
    pad: [24]c_long,
};

pub const XSizeHints = extern struct {
    flags: c_long,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    min_width: c_int,
    min_height: c_int,
    max_width: c_int,
    max_height: c_int,
    width_inc: c_int,
    height_inc: c_int,
    min_aspect: extern struct { x: c_int, y: c_int },
    max_aspect: extern struct { x: c_int, y: c_int },
    base_width: c_int,
    base_height: c_int,
    win_gravity: c_int,
};

const USPosition: c_long = 1 << 0;
const PWinGravity: c_long = 1 << 9;
const StaticGravity: c_int = 10;
const PMinSize: c_long = 1 << 4;
const PMaxSize: c_long = 1 << 5;

// GLX types (also used from gl.zig)
pub const GLXContext = *anyopaque;
pub const GLXDrawable = XID;
pub const GLXFBConfig = *anyopaque;

pub const XVisualInfo = extern struct {
    visual: *anyopaque,
    visualid: c_ulong,
    screen: c_int,
    depth: c_int,
    class: c_int,
    red_mask: c_ulong,
    green_mask: c_ulong,
    blue_mask: c_ulong,
    colormap_size: c_int,
    bits_per_rgb: c_int,
};

// GLX attribute constants
pub const GLX_RGBA = 4;
pub const GLX_DOUBLEBUFFER = 5;
pub const GLX_RED_SIZE = 8;
pub const GLX_GREEN_SIZE = 9;
pub const GLX_BLUE_SIZE = 10;
pub const GLX_ALPHA_SIZE = 11;
pub const GLX_DEPTH_SIZE = 12;
pub const GLX_STENCIL_SIZE = 13;
pub const GLX_RENDER_TYPE = 0x8011;
pub const GLX_DRAWABLE_TYPE = 0x8010;
pub const GLX_WINDOW_BIT = 0x0001;
pub const GLX_RGBA_BIT = 0x00000001;
pub const GLX_RGBA_TYPE = 0x8014; // renderType for glXCreateNewContext
pub const GLX_CONTEXT_MAJOR_VERSION_ARB = 0x2091;
pub const GLX_CONTEXT_MINOR_VERSION_ARB = 0x2092;
pub const GLX_CONTEXT_PROFILE_MASK_ARB = 0x9126;
pub const GLX_CONTEXT_CORE_PROFILE_BIT_ARB = 0x00000001;
pub const GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB = 0x00000002;
pub const GLX_CONTEXT_FLAGS_ARB = 0x2094;
pub const GLX_CONTEXT_DEBUG_BIT_ARB = 0x0001;
pub const GLX_NONE = 0x8000;

pub const PFNGLXCREATECONTEXTATTRIBSARBPROC = *const fn (
    display: *Display,
    config: GLXFBConfig,
    share: ?GLXContext,
    direct: Bool_x,
    attribs: [*]const c_int,
) callconv(.c) ?GLXContext;

// --- X11 extern functions ---

pub extern fn XOpenDisplay(name: ?[*:0]const u8) ?*Display;
pub extern fn XInitThreads() c_int;
pub extern fn XCloseDisplay(display: *Display) c_int;
pub extern fn XFlush(display: *Display) c_int;
pub extern fn XSync(display: *Display, discard: Bool_x) c_int;
pub extern fn XPending(display: *Display) c_int;
pub extern fn XNextEvent(display: *Display, event: *XEvent) c_int;
pub extern fn XConnectionNumber(display: *Display) c_int;
pub extern fn XDefaultScreen(display: *Display) c_int;
pub extern fn XDefaultRootWindow(display: *Display) Window;
pub extern fn XDisplayWidth(display: *Display, screen: c_int) c_int;
pub extern fn XDisplayHeight(display: *Display, screen: c_int) c_int;
pub extern fn XBlackPixel(display: *Display, screen: c_int) c_ulong;
pub extern fn XWhitePixel(display: *Display, screen: c_int) c_ulong;
pub extern fn XCreateSimpleWindow(display: *Display, parent: Window, x: c_int, y: c_int, w: c_uint, h: c_uint, border_width: c_uint, border: c_ulong, background: c_ulong) Window;
pub extern fn XDestroyWindow(display: *Display, w: Window) c_int;
pub extern fn XMapWindow(display: *Display, w: Window) c_int;
pub extern fn XUnmapWindow(display: *Display, w: Window) c_int;
pub extern fn XResizeWindow(display: *Display, w: Window, width: c_uint, height: c_uint) c_int;
pub extern fn XMoveWindow(display: *Display, w: Window, x: c_int, y: c_int) c_int;
pub extern fn XStoreName(display: *Display, w: Window, name: [*:0]const u8) c_int;
pub extern fn XSetWMProtocols(display: *Display, w: Window, protocols: *Atom, count: c_int) c_int;
pub extern fn XSelectInput(display: *Display, w: Window, mask: c_long) c_int;
pub extern fn XInternAtom(display: *Display, name: [*:0]const u8, only_if_exists: Bool_x) Atom;
pub extern fn XLookupKeysym(event: *XKeyEvent_t, index: c_int) KeySym;
pub extern fn XLookupString(event: *XKeyEvent_t, buf: [*]u8, bytes: c_int, keysym: *KeySym, status: ?*anyopaque) c_int;

// XIM/XIC
pub const XIM = *opaque {};
pub const XIC = *opaque {};
const XIMPreeditNothing: c_long = 0x0008;
const XIMStatusNothing: c_long = 0x0400;
pub extern fn XOpenIM(display: *Display, db: ?*anyopaque, res_name: ?[*:0]u8, res_class: ?[*:0]u8) ?XIM;
pub extern fn XCloseIM(im: XIM) c_int;
pub extern fn XCreateIC(im: XIM, ...) ?XIC;
pub extern fn XDestroyIC(ic: XIC) void;
pub extern fn Xutf8LookupString(ic: XIC, event: *XKeyEvent_t, buf: [*]u8, bytes: c_int, keysym: *KeySym, status: *c_int) c_int;
const XLookupChars: c_int = 2;
const XLookupKeySym_x: c_int = 3;
const XLookupBoth: c_int = 4;
pub extern fn XSetInputFocus(display: *Display, w: Window, revert: c_int, time: Time) c_int;
pub extern fn XGetInputFocus(display: *Display, w: *Window, revert: *c_int) c_int;
pub extern fn XSetICValues(ic: XIC, ...) ?[*:0]u8;
pub extern fn XSetICFocus(ic: XIC) void;
pub extern fn XUnsetICFocus(ic: XIC) void;

pub const XPoint = extern struct { x: c_short, y: c_short };
const XNSpotLocation = "spotLocation";
pub extern fn XDefineCursor(display: *Display, w: Window, cursor: Cursor_x) c_int;
pub extern fn XFreeCursor(display: *Display, cursor: Cursor_x) c_int;
pub extern fn XCreateFontCursor(display: *Display, shape: c_uint) Cursor_x;
pub extern fn XSetWMNormalHints(display: *Display, w: Window, hints: *XSizeHints) void;
pub extern fn XAllocSizeHints() ?*XSizeHints;
pub extern fn XFree(data: *anyopaque) c_int;
pub extern fn XSendEvent(display: *Display, w: Window, propagate: Bool_x, mask: c_long, event: *XEvent) c_int;
pub extern fn XRaiseWindow(display: *Display, w: Window) c_int;
pub extern fn XChangeProperty(display: *Display, w: Window, property: Atom, @"type": Atom, format: c_int, mode: c_int, data: [*]const u8, nelements: c_int) c_int;
pub extern fn XSetSelectionOwner(display: *Display, selection: Atom, owner: Window, time: Time) c_int;
pub extern fn XGetSelectionOwner(display: *Display, selection: Atom) Window;
pub extern fn XConvertSelection(display: *Display, selection: Atom, target: Atom, property: Atom, requestor: Window, time: Time) c_int;
pub extern fn XGetWindowProperty(
    display: *Display,
    w: Window,
    property: Atom,
    long_offset: c_long,
    long_length: c_long,
    delete: Bool_x,
    req_type: Atom,
    actual_type_return: *Atom,
    actual_format_return: *c_int,
    nitems_return: *c_ulong,
    bytes_after_return: *c_ulong,
    prop_return: *[*]u8,
) c_int;
pub extern fn XGetAtomName(display: *Display, atom: Atom) ?[*:0]u8;
pub extern fn XDeleteProperty(display: *Display, w: Window, property: Atom) c_int;
pub extern fn XSetTransientForHint(display: *Display, w: Window, prop_window: Window) c_int;
pub extern fn XIconifyWindow(display: *Display, w: Window, screen_number: c_int) c_int;
pub extern fn XTranslateCoordinates(
    display: *Display,
    src_w: Window,
    dest_w: Window,
    src_x: c_int,
    src_y: c_int,
    dest_x_return: *c_int,
    dest_y_return: *c_int,
    child_return: *Window,
) Bool_x;

pub const XClassHint = extern struct {
    res_name: [*:0]u8,
    res_class: [*:0]u8,
};
pub extern fn XSetClassHint(display: *Display, w: Window, class_hints: *XClassHint) c_int;

// Xcursor (from libXcursor)
pub extern fn XcursorLibraryLoadCursor(display: *Display, name: [*:0]const u8) Cursor_x;

// GLX
pub extern fn glXChooseVisual(display: *Display, screen: c_int, attribList: [*]c_int) ?*XVisualInfo;
pub extern fn glXCreateContext(display: *Display, vis: *XVisualInfo, shareList: ?GLXContext, direct: Bool_x) ?GLXContext;
pub extern fn glXDestroyContext(display: *Display, ctx: GLXContext) void;
pub extern fn glXMakeCurrent(display: *Display, drawable: GLXDrawable, ctx: ?GLXContext) Bool_x;
pub extern fn glXSwapBuffers(display: *Display, drawable: GLXDrawable) void;
pub extern fn glXChooseFBConfig(display: *Display, screen: c_int, attribList: [*]const c_int, nelements: *c_int) ?[*]GLXFBConfig;
pub extern fn glXCreateNewContext(display: *Display, config: GLXFBConfig, renderType: c_int, shareList: ?GLXContext, direct: Bool_x) ?GLXContext;
pub extern fn glXGetProcAddress(procname: [*:0]const u8) ?*anyopaque;
pub extern fn glXGetVisualFromFBConfig(display: *Display, config: GLXFBConfig) ?*XVisualInfo;

// --- Timer ---

const Timer = struct {
    id: usize,
    view: *root.View,
    interval_ns: u64,
    next_fire_ns: u64,
};

// --- WorldImpl ---

const ClipboardState = struct {
    // Owned (we own the selection)
    owned_mime: ?[]u8 = null,
    owned_data: ?[]u8 = null,
    // Receiving (paste in flight)
    recv_view: ?*root.View = null,
    recv_targets: std.ArrayListUnmanaged(Atom) = .empty,
    recv_type_strs: std.ArrayListUnmanaged([]u8) = .empty,
    recv_buf: std.ArrayListUnmanaged(u8) = .empty,
    accepted_target: Atom = 0,
};

pub const FdWatcher = struct {
    fd: c_int,
    user_data: ?*anyopaque,
    callback: *const fn (fd: c_int, user_data: ?*anyopaque) void,
};

pub const DragState = struct {
    source: Window = 0,
    targets: std.ArrayListUnmanaged(Atom) = .empty,
    type_strs: std.ArrayListUnmanaged([]u8) = .empty,
    accepted_target: Atom = 0,
    accepted_index: u32 = 0,
    buf: std.ArrayListUnmanaged(u8) = .empty,
    drop_time: Time = 0,
};

pub const WorldImpl = struct {
    display: *Display,
    wm_protocols: Atom,
    wm_delete_window: Atom,
    a_clipboard: Atom,
    a_utf8_string: Atom,
    a_targets: Atom,
    a_zpugl_sel: Atom,
    // EWMH state atoms
    a_net_wm_state: Atom,
    a_net_wm_state_above: Atom,
    a_net_wm_state_below: Atom,
    a_net_wm_state_fullscreen: Atom,
    a_net_wm_state_modal: Atom,
    a_net_wm_state_hidden: Atom,
    a_net_wm_state_demands_attention: Atom,
    a_net_wm_state_maximized_vert: Atom,
    a_net_wm_state_maximized_horz: Atom,
    // Xdnd atoms
    a_xdnd_aware: Atom,
    a_xdnd_enter: Atom,
    a_xdnd_position: Atom,
    a_xdnd_status: Atom,
    a_xdnd_leave: Atom,
    a_xdnd_drop: Atom,
    a_xdnd_finished: Atom,
    a_xdnd_selection: Atom,
    a_xdnd_type_list: Atom,
    a_xdnd_action_copy: Atom,
    a_pugl_client_msg: Atom,
    timers: std.ArrayListUnmanaged(Timer) = .empty,
    clipboard: ClipboardState = .{},
    drag: DragState = .{},
    fd_watchers: std.ArrayListUnmanaged(FdWatcher) = .empty,
    screen: c_int = 0,
    xim: ?XIM = null,
    xic_map: std.AutoHashMapUnmanaged(Window, XIC) = .{},
};

fn getWorldImpl(world: *root.World) ?*WorldImpl {
    return if (world.impl) |p| @ptrCast(@alignCast(p)) else null;
}

fn getOrInitWorldImpl(world: *root.World) !*WorldImpl {
    if (world.impl) |p| return @ptrCast(@alignCast(p));
    if (world.type == .program) _ = XInitThreads();
    const display = XOpenDisplay(null) orelse return error.NoDisplay;
    const impl = try world.allocator.create(WorldImpl);
    impl.* = .{
        .display = display,
        .wm_protocols = XInternAtom(display, "WM_PROTOCOLS", 0),
        .wm_delete_window = XInternAtom(display, "WM_DELETE_WINDOW", 0),
        .a_clipboard = XInternAtom(display, "CLIPBOARD", 0),
        .a_utf8_string = XInternAtom(display, "UTF8_STRING", 0),
        .a_targets = XInternAtom(display, "TARGETS", 0),
        .a_zpugl_sel = XInternAtom(display, "ZPUGL_SELECTION", 0),
        .a_net_wm_state = XInternAtom(display, "_NET_WM_STATE", 0),
        .a_net_wm_state_above = XInternAtom(display, "_NET_WM_STATE_ABOVE", 0),
        .a_net_wm_state_below = XInternAtom(display, "_NET_WM_STATE_BELOW", 0),
        .a_net_wm_state_fullscreen = XInternAtom(display, "_NET_WM_STATE_FULLSCREEN", 0),
        .a_net_wm_state_modal = XInternAtom(display, "_NET_WM_STATE_MODAL", 0),
        .a_net_wm_state_hidden = XInternAtom(display, "_NET_WM_STATE_HIDDEN", 0),
        .a_net_wm_state_demands_attention = XInternAtom(display, "_NET_WM_STATE_DEMANDS_ATTENTION", 0),
        .a_net_wm_state_maximized_vert = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_VERT", 0),
        .a_net_wm_state_maximized_horz = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_HORZ", 0),
        .a_xdnd_aware = XInternAtom(display, "XdndAware", 0),
        .a_xdnd_enter = XInternAtom(display, "XdndEnter", 0),
        .a_xdnd_position = XInternAtom(display, "XdndPosition", 0),
        .a_xdnd_status = XInternAtom(display, "XdndStatus", 0),
        .a_xdnd_leave = XInternAtom(display, "XdndLeave", 0),
        .a_xdnd_drop = XInternAtom(display, "XdndDrop", 0),
        .a_xdnd_finished = XInternAtom(display, "XdndFinished", 0),
        .a_xdnd_selection = XInternAtom(display, "XdndSelection", 0),
        .a_xdnd_type_list = XInternAtom(display, "XdndTypeList", 0),
        .a_xdnd_action_copy = XInternAtom(display, "XdndActionCopy", 0),
        .a_pugl_client_msg = XInternAtom(display, "_PUGL_CLIENT_MSG", 0),
        .screen = XDefaultScreen(display),
    };
    impl.xim = XOpenIM(display, null, null, null);
    world.impl = impl;
    return impl;
}

// --- Key translation ---

fn keysymToKey(sym: KeySym) u32 {
    // Direct printable ASCII / Latin-1
    if (sym >= 0x0020 and sym <= 0x00FF) return @intCast(sym);
    // Unicode private-use keysyms (X11 encodes as 0x01000000 | codepoint)
    if (sym >= 0x01000020 and sym <= 0x0110FFFF) return @intCast(sym - 0x01000000);
    return switch (sym) {
        0xFF08 => 0x0008, // BackSpace
        0xFF09 => 0x0009, // Tab
        0xFF0D => 0x000D, // Return
        0xFF1B => 0x001B, // Escape
        0xFFFF => 0x007F, // Delete
        0xFFBE => 0xE000, // F1
        0xFFBF => 0xE001, // F2
        0xFFC0 => 0xE002, // F3
        0xFFC1 => 0xE003, // F4
        0xFFC2 => 0xE004, // F5
        0xFFC3 => 0xE005, // F6
        0xFFC4 => 0xE006, // F7
        0xFFC5 => 0xE007, // F8
        0xFFC6 => 0xE008, // F9
        0xFFC7 => 0xE009, // F10
        0xFFC8 => 0xE00A, // F11
        0xFFC9 => 0xE00B, // F12
        0xFF55 => 0xE031, // Page_Up
        0xFF56 => 0xE032, // Page_Down
        0xFF57 => 0xE033, // End
        0xFF50 => 0xE034, // Home
        0xFF51 => 0xE035, // Left
        0xFF52 => 0xE036, // Up
        0xFF53 => 0xE037, // Right
        0xFF54 => 0xE038, // Down
        0xFF61 => 0xE041, // Print
        0xFF63 => 0xE042, // Insert
        0xFF13 => 0xE043, // Pause
        0xFF67 => 0xE044, // Menu
        0xFF7F => 0xE045, // Num_Lock
        0xFF14 => 0xE046, // Scroll_Lock
        0xFFE5 => 0xE047, // Caps_Lock
        0xFFE1 => 0xE051, // Shift_L
        0xFFE2 => 0xE052, // Shift_R
        0xFFE3 => 0xE053, // Control_L
        0xFFE4 => 0xE054, // Control_R
        0xFFE9 => 0xE055, // Alt_L
        0xFFEA => 0xE056, // Alt_R
        0xFFEB => 0xE057, // Super_L
        0xFFEC => 0xE058, // Super_R
        0xFFB0 => 0xE060, // KP_0
        0xFFB1 => 0xE061, // KP_1
        0xFFB2 => 0xE062, // KP_2
        0xFFB3 => 0xE063, // KP_3
        0xFFB4 => 0xE064, // KP_4
        0xFFB5 => 0xE065, // KP_5
        0xFFB6 => 0xE066, // KP_6
        0xFFB7 => 0xE067, // KP_7
        0xFFB8 => 0xE068, // KP_8
        0xFFB9 => 0xE069, // KP_9
        0xFF8D => 0xE070, // KP_Enter
        0xFFAA => 0xE0AA, // KP_Multiply
        0xFFAB => 0xE0AB, // KP_Add
        0xFFAC => 0xE0AC, // KP_Separator
        0xFFAD => 0xE0AD, // KP_Subtract
        0xFFAE => 0xE0AE, // KP_Decimal
        0xFFAF => 0xE0AF, // KP_Divide
        0xFF9A => 0xE071, // KP_Page_Up
        0xFF9B => 0xE072, // KP_Page_Down
        0xFF9C => 0xE073, // KP_End
        0xFF95 => 0xE074, // KP_Home
        0xFF96 => 0xE075, // KP_Left
        0xFF97 => 0xE076, // KP_Up
        0xFF98 => 0xE077, // KP_Right
        0xFF99 => 0xE078, // KP_Down
        0xFF9D => 0xE09D, // KP_Begin (Clear)
        0xFF9E => 0xE09E, // KP_Insert
        0xFF9F => 0xE09F, // KP_Delete
        0xFFBD => 0xE0A0, // KP_Equal
        else => 0,
    };
}

fn stateMods(state: c_uint) root.Mods {
    return .{
        .shift = (state & ShiftMask) != 0,
        .ctrl = (state & ControlMask) != 0,
        .alt = (state & Mod1Mask) != 0,
        .super = (state & Mod4Mask) != 0,
        .num_lock = (state & Mod2Mask) != 0,
        .caps_lock = (state & LockMask) != 0,
    };
}

// --- Event processing ---

fn processEvent(world: *root.World, impl: *WorldImpl, xev: *XEvent) void {
    const win_id: usize = @intCast(xev.any.window);
    const view = world.view_map.get(win_id) orelse return;
    const display = impl.display;

    switch (xev.type) {
        Expose_ev => {
            // Only dispatch on last expose in sequence (count == 0)
            if (xev.expose.count == 0) {
                const ev = root.Event{ .expose = .{
                    .x = @intCast(xev.expose.x),
                    .y = @intCast(xev.expose.y),
                    .width = @intCast(@min(xev.expose.width, std.math.maxInt(u16))),
                    .height = @intCast(@min(xev.expose.height, std.math.maxInt(u16))),
                } };
                _ = common.dispatchEvent(view, &ev);
            }
        },
        ConfigureNotify => {
            const w: u16 = @intCast(@min(xev.configure.width, std.math.maxInt(u16)));
            const h: u16 = @intCast(@min(xev.configure.height, std.math.maxInt(u16)));
            view.size_hints[@backingInt(root.SizeHint.current_size)] = .{ .width = w, .height = h };
            const ev = root.Event{ .configure = .{
                .x = @intCast(xev.configure.x),
                .y = @intCast(xev.configure.y),
                .width = w,
                .height = h,
                .style = view.style,
            } };
            _ = common.dispatchEvent(view, &ev);
            // Resize GL context if needed
            if (view.gl_context != 0) {
                _ = glXMakeCurrent(display, win_id, @ptrFromInt(view.gl_context));
            }
        },
        ButtonPress, ButtonRelease => {
            if (xev.type == ButtonPress and xev.button.button <= 3 and view.parent != 0) {
                _ = XSetInputFocus(display, @intCast(win_id), RevertToParent, xev.button.time);
            }
            const button: u32 = switch (xev.button.button) {
                1 => 0, // left → 0
                2 => 2, // middle → 2
                3 => 1, // right → 1
                else => xev.button.button - 1,
            };
            const t: f64 = @as(f64, @floatFromInt(xev.button.time)) / 1000.0;
            const ev = if (xev.type == ButtonPress)
                root.Event{ .button_press = .{
                    .time = t,
                    .x = @floatFromInt(xev.button.x),
                    .y = @floatFromInt(xev.button.y),
                    .root_x = @floatFromInt(xev.button.x_root),
                    .root_y = @floatFromInt(xev.button.y_root),
                    .state = stateMods(xev.button.state),
                    .button = button,
                } }
            else
                root.Event{ .button_release = .{
                    .time = t,
                    .x = @floatFromInt(xev.button.x),
                    .y = @floatFromInt(xev.button.y),
                    .root_x = @floatFromInt(xev.button.x_root),
                    .root_y = @floatFromInt(xev.button.y_root),
                    .state = stateMods(xev.button.state),
                    .button = button,
                } };
            // Scroll wheel: button 4/5/6/7
            if (xev.button.button >= 4 and xev.button.button <= 7 and xev.type == ButtonPress) {
                const dir: root.ScrollDirection = switch (xev.button.button) {
                    4 => .up,
                    5 => .down,
                    6 => .left,
                    7 => .right,
                    else => .smooth,
                };
                const dy: f64 = if (xev.button.button == 4) 1.0 else if (xev.button.button == 5) -1.0 else 0.0;
                const dx: f64 = if (xev.button.button == 6) -1.0 else if (xev.button.button == 7) 1.0 else 0.0;
                const sev = root.Event{ .scroll = .{
                    .time = t,
                    .x = @floatFromInt(xev.button.x),
                    .y = @floatFromInt(xev.button.y),
                    .root_x = @floatFromInt(xev.button.x_root),
                    .root_y = @floatFromInt(xev.button.y_root),
                    .state = stateMods(xev.button.state),
                    .direction = dir,
                    .dx = dx,
                    .dy = dy,
                } };
                _ = common.dispatchEvent(view, &sev);
                return;
            }
            _ = common.dispatchEvent(view, &ev);
        },
        MotionNotify => {
            const t: f64 = @as(f64, @floatFromInt(xev.motion.time)) / 1000.0;
            const ev = root.Event{ .motion = .{
                .time = t,
                .x = @floatFromInt(xev.motion.x),
                .y = @floatFromInt(xev.motion.y),
                .root_x = @floatFromInt(xev.motion.x_root),
                .root_y = @floatFromInt(xev.motion.y_root),
                .state = stateMods(xev.motion.state),
            } };
            _ = common.dispatchEvent(view, &ev);
        },
        EnterNotify => {
            const t: f64 = @as(f64, @floatFromInt(xev.crossing.time)) / 1000.0;
            const mode: root.CrossingMode = @fromBackingInt(@intCast(@min(@as(u32, @intCast(@max(xev.crossing.mode, 0))), 2)));
            const ev = root.Event{ .pointer_in = .{
                .time = t,
                .x = @floatFromInt(xev.crossing.x),
                .y = @floatFromInt(xev.crossing.y),
                .root_x = @floatFromInt(xev.crossing.x_root),
                .root_y = @floatFromInt(xev.crossing.y_root),
                .state = stateMods(xev.crossing.state),
                .mode = mode,
            } };
            _ = common.dispatchEvent(view, &ev);
        },
        LeaveNotify => {
            const t: f64 = @as(f64, @floatFromInt(xev.crossing.time)) / 1000.0;
            const mode: root.CrossingMode = @fromBackingInt(@intCast(@min(@as(u32, @intCast(@max(xev.crossing.mode, 0))), 2)));
            const ev = root.Event{ .pointer_out = .{
                .time = t,
                .x = @floatFromInt(xev.crossing.x),
                .y = @floatFromInt(xev.crossing.y),
                .root_x = @floatFromInt(xev.crossing.x_root),
                .root_y = @floatFromInt(xev.crossing.y_root),
                .state = stateMods(xev.crossing.state),
                .mode = mode,
            } };
            _ = common.dispatchEvent(view, &ev);
        },
        FocusIn => {
            const mode: root.CrossingMode = @fromBackingInt(@intCast(@min(@as(u32, @intCast(@max(xev.focus.mode, 0))), 2)));
            _ = common.dispatchEvent(view, &root.Event{ .focus_in = .{ .mode = mode } });
        },
        FocusOut => {
            const mode: root.CrossingMode = @fromBackingInt(@intCast(@min(@as(u32, @intCast(@max(xev.focus.mode, 0))), 2)));
            _ = common.dispatchEvent(view, &root.Event{ .focus_out = .{ .mode = mode } });
        },
        KeyPress, KeyRelease => {
            var sym: KeySym = 0;
            var buf: [8]u8 = @splat(0);
            const win_key: Window = @intCast(xev.any.window);
            const xic_opt = impl.xic_map.get(win_key);
            var n: usize = 0;
            if (xic_opt) |xic| {
                var status: c_int = 0;
                const nr = Xutf8LookupString(xic, &xev.key, &buf, @intCast(buf.len - 1), &sym, &status);
                if (nr > 0 and (status == XLookupChars or status == XLookupBoth)) {
                    n = @intCast(nr);
                } else if (status == XLookupKeySym_x or status == XLookupBoth) {
                    // sym already set, no chars
                }
            } else {
                const n_lookup = XLookupString(&xev.key, &buf, @intCast(buf.len - 1), &sym, null);
                if (n_lookup > 0) {
                    // Transcode Latin-1 -> UTF-8
                    const src: [8]u8 = buf;
                    var out: usize = 0;
                    var i: usize = 0;
                    while (i < @as(usize, @intCast(n_lookup)) and out < buf.len - 1) : (i += 1) {
                        const c = src[i];
                        if (c < 0x80) {
                            buf[out] = c;
                            out += 1;
                        } else {
                            if (out + 2 > buf.len - 1) break;
                            buf[out] = 0xC0 | (c >> 6);
                            buf[out + 1] = 0x80 | (c & 0x3F);
                            out += 2;
                        }
                    }
                    n = out;
                }
            }
            const key = keysymToKey(sym);
            const t: f64 = @as(f64, @floatFromInt(xev.key.time)) / 1000.0;
            const mods = stateMods(xev.key.state);
            if (xev.type == KeyPress) {
                const kev = root.Event{ .key_press = .{
                    .time = t,
                    .x = @floatFromInt(xev.key.x),
                    .y = @floatFromInt(xev.key.y),
                    .root_x = @floatFromInt(xev.key.x_root),
                    .root_y = @floatFromInt(xev.key.y_root),
                    .state = mods,
                    .keycode = xev.key.keycode,
                    .key = key,
                } };
                _ = common.dispatchEvent(view, &kev);
                if (n > 0 and buf[0] >= 0x20 and buf[0] != 0x7F) {
                    var str8: [8]u8 = @splat(0);
                    @memcpy(str8[0..n], buf[0..n]);
                    // Decode first codepoint for .character field
                    const first_cp: u32 = blk: {
                        if (buf[0] < 0x80) break :blk buf[0];
                        if (n >= 2 and (buf[0] & 0xE0) == 0xC0)
                            break :blk (@as(u32, buf[0] & 0x1F) << 6) | (buf[1] & 0x3F);
                        if (n >= 3 and (buf[0] & 0xF0) == 0xE0)
                            break :blk (@as(u32, buf[0] & 0x0F) << 12) | (@as(u32, buf[1] & 0x3F) << 6) | (buf[2] & 0x3F);
                        break :blk buf[0];
                    };
                    const tev = root.Event{ .text = .{
                        .time = t,
                        .x = @floatFromInt(xev.key.x),
                        .y = @floatFromInt(xev.key.y),
                        .root_x = @floatFromInt(xev.key.x_root),
                        .root_y = @floatFromInt(xev.key.y_root),
                        .state = mods,
                        .keycode = xev.key.keycode,
                        .character = first_cp,
                        .string = str8,
                    } };
                    _ = common.dispatchEvent(view, &tev);
                }
            } else {
                const kev = root.Event{ .key_release = .{
                    .time = t,
                    .x = @floatFromInt(xev.key.x),
                    .y = @floatFromInt(xev.key.y),
                    .root_x = @floatFromInt(xev.key.x_root),
                    .root_y = @floatFromInt(xev.key.y_root),
                    .state = mods,
                    .keycode = xev.key.keycode,
                    .key = key,
                } };
                _ = common.dispatchEvent(view, &kev);
            }
        },
        ClientMessage_ev => {
            if (xev.client.message_type == impl.wm_protocols and
                xev.client.format == 32 and
                @as(Atom, @intCast(xev.client.data.l[0])) == impl.wm_delete_window)
            {
                _ = common.dispatchEvent(view, &root.Event{ .close = {} });
            } else if (xev.client.message_type == impl.a_pugl_client_msg) {
                const cev = root.Event{ .client = .{
                    .data1 = @intCast(xev.client.data.l[0]),
                    .data2 = @intCast(xev.client.data.l[1]),
                } };
                _ = common.dispatchEvent(view, &cev);
            } else if (xev.client.message_type == impl.a_xdnd_enter) {
                handleXdndEnter(world, impl, view, &xev.client);
            } else if (xev.client.message_type == impl.a_xdnd_position) {
                handleXdndPosition(world, impl, view, &xev.client);
            } else if (xev.client.message_type == impl.a_xdnd_leave) {
                handleXdndLeave(world, impl);
            } else if (xev.client.message_type == impl.a_xdnd_drop) {
                handleXdndDrop(world, impl, view, &xev.client);
            }
        },
        SelectionClear_ev => {
            // Lost ownership: free owned data
            if (impl.clipboard.owned_mime) |m| world.allocator.free(m);
            if (impl.clipboard.owned_data) |d| world.allocator.free(d);
            impl.clipboard.owned_mime = null;
            impl.clipboard.owned_data = null;
        },
        SelectionRequest_ev => {
            handleSelectionRequest(world, impl, &xev.selection_request);
        },
        SelectionNotify_ev => {
            handleSelectionNotify(world, impl, &xev.selection);
        },
        else => {},
    }
}

fn handleSelectionRequest(world: *root.World, impl: *WorldImpl, req: *XSelectionRequestEvent_t) void {
    _ = world;
    var notify = XEvent{
        .selection = .{
            .type = SelectionNotify_ev,
            .serial = 0,
            .send_event = 1,
            .display = impl.display,
            .requestor = req.requestor,
            .selection = req.selection,
            .target = req.target,
            .property = 0, // None = refused
            .time = req.time,
        },
    };

    if (impl.clipboard.owned_data) |data| {
        if (req.target == impl.a_targets) {
            // Reply with list of supported targets
            var targets = [_]Atom{ impl.a_targets, impl.a_utf8_string };
            _ = XChangeProperty(
                impl.display,
                req.requestor,
                req.property,
                4, // XA_ATOM
                32,
                PropModeReplace,
                @ptrCast(&targets),
                @intCast(targets.len),
            );
            notify.selection.property = req.property;
        } else if (req.target == impl.a_utf8_string or req.target == 31) {
            // 31 = XA_STRING
            _ = XChangeProperty(
                impl.display,
                req.requestor,
                req.property,
                req.target,
                8,
                PropModeReplace,
                data.ptr,
                @intCast(data.len),
            );
            notify.selection.property = req.property;
        }
    }

    _ = XSendEvent(impl.display, req.requestor, 0, 0, &notify);
    _ = XFlush(impl.display);
}

fn handleSelectionNotify(world: *root.World, impl: *WorldImpl, ev: *XSelectionEvent_t) void {
    // Xdnd drop reply: selection == XdndSelection
    if (ev.selection == impl.a_xdnd_selection) {
        handleXdndSelection(world, impl, ev);
        return;
    }
    const cb = &impl.clipboard;
    const view = cb.recv_view orelse return;
    if (ev.property == 0) return; // refused

    var actual_type: Atom = 0;
    var actual_format: c_int = 0;
    var nitems: c_ulong = 0;
    var bytes_after: c_ulong = 0;
    var prop_data: [*]u8 = undefined;
    const r = XGetWindowProperty(
        impl.display,
        ev.requestor,
        ev.property,
        0,
        0x7fffffff,
        1, // delete after read
        AnyPropertyType,
        &actual_type,
        &actual_format,
        &nitems,
        &bytes_after,
        &prop_data,
    );
    if (r != 0) return;
    defer _ = XFree(@ptrCast(prop_data));

    if (ev.target == impl.a_targets) {
        // Build target list and dispatch data_offer
        for (cb.recv_type_strs.items) |s| world.allocator.free(s);
        cb.recv_type_strs.clearRetainingCapacity();
        cb.recv_targets.clearRetainingCapacity();
        const atoms_ptr: [*]const Atom = @ptrCast(@alignCast(prop_data));
        var i: usize = 0;
        while (i < nitems) : (i += 1) {
            const a = atoms_ptr[i];
            if (a == impl.a_utf8_string or a == 31) {
                cb.recv_targets.append(world.allocator, a) catch return;
                const name: []const u8 = if (a == impl.a_utf8_string) "text/plain" else "text/plain;charset=string";
                const dup = world.allocator.dupe(u8, name) catch return;
                cb.recv_type_strs.append(world.allocator, dup) catch {
                    world.allocator.free(dup);
                    return;
                };
            }
        }
        const offer = root.Event{ .data_offer = .{
            .time = @as(f64, @floatFromInt(ev.time)) / 1000.0,
            .x = 0,
            .y = 0,
            .clipboard = .general,
        } };
        _ = common.dispatchEvent(view, &offer);
    } else {
        // Data reply: store and dispatch data event
        cb.recv_buf.clearRetainingCapacity();
        cb.recv_buf.appendSlice(world.allocator, prop_data[0..nitems]) catch return;
        const dev = root.Event{ .data = .{
            .time = @as(f64, @floatFromInt(ev.time)) / 1000.0,
            .x = 0,
            .y = 0,
            .clipboard = .general,
            .type_index = 0,
        } };
        _ = common.dispatchEvent(view, &dev);
    }
}

fn handleXdndEnter(world: *root.World, impl: *WorldImpl, view: *root.View, msg: *XClientMessageEvent_t) void {
    const drag = &impl.drag;
    drag.source = @intCast(msg.data.l[0]);
    // clear previous targets
    for (drag.type_strs.items) |s| world.allocator.free(s);
    drag.type_strs.clearRetainingCapacity();
    drag.targets.clearRetainingCapacity();
    drag.accepted_target = 0;

    const is_list = (msg.data.l[1] & 1) != 0;
    if (!is_list) {
        // Up to 3 inline atoms in data.l[2..5]
        var i: usize = 0;
        while (i < 3) : (i += 1) {
            const a: Atom = @intCast(@as(c_long, msg.data.l[2 + i]));
            if (a == 0) continue;
            drag.targets.append(world.allocator, a) catch return;
            appendDragTypeName(world, impl, a) catch return;
        }
    } else {
        // Read XdndTypeList property from source window
        var actual_type: Atom = 0;
        var actual_format: c_int = 0;
        var nitems: c_ulong = 0;
        var bytes_after: c_ulong = 0;
        var prop_data: [*]u8 = undefined;
        const r = XGetWindowProperty(
            impl.display,
            drag.source,
            impl.a_xdnd_type_list,
            0,
            0x7fffffff,
            0,
            XA_ATOM,
            &actual_type,
            &actual_format,
            &nitems,
            &bytes_after,
            &prop_data,
        );
        if (r != 0) return;
        defer _ = XFree(@ptrCast(prop_data));
        const atoms_ptr: [*]const Atom = @ptrCast(@alignCast(prop_data));
        var i: usize = 0;
        while (i < nitems) : (i += 1) {
            const a = atoms_ptr[i];
            drag.targets.append(world.allocator, a) catch return;
            appendDragTypeName(world, impl, a) catch return;
        }
    }
    _ = view;
}

fn appendDragTypeName(world: *root.World, impl: *WorldImpl, a: Atom) !void {
    const name_c = XGetAtomName(impl.display, a);
    if (name_c) |nm| {
        defer _ = XFree(@ptrCast(nm));
        const slice = std.mem.span(nm);
        const dup = try world.allocator.dupe(u8, slice);
        impl.drag.type_strs.append(world.allocator, dup) catch {
            world.allocator.free(dup);
            return error.OutOfMemory;
        };
    } else {
        const dup = try world.allocator.dupe(u8, "");
        impl.drag.type_strs.append(world.allocator, dup) catch {
            world.allocator.free(dup);
            return error.OutOfMemory;
        };
    }
}

fn handleXdndPosition(world: *root.World, impl: *WorldImpl, view: *root.View, msg: *XClientMessageEvent_t) void {
    _ = world;
    const display = impl.display;
    const drag = &impl.drag;
    const win: Window = @intFromPtr(view.handle orelse return);
    const time: Time = @intCast(msg.data.l[3]);
    const root_x: i32 = @intCast((msg.data.l[2] >> 16) & 0xFFFF);
    const root_y: i32 = @intCast(msg.data.l[2] & 0xFFFF);

    var win_x: c_int = 0;
    var win_y: c_int = 0;
    var child: Window = 0;
    _ = XTranslateCoordinates(
        display,
        XDefaultRootWindow(display),
        win,
        root_x,
        root_y,
        &win_x,
        &win_y,
        &child,
    );

    // XdndStatus reply
    var reply = XEvent{
        .client = .{
            .type = ClientMessage_ev,
            .serial = 0,
            .send_event = 1,
            .display = display,
            .window = drag.source,
            .message_type = impl.a_xdnd_status,
            .format = 32,
            .data = .{
                .l = .{
                    @intCast(win),
                    if (drag.targets.items.len > 0) 1 else 0, // accept
                    0,
                    0,
                    if (drag.targets.items.len > 0) @intCast(impl.a_xdnd_action_copy) else 0,
                },
            },
        },
    };
    _ = XSendEvent(display, drag.source, 0, NoEventMask, &reply);
    _ = XFlush(display);

    // Dispatch data_offer
    const offer = root.Event{ .data_offer = .{
        .time = @as(f64, @floatFromInt(time)) / 1000.0,
        .x = @floatFromInt(win_x),
        .y = @floatFromInt(win_y),
        .clipboard = .drag,
    } };
    _ = common.dispatchEvent(view, &offer);
}

fn handleXdndLeave(world: *root.World, impl: *WorldImpl) void {
    const drag = &impl.drag;
    for (drag.type_strs.items) |s| world.allocator.free(s);
    drag.type_strs.clearRetainingCapacity();
    drag.targets.clearRetainingCapacity();
    drag.source = 0;
    drag.accepted_target = 0;
    drag.buf.clearRetainingCapacity();
}

fn handleXdndDrop(world: *root.World, impl: *WorldImpl, view: *root.View, msg: *XClientMessageEvent_t) void {
    _ = world;
    const drag = &impl.drag;
    const win: Window = @intFromPtr(view.handle orelse return);
    drag.drop_time = @intCast(msg.data.l[2]);
    if (drag.accepted_target == 0 and drag.targets.items.len > 0) {
        drag.accepted_target = drag.targets.items[0];
        drag.accepted_index = 0;
    }
    if (drag.accepted_target != 0) {
        _ = XConvertSelection(
            impl.display,
            impl.a_xdnd_selection,
            drag.accepted_target,
            impl.a_xdnd_selection,
            win,
            drag.drop_time,
        );
        _ = XFlush(impl.display);
    }
}

fn handleXdndSelection(world: *root.World, impl: *WorldImpl, ev: *XSelectionEvent_t) void {
    const drag = &impl.drag;
    // Look up view from window
    const win_id: usize = @intCast(ev.requestor);
    const view = world.view_map.get(win_id) orelse return;

    if (ev.property != 0) {
        var actual_type: Atom = 0;
        var actual_format: c_int = 0;
        var nitems: c_ulong = 0;
        var bytes_after: c_ulong = 0;
        var prop_data: [*]u8 = undefined;
        const r = XGetWindowProperty(
            impl.display,
            ev.requestor,
            ev.property,
            0,
            0x7fffffff,
            1,
            AnyPropertyType,
            &actual_type,
            &actual_format,
            &nitems,
            &bytes_after,
            &prop_data,
        );
        if (r == 0) {
            defer _ = XFree(@ptrCast(prop_data));
            drag.buf.clearRetainingCapacity();
            drag.buf.appendSlice(world.allocator, prop_data[0..nitems]) catch {};
        }
    }

    // Send XdndFinished to source
    var reply = XEvent{
        .client = .{
            .type = ClientMessage_ev,
            .serial = 0,
            .send_event = 1,
            .display = impl.display,
            .window = drag.source,
            .message_type = impl.a_xdnd_finished,
            .format = 32,
            .data = .{
                .l = .{
                    @intCast(ev.requestor),
                    1, // accepted
                    @intCast(impl.a_xdnd_action_copy),
                    0,
                    0,
                },
            },
        },
    };
    _ = XSendEvent(impl.display, drag.source, 0, NoEventMask, &reply);
    _ = XFlush(impl.display);

    // Dispatch data event
    const dev = root.Event{ .data = .{
        .time = @as(f64, @floatFromInt(ev.time)) / 1000.0,
        .x = 0,
        .y = 0,
        .clipboard = .drag,
        .type_index = drag.accepted_index,
    } };
    _ = common.dispatchEvent(view, &dev);
}

fn getTimeNs() u64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}

fn checkTimers(world: *root.World, impl: *WorldImpl) void {
    _ = world;
    const now = getTimeNs();
    for (impl.timers.items) |*timer| {
        if (now >= timer.next_fire_ns) {
            _ = common.dispatchEvent(timer.view, &root.Event{ .timer = .{ .id = timer.id } });
            // Realign phase: skip missed ticks so next_fire_ns > now (matches pugl behavior).
            timer.next_fire_ns += timer.interval_ns;
            while (timer.next_fire_ns <= now) {
                timer.next_fire_ns += timer.interval_ns;
            }
        }
    }
}

// --- XC cursor constants (fallback when Xcursor unavailable) ---
const XC_left_ptr = 68;
const XC_xterm = 152;
const XC_crosshair = 34;
const XC_hand2 = 60;
const XC_X_cursor = 0;
const XC_sb_h_double_arrow = 108;
const XC_sb_v_double_arrow = 116;
const XC_bottom_right_corner = 14;
const XC_bottom_left_corner = 12;
const XC_fleur = 52;

fn loadCursor(display: *Display, win: Window, cursor: root.Cursor) void {
    // Try named Xcursor first, fall back to XCreateFontCursor
    const named: ?[*:0]const u8 = switch (cursor) {
        .arrow => "default",
        .caret => "text",
        .crosshair => "crosshair",
        .hand => "pointer",
        .no => "not-allowed",
        .left_right => "ew-resize",
        .up_down => "ns-resize",
        .up_left_down_right => "nwse-resize",
        .up_right_down_left => "nesw-resize",
        .all_scroll => "all-scroll",
    };
    const xc = if (named) |n| XcursorLibraryLoadCursor(display, n) else 0;
    const c = if (xc != 0) xc else blk: {
        const shape: c_uint = switch (cursor) {
            .arrow => XC_left_ptr,
            .caret => XC_xterm,
            .crosshair => XC_crosshair,
            .hand => XC_hand2,
            .no => XC_X_cursor,
            .left_right => XC_sb_h_double_arrow,
            .up_down => XC_sb_v_double_arrow,
            .up_left_down_right => XC_bottom_right_corner,
            .up_right_down_left => XC_bottom_left_corner,
            .all_scroll => XC_fleur,
        };
        break :blk XCreateFontCursor(display, shape);
    };
    _ = XDefineCursor(display, win, c);
    if (xc == 0) _ = XFreeCursor(display, c);
}

// --- Backend functions ---

pub fn deinitWorld(world: *root.World) void {
    const impl = getWorldImpl(world) orelse return;
    impl.timers.deinit(world.allocator);
    impl.fd_watchers.deinit(world.allocator);
    for (impl.drag.type_strs.items) |s| world.allocator.free(s);
    impl.drag.type_strs.deinit(world.allocator);
    impl.drag.targets.deinit(world.allocator);
    impl.drag.buf.deinit(world.allocator);
    if (impl.clipboard.owned_mime) |m| world.allocator.free(m);
    if (impl.clipboard.owned_data) |d| world.allocator.free(d);
    for (impl.clipboard.recv_type_strs.items) |s| world.allocator.free(s);
    impl.clipboard.recv_type_strs.deinit(world.allocator);
    impl.clipboard.recv_targets.deinit(world.allocator);
    impl.clipboard.recv_buf.deinit(world.allocator);
    if (impl.xim) |xim| _ = XCloseIM(xim);
    impl.xic_map.deinit(world.allocator);
    _ = XCloseDisplay(impl.display);
    world.allocator.destroy(impl);
    world.impl = null;
}

pub fn getNativeWorld(world: *root.World) ?*anyopaque {
    const impl = getWorldImpl(world) orelse return null;
    return impl.display;
}

pub fn getTime(world: *root.World) f64 {
    _ = world;
    return @as(f64, @floatFromInt(getTimeNs())) / 1_000_000_000.0;
}

pub fn update(world: *root.World, timeout: f64) root.Status {
    const impl = getWorldImpl(world) orelse return .realize_failed;
    const display = impl.display;

    // Drain all pending events
    while (XPending(display) > 0) {
        var xev: XEvent = undefined;
        _ = XNextEvent(display, &xev);
        processEvent(world, impl, &xev);
    }

    checkTimers(world, impl);

    if (timeout == 0) return .success;

    // Wait for events with timeout using poll (X connection FD + user-watched FDs)
    const x_fd = XConnectionNumber(display);
    const max_fds = impl.fd_watchers.items.len + 1;
    var pfd_buf: [16]std.posix.pollfd = undefined;
    const use_heap = max_fds > pfd_buf.len;
    const pfd_storage: []std.posix.pollfd = if (use_heap)
        (world.allocator.alloc(std.posix.pollfd, max_fds) catch pfd_buf[0..1])
    else
        pfd_buf[0..max_fds];
    defer if (use_heap and pfd_storage.len == max_fds) world.allocator.free(pfd_storage);

    pfd_storage[0] = .{ .fd = x_fd, .events = std.posix.POLL.IN, .revents = 0 };
    var nfds: usize = 1;
    for (impl.fd_watchers.items) |w| {
        if (nfds >= pfd_storage.len) break;
        pfd_storage[nfds] = .{ .fd = w.fd, .events = std.posix.POLL.IN, .revents = 0 };
        nfds += 1;
    }
    const ms: i32 = if (timeout < 0) -1 else @intCast(@min(@as(i64, @intFromFloat(timeout * 1000)), std.math.maxInt(i32)));
    _ = std.posix.poll(pfd_storage[0..nfds], ms) catch {};

    // Dispatch FD watcher callbacks for ready FDs
    var i: usize = 1;
    while (i < nfds) : (i += 1) {
        if ((pfd_storage[i].revents & std.posix.POLL.IN) != 0) {
            const fd = pfd_storage[i].fd;
            for (impl.fd_watchers.items) |w| {
                if (w.fd == fd) {
                    w.callback(fd, w.user_data);
                    break;
                }
            }
        }
    }

    while (XPending(display) > 0) {
        var xev: XEvent = undefined;
        _ = XNextEvent(display, &xev);
        processEvent(world, impl, &xev);
    }

    checkTimers(world, impl);

    return .success;
}

pub fn createView(view: *root.View) root.Status {
    const impl = getOrInitWorldImpl(view.world) catch return .realize_failed;
    const display = impl.display;
    const screen = XDefaultScreen(display);

    const parent: Window = if (view.parent != 0)
        @intCast(view.parent)
    else
        XDefaultRootWindow(display);

    const sz = view.size_hints[@backingInt(root.SizeHint.default_size)];
    const pos = view.pos_hints[@backingInt(root.PositionHint.default_position)];
    const w: c_uint = if (sz.width == 0) 800 else sz.width;
    const h: c_uint = if (sz.height == 0) 600 else sz.height;
    const placed = view.parent != 0 or onScreen(display, screen, pos, w, h);
    const x: c_int = if (placed and pos.x != std.math.minInt(i16)) pos.x else 0;
    const y: c_int = if (placed and pos.y != std.math.minInt(i16)) pos.y else 0;

    const black = XBlackPixel(display, screen);
    const win = XCreateSimpleWindow(display, parent, x, y, w, h, 0, black, black);
    if (win == 0) return .realize_failed;

    _ = XSelectInput(display, win, KeyPressMask | KeyReleaseMask |
        ButtonPressMask | ButtonReleaseMask |
        EnterWindowMask | LeaveWindowMask |
        PointerMotionMask | ExposureMask |
        StructureNotifyMask | FocusChangeMask | PropertyChangeMask);

    // WM close button
    if (view.parent == 0) {
        var proto = impl.wm_delete_window;
        _ = XSetWMProtocols(display, win, &proto, 1);
    }

    // Window title
    const title = view.getViewString(.window_title);
    if (title.len > 0) {
        // Stack-allocate null-terminated title
        var buf: [256]u8 = undefined;
        const n = @min(title.len, buf.len - 1);
        @memcpy(buf[0..n], title[0..n]);
        buf[n] = 0;
        _ = XStoreName(display, win, buf[0..n :0]);
    }

    // WM_CLASS hint (application_name + class_name)
    const app_name = view.world.getString(.application_name);
    const class_name = view.world.getString(.class_name);
    if (app_name.len > 0 or class_name.len > 0) {
        var name_buf: [128]u8 = undefined;
        var class_buf: [128]u8 = undefined;
        const an = @min(app_name.len, name_buf.len - 1);
        const cn = @min(class_name.len, class_buf.len - 1);
        @memcpy(name_buf[0..an], app_name[0..an]);
        name_buf[an] = 0;
        @memcpy(class_buf[0..cn], class_name[0..cn]);
        class_buf[cn] = 0;
        var hint = XClassHint{
            .res_name = @ptrCast(&name_buf),
            .res_class = @ptrCast(&class_buf),
        };
        _ = XSetClassHint(display, win, &hint);
    }

    // XdndAware = 5
    {
        const version: c_long = 5;
        _ = XChangeProperty(
            display,
            win,
            impl.a_xdnd_aware,
            XA_ATOM,
            32,
            PropModeReplace,
            @ptrCast(&version),
            1,
        );
    }

    // Size hints
    applyWMSizeHints(display, win, view, placed);

    if (view.parent != 0) _ = XMapWindow(display, win);
    _ = XFlush(display);

    view.handle = @ptrFromInt(win);
    view.visible = view.parent != 0;

    if (impl.xim) |xim| {
        const xic = XCreateIC(xim, "inputStyle", XIMPreeditNothing | XIMStatusNothing, "clientWindow", win, "focusWindow", win, @as(?*anyopaque, null));
        if (xic) |ic| {
            impl.xic_map.put(view.world.allocator, win, ic) catch {};
        }
    }

    return .success;
}

fn onScreen(display: *Display, screen: c_int, pos: root.Point, w: c_uint, h: c_uint) bool {
    if (pos.x == std.math.minInt(i16) or pos.y == std.math.minInt(i16)) return true;
    return pos.x < XDisplayWidth(display, screen) and pos.y < XDisplayHeight(display, screen) and
        @as(i64, pos.x) + w > 0 and @as(i64, pos.y) + h > 0;
}

fn applyWMSizeHints(display: *Display, win: Window, view: *root.View, placed: bool) void {
    const mins = view.size_hints[@backingInt(root.SizeHint.min_size)];
    const maxs = view.size_hints[@backingInt(root.SizeHint.max_size)];
    const pos = view.pos_hints[@backingInt(root.PositionHint.default_position)];
    const place = placed and view.parent == 0 and pos.x != std.math.minInt(i16) and pos.y != std.math.minInt(i16);
    if (!place and mins.width == 0 and mins.height == 0 and maxs.width == 0 and maxs.height == 0) return;
    const hints = XAllocSizeHints() orelse return;
    defer _ = XFree(hints);
    hints.flags = 0;
    if (place) {
        hints.flags |= USPosition | PWinGravity;
        hints.x = pos.x;
        hints.y = pos.y;
        hints.win_gravity = StaticGravity;
    }
    if (mins.width > 0 or mins.height > 0) {
        hints.flags |= PMinSize;
        hints.min_width = mins.width;
        hints.min_height = mins.height;
    }
    if (maxs.width > 0 or maxs.height > 0) {
        hints.flags |= PMaxSize;
        hints.max_width = if (maxs.width == 0) 32767 else maxs.width;
        hints.max_height = if (maxs.height == 0) 32767 else maxs.height;
    }
    XSetWMNormalHints(display, win, hints);
}

pub fn destroyView(view: *root.View) void {
    const impl = getWorldImpl(view.world) orelse return;
    if (view.handle) |h| {
        const win: Window = @intFromPtr(h);
        if (impl.xic_map.fetchRemove(win)) |kv| {
            XDestroyIC(kv.value);
        }
        _ = XDestroyWindow(impl.display, win);
        _ = XFlush(impl.display);
        view.handle = null;
    }
}

pub fn showView(view: *root.View, command: root.ShowCommand) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    _ = XMapWindow(impl.display, win);
    if (command == .raise or command == .force_raise) {
        _ = XRaiseWindow(impl.display, win);
    }
    _ = XFlush(impl.display);
    view.visible = true;
    return .success;
}

pub fn hideView(view: *root.View) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    _ = XUnmapWindow(impl.display, win);
    _ = XFlush(impl.display);
    view.visible = false;
    return .success;
}

pub fn setViewSize(view: *root.View, w: u32, h: u32) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    _ = XResizeWindow(impl.display, win, @intCast(w), @intCast(h));
    _ = XFlush(impl.display);
    return .success;
}

pub fn getWindowPosition(view: *root.View) ?root.Point {
    const impl = getWorldImpl(view.world) orelse return null;
    const win: Window = @intFromPtr(view.handle orelse return null);
    var x: c_int = 0;
    var y: c_int = 0;
    var child: Window = 0;
    _ = XTranslateCoordinates(impl.display, win, XDefaultRootWindow(impl.display), 0, 0, &x, &y, &child);
    return .{ .x = @intCast(std.math.clamp(x, std.math.minInt(i16) + 1, std.math.maxInt(i16))), .y = @intCast(std.math.clamp(y, std.math.minInt(i16) + 1, std.math.maxInt(i16))) };
}

pub fn setViewPosition(view: *root.View, x: i32, y: i32) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    _ = XMoveWindow(impl.display, win, @intCast(x), @intCast(y));
    _ = XFlush(impl.display);
    return .success;
}

pub fn applySizeHints(view: *root.View) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    applyWMSizeHints(impl.display, win, view, false);
    return .success;
}

pub fn getScaleFactor(view: *root.View) f64 {
    _ = view;
    return 1.0; // X11 DPI scaling is app-managed; return 1 as baseline
}

pub fn setViewStyle(view: *root.View, flags: root.ViewStyleFlags) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    const display = impl.display;
    const old = view.style;
    const root_win = XDefaultRootWindow(display);

    const Pair = struct { mask: u32, atom: Atom };
    const pairs = [_]Pair{
        .{ .mask = @as(u32, 1) << 1, .atom = impl.a_net_wm_state_modal }, // modal
        .{ .mask = @as(u32, 1) << 2, .atom = impl.a_net_wm_state_above }, // above
        .{ .mask = @as(u32, 1) << 3, .atom = impl.a_net_wm_state_below }, // below
        .{ .mask = @as(u32, 1) << 4, .atom = impl.a_net_wm_state_hidden }, // hidden
        .{ .mask = @as(u32, 1) << 5, .atom = impl.a_net_wm_state_maximized_vert }, // tall
        .{ .mask = @as(u32, 1) << 6, .atom = impl.a_net_wm_state_maximized_horz }, // wide
        .{ .mask = @as(u32, 1) << 7, .atom = impl.a_net_wm_state_fullscreen }, // fullscreen
        .{ .mask = @as(u32, 1) << 9, .atom = impl.a_net_wm_state_demands_attention }, // demanding
    };

    const old_bits: u32 = @bitCast(old);
    const new_bits: u32 = @bitCast(flags);

    for (pairs) |p| {
        const old_v = (old_bits & p.mask) != 0;
        const new_v = (new_bits & p.mask) != 0;
        if (old_v == new_v) continue;
        if (p.atom == impl.a_net_wm_state_hidden) {
            _ = XIconifyWindow(display, win, impl.screen);
            continue;
        }
        var ev = XEvent{ .client = .{
            .type = ClientMessage_ev,
            .serial = 0,
            .send_event = 1,
            .display = display,
            .window = win,
            .message_type = impl.a_net_wm_state,
            .format = 32,
            .data = .{ .l = .{
                if (new_v) WM_STATE_ADD else WM_STATE_REMOVE,
                @intCast(p.atom),
                0,
                1,
                0,
            } },
        } };
        if (XSendEvent(display, root_win, 0, SubstructureNotifyMask | SubstructureRedirectMask, &ev) == 0) {
            return .unknown_error;
        }
    }
    view.style = flags;
    _ = XFlush(display);
    return .success;
}

pub fn setTransientParent(view: *root.View, parent: root.NativeView) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    if (view.parent != 0) return .failure;
    if (view.handle) |h| {
        if (parent != 0) {
            const win: Window = @intFromPtr(h);
            _ = XSetTransientForHint(impl.display, win, @intCast(parent));
        }
    }
    return .success;
}

pub fn watchFD(
    world: *root.World,
    fd: c_int,
    user_data: ?*anyopaque,
    callback: *const fn (fd: c_int, user_data: ?*anyopaque) void,
) root.Status {
    const impl = getOrInitWorldImpl(world) catch return .realize_failed;
    impl.fd_watchers.append(world.allocator, .{
        .fd = fd,
        .user_data = user_data,
        .callback = callback,
    }) catch return .no_memory;
    return .success;
}

pub fn unwatchFD(world: *root.World, fd: c_int) root.Status {
    const impl = getWorldImpl(world) orelse return .bad_call;
    for (impl.fd_watchers.items, 0..) |w, i| {
        if (w.fd == fd) {
            _ = impl.fd_watchers.swapRemove(i);
            return .success;
        }
    }
    return .failure;
}

pub fn obscureView(view: *root.View) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    var ev = XEvent{ .expose = .{
        .type = Expose_ev,
        .serial = 0,
        .send_event = 1,
        .display = impl.display,
        .window = win,
        .x = 0,
        .y = 0,
        .width = 0,
        .height = 0,
        .count = 0,
    } };
    _ = XSendEvent(impl.display, win, 0, ExposureMask, &ev);
    _ = XFlush(impl.display);
    return .success;
}

pub fn obscureRegion(view: *root.View, x: i32, y: i32, w: u32, h: u32) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    var ev = XEvent{ .expose = .{
        .type = Expose_ev,
        .serial = 0,
        .send_event = 1,
        .display = impl.display,
        .window = win,
        .x = @intCast(x),
        .y = @intCast(y),
        .width = @intCast(w),
        .height = @intCast(h),
        .count = 0,
    } };
    _ = XSendEvent(impl.display, win, 0, ExposureMask, &ev);
    _ = XFlush(impl.display);
    return .success;
}

pub fn grabFocus(view: *root.View) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    _ = XSetInputFocus(impl.display, win, RevertToParent, CurrentTime);
    _ = XFlush(impl.display);
    return .success;
}

pub fn hasFocus(view: *root.View) bool {
    const impl = getWorldImpl(view.world) orelse return false;
    var focused: Window = 0;
    var revert: c_int = 0;
    _ = XGetInputFocus(impl.display, &focused, &revert);
    const win: Window = @intFromPtr(view.handle orelse return false);
    return focused == win;
}

pub fn setCursor(view: *root.View, cursor: root.Cursor) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    loadCursor(impl.display, win, cursor);
    _ = XFlush(impl.display);
    return .success;
}

pub fn startTimer(world: *root.World, view: *root.View, id: usize, freq: f64) root.Status {
    const impl = getWorldImpl(world) orelse return .bad_call;
    if (freq <= 0) return .bad_parameter;
    const interval_ns: u64 = @intFromFloat(1_000_000_000.0 / freq);
    // Replace existing timer with same id
    for (impl.timers.items) |*t| {
        if (t.id == id and t.view == view) {
            t.interval_ns = interval_ns;
            t.next_fire_ns = getTimeNs() + interval_ns;
            return .success;
        }
    }
    impl.timers.append(world.allocator, .{
        .id = id,
        .view = view,
        .interval_ns = interval_ns,
        .next_fire_ns = getTimeNs() + interval_ns,
    }) catch return .no_memory;
    return .success;
}

pub fn stopTimer(world: *root.World, view: *root.View, id: usize) root.Status {
    const impl = getWorldImpl(world) orelse return .bad_call;
    for (impl.timers.items, 0..) |t, i| {
        if (t.id == id and t.view == view) {
            _ = impl.timers.swapRemove(i);
            return .success;
        }
    }
    return .failure;
}

pub fn sendEvent(view: *root.View, event: *const root.Event) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    if (@as(root.EventType, event.*) == .client) {
        var xev = XEvent{ .client = .{
            .type = ClientMessage_ev,
            .serial = 0,
            .send_event = 1,
            .display = impl.display,
            .window = win,
            .message_type = impl.a_pugl_client_msg,
            .format = 32,
            .data = .{ .l = .{
                @intCast(event.client.data1),
                @intCast(event.client.data2),
                0,
                0,
                0,
            } },
        } };
        _ = XSendEvent(impl.display, win, 0, 0, &xev);
        _ = XFlush(impl.display);
        return .success;
    }
    return .unsupported;
}

pub fn registerDropType(view: *root.View, mime_type: []const u8) root.Status {
    _ = view;
    _ = mime_type;
    return .success;
}

pub fn paste(view: *root.View) root.Status {
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    impl.clipboard.recv_view = view;
    impl.clipboard.accepted_target = 0;
    _ = XConvertSelection(impl.display, impl.a_clipboard, impl.a_targets, impl.a_zpugl_sel, win, CurrentTime);
    _ = XFlush(impl.display);
    return .success;
}

pub fn getNumClipboardTypes(view: *root.View, clipboard: root.Clipboard) u32 {
    const impl = getWorldImpl(view.world) orelse return 0;
    if (clipboard != .general) return 0;
    return @intCast(impl.clipboard.recv_type_strs.items.len);
}

pub fn getClipboardType(view: *root.View, clipboard: root.Clipboard, type_index: u32) ?[]const u8 {
    const impl = getWorldImpl(view.world) orelse return null;
    if (clipboard != .general) return null;
    if (type_index >= impl.clipboard.recv_type_strs.items.len) return null;
    return impl.clipboard.recv_type_strs.items[type_index];
}

pub fn acceptOffer(
    view: *root.View,
    offer: *const root.DataOfferEvent,
    type_index: u32,
    action: root.DataAction,
    rx: i32,
    ry: i32,
    rw: u32,
    rh: u32,
) root.Status {
    _ = offer;
    _ = action;
    _ = rx;
    _ = ry;
    _ = rw;
    _ = rh;
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    if (type_index >= impl.clipboard.recv_targets.items.len) return .bad_parameter;
    const target = impl.clipboard.recv_targets.items[type_index];
    impl.clipboard.accepted_target = target;
    _ = XConvertSelection(impl.display, impl.a_clipboard, target, impl.a_zpugl_sel, win, CurrentTime);
    _ = XFlush(impl.display);
    return .success;
}

pub fn rejectOffer(view: *root.View, offer: *const root.DataOfferEvent, rx: i32, ry: i32, rw: u32, rh: u32) root.Status {
    _ = offer;
    _ = rx;
    _ = ry;
    _ = rw;
    _ = rh;
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    impl.clipboard.recv_view = null;
    return .success;
}

pub fn setClipboard(view: *root.View, clipboard: root.Clipboard, mime_type: []const u8, data: []const u8) root.Status {
    if (clipboard != .general) return .unsupported;
    const impl = getWorldImpl(view.world) orelse return .bad_call;
    const win: Window = @intFromPtr(view.handle orelse return .bad_call);
    const allocator = view.world.allocator;
    if (impl.clipboard.owned_mime) |m| allocator.free(m);
    if (impl.clipboard.owned_data) |d| allocator.free(d);
    impl.clipboard.owned_mime = allocator.dupe(u8, mime_type) catch return .no_memory;
    impl.clipboard.owned_data = allocator.dupe(u8, data) catch return .no_memory;
    _ = XSetSelectionOwner(impl.display, impl.a_clipboard, win, CurrentTime);
    // Sync so the ownership change is visible before we query it.
    _ = XSync(impl.display, 0);
    if (XGetSelectionOwner(impl.display, impl.a_clipboard) != win) return .failure;
    return .success;
}

pub fn getClipboard(view: *root.View, clipboard: root.Clipboard, type_index: u32) ?[]const u8 {
    _ = type_index;
    const impl = getWorldImpl(view.world) orelse return null;
    if (clipboard != .general) return null;
    if (impl.clipboard.recv_buf.items.len > 0) return impl.clipboard.recv_buf.items;
    return impl.clipboard.owned_data;
}

pub fn startTextInput(view: *root.View, rect: root.TextInputRect) root.Status {
    const impl = getWorldImpl(view.world) orelse return .success;
    const win: Window = @intFromPtr(view.handle orelse return .success);
    const xic = impl.xic_map.get(win) orelse return .success;
    var spot = XPoint{
        .x = @intCast(@min(@max(rect.x, std.math.minInt(c_short)), std.math.maxInt(c_short))),
        .y = @intCast(@min(@max(rect.y +| @as(i32, @intCast(@min(rect.height, std.math.maxInt(i16)))), std.math.minInt(c_short)), std.math.maxInt(c_short))),
    };
    _ = XSetICValues(xic, XNSpotLocation, &spot, @as(?*anyopaque, null));
    XSetICFocus(xic);
    return .success;
}

pub fn stopTextInput(view: *root.View) root.Status {
    const impl = getWorldImpl(view.world) orelse return .success;
    const win: Window = @intFromPtr(view.handle orelse return .success);
    const xic = impl.xic_map.get(win) orelse return .success;
    XUnsetICFocus(xic);
    return .success;
}

pub fn setTextInputRect(view: *root.View, rect: root.TextInputRect) root.Status {
    const impl = getWorldImpl(view.world) orelse return .success;
    const win: Window = @intFromPtr(view.handle orelse return .success);
    const xic = impl.xic_map.get(win) orelse return .success;
    var spot = XPoint{
        .x = @intCast(@min(@max(rect.x, std.math.minInt(c_short)), std.math.maxInt(c_short))),
        .y = @intCast(@min(@max(rect.y +| @as(i32, @intCast(@min(rect.height, std.math.maxInt(i16)))), std.math.minInt(c_short)), std.math.maxInt(c_short))),
    };
    _ = XSetICValues(xic, XNSpotLocation, &spot, @as(?*anyopaque, null));
    return .success;
}

extern "c" fn posix_spawnp(pid: *std.c.pid_t, file: [*:0]const u8, file_actions: ?*const anyopaque, attrp: ?*const anyopaque, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) c_int;

pub fn openUrl(url: [:0]const u8) root.Status {
    const argv = [_:null]?[*:0]const u8{ "sh", "-c", "xdg-open \"$1\" >/dev/null 2>&1 &", "sh", url.ptr };
    var pid: std.c.pid_t = 0;
    if (posix_spawnp(&pid, "sh", null, null, &argv, @ptrCast(std.c.environ)) != 0) return .failure;
    _ = std.c.waitpid(pid, null, 0);
    return .success;
}

pub fn prefersDark(view: *root.View) ?bool {
    _ = view;
    return null;
}
