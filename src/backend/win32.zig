const std = @import("std");
const root = @import("../root.zig");
const common = root.common;

// --- Win32 types ---

pub const HWND = ?*anyopaque;
pub const HINSTANCE = ?*anyopaque;
pub const HICON = ?*anyopaque;
pub const HCURSOR = ?*anyopaque;
pub const HBRUSH = ?*anyopaque;
pub const HDC = ?*anyopaque;
pub const HGLRC = ?*anyopaque;
pub const HMENU = ?*anyopaque;
pub const HMODULE = ?*anyopaque;
pub const HANDLE = ?*anyopaque;
pub const BOOL = c_int;
pub const UINT = u32;
pub const DWORD = u32;
pub const WORD = u16;
pub const LONG = i32;
pub const LONG_PTR = isize;
pub const UINT_PTR = usize;
pub const LRESULT = isize;
pub const WPARAM = usize;
pub const LPARAM = isize;
pub const ATOM = u16;

pub const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.winapi) LRESULT;

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXW),
    style: UINT = 0,
    lpfnWndProc: WNDPROC,
    cbClsExtra: c_int = 0,
    cbWndExtra: c_int = 0,
    hInstance: HINSTANCE = null,
    hIcon: HICON = null,
    hCursor: HCURSOR = null,
    hbrBackground: HBRUSH = null,
    lpszMenuName: ?[*:0]const u16 = null,
    lpszClassName: [*:0]const u16,
    hIconSm: HICON = null,
};

pub const MSG = extern struct {
    hwnd: HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: extern struct { x: LONG, y: LONG },
    lPrivate: DWORD = 0,
};

pub const RECT = extern struct { left: LONG, top: LONG, right: LONG, bottom: LONG };

pub const POINT = extern struct { x: LONG, y: LONG };

pub const MINMAXINFO = extern struct {
    ptReserved: POINT,
    ptMaxSize: POINT,
    ptMaxPosition: POINT,
    ptMinTrackSize: POINT,
    ptMaxTrackSize: POINT,
};

pub const PIXELFORMATDESCRIPTOR = extern struct {
    nSize: WORD = @sizeOf(PIXELFORMATDESCRIPTOR),
    nVersion: WORD = 1,
    dwFlags: DWORD = 0,
    iPixelType: u8 = 0,
    cColorBits: u8 = 0,
    cRedBits: u8 = 0,
    cRedShift: u8 = 0,
    cGreenBits: u8 = 0,
    cGreenShift: u8 = 0,
    cBlueBits: u8 = 0,
    cBlueShift: u8 = 0,
    cAlphaBits: u8 = 0,
    cAlphaShift: u8 = 0,
    cAccumBits: u8 = 0,
    cAccumRedBits: u8 = 0,
    cAccumGreenBits: u8 = 0,
    cAccumBlueBits: u8 = 0,
    cAccumAlphaBits: u8 = 0,
    cDepthBits: u8 = 0,
    cStencilBits: u8 = 0,
    cAuxBuffers: u8 = 0,
    iLayerType: u8 = 0,
    bReserved: u8 = 0,
    dwLayerMask: DWORD = 0,
    dwVisibleMask: DWORD = 0,
    dwDamageMask: DWORD = 0,
};

// Window messages
const WM_DESTROY = 0x0002;
const WM_SIZE = 0x0005;
const WM_SHOWWINDOW = 0x0018;
const SIZE_MINIMIZED = 1;
const WM_PAINT = 0x000F;
const WM_CLOSE = 0x0010;
const WM_ENTERSIZEMOVE = 0x0231;
const WM_EXITSIZEMOVE = 0x0232;
const WM_SETFOCUS = 0x0007;
const WM_KILLFOCUS = 0x0008;
const WM_KEYDOWN = 0x0100;
const WM_KEYUP = 0x0101;
const WM_CHAR = 0x0102;
const WM_SYSKEYDOWN = 0x0104;
const WM_SYSKEYUP = 0x0105;
const WM_SYSDEADCHAR = 0x0107;
const WM_GETDLGCODE = 0x0087;
const DLGC_WANT_KEYS: LRESULT = 0x0001 | 0x0002 | 0x0004 | 0x0080; // arrows, tab, all keys, chars
const WM_IME_SETCONTEXT = 0x0281;
const WM_IME_KEYUP = 0x0291;
const GWLP_WNDPROC: c_int = -4;
const EDIT_CLASS = std.unicode.utf8ToUtf16LeStringLiteral("EDIT");
const WM_MOUSEMOVE = 0x0200;
const WM_LBUTTONDOWN = 0x0201;
const WM_LBUTTONUP = 0x0202;
const WM_RBUTTONDOWN = 0x0204;
const WM_RBUTTONUP = 0x0205;
const WM_MBUTTONDOWN = 0x0207;
const WM_MBUTTONUP = 0x0208;
const WM_MOUSEWHEEL = 0x020A;
const WM_MOUSEHWHEEL = 0x020E;
const WM_MOUSELEAVE = 0x02A3;
const WM_SETCURSOR = 0x0020;
const HTCLIENT = 1;
const WM_TIMER = 0x0113;
const WM_USER = 0x0400;
const WM_GETMINMAXINFO = 0x0024;
const WM_IME_STARTCOMPOSITION = 0x010D;
const WM_IME_ENDCOMPOSITION = 0x010E;
const WM_IME_COMPOSITION = 0x010F;
const WM_IME_CHAR = 0x0286;
const GCS_RESULTSTR: DWORD = 0x0800;

// Window styles
const WS_OVERLAPPEDWINDOW: DWORD = 0x00CF0000;
const WS_CHILD: DWORD = 0x40000000;
const WS_VISIBLE: DWORD = 0x10000000;
const WS_CLIPCHILDREN: DWORD = 0x02000000;
const WS_CLIPSIBLINGS: DWORD = 0x04000000;
const WS_THICKFRAME: DWORD = 0x00040000;
const WS_MAXIMIZEBOX: DWORD = 0x00010000;
const WS_POPUP: DWORD = 0x80000000;
const WS_BORDER: DWORD = 0x00800000;
const WS_CAPTION: DWORD = 0x00C00000;
const WS_SYSMENU: DWORD = 0x00080000;
const WS_MINIMIZEBOX: DWORD = 0x00020000;

const WS_EX_TOPMOST: DWORD = 0x00000008;
const WS_EX_TOOLWINDOW: DWORD = 0x00000080;
const WS_EX_DLGMODALFRAME: DWORD = 0x00000001;

const GWL_STYLE: c_int = -16;
const GWL_EXSTYLE: c_int = -20;

const SWP_FRAMECHANGED: DWORD = 0x0020;
const SWP_NOSIZE: DWORD = 0x0001;
const SWP_NOOWNERZORDER: DWORD = 0x0200;
const HWND_TOPMOST: HWND = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));
const HWND_NOTOPMOST: HWND = @ptrFromInt(@as(usize, @bitCast(@as(isize, -2))));

// Clipboard
const CF_UNICODETEXT: UINT = 13;
const GMEM_MOVEABLE: UINT = 0x0002;

// FlashWindow
const FLASHW_ALL: DWORD = 0x00000003;
const FLASHW_TIMERNOFG: DWORD = 0x0000000C;

// ShowWindow commands
const SW_HIDE = 0;
const SW_SHOW = 5;
const SW_SHOWNOACTIVATE = 4;
const SW_SHOWNA = 8;
const SW_MAXIMIZE = 3;
const SW_MINIMIZE = 6;
const SW_RESTORE = 9;
const SW_SHOWMINIMIZED = 2;

// SetWindowPos flags
const SWP_NOACTIVATE: DWORD = 0x0010;
const SWP_NOMOVE: DWORD = 0x0002;
const SWP_NOZORDER: DWORD = 0x0004;

// Virtual key codes
const VK_BACK = 0x08;
const VK_TAB = 0x09;
const VK_RETURN = 0x0D;
const VK_ESCAPE = 0x1B;
const VK_DELETE = 0x2E;
const VK_PRIOR = 0x21; // Page Up
const VK_NEXT = 0x22; // Page Down
const VK_END = 0x23;
const VK_HOME = 0x24;
const VK_LEFT = 0x25;
const VK_UP = 0x26;
const VK_RIGHT = 0x27;
const VK_DOWN = 0x28;
const VK_INSERT = 0x2D;
const VK_SNAPSHOT = 0x2C; // Print Screen
const VK_PAUSE = 0x13;
const VK_NUMLOCK = 0x90;
const VK_SCROLL = 0x91;
const VK_CAPITAL = 0x14;
const VK_SHIFT = 0x10;
const VK_CONTROL = 0x11;
const VK_MENU = 0x12; // Alt
const VK_LSHIFT = 0xA0;
const VK_RSHIFT = 0xA1;
const VK_LCONTROL = 0xA2;
const VK_RCONTROL = 0xA3;
const VK_LMENU = 0xA4;
const VK_RMENU = 0xA5;
const VK_LWIN = 0x5B;
const VK_RWIN = 0x5C;
const VK_APPS = 0x5D; // Menu
const VK_F1 = 0x70;
const VK_NUMPAD0 = 0x60;
const VK_ADD = 0x6B;
const VK_SEPARATOR = 0x6C;
const VK_SUBTRACT = 0x6D;
const VK_DECIMAL = 0x6E;
const VK_DIVIDE = 0x6F;
const VK_MULTIPLY = 0x6A;

// Key state masks for GetKeyState
const MK_SHIFT: WPARAM = 0x0004;
const MK_CONTROL: WPARAM = 0x0008;

// GWLP_USERDATA
const GWLP_USERDATA: c_int = -21;
const GWLP_HWNDPARENT: c_int = -8;

// PIXELFORMATDESCRIPTOR flags
pub const PFD_DRAW_TO_WINDOW: DWORD = 0x00000004;
pub const PFD_DRAW_TO_BITMAP: DWORD = 0x00000008;
pub const PFD_SUPPORT_OPENGL: DWORD = 0x00000020;
pub const PFD_DOUBLEBUFFER: DWORD = 0x00000001;
pub const PFD_GENERIC_FORMAT: DWORD = 0x00000040;
pub const PFD_GENERIC_ACCELERATED: DWORD = 0x00001000;
pub const PFD_TYPE_RGBA: u8 = 0;

// Timer ID base (avoid conflict with user timers which start at 0)
const TIMER_ID_BASE: UINT_PTR = 0x8000_0000;

// --- Win32 extern functions ---

pub extern "user32" fn RegisterClassExW(lpWndClass: *const WNDCLASSEXW) callconv(.winapi) ATOM;
pub extern "kernel32" fn GetLastError() callconv(.winapi) DWORD;
pub extern "user32" fn UnregisterClassW(lpClassName: [*:0]const u16, hInstance: HINSTANCE) callconv(.winapi) BOOL;
pub extern "user32" fn CreateWindowExW(dwExStyle: DWORD, lpClassName: [*:0]const u16, lpWindowName: ?[*:0]const u16, dwStyle: DWORD, x: c_int, y: c_int, nWidth: c_int, nHeight: c_int, hWndParent: HWND, hMenu: HMENU, hInstance: HINSTANCE, lpParam: ?*anyopaque) callconv(.winapi) HWND;
pub extern "user32" fn DestroyWindow(hWnd: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: c_int) callconv(.winapi) BOOL;
pub extern "user32" fn SetWindowPos(hWnd: HWND, hWndInsertAfter: HWND, x: c_int, y: c_int, cx: c_int, cy: c_int, uFlags: UINT) callconv(.winapi) BOOL;
pub extern "user32" fn GetWindowRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
pub extern "user32" fn MonitorFromRect(lprc: *const RECT, dwFlags: DWORD) callconv(.winapi) ?*anyopaque;
pub extern "user32" fn IsIconic(hWnd: HWND) callconv(.winapi) BOOL;
extern "user32" fn IsWindowVisible(hWnd: HWND) callconv(.winapi) BOOL;
extern "user32" fn GetAncestor(hWnd: HWND, flags: UINT) callconv(.winapi) HWND;
const GA_ROOT: UINT = 2;
pub extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) callconv(.winapi) BOOL;
pub extern "user32" fn InvalidateRect(hWnd: HWND, lpRect: ?*const RECT, bErase: BOOL) callconv(.winapi) BOOL;
pub extern "user32" fn BeginPaint(hWnd: HWND, lpPaint: *anyopaque) callconv(.winapi) HDC;
pub extern "user32" fn EndPaint(hWnd: HWND, lpPaint: *anyopaque) callconv(.winapi) BOOL;
pub extern "user32" fn ValidateRect(hWnd: HWND, lpRect: ?*const RECT) callconv(.winapi) BOOL;
pub extern "user32" fn DefWindowProcW(hWnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
pub extern "user32" fn PostQuitMessage(nExitCode: c_int) callconv(.winapi) void;
pub extern "user32" fn PeekMessageW(lpMsg: *MSG, hWnd: HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(.winapi) BOOL;
pub extern "user32" fn MapVirtualKeyW(code: UINT, map_type: UINT) callconv(.winapi) UINT;
pub extern "user32" fn ToUnicode(vk: UINT, scan: UINT, state: *const [256]u8, buf: [*]u16, len: c_int, flags: UINT) callconv(.winapi) c_int;
const MAPVK_VSC_TO_VK_EX = 3;
pub extern "user32" fn UpdateWindow(hWnd: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.winapi) BOOL;
pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(.winapi) LRESULT;
pub extern "user32" fn MsgWaitForMultipleObjects(nCount: DWORD, pHandles: ?*const HANDLE, fWaitAll: BOOL, dwMilliseconds: DWORD, dwWakeMask: DWORD) callconv(.winapi) DWORD;
pub extern "user32" fn SetWindowLongPtrW(hWnd: HWND, nIndex: c_int, dwNewLong: LONG_PTR) callconv(.winapi) LONG_PTR;
pub extern "user32" fn GetWindowLongPtrW(hWnd: HWND, nIndex: c_int) callconv(.winapi) LONG_PTR;
pub extern "user32" fn SetWindowTextW(hWnd: HWND, lpString: [*:0]const u16) callconv(.winapi) BOOL;
pub extern "user32" fn SetFocus(hWnd: HWND) callconv(.winapi) HWND;
pub extern "user32" fn GetFocus() callconv(.winapi) HWND;
pub extern "user32" fn SetCapture(hWnd: HWND) callconv(.winapi) HWND;
pub extern "user32" fn ReleaseCapture() callconv(.winapi) BOOL;
pub extern "user32" fn LoadCursorW(hInstance: HINSTANCE, lpCursorName: usize) callconv(.winapi) HCURSOR;
pub extern "user32" fn SetCursor(hCursor: HCURSOR) callconv(.winapi) HCURSOR;
pub extern "shell32" fn ShellExecuteW(hwnd: HWND, op: ?[*:0]const u16, file: [*:0]const u16, params: ?[*:0]const u16, dir: ?[*:0]const u16, show: c_int) callconv(.winapi) ?*anyopaque;
pub extern "user32" fn SetTimer(hWnd: HWND, nIDEvent: UINT_PTR, uElapse: UINT, lpTimerFunc: ?*anyopaque) callconv(.winapi) UINT_PTR;
pub extern "user32" fn KillTimer(hWnd: HWND, uIDEvent: UINT_PTR) callconv(.winapi) BOOL;
pub extern "user32" fn GetDpiForWindow(hwnd: HWND) callconv(.winapi) UINT;
pub extern "user32" fn TrackMouseEvent(lpEventTrack: *anyopaque) callconv(.winapi) BOOL;
pub extern "user32" fn GetCursorPos(lpPoint: *POINT) callconv(.winapi) BOOL;
pub extern "user32" fn ScreenToClient(hWnd: HWND, lpPoint: *POINT) callconv(.winapi) BOOL;
pub extern "user32" fn AdjustWindowRectEx(lpRect: *RECT, dwStyle: DWORD, bMenu: BOOL, dwExStyle: DWORD) callconv(.winapi) BOOL;
pub extern "user32" fn SendMessageW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
pub extern "user32" fn PostMessageW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) BOOL;
pub extern "user32" fn CallWindowProcW(lpPrevWndFunc: LONG_PTR, hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT;
pub extern "user32" fn GetParent(hWnd: HWND) callconv(.winapi) HWND;
pub extern "user32" fn OpenClipboard(hWndNewOwner: HWND) callconv(.winapi) BOOL;
pub extern "user32" fn CloseClipboard() callconv(.winapi) BOOL;
pub extern "user32" fn EmptyClipboard() callconv(.winapi) BOOL;
pub extern "user32" fn SetClipboardData(uFormat: UINT, hMem: HANDLE) callconv(.winapi) HANDLE;
pub extern "user32" fn GetClipboardData(uFormat: UINT) callconv(.winapi) HANDLE;
pub extern "user32" fn IsClipboardFormatAvailable(format: UINT) callconv(.winapi) BOOL;
pub extern "user32" fn FlashWindow(hWnd: HWND, bInvert: BOOL) callconv(.winapi) BOOL;
pub extern "kernel32" fn GlobalAlloc(uFlags: UINT, dwBytes: usize) callconv(.winapi) HANDLE;
pub extern "kernel32" fn GlobalLock(hMem: HANDLE) callconv(.winapi) ?*anyopaque;
pub extern "kernel32" fn GlobalUnlock(hMem: HANDLE) callconv(.winapi) BOOL;
pub extern "kernel32" fn GlobalFree(hMem: HANDLE) callconv(.winapi) HANDLE;
pub extern "kernel32" fn GlobalSize(hMem: HANDLE) callconv(.winapi) usize;
pub extern "kernel32" fn GetModuleHandleW(lpModuleName: ?[*:0]const u16) callconv(.winapi) HMODULE;
pub extern "kernel32" fn GetModuleHandleExW(dwFlags: DWORD, lpModuleName: ?*const anyopaque, phModule: *HMODULE) callconv(.winapi) BOOL;
pub extern "kernel32" fn QueryPerformanceCounter(lpPerformanceCount: *i64) callconv(.winapi) BOOL;
pub extern "kernel32" fn QueryPerformanceFrequency(lpFrequency: *i64) callconv(.winapi) BOOL;
pub extern "user32" fn GetDC(hWnd: HWND) callconv(.winapi) HDC;
pub extern "user32" fn ReleaseDC(hWnd: HWND, hDC: HDC) callconv(.winapi) c_int;
pub const HBITMAP = ?*anyopaque;
pub const BITMAPINFOHEADER = extern struct {
    biSize: DWORD = @sizeOf(BITMAPINFOHEADER),
    biWidth: i32 = 0,
    biHeight: i32 = 0,
    biPlanes: WORD = 1,
    biBitCount: WORD = 32,
    biCompression: DWORD = 0, // BI_RGB
    biSizeImage: DWORD = 0,
    biXPelsPerMeter: i32 = 0,
    biYPelsPerMeter: i32 = 0,
    biClrUsed: DWORD = 0,
    biClrImportant: DWORD = 0,
};
pub const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER = .{},
    bmiColors: [1]u32 = .{0},
};
pub extern "gdi32" fn CreateCompatibleDC(hdc: HDC) callconv(.winapi) HDC;
pub extern "gdi32" fn DeleteDC(hdc: HDC) callconv(.winapi) BOOL;
pub extern "gdi32" fn CreateDIBSection(hdc: HDC, pbmi: *const BITMAPINFO, usage: UINT, ppvBits: ?*?*anyopaque, hSection: ?*anyopaque, offset: DWORD) callconv(.winapi) HBITMAP;
pub extern "gdi32" fn SelectObject(hdc: HDC, h: HBITMAP) callconv(.winapi) HBITMAP;
pub extern "gdi32" fn DeleteObject(ho: HBITMAP) callconv(.winapi) BOOL;
pub extern "gdi32" fn ChoosePixelFormat(hdc: HDC, ppfd: *const PIXELFORMATDESCRIPTOR) callconv(.winapi) c_int;
pub extern "gdi32" fn SetPixelFormat(hdc: HDC, iPixelFormat: c_int, ppfd: *const PIXELFORMATDESCRIPTOR) callconv(.winapi) BOOL;
pub extern "gdi32" fn DescribePixelFormat(hdc: HDC, iPixelFormat: c_int, nBytes: UINT, ppfd: ?*PIXELFORMATDESCRIPTOR) callconv(.winapi) c_int;
pub extern "gdi32" fn SwapBuffers(hdc: HDC) callconv(.winapi) BOOL;
pub extern "opengl32" fn wglCreateContext(hdc: HDC) callconv(.winapi) HGLRC;
pub extern "opengl32" fn wglDeleteContext(hglrc: HGLRC) callconv(.winapi) BOOL;
pub extern "opengl32" fn wglMakeCurrent(hdc: HDC, hglrc: HGLRC) callconv(.winapi) BOOL;
pub extern "opengl32" fn wglGetProcAddress(procname: [*:0]const u8) callconv(.winapi) ?*anyopaque;

// IMM
pub const HIMC = ?*anyopaque;
pub extern "imm32" fn ImmGetContext(hWnd: HWND) callconv(.winapi) HIMC;
pub extern "imm32" fn ImmReleaseContext(hWnd: HWND, hIMC: HIMC) callconv(.winapi) BOOL;
pub extern "imm32" fn ImmGetCompositionStringW(hIMC: HIMC, dwIndex: DWORD, lpBuf: ?*anyopaque, dwBufLen: DWORD) callconv(.winapi) LONG;
pub extern "imm32" fn ImmAssociateContext(hWnd: HWND, hIMC: HIMC) callconv(.winapi) HIMC;
pub extern "imm32" fn ImmSetCompositionWindow(hIMC: HIMC, lpCompForm: *COMPOSITIONFORM) callconv(.winapi) BOOL;

const CFS_POINT: u32 = 0x0002;
pub const COMPOSITIONFORM = extern struct {
    dwStyle: u32,
    ptCurrentPos: POINT,
    rcArea: RECT,
};

// RegisterWindowMessage
pub extern "user32" fn RegisterWindowMessageW(lpString: [*:0]const u16) callconv(.winapi) UINT;

// OLE
pub const HRESULT = i32;
pub const REFIID = *const GUID;
pub const GUID = extern struct {
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,
};
pub const CLSCTX_INPROC_SERVER: DWORD = 0x1;
pub const S_OK: HRESULT = 0;
pub const S_FALSE: HRESULT = 1;
pub const E_NOINTERFACE: HRESULT = @bitCast(@as(u32, 0x80004002));
pub const DRAGDROP_S_DROP: HRESULT = 0x00040100;
pub const DROPEFFECT_NONE: DWORD = 0;
pub const DROPEFFECT_COPY: DWORD = 1;
pub const CF_TEXT: c_short = 1;
pub const CF_UNICODETEXT_S: c_short = 13;
pub const TYMED_HGLOBAL: DWORD = 1;
pub const DVASPECT_CONTENT: DWORD = 1;

pub const POINTL = extern struct { x: LONG, y: LONG };

pub const FORMATETC = extern struct {
    cfFormat: c_short,
    ptd: ?*anyopaque,
    dwAspect: DWORD,
    lindex: LONG,
    tymed: DWORD,
};

pub const STGMEDIUM = extern struct {
    tymed: DWORD,
    u: extern union {
        hGlobal: HANDLE,
        pad: usize,
    },
    pUnkForRelease: ?*anyopaque,
};

pub const IDataObjectVtbl = extern struct {
    QueryInterface: *const fn (*IDataObject, REFIID, *?*anyopaque) callconv(.winapi) HRESULT,
    AddRef: *const fn (*IDataObject) callconv(.winapi) u32,
    Release: *const fn (*IDataObject) callconv(.winapi) u32,
    GetData: *const fn (*IDataObject, *FORMATETC, *STGMEDIUM) callconv(.winapi) HRESULT,
    GetDataHere: *const fn (*IDataObject, *FORMATETC, *STGMEDIUM) callconv(.winapi) HRESULT,
    QueryGetData: *const fn (*IDataObject, *FORMATETC) callconv(.winapi) HRESULT,
    GetCanonicalFormatEtc: *const fn (*IDataObject, *FORMATETC, *FORMATETC) callconv(.winapi) HRESULT,
    SetData: *const fn (*IDataObject, *FORMATETC, *STGMEDIUM, BOOL) callconv(.winapi) HRESULT,
    EnumFormatEtc: *const fn (*IDataObject, DWORD, *?*anyopaque) callconv(.winapi) HRESULT,
    DAdvise: *const fn () callconv(.winapi) HRESULT,
    DUnadvise: *const fn () callconv(.winapi) HRESULT,
    EnumDAdvise: *const fn () callconv(.winapi) HRESULT,
};
pub const IDataObject = extern struct { vtbl: *const IDataObjectVtbl };

pub const IDropTargetVtbl = extern struct {
    QueryInterface: *const fn (*IDropTarget, REFIID, *?*anyopaque) callconv(.winapi) HRESULT,
    AddRef: *const fn (*IDropTarget) callconv(.winapi) u32,
    Release: *const fn (*IDropTarget) callconv(.winapi) u32,
    DragEnter: *const fn (*IDropTarget, *IDataObject, DWORD, POINTL, *DWORD) callconv(.winapi) HRESULT,
    DragOver: *const fn (*IDropTarget, DWORD, POINTL, *DWORD) callconv(.winapi) HRESULT,
    DragLeave: *const fn (*IDropTarget) callconv(.winapi) HRESULT,
    Drop: *const fn (*IDropTarget, *IDataObject, DWORD, POINTL, *DWORD) callconv(.winapi) HRESULT,
};
pub const IDropTarget = extern struct { vtbl: *const IDropTargetVtbl };

pub extern "ole32" fn OleInitialize(pvReserved: ?*anyopaque) callconv(.winapi) HRESULT;
pub extern "ole32" fn OleUninitialize() callconv(.winapi) void;
pub extern "ole32" fn RegisterDragDrop(hwnd: HWND, pDropTarget: *IDropTarget) callconv(.winapi) HRESULT;
pub extern "ole32" fn RevokeDragDrop(hwnd: HWND) callconv(.winapi) HRESULT;
pub extern "ole32" fn ReleaseStgMedium(p: *STGMEDIUM) callconv(.winapi) void;

// IDC_* cursor constants (MAKEINTRESOURCE style — low ordinal)
const IDC_ARROW: usize = 32512;
const IDC_IBEAM: usize = 32513;
const IDC_WAIT: usize = 32514;
const IDC_CROSS: usize = 32515;
const IDC_HAND: usize = 32649;
const IDC_NO: usize = 32648;
const IDC_SIZEWE: usize = 32644;
const IDC_SIZENS: usize = 32645;
const IDC_SIZENWSE: usize = 32642;
const IDC_SIZENESW: usize = 32643;
const IDC_SIZEALL: usize = 32646;

const PM_REMOVE: UINT = 0x0001;
const QS_ALLINPUT: DWORD = 0x04FF;
const INFINITE: DWORD = 0xFFFF_FFFF;
const WAIT_OBJECT_0: DWORD = 0;

// Class name as comptime UTF-16
const CLASS_NAME = std.unicode.utf8ToUtf16LeStringLiteral("zpugl_window");
var class_refs: usize = 0;
var class_atom: ATOM = 0;

// --- Timer bookkeeping ---

const TimerEntry = struct {
    hwnd: HWND,
    win_id: UINT_PTR, // SetTimer id
    view: *root.View,
    id: usize, // zpugl timer id
};

// --- WorldImpl ---

pub const WorldImpl = struct {
    hinstance: HMODULE,
    class_atom: ATOM,
    qpf: i64, // QueryPerformanceFrequency result
    timers: std.ArrayListUnmanaged(TimerEntry) = .empty,
    clip_buf: std.ArrayListUnmanaged(u8) = .empty,
    high_surrogate: u16 = 0, // pending WM_CHAR high surrogate, 0 if none
    client_msg: UINT = 0, // RegisterWindowMessageW("PuglClientMessage")
    ole_inited: bool = false,
};

pub const ViewImpl = struct {
    drop_target: DropTarget = undefined,
    drop_registered: bool = false,
    cursor: HCURSOR = null,
    text_edit: HWND = null,
    text_active: bool = false,
};

// Hosts such as REAPER keep Space and other shortcuts for themselves unless the
// focused window is an Edit control. While dvui edits text, a zero-sized child
// Edit has the focus and hands every key to the view.
var edit_proc_orig: LONG_PTR = 0;

fn editProc(hwnd: HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT {
    std.debug.assert(edit_proc_orig != 0);
    const parent = GetParent(hwnd);
    const view = getViewFromHwnd(parent orelse return CallWindowProcW(edit_proc_orig, hwnd, msg, wParam, lParam)) orelse
        return CallWindowProcW(edit_proc_orig, hwnd, msg, wParam, lParam);
    switch (msg) {
        WM_KEYDOWN...WM_SYSDEADCHAR => return wndProc(parent, msg, wParam, lParam),
        WM_GETDLGCODE => return DLGC_WANT_KEYS,
        WM_IME_STARTCOMPOSITION...WM_IME_COMPOSITION, WM_IME_SETCONTEXT...WM_IME_KEYUP => return DefWindowProcW(hwnd, msg, wParam, lParam),
        WM_SETFOCUS, WM_KILLFOCUS => if (@as(HWND, @ptrFromInt(wParam)) != parent) {
            _ = common.dispatchEvent(view, &if (msg == WM_SETFOCUS) root.Event{ .focus_in = .{ .mode = .normal } } else root.Event{ .focus_out = .{ .mode = .normal } });
        },
        else => {},
    }
    return CallWindowProcW(edit_proc_orig, hwnd, msg, wParam, lParam);
}

fn focusTarget(view: *root.View) HWND {
    const vi = getOrInitViewImpl(view) orelse return view.handle;
    return if (vi.text_active and vi.text_edit != null) vi.text_edit else view.handle;
}

fn focusView(view: *root.View) void {
    const target = focusTarget(view) orelse return;
    if (GetFocus() != target) _ = SetFocus(target);
}

fn ensureTextEdit(view: *root.View, vi: *ViewImpl) void {
    if (vi.text_edit != null) return;
    const hwnd = view.handle orelse return;
    const impl = getWorldImpl(view.world) orelse return;
    const edit = CreateWindowExW(0, EDIT_CLASS, null, WS_CHILD | WS_VISIBLE, 0, 0, 0, 0, hwnd, null, impl.hinstance, null) orelse return;
    const old = SetWindowLongPtrW(edit, GWLP_WNDPROC, @bitCast(@intFromPtr(&editProc)));
    std.debug.assert(old != 0 and (edit_proc_orig == 0 or edit_proc_orig == old));
    edit_proc_orig = old;
    vi.text_edit = edit;
    _ = ImmAssociateContext(hwnd, null);
}


const DropTarget = extern struct {
    vtbl: *const IDropTargetVtbl,
    refcount: u32,
    view: *root.View,
};

fn dropQI(self: *IDropTarget, riid: REFIID, ppv: *?*anyopaque) callconv(.winapi) HRESULT {
    _ = riid;
    ppv.* = self;
    const dt: *DropTarget = @ptrCast(@alignCast(self));
    dt.refcount +%= 1;
    return S_OK;
}
fn dropAddRef(self: *IDropTarget) callconv(.winapi) u32 {
    const dt: *DropTarget = @ptrCast(@alignCast(self));
    dt.refcount +%= 1;
    return dt.refcount;
}
fn dropRelease(self: *IDropTarget) callconv(.winapi) u32 {
    const dt: *DropTarget = @ptrCast(@alignCast(self));
    if (dt.refcount > 0) dt.refcount -%= 1;
    return dt.refcount;
}
fn emitOffer(view: *root.View, x: f64, y: f64) void {
    const ev = root.Event{ .data_offer = .{
        .time = 0,
        .x = x,
        .y = y,
        .clipboard = .general,
    } };
    _ = common.dispatchEvent(view, &ev);
}
fn dropDragEnter(self: *IDropTarget, _: *IDataObject, _: DWORD, pt: POINTL, effect: *DWORD) callconv(.winapi) HRESULT {
    const dt: *DropTarget = @ptrCast(@alignCast(self));
    effect.* = DROPEFFECT_COPY;
    var p = POINT{ .x = pt.x, .y = pt.y };
    if (dt.view.handle) |h| _ = ScreenToClient(h, &p);
    emitOffer(dt.view, @floatFromInt(p.x), @floatFromInt(p.y));
    return S_OK;
}
fn dropDragOver(self: *IDropTarget, _: DWORD, pt: POINTL, effect: *DWORD) callconv(.winapi) HRESULT {
    const dt: *DropTarget = @ptrCast(@alignCast(self));
    effect.* = DROPEFFECT_COPY;
    var p = POINT{ .x = pt.x, .y = pt.y };
    if (dt.view.handle) |h| _ = ScreenToClient(h, &p);
    emitOffer(dt.view, @floatFromInt(p.x), @floatFromInt(p.y));
    return S_OK;
}
fn dropDragLeave(_: *IDropTarget) callconv(.winapi) HRESULT {
    return S_OK;
}
fn dropDrop(self: *IDropTarget, data: *IDataObject, _: DWORD, pt: POINTL, effect: *DWORD) callconv(.winapi) HRESULT {
    const dt: *DropTarget = @ptrCast(@alignCast(self));
    effect.* = DROPEFFECT_COPY;
    // Try to extract CF_UNICODETEXT
    var fmt = FORMATETC{
        .cfFormat = CF_UNICODETEXT_S,
        .ptd = null,
        .dwAspect = DVASPECT_CONTENT,
        .lindex = -1,
        .tymed = TYMED_HGLOBAL,
    };
    var med: STGMEDIUM = undefined;
    const hr = data.vtbl.GetData(data, &fmt, &med);
    if (hr == S_OK) {
        defer ReleaseStgMedium(&med);
        if (GlobalLock(med.u.hGlobal)) |p| {
            defer _ = GlobalUnlock(med.u.hGlobal);
            const u16_ptr: [*:0]const u16 = @ptrCast(@alignCast(p));
            const len = std.mem.indexOfSentinel(u16, 0, u16_ptr);
            if (getWorldImpl(dt.view.world)) |wi| {
                wi.clip_buf.clearRetainingCapacity();
                wi.clip_buf.ensureTotalCapacity(dt.view.world.allocator, len * 3 + 1) catch return S_OK;
                const written = std.unicode.utf16LeToUtf8(wi.clip_buf.allocatedSlice(), u16_ptr[0..len]) catch return S_OK;
                wi.clip_buf.items.len = written;
            }
        }
    }
    var p = POINT{ .x = pt.x, .y = pt.y };
    if (dt.view.handle) |h| _ = ScreenToClient(h, &p);
    emitOffer(dt.view, @floatFromInt(p.x), @floatFromInt(p.y));
    return S_OK;
}

const drop_target_vtbl = IDropTargetVtbl{
    .QueryInterface = dropQI,
    .AddRef = dropAddRef,
    .Release = dropRelease,
    .DragEnter = dropDragEnter,
    .DragOver = dropDragOver,
    .DragLeave = dropDragLeave,
    .Drop = dropDrop,
};

fn getOrInitViewImpl(view: *root.View) ?*ViewImpl {
    if (view.impl) |p| return @ptrCast(@alignCast(p));
    const vi = view.world.allocator.create(ViewImpl) catch return null;
    vi.* = .{};
    view.impl = vi;
    return vi;
}

fn getWorldImpl(world: *root.World) ?*WorldImpl {
    return if (world.impl) |p| @ptrCast(@alignCast(p)) else null;
}

fn getOrInitWorldImpl(world: *root.World) !*WorldImpl {
    if (world.impl) |p| return @ptrCast(@alignCast(p));

    var hinstance: HMODULE = null;
    if (GetModuleHandleExW(0x6, @ptrCast(&wndProc), &hinstance) == 0) return error.RegisterClassFailed;
    var qpf: i64 = 0;
    _ = QueryPerformanceFrequency(&qpf);

    if (class_refs == 0) {
        const wc = WNDCLASSEXW{
            .lpfnWndProc = wndProc,
            .hInstance = hinstance,
            .lpszClassName = CLASS_NAME,
            .style = 0x0023, // CS_HREDRAW | CS_VREDRAW | CS_OWNDC
        };
        class_atom = RegisterClassExW(&wc);
        if (class_atom == 0) return error.RegisterClassFailed;
    }
    class_refs += 1;
    errdefer releaseClass(hinstance);

    const impl = try world.allocator.create(WorldImpl);
    impl.* = .{
        .hinstance = hinstance,
        .class_atom = class_atom,
        .qpf = if (qpf > 0) qpf else 10_000_000,
    };
    const client_msg_name = std.unicode.utf8ToUtf16LeStringLiteral("PuglClientMessage");
    impl.client_msg = RegisterWindowMessageW(client_msg_name);
    impl.ole_inited = (OleInitialize(null) == S_OK);
    world.impl = impl;
    return impl;
}

fn releaseClass(hinstance: HMODULE) void {
    class_refs -= 1;
    if (class_refs == 0) _ = UnregisterClassW(CLASS_NAME, hinstance);
}

fn getViewFromHwnd(hwnd: HWND) ?*root.View {
    const ptr = GetWindowLongPtrW(hwnd, GWLP_USERDATA);
    if (ptr == 0) return null;
    return @ptrFromInt(@as(usize, @bitCast(ptr)));
}

// --- Mod state ---

fn currentMods() root.Mods {
    // GetKeyState is synchronous with message queue
    const shift = GetKeyStateDown(VK_SHIFT);
    const ctrl = GetKeyStateDown(VK_CONTROL);
    const alt = GetKeyStateDown(VK_MENU);
    const super = GetKeyStateDown(VK_LWIN) or GetKeyStateDown(VK_RWIN);
    const num = GetKeyStateToggled(VK_NUMLOCK);
    const caps = GetKeyStateToggled(VK_CAPITAL);
    return .{ .shift = shift, .ctrl = ctrl, .alt = alt, .super = super, .num_lock = num, .caps_lock = caps };
}

extern "user32" fn GetKeyState(nVirtKey: c_int) callconv(.winapi) i16;

fn GetKeyStateDown(vk: c_int) bool {
    return (@as(u16, @bitCast(GetKeyState(vk))) & 0x8000) != 0;
}
fn GetKeyStateToggled(vk: c_int) bool {
    return (GetKeyState(vk) & 0x0001) != 0;
}

// --- Virtual key → zpugl Key ---

fn vkToKey(vk: WPARAM, lParam: LPARAM) u32 {
    const ext = (lParam >> 24) & 1 != 0;
    const scan: UINT = @intCast((lParam >> 16) & 0xFF);
    return switch (@as(u8, @truncate(vk))) {
        VK_SHIFT => if (MapVirtualKeyW(scan, MAPVK_VSC_TO_VK_EX) == VK_RSHIFT) 0xE052 else 0xE051,
        VK_CONTROL => if (ext) 0xE054 else 0xE053,
        VK_MENU => if (ext) 0xE056 else 0xE055,
        ' ', '0'...'9' => |c| c,
        'A'...'Z' => |c| @as(u32, c) + 0x20,
        VK_BACK => 0x0008,
        VK_TAB => 0x0009,
        VK_RETURN => 0x000D,
        VK_ESCAPE => 0x001B,
        VK_DELETE => 0x007F,
        VK_F1 + 0 => 0xE000,
        VK_F1 + 1 => 0xE001,
        VK_F1 + 2 => 0xE002,
        VK_F1 + 3 => 0xE003,
        VK_F1 + 4 => 0xE004,
        VK_F1 + 5 => 0xE005,
        VK_F1 + 6 => 0xE006,
        VK_F1 + 7 => 0xE007,
        VK_F1 + 8 => 0xE008,
        VK_F1 + 9 => 0xE009,
        VK_F1 + 10 => 0xE00A,
        VK_F1 + 11 => 0xE00B,
        VK_PRIOR => 0xE031,
        VK_NEXT => 0xE032,
        VK_END => 0xE033,
        VK_HOME => 0xE034,
        VK_LEFT => 0xE035,
        VK_UP => 0xE036,
        VK_RIGHT => 0xE037,
        VK_DOWN => 0xE038,
        VK_SNAPSHOT => 0xE041,
        VK_INSERT => 0xE042,
        VK_PAUSE => 0xE043,
        VK_APPS => 0xE044,
        VK_NUMLOCK => 0xE045,
        VK_SCROLL => 0xE046,
        VK_CAPITAL => 0xE047,
        VK_LSHIFT => 0xE051,
        VK_RSHIFT => 0xE052,
        VK_LCONTROL => 0xE053,
        VK_RCONTROL => 0xE054,
        VK_LMENU => 0xE055,
        VK_RMENU => 0xE056,
        VK_LWIN => 0xE057,
        VK_RWIN => 0xE058,
        VK_NUMPAD0 + 0 => 0xE060,
        VK_NUMPAD0 + 1 => 0xE061,
        VK_NUMPAD0 + 2 => 0xE062,
        VK_NUMPAD0 + 3 => 0xE063,
        VK_NUMPAD0 + 4 => 0xE064,
        VK_NUMPAD0 + 5 => 0xE065,
        VK_NUMPAD0 + 6 => 0xE066,
        VK_NUMPAD0 + 7 => 0xE067,
        VK_NUMPAD0 + 8 => 0xE068,
        VK_NUMPAD0 + 9 => 0xE069,
        // VK_RETURN numpad variant uses the extended-key bit at runtime;
        // can't be distinguished here as a separate switch arm.
        VK_MULTIPLY => 0xE0AA,
        VK_ADD => 0xE0AB,
        VK_SEPARATOR => 0xE0AC,
        VK_SUBTRACT => 0xE0AD,
        VK_DECIMAL => 0xE0AE,
        VK_DIVIDE => 0xE0AF,
        else => |c| unshifted(c, scan),
    };
}

fn unshifted(vk: UINT, scan: UINT) u32 {
    const state: [256]u8 = @splat(0);
    var buf: [4]u16 = undefined;
    return if (ToUnicode(vk, scan, &state, &buf, buf.len, 4) == 1) buf[0] else 0;
}

// --- WndProc ---

fn wndProc(hwnd: HWND, msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(.winapi) LRESULT {
    const view = getViewFromHwnd(hwnd) orelse {
        return DefWindowProcW(hwnd, msg, wParam, lParam);
    };

    const world_impl = getWorldImpl(view.world);
    const now = blk: {
        var qpc: i64 = 0;
        _ = QueryPerformanceCounter(&qpc);
        const freq: f64 = if (world_impl) |i| @floatFromInt(i.qpf) else 10_000_000.0;
        break :blk @as(f64, @floatFromInt(qpc)) / freq;
    };
    if (world_impl) |wi| {
        if (wi.client_msg != 0 and msg == wi.client_msg) {
            _ = common.dispatchEvent(view, &root.Event{ .client = .{
                .data1 = @as(usize, wParam),
                .data2 = @as(usize, @bitCast(lParam)),
            } });
            return 0;
        }
    }

    const mods = currentMods();

    switch (msg) {
        WM_PAINT => {
            // Get client rect for expose size
            var rc: RECT = undefined;
            _ = GetClientRect(hwnd, &rc);
            const w: u16 = @intCast(@min(rc.right - rc.left, std.math.maxInt(u16)));
            const h: u16 = @intCast(@min(rc.bottom - rc.top, std.math.maxInt(u16)));
            const ev = root.Event{ .expose = .{ .x = 0, .y = 0, .width = w, .height = h } };
            _ = common.dispatchEvent(view, &ev);
            _ = ValidateRect(hwnd, null);
            return 0;
        },
        WM_SIZE => {
            view.style.hidden = wParam == SIZE_MINIMIZED;
            configure(view, @intCast(lParam & 0xFFFF), @intCast((lParam >> 16) & 0xFFFF));
            return 0;
        },
        WM_ENTERSIZEMOVE, WM_EXITSIZEMOVE => {
            view.style.resizing = msg == WM_ENTERSIZEMOVE;
            _ = common.dispatchEvent(view, &if (view.style.resizing) root.Event{ .loop_enter = {} } else root.Event{ .loop_leave = {} });
            var rc: RECT = undefined;
            _ = GetClientRect(hwnd, &rc);
            configure(view, rc.right - rc.left, rc.bottom - rc.top);
            return 0;
        },
        WM_SHOWWINDOW => {
            common.dispatchStyle(view, wParam != 0, view.style.hidden);
            return DefWindowProcW(hwnd, msg, wParam, lParam);
        },
        WM_CLOSE => {
            _ = common.dispatchEvent(view, &root.Event{ .close = {} });
            return 0;
        },
        WM_SETFOCUS, WM_KILLFOCUS => {
            const other: HWND = @ptrFromInt(wParam);
            const edit = if (getOrInitViewImpl(view)) |vi| vi.text_edit else null;
            if (edit == null or other != edit) {
                _ = common.dispatchEvent(view, &if (msg == WM_SETFOCUS) root.Event{ .focus_in = .{ .mode = .normal } } else root.Event{ .focus_out = .{ .mode = .normal } });
            }
            return 0;
        },
        WM_GETDLGCODE => return DLGC_WANT_KEYS,
        WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN => {
            const btn: u32 = switch (msg) {
                WM_LBUTTONDOWN => 0,
                WM_MBUTTONDOWN => 2,
                WM_RBUTTONDOWN => 1,
                else => 0,
            };
            const x: f64 = @floatFromInt(@as(i16, @bitCast(@as(u16, @intCast(lParam & 0xFFFF)))));
            const y: f64 = @floatFromInt(@as(i16, @bitCast(@as(u16, @intCast((lParam >> 16) & 0xFFFF)))));
            focusView(view);
            _ = SetCapture(hwnd);
            _ = common.dispatchEvent(view, &root.Event{ .button_press = .{
                .time = now,
                .x = x,
                .y = y,
                .root_x = x,
                .root_y = y,
                .state = mods,
                .button = btn,
            } });
            return 0;
        },
        WM_LBUTTONUP, WM_RBUTTONUP, WM_MBUTTONUP => {
            const btn: u32 = switch (msg) {
                WM_LBUTTONUP => 0,
                WM_MBUTTONUP => 2,
                WM_RBUTTONUP => 1,
                else => 0,
            };
            const x: f64 = @floatFromInt(@as(i16, @bitCast(@as(u16, @intCast(lParam & 0xFFFF)))));
            const y: f64 = @floatFromInt(@as(i16, @bitCast(@as(u16, @intCast((lParam >> 16) & 0xFFFF)))));
            _ = ReleaseCapture();
            _ = common.dispatchEvent(view, &root.Event{ .button_release = .{
                .time = now,
                .x = x,
                .y = y,
                .root_x = x,
                .root_y = y,
                .state = mods,
                .button = btn,
            } });
            return 0;
        },
        WM_SETCURSOR => {
            if (lParam & 0xFFFF == HTCLIENT) {
                const vi = getOrInitViewImpl(view);
                _ = SetCursor(if (vi) |v| v.cursor orelse LoadCursorW(null, IDC_ARROW) else LoadCursorW(null, IDC_ARROW));
                return 1;
            }
        },
        WM_MOUSEMOVE => {
            const x: f64 = @floatFromInt(@as(i16, @bitCast(@as(u16, @intCast(lParam & 0xFFFF)))));
            const y: f64 = @floatFromInt(@as(i16, @bitCast(@as(u16, @intCast((lParam >> 16) & 0xFFFF)))));
            _ = common.dispatchEvent(view, &root.Event{ .motion = .{
                .time = now,
                .x = x,
                .y = y,
                .root_x = x,
                .root_y = y,
                .state = mods,
            } });
            // Track mouse leave
            var tme: extern struct {
                cbSize: DWORD = @sizeOf(@This()),
                dwFlags: DWORD = 0x00000002, // TME_LEAVE
                hwndTrack: HWND,
                dwHoverTime: DWORD = 0,
            } = .{ .hwndTrack = hwnd };
            _ = TrackMouseEvent(&tme);
            return 0;
        },
        WM_MOUSELEAVE => {
            _ = common.dispatchEvent(view, &root.Event{ .pointer_out = .{
                .time = now,
                .x = 0,
                .y = 0,
                .root_x = 0,
                .root_y = 0,
                .state = mods,
                .mode = .normal,
            } });
            return 0;
        },
        WM_MOUSEWHEEL => {
            const delta: i16 = @bitCast(@as(u16, @intCast((wParam >> 16) & 0xFFFF)));
            const dy: f64 = @as(f64, @floatFromInt(delta)) / 120.0;
            var pt = POINT{ .x = @intCast(@as(i16, @bitCast(@as(u16, @intCast(lParam & 0xFFFF))))), .y = @intCast(@as(i16, @bitCast(@as(u16, @intCast((lParam >> 16) & 0xFFFF))))) };
            _ = ScreenToClient(hwnd, &pt);
            const x: f64 = @floatFromInt(pt.x);
            const y: f64 = @floatFromInt(pt.y);
            const dir: root.ScrollDirection = if (dy > 0) .up else .down;
            _ = common.dispatchEvent(view, &root.Event{ .scroll = .{
                .time = now,
                .x = x,
                .y = y,
                .root_x = x,
                .root_y = y,
                .state = mods,
                .direction = dir,
                .dx = 0,
                .dy = dy,
            } });
            return 0;
        },
        WM_MOUSEHWHEEL => {
            const delta: i16 = @bitCast(@as(u16, @intCast((wParam >> 16) & 0xFFFF)));
            const dx: f64 = @as(f64, @floatFromInt(delta)) / 120.0;
            var pt = POINT{ .x = @intCast(@as(i16, @bitCast(@as(u16, @intCast(lParam & 0xFFFF))))), .y = @intCast(@as(i16, @bitCast(@as(u16, @intCast((lParam >> 16) & 0xFFFF))))) };
            _ = ScreenToClient(hwnd, &pt);
            const x: f64 = @floatFromInt(pt.x);
            const y: f64 = @floatFromInt(pt.y);
            const dir: root.ScrollDirection = if (dx > 0) .right else .left;
            _ = common.dispatchEvent(view, &root.Event{ .scroll = .{
                .time = now,
                .x = x,
                .y = y,
                .root_x = x,
                .root_y = y,
                .state = mods,
                .direction = dir,
                .dx = dx,
                .dy = 0,
            } });
            return 0;
        },
        WM_KEYDOWN, WM_SYSKEYDOWN, WM_KEYUP, WM_SYSKEYUP => {
            const press = msg == WM_KEYDOWN or msg == WM_SYSKEYDOWN;
            const ev: root.KeyEvent = .{ .time = now, .x = 0, .y = 0, .root_x = 0, .root_y = 0, .state = mods, .keycode = @intCast((lParam >> 16) & 0xFF), .key = vkToKey(wParam, lParam) };
            _ = common.dispatchEvent(view, &if (press) root.Event{ .key_press = ev } else root.Event{ .key_release = ev });
            return 0;
        },
        WM_CHAR => {
            const unit: u16 = @intCast(wParam & 0xFFFF);
            var cp: u32 = unit;
            if (world_impl) |wi| {
                if (unit >= 0xD800 and unit < 0xDC00) {
                    // High surrogate: buffer and wait for low surrogate
                    wi.high_surrogate = unit;
                    return 0;
                } else if (unit >= 0xDC00 and unit <= 0xDFFF) {
                    if (wi.high_surrogate != 0) {
                        const hi: u32 = wi.high_surrogate;
                        const lo: u32 = unit;
                        cp = (((hi & 0x03FF) << 10) | (lo & 0x03FF)) + 0x10000;
                        wi.high_surrogate = 0;
                    } else {
                        cp = 0xFFFD;
                    }
                } else {
                    wi.high_surrogate = 0;
                }
            }
            if (cp >= 0x0020 and cp != 0x007F) {
                var buf: [4]u8 = undefined;
                const n = std.unicode.utf8Encode(@intCast(cp), &buf) catch return 0;
                var str8: [8]u8 = @splat(0);
                @memcpy(str8[0..n], buf[0..n]);
                _ = common.dispatchEvent(view, &root.Event{ .text = .{
                    .time = now,
                    .x = 0,
                    .y = 0,
                    .root_x = 0,
                    .root_y = 0,
                    .state = mods,
                    .keycode = 0,
                    .character = cp,
                    .string = str8,
                } });
            }
            return 0;
        },
        WM_GETMINMAXINFO => {
            const mmi: *MINMAXINFO = @ptrFromInt(@as(usize, @bitCast(lParam)));
            const style = getWindowStyle(hwnd);
            const ex_style = getWindowExStyle(hwnd);
            const min_sz = view.size_hints[@backingInt(root.SizeHint.min_size)];
            var min_rc = RECT{ .left = 0, .top = 0, .right = @intCast(min_sz.width), .bottom = @intCast(min_sz.height) };
            _ = AdjustWindowRectEx(&min_rc, style, 0, ex_style);
            mmi.ptMinTrackSize.x = min_rc.right - min_rc.left;
            mmi.ptMinTrackSize.y = min_rc.bottom - min_rc.top;
            const max_sz = view.size_hints[@backingInt(root.SizeHint.max_size)];
            if (max_sz.width > 0 and max_sz.height > 0) {
                var max_rc = RECT{ .left = 0, .top = 0, .right = @intCast(max_sz.width), .bottom = @intCast(max_sz.height) };
                _ = AdjustWindowRectEx(&max_rc, style, 0, ex_style);
                mmi.ptMaxTrackSize.x = max_rc.right - max_rc.left;
                mmi.ptMaxTrackSize.y = max_rc.bottom - max_rc.top;
            }
            return 0;
        },
        WM_IME_CHAR => {
            // Swallow — handled via WM_IME_COMPOSITION GCS_RESULTSTR
            return 0;
        },
        WM_IME_COMPOSITION => {
            if ((@as(DWORD, @intCast(lParam & 0xFFFFFFFF)) & GCS_RESULTSTR) != 0) {
                const himc = ImmGetContext(hwnd);
                if (himc != null) {
                    defer _ = ImmReleaseContext(hwnd, himc);
                    const byte_len = ImmGetCompositionStringW(himc, GCS_RESULTSTR, null, 0);
                    if (byte_len > 0) {
                        const u16_count: usize = @intCast(@divTrunc(byte_len, 2));
                        var buf16: [128]u16 = undefined;
                        if (u16_count <= buf16.len) {
                            _ = ImmGetCompositionStringW(himc, GCS_RESULTSTR, &buf16, @intCast(byte_len));
                            var buf8: [512]u8 = undefined;
                            const n = std.unicode.utf16LeToUtf8(&buf8, buf16[0..u16_count]) catch 0;
                            if (n > 0) {
                                // Iterate codepoints, emit each as text event
                                var i: usize = 0;
                                while (i < n) {
                                    const cp_len = std.unicode.utf8ByteSequenceLength(buf8[i]) catch 1;
                                    if (i + cp_len > n) break;
                                    const cp = std.unicode.utf8Decode(buf8[i .. i + cp_len]) catch 0xFFFD;
                                    var str8: [8]u8 = @splat(0);
                                    @memcpy(str8[0..cp_len], buf8[i .. i + cp_len]);
                                    _ = common.dispatchEvent(view, &root.Event{ .text = .{
                                        .time = now,
                                        .x = 0,
                                        .y = 0,
                                        .root_x = 0,
                                        .root_y = 0,
                                        .state = mods,
                                        .keycode = 0,
                                        .character = cp,
                                        .string = str8,
                                    } });
                                    i += cp_len;
                                }
                            }
                        }
                    }
                }
                return 0;
            }
            // fall through to default
        },
        WM_TIMER => {
            // Find the zpugl timer for this win32 timer id
            const win_tid: UINT_PTR = wParam;
            const world = view.world;
            if (getWorldImpl(world)) |impl| {
                for (impl.timers.items) |t| {
                    if (t.win_id == win_tid and t.hwnd == hwnd) {
                        _ = common.dispatchEvent(t.view, &root.Event{ .timer = .{ .id = t.id } });
                        break;
                    }
                }
            }
            return 0;
        },
        else => {},
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

// --- Backend functions ---

pub fn deinitWorld(world: *root.World) void {
    const impl = getWorldImpl(world) orelse return;
    impl.timers.deinit(world.allocator);
    impl.clip_buf.deinit(world.allocator);
    if (impl.ole_inited) OleUninitialize();
    releaseClass(impl.hinstance);
    world.allocator.destroy(impl);
    world.impl = null;
}

pub fn getNativeWorld(world: *root.World) ?*anyopaque {
    const impl = getWorldImpl(world) orelse return null;
    return impl.hinstance;
}

pub fn getTime(world: *root.World) f64 {
    const impl = getWorldImpl(world);
    var qpc: i64 = 0;
    _ = QueryPerformanceCounter(&qpc);
    const freq: f64 = if (impl) |i| @floatFromInt(i.qpf) else 10_000_000.0;
    return @as(f64, @floatFromInt(qpc)) / freq;
}

pub fn update(world: *root.World, timeout: f64) root.Status {
    if (world.type == .module) return .success;
    var msg: MSG = undefined;
    // Drain all pending messages
    while (PeekMessageW(&msg, null, 0, 0, PM_REMOVE) != 0) {
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
    }
    if (timeout == 0) return .success;

    // Wait for messages with timeout
    const ms: DWORD = if (timeout < 0) INFINITE else @intCast(@min(@as(i64, @intFromFloat(timeout * 1000)), std.math.maxInt(i32)));
    _ = MsgWaitForMultipleObjects(0, null, 0, ms, QS_ALLINPUT);

    while (PeekMessageW(&msg, null, 0, 0, PM_REMOVE) != 0) {
        _ = TranslateMessage(&msg);
        _ = DispatchMessageW(&msg);
    }
    return .success;
}

pub fn createView(view: *root.View) root.Status {
    const impl = getOrInitWorldImpl(view.world) catch return .realize_failed;

    const sz = view.size_hints[@backingInt(root.SizeHint.default_size)];
    const pos = view.pos_hints[@backingInt(root.PositionHint.default_position)];
    const w: c_int = if (sz.width == 0) 800 else sz.width;
    const h: c_int = if (sz.height == 0) 600 else sz.height;
    const has_pos = pos.x != std.math.minInt(i16) and pos.y != std.math.minInt(i16);
    const on_screen = view.parent != 0 or MonitorFromRect(&.{ .left = pos.x, .top = pos.y, .right = pos.x + w, .bottom = pos.y + h }, 0) != null;
    const x: c_int = if (has_pos and on_screen) pos.x else @bitCast(@as(u32, 0x80000000)); // CW_USEDEFAULT
    const y: c_int = if (has_pos and on_screen) pos.y else 0;

    const style: DWORD = if (view.parent != 0)
        WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN | WS_CLIPSIBLINGS
    else
        WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN | WS_CLIPSIBLINGS;

    const parent_hwnd: HWND = if (view.parent != 0) @ptrFromInt(view.parent) else null;

    const hwnd = CreateWindowExW(
        0,
        CLASS_NAME,
        null,
        style,
        x,
        y,
        w,
        h,
        parent_hwnd,
        null,
        impl.hinstance,
        null,
    ) orelse return .realize_failed;

    // Store view pointer in HWND user data
    _ = SetWindowLongPtrW(hwnd, GWLP_USERDATA, @bitCast(@intFromPtr(view)));

    // Set title
    const title = view.getViewString(.window_title);
    if (title.len > 0) {
        var buf: [256]u16 = undefined;
        const n = std.unicode.utf8ToUtf16Le(&buf, title) catch 0;
        if (n < buf.len) {
            buf[n] = 0;
            _ = SetWindowTextW(hwnd, buf[0..n :0]);
        }
    }

    view.handle = hwnd;
    view.visible = view.parent != 0;
    if (view.transient_parent != 0) {
        _ = setTransientParent(view, view.transient_parent);
    }
    return .success;
}

fn configure(view: *root.View, width: i64, height: i64) void {
    const w: u16 = @intCast(@min(width, std.math.maxInt(u16)));
    const h: u16 = @intCast(@min(height, std.math.maxInt(u16)));
    view.size_hints[@backingInt(root.SizeHint.current_size)] = .{ .width = w, .height = h };
    _ = common.dispatchEvent(view, &.{ .configure = .{ .x = 0, .y = 0, .width = w, .height = h, .style = view.style } });
}

pub fn realized(view: *root.View) void {
    if (view.parent == 0) return;
    var rc: RECT = undefined;
    if (GetClientRect(view.handle.?, &rc) == 0) return;
    configure(view, rc.right - rc.left, rc.bottom - rc.top);
}

pub fn destroyView(view: *root.View) void {
    if (view.handle) |h| {
        if (view.impl) |p| {
            const vi: *ViewImpl = @ptrCast(@alignCast(p));
            if (vi.drop_registered) _ = RevokeDragDrop(h);
        }
        view.style.mapped = false;
        _ = DestroyWindow(h);
        view.handle = null;
    }
    if (view.impl) |p| {
        const vi: *ViewImpl = @ptrCast(@alignCast(p));
        view.world.allocator.destroy(vi);
        view.impl = null;
    }
}

pub fn showView(view: *root.View, command: root.ShowCommand) root.Status {
    const hwnd = view.handle orelse return .bad_call;
    const cmd: c_int = switch (command) {
        .passive => SW_SHOWNOACTIVATE,
        .raise => SW_SHOW,
        .force_raise => SW_SHOW,
    };
    _ = ShowWindow(hwnd, cmd);
    view.visible = true;
    return .success;
}

pub fn hideView(view: *root.View) root.Status {
    const hwnd = view.handle orelse return .bad_call;
    _ = ShowWindow(hwnd, SW_HIDE);
    view.visible = false;
    return .success;
}

fn getWindowStyle(hwnd: HWND) DWORD {
    return @truncate(@as(usize, @bitCast(GetWindowLongPtrW(hwnd, GWL_STYLE))));
}

fn getWindowExStyle(hwnd: HWND) DWORD {
    return @truncate(@as(usize, @bitCast(GetWindowLongPtrW(hwnd, GWL_EXSTYLE))));
}

pub fn setViewSize(view: *root.View, w: u32, h: u32) root.Status {
    const hwnd = view.handle orelse return .bad_call;
    // Compute outer window rect from desired client size, mirroring pugl
    var rc = RECT{ .left = 0, .top = 0, .right = @intCast(w), .bottom = @intCast(h) };
    _ = AdjustWindowRectEx(&rc, getWindowStyle(hwnd), 0, getWindowExStyle(hwnd));
    _ = SetWindowPos(hwnd, null, 0, 0, rc.right - rc.left, rc.bottom - rc.top, SWP_NOACTIVATE | SWP_NOMOVE | SWP_NOZORDER);
    return .success;
}

pub fn getWindowPosition(view: *root.View) ?root.Point {
    const hwnd = view.handle orelse return null;
    if (IsIconic(hwnd) != 0) return null;
    var r: RECT = undefined;
    if (GetWindowRect(hwnd, &r) == 0) return null;
    return .{ .x = @intCast(std.math.clamp(r.left, std.math.minInt(i16) + 1, std.math.maxInt(i16))), .y = @intCast(std.math.clamp(r.top, std.math.minInt(i16) + 1, std.math.maxInt(i16))) };
}

pub fn setViewPosition(view: *root.View, x: i32, y: i32) root.Status {
    const hwnd = view.handle orelse return .bad_call;
    _ = SetWindowPos(hwnd, null, x, y, 0, 0, SWP_NOACTIVATE | SWP_NOSIZE | SWP_NOZORDER);
    return .success;
}

pub fn applySizeHints(view: *root.View) root.Status {
    _ = view;
    return .success; // Win32 doesn't have WM-level size hints; min/max handled in WM_GETMINMAXINFO if needed
}

pub fn getScaleFactor(view: *root.View) f64 {
    const hwnd = view.handle orelse return 1.0;
    const dpi = GetDpiForWindow(hwnd);
    if (dpi == 0) return 1.0;
    return @as(f64, @floatFromInt(dpi)) / 96.0;
}

pub fn setViewStyle(view: *root.View, flags: root.ViewStyleFlags) root.Status {
    const hwnd = view.handle orelse return .bad_call;
    var new_ex: DWORD = getWindowExStyle(hwnd);
    if (flags.modal) {
        new_ex |= WS_EX_DLGMODALFRAME;
    } else {
        new_ex &= ~WS_EX_DLGMODALFRAME;
    }
    _ = SetWindowLongPtrW(hwnd, GWL_EXSTYLE, @bitCast(@as(usize, new_ex)));
    const z: HWND = if (flags.above) HWND_TOPMOST else HWND_NOTOPMOST;
    _ = SetWindowPos(hwnd, z, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED | SWP_NOACTIVATE);
    if (flags.demanding) {
        _ = FlashWindow(hwnd, 1);
    }
    if (flags.hidden != (IsIconic(hwnd) != 0)) _ = ShowWindow(hwnd, if (flags.hidden) SW_SHOWMINIMIZED else SW_RESTORE);
    view.style = common.keepState(view.style, flags);
    return .success;
}

extern "dwmapi" fn DwmGetWindowAttribute(hwnd: HWND, attribute: DWORD, value: *anyopaque, size: DWORD) callconv(.winapi) i32;
const DWMWA_CLOAKED: DWORD = 14;

pub fn isOccluded(view: *root.View) bool {
    const own = view.handle orelse return false;
    const hwnd = GetAncestor(own, GA_ROOT) orelse own;
    if (IsIconic(hwnd) != 0 or IsWindowVisible(hwnd) == 0) return true;
    var cloaked: DWORD = 0;
    return DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, &cloaked, @sizeOf(DWORD)) == 0 and cloaked != 0;
}

pub fn obscureView(view: *root.View) root.Status {
    const hwnd = view.handle orelse return .bad_call;
    _ = InvalidateRect(hwnd, null, 0);
    return .success;
}

pub fn obscureRegion(view: *root.View, x: i32, y: i32, w: u32, h: u32) root.Status {
    const hwnd = view.handle orelse return .bad_call;
    const rc = RECT{
        .left = x,
        .top = y,
        .right = x + @as(i32, @intCast(w)),
        .bottom = y + @as(i32, @intCast(h)),
    };
    _ = InvalidateRect(hwnd, &rc, 0);
    return .success;
}

pub fn grabFocus(view: *root.View) root.Status {
    if (view.handle == null) return .bad_call;
    focusView(view);
    return .success;
}

pub fn hasFocus(view: *root.View) bool {
    const hwnd = view.handle orelse return false;
    const f = GetFocus();
    return f == hwnd or (f != null and f == focusTarget(view));
}

pub fn setCursor(view: *root.View, cursor: root.Cursor) root.Status {
    const idc: usize = switch (cursor) {
        .arrow => IDC_ARROW,
        .caret => IDC_IBEAM,
        .crosshair => IDC_CROSS,
        .hand => IDC_HAND,
        .no => IDC_NO,
        .left_right => IDC_SIZEWE,
        .up_down => IDC_SIZENS,
        .up_left_down_right => IDC_SIZENWSE,
        .up_right_down_left => IDC_SIZENESW,
        .all_scroll => IDC_SIZEALL,
    };
    const h = LoadCursorW(null, idc);
    if (getOrInitViewImpl(view)) |vi| vi.cursor = h;
    _ = SetCursor(h);
    return .success;
}

pub fn startTimer(world: *root.World, view: *root.View, id: usize, timeout: f64) root.Status {
    const impl = getWorldImpl(world) orelse return .bad_call;
    const hwnd = view.handle orelse return .bad_call;
    if (timeout <= 0) return .bad_parameter;

    const ms_interval: UINT = @intFromFloat(@min(@floor(timeout * 1000.0), std.math.maxInt(UINT)));

    // Replace existing
    for (impl.timers.items) |*t| {
        if (t.id == id and t.view == view) {
            _ = KillTimer(hwnd, t.win_id);
            t.win_id = SetTimer(hwnd, t.win_id, ms_interval, null);
            return .success;
        }
    }

    // New win32 timer id — use next free slot above TIMER_ID_BASE
    var win_id: UINT_PTR = TIMER_ID_BASE;
    outer: while (true) : (win_id += 1) {
        for (impl.timers.items) |t| {
            if (t.win_id == win_id) continue :outer;
        }
        break;
    }

    const actual = SetTimer(hwnd, win_id, ms_interval, null);
    impl.timers.append(world.allocator, .{
        .hwnd = hwnd,
        .win_id = actual,
        .view = view,
        .id = id,
    }) catch return .no_memory;
    return .success;
}

pub fn stopTimer(world: *root.World, view: *root.View, id: usize) root.Status {
    const impl = getWorldImpl(world) orelse return .bad_call;
    for (impl.timers.items, 0..) |t, i| {
        if (t.id == id and t.view == view) {
            _ = KillTimer(t.hwnd, t.win_id);
            _ = impl.timers.swapRemove(i);
            return .success;
        }
    }
    return .failure;
}

pub fn sendEvent(view: *root.View, event: *const root.Event) root.Status {
    const hwnd = view.handle orelse return .bad_call;
    switch (event.*) {
        .close => {
            _ = SendMessageW(hwnd, WM_CLOSE, 0, 0);
            return .success;
        },
        .client => |c| {
            const wi = getWorldImpl(view.world) orelse return .bad_call;
            if (wi.client_msg == 0) return .failure;
            const lp: LPARAM = @bitCast(@as(usize, c.data2));
            _ = PostMessageW(hwnd, wi.client_msg, @as(WPARAM, c.data1), lp);
            return .success;
        },
        else => return .unsupported,
    }
}

pub fn registerDropType(view: *root.View, mime_type: []const u8) root.Status {
    _ = mime_type;
    const hwnd = view.handle orelse return .bad_call;
    const vi = getOrInitViewImpl(view) orelse return .no_memory;
    if (vi.drop_registered) return .success;
    vi.drop_target = .{
        .vtbl = &drop_target_vtbl,
        .refcount = 1,
        .view = view,
    };
    const dt_ptr: *IDropTarget = @ptrCast(@alignCast(&vi.drop_target));
    if (RegisterDragDrop(hwnd, dt_ptr) != S_OK) return .failure;
    vi.drop_registered = true;
    return .success;
}

pub fn setTransientParent(view: *root.View, parent: root.NativeView) root.Status {
    const hwnd = view.handle orelse return .bad_call;
    const parent_hwnd: HWND = @ptrFromInt(parent);
    _ = SetWindowLongPtrW(hwnd, GWLP_HWNDPARENT, @bitCast(@intFromPtr(parent_hwnd)));
    return .success;
}

pub fn paste(view: *root.View) root.Status {
    if (IsClipboardFormatAvailable(CF_UNICODETEXT) == 0) return .failure;
    if (readClipboardUtf8(view.world) == null) return .failure;
    const offer = root.Event{ .data_offer = .{
        .time = 0,
        .x = 0,
        .y = 0,
        .clipboard = .general,
    } };
    _ = common.dispatchEvent(view, &offer);
    return .success;
}

pub fn getNumClipboardTypes(view: *root.View, clipboard: root.Clipboard) u32 {
    _ = view;
    if (clipboard != .general) return 0;
    return if (IsClipboardFormatAvailable(CF_UNICODETEXT) != 0) 1 else 0;
}

pub fn getClipboardType(view: *root.View, clipboard: root.Clipboard, type_index: u32) ?[]const u8 {
    _ = view;
    if (clipboard != .general or type_index != 0) return null;
    if (IsClipboardFormatAvailable(CF_UNICODETEXT) == 0) return null;
    return "text/plain";
}

fn readClipboardUtf8(world: *root.World) ?[]const u8 {
    const impl = getWorldImpl(world) orelse return null;
    if (OpenClipboard(null) == 0) return null;
    defer _ = CloseClipboard();
    const h = GetClipboardData(CF_UNICODETEXT) orelse return null;
    const ptr = GlobalLock(h) orelse return null;
    defer _ = GlobalUnlock(h);
    const u16_ptr: [*:0]const u16 = @ptrCast(@alignCast(ptr));
    const len = std.mem.indexOfSentinel(u16, 0, u16_ptr);
    impl.clip_buf.clearRetainingCapacity();
    impl.clip_buf.ensureTotalCapacity(world.allocator, len * 3 + 1) catch return null;
    const written = std.unicode.utf16LeToUtf8(impl.clip_buf.allocatedSlice(), u16_ptr[0..len]) catch return null;
    impl.clip_buf.items.len = written;
    return impl.clip_buf.items;
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
    if (type_index != 0) return .bad_parameter;
    const wi = getWorldImpl(view.world) orelse return .failure;
    if (wi.clip_buf.items.len == 0) {
        if (readClipboardUtf8(view.world) == null) return .failure;
    }
    const dev = root.Event{ .data = .{
        .time = 0,
        .x = 0,
        .y = 0,
        .clipboard = .general,
        .type_index = 0,
    } };
    _ = common.dispatchEvent(view, &dev);
    return .success;
}

pub fn rejectOffer(view: *root.View, offer: *const root.DataOfferEvent, rx: i32, ry: i32, rw: u32, rh: u32) root.Status {
    _ = view;
    _ = offer;
    _ = rx;
    _ = ry;
    _ = rw;
    _ = rh;
    return .success;
}

pub fn setClipboard(view: *root.View, clipboard: root.Clipboard, mime_type: []const u8, data: []const u8) root.Status {
    _ = mime_type;
    if (clipboard != .general) return .unsupported;
    const hwnd = view.handle orelse return .bad_call;
    // UTF-8 → UTF-16
    const u16_len = std.unicode.calcUtf16LeLen(data) catch return .bad_parameter;
    const total_bytes = (u16_len + 1) * 2;
    const h = GlobalAlloc(GMEM_MOVEABLE, total_bytes) orelse return .no_memory;
    var owned = true;
    defer if (owned) {
        _ = GlobalFree(h);
    };
    {
        const p = GlobalLock(h) orelse return .failure;
        defer _ = GlobalUnlock(h);
        const dst: [*]u16 = @ptrCast(@alignCast(p));
        _ = std.unicode.utf8ToUtf16Le(dst[0..u16_len], data) catch return .bad_parameter;
        dst[u16_len] = 0;
    }
    if (OpenClipboard(hwnd) == 0) return .failure;
    defer _ = CloseClipboard();
    _ = EmptyClipboard();
    if (SetClipboardData(CF_UNICODETEXT, h) == null) return .failure;
    owned = false;
    return .success;
}

pub fn getClipboard(view: *root.View, clipboard: root.Clipboard, type_index: u32) ?[]const u8 {
    _ = type_index;
    if (clipboard != .general) return null;
    const impl = getWorldImpl(view.world) orelse return null;
    if (impl.clip_buf.items.len > 0) return impl.clip_buf.items;
    return readClipboardUtf8(view.world);
}

pub fn startTextInput(view: *root.View, rect: root.TextInputRect) root.Status {
    const hwnd = view.handle orelse return .bad_call;
    const vi = getOrInitViewImpl(view) orelse return .no_memory;
    ensureTextEdit(view, vi);
    vi.text_active = true;
    if (GetFocus() == hwnd) focusView(view);
    return setTextInputRect(view, rect);
}
pub fn stopTextInput(view: *root.View) root.Status {
    const hwnd = view.handle orelse return .bad_call;
    const vi = getOrInitViewImpl(view) orelse return .no_memory;
    vi.text_active = false;
    if (vi.text_edit != null and GetFocus() == vi.text_edit) _ = SetFocus(hwnd);
    return .success;
}
pub fn setTextInputRect(view: *root.View, rect: root.TextInputRect) root.Status {
    const hwnd = (if (getOrInitViewImpl(view)) |vi| vi.text_edit else null) orelse view.handle orelse return .bad_call;
    const himc = ImmGetContext(hwnd);
    if (himc != null) {
        defer _ = ImmReleaseContext(hwnd, himc);
        var cf = COMPOSITIONFORM{
            .dwStyle = CFS_POINT,
            .ptCurrentPos = .{ .x = rect.x, .y = rect.y },
            .rcArea = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 },
        };
        _ = ImmSetCompositionWindow(himc, &cf);
    }
    return .success;
}

pub fn openUrl(url: [:0]const u8) root.Status {
    var buf: [2048:0]u16 = undefined;
    if (url.len >= buf.len) return .bad_parameter;
    const n = std.unicode.utf8ToUtf16Le(&buf, url) catch return .bad_parameter;
    buf[n] = 0;
    const r = @intFromPtr(ShellExecuteW(null, std.unicode.utf8ToUtf16LeStringLiteral("open"), buf[0..n :0], null, null, 1));
    return if (r > 32) .success else .failure;
}
