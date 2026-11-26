const std = @import("std");
const builtin = @import("builtin");
const root = @import("../root.zig");

pub const GlContext = usize; // platform handle stored in view.gl_context
const is_android = builtin.abi.isAndroid();
const android = if (is_android) @import("android.zig") else struct {};

pub fn get_backend() root.GraphicsBackend {
    return .{
        .configure = configure,
        .create = create,
        .destroy = destroy,
        .enter = enter,
        .leave = leave,
        .get_context = get_context,
    };
}

fn configure(v: ?*anyopaque) root.Status {
    _ = v;
    return .success;
}

fn get_context(v: ?*anyopaque) ?*anyopaque {
    const view: *root.View = @ptrCast(@alignCast(v.?));
    return @ptrFromInt(view.gl_context);
}

pub fn create(v: ?*anyopaque) root.Status {
    const view: *root.View = @ptrCast(@alignCast(v.?));
    const native = @intFromPtr(view.handle orelse return .bad_call);
    const major = view.hints[@backingInt(root.ViewHint.context_version_major)];
    const minor = view.hints[@backingInt(root.ViewHint.context_version_minor)];
    const profile = view.hints[@backingInt(root.ViewHint.context_profile)];
    const double_buf = view.hints[@backingInt(root.ViewHint.double_buffer)] != 0;
    const swap_interval = view.hints[@backingInt(root.ViewHint.swap_interval)];

    const ctx = if (is_android) android.glCreate(view) else switch (builtin.os.tag) {
        .macos => macos_gl_create(native, major, minor, profile, double_buf, swap_interval),
        .windows => win32_gl_create(view, double_buf),
        else => x11_gl_create(view, major, minor, profile, double_buf),
    };
    if (ctx == 0) return .create_context_failed;
    view.gl_context = ctx;
    return .success;
}

pub fn destroy(v: ?*anyopaque) void {
    const view: *root.View = @ptrCast(@alignCast(v.?));
    if (view.gl_context == 0) return;
    if (is_android) android.glDestroy() else switch (builtin.os.tag) {
        .macos => macos_gl_destroy(view.gl_context),
        .windows => win32_gl_destroy(view),
        else => x11_gl_destroy(view),
    }
    view.gl_context = 0;
}

pub fn enter(v: ?*anyopaque, expose: ?*const root.ExposeEvent) root.Status {
    _ = expose;
    const view: *root.View = @ptrCast(@alignCast(v.?));
    if (view.gl_context == 0) return .bad_call;
    const ok: bool = if (is_android) android.glEnter() else switch (builtin.os.tag) {
        .macos => blk: {
            macos_gl_enter(view.gl_context);
            break :blk true;
        },
        .windows => win32_gl_enter(view.gl_context),
        else => blk: {
            x11_gl_enter(view.gl_context);
            break :blk true;
        },
    };
    if (!ok) return .bad_call;
    return .success;
}

pub fn leave(v: ?*anyopaque, expose: ?*const root.ExposeEvent) root.Status {
    const swap = expose != null;
    const view: *root.View = @ptrCast(@alignCast(v.?));
    if (view.gl_context == 0) return .bad_call;
    if (is_android) android.glLeave(swap) else switch (builtin.os.tag) {
        .macos => macos_gl_leave(view.gl_context, swap),
        .windows => win32_gl_leave(view.gl_context, swap),
        else => x11_gl_leave(view.gl_context, swap),
    }
    return .success;
}

pub fn resize(view: *root.View) void {
    if (view.gl_context == 0) return;
    switch (builtin.os.tag) {
        .macos => macos_gl_resize(view.gl_context),
        else => {},
    }
}

// ─── macOS ───────────────────────────────────────────────────────────────────

const macos_backend = if (builtin.os.tag == .macos) @import("macos.zig") else struct {};

fn macos_gl_create(native: usize, major: i32, minor: i32, profile: i32, double_buf: bool, swap_interval: i32) usize {
    if (builtin.os.tag != .macos) return 0;
    return macos_backend.zpugl_mac_gl_create(native, major, minor, profile, double_buf, swap_interval);
}
fn macos_gl_destroy(ctx: usize) void {
    if (builtin.os.tag == .macos) macos_backend.zpugl_mac_gl_destroy(ctx);
}
fn macos_gl_enter(ctx: usize) void {
    if (builtin.os.tag == .macos) macos_backend.zpugl_mac_gl_enter(ctx);
}
fn macos_gl_leave(ctx: usize, swap: bool) void {
    if (builtin.os.tag == .macos) macos_backend.zpugl_mac_gl_leave(ctx, swap);
}
fn macos_gl_resize(ctx: usize) void {
    if (builtin.os.tag == .macos) macos_backend.zpugl_mac_gl_resize(ctx);
}

// ─── Win32 / WGL ─────────────────────────────────────────────────────────────

const win32 = if (builtin.os.tag == .windows) @import("win32.zig") else struct {};

const WglCtx = struct {
    hdc: win32.HDC,
    hglrc: win32.HGLRC,
    hwnd: win32.HWND,
    // Non-null when using a memory DC (offscreen fallback for Session 0).
    mem_dc: win32.HDC = null,
    mem_bmp: win32.HBITMAP = null,
};

fn win32_gl_create(view: *root.View, double_buf: bool) usize {
    if (builtin.os.tag != .windows) return 0;
    const hwnd = view.handle orelse return 0;
    const hdc = win32.GetDC(hwnd);
    const alloc = view.world.allocator;

    var pfd = win32.PIXELFORMATDESCRIPTOR{
        .dwFlags = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL |
            if (double_buf) win32.PFD_DOUBLEBUFFER else 0,
        .iPixelType = win32.PFD_TYPE_RGBA,
        .cColorBits = 32,
        .cDepthBits = 24,
        .cStencilBits = 8,
        .iLayerType = 0,
    };

    const fmt = win32.ChoosePixelFormat(hdc, &pfd);
    if (fmt == 0) {
        _ = win32.ReleaseDC(hwnd, hdc);
        return 0;
    }
    if (win32.SetPixelFormat(hdc, fmt, &pfd) == 0) {
        _ = win32.ReleaseDC(hwnd, hdc);
        return 0;
    }

    const hglrc = win32.wglCreateContext(hdc) orelse {
        _ = win32.ReleaseDC(hwnd, hdc);
        return 0;
    };

    if (win32.wglMakeCurrent(hdc, hglrc) == 0) {
        // Hardware ICD refused to make context current (common in Session 0 /
        // headless environments on AMD).  Delete the unusable context and try
        // creating a generic software-renderer context on the SAME DC.  This
        // requires choosing a software pixel format; because SetPixelFormat
        // can only be called once per DC, we pick format 1 directly (the
        // generic GDI renderer, always present on Windows).
        // Note: don't call wglDeleteContext here — on some AMD ICDs the handle
        // may be a stub that crashes on delete.  The leaked context is small.

        // Try format 1 (Microsoft generic OpenGL) explicitly.
        var sw_pfd = win32.PIXELFORMATDESCRIPTOR{
            .dwFlags = win32.PFD_DRAW_TO_WINDOW | win32.PFD_SUPPORT_OPENGL |
                win32.PFD_GENERIC_FORMAT |
                if (double_buf) win32.PFD_DOUBLEBUFFER else 0,
            .iPixelType = win32.PFD_TYPE_RGBA,
            .cColorBits = 32,
            .cDepthBits = 24,
            .cStencilBits = 8,
            .iLayerType = 0,
        };
        // SetPixelFormat will fail (already called); that's expected.
        // wglCreateContext reads the format that was already set on the DC.
        _ = win32.SetPixelFormat(hdc, 1, &sw_pfd);
        const sw_hglrc = win32.wglCreateContext(hdc) orelse {
            std.debug.print("[gl.create] software fallback wglCreateContext failed hwnd={?*}\n", .{hwnd});
            _ = win32.ReleaseDC(hwnd, hdc);
            return 0;
        };
        if (win32.wglMakeCurrent(hdc, sw_hglrc) == 0) {
            // Both window-DC paths failed (likely Session 0, no display).
            // Final fallback: create a memory DC with a DIB bitmap.  This
            // offscreen surface works even without a display or active session.
            _ = win32.ReleaseDC(hwnd, hdc);
            const mem_dc = win32.CreateCompatibleDC(null);
            if (mem_dc == null) {
                std.debug.print("[gl.create] CreateCompatibleDC failed hwnd={?*}\n", .{hwnd});
                return 0;
            }
            var bmi = win32.BITMAPINFO{};
            bmi.bmiHeader.biWidth = 512;
            bmi.bmiHeader.biHeight = 512;
            bmi.bmiHeader.biBitCount = 32;
            var bits: ?*anyopaque = null;
            const bmp = win32.CreateDIBSection(mem_dc, &bmi, 0, &bits, null, 0);
            _ = win32.SelectObject(mem_dc, bmp);
            var dib_pfd = win32.PIXELFORMATDESCRIPTOR{
                .dwFlags = win32.PFD_DRAW_TO_BITMAP | win32.PFD_SUPPORT_OPENGL |
                    win32.PFD_GENERIC_FORMAT,
                .iPixelType = win32.PFD_TYPE_RGBA,
                .cColorBits = 32,
                .cDepthBits = 24,
                .cStencilBits = 8,
                .iLayerType = 0,
            };
            const dib_fmt = win32.ChoosePixelFormat(mem_dc, &dib_pfd);
            if (dib_fmt == 0 or win32.SetPixelFormat(mem_dc, dib_fmt, &dib_pfd) == 0) {
                std.debug.print("[gl.create] memory DC pixel format failed\n", .{});
                _ = win32.DeleteObject(bmp);
                _ = win32.DeleteDC(mem_dc);
                return 0;
            }
            const dib_hglrc = win32.wglCreateContext(mem_dc) orelse {
                std.debug.print("[gl.create] memory DC wglCreateContext failed\n", .{});
                _ = win32.DeleteObject(bmp);
                _ = win32.DeleteDC(mem_dc);
                return 0;
            };
            if (win32.wglMakeCurrent(mem_dc, dib_hglrc) == 0) {
                std.debug.print("[gl.create] memory DC wglMakeCurrent failed — no OpenGL available\n", .{});
                _ = win32.wglDeleteContext(dib_hglrc);
                _ = win32.DeleteObject(bmp);
                _ = win32.DeleteDC(mem_dc);
                return 0;
            }
            _ = win32.wglMakeCurrent(null, null);
            const dib_ctx = alloc.create(WglCtx) catch {
                _ = win32.wglDeleteContext(dib_hglrc);
                _ = win32.DeleteObject(bmp);
                _ = win32.DeleteDC(mem_dc);
                return 0;
            };
            dib_ctx.* = .{ .hdc = mem_dc, .hglrc = dib_hglrc, .hwnd = hwnd, .mem_dc = mem_dc, .mem_bmp = bmp };
            return @intFromPtr(dib_ctx);
        }
        _ = win32.wglMakeCurrent(null, null);
        const ctx = alloc.create(WglCtx) catch {
            _ = win32.wglDeleteContext(sw_hglrc);
            _ = win32.ReleaseDC(hwnd, hdc);
            return 0;
        };
        ctx.* = .{ .hdc = hdc, .hglrc = sw_hglrc, .hwnd = hwnd };
        return @intFromPtr(ctx);
    }

    _ = win32.wglMakeCurrent(null, null);
    const ctx = alloc.create(WglCtx) catch {
        _ = win32.wglDeleteContext(hglrc);
        _ = win32.ReleaseDC(hwnd, hdc);
        return 0;
    };
    ctx.* = .{ .hdc = hdc, .hglrc = hglrc, .hwnd = hwnd };
    return @intFromPtr(ctx);
}

fn win32_gl_destroy(view: *root.View) void {
    if (builtin.os.tag != .windows) return;
    const ctx: *WglCtx = @ptrFromInt(view.gl_context);
    _ = win32.wglMakeCurrent(null, null);
    _ = win32.wglDeleteContext(ctx.hglrc);
    if (ctx.mem_dc != null) {
        // Memory DC path: release the bitmap and DC.
        _ = win32.DeleteObject(ctx.mem_bmp);
        _ = win32.DeleteDC(ctx.mem_dc);
    } else {
        _ = win32.ReleaseDC(ctx.hwnd, ctx.hdc);
    }
    view.world.allocator.destroy(ctx);
}

fn win32_gl_enter(ctx_ptr: usize) bool {
    if (builtin.os.tag != .windows) return true;
    const ctx: *WglCtx = @ptrFromInt(ctx_ptr);
    return win32.wglMakeCurrent(ctx.hdc, ctx.hglrc) != 0;
}

fn win32_gl_leave(ctx_ptr: usize, swap: bool) void {
    if (builtin.os.tag != .windows) return;
    const ctx: *WglCtx = @ptrFromInt(ctx_ptr);
    if (swap and ctx.mem_dc == null) {
        _ = win32.SwapBuffers(ctx.hdc);
    }
    _ = win32.wglMakeCurrent(null, null);
}

// ─── X11 / GLX ───────────────────────────────────────────────────────────────

const x11 = if (builtin.os.tag == .linux and !is_android) @import("x11.zig") else struct {};

const GlxCtx = struct {
    display: *x11.Display,
    ctx: x11.GLXContext,
    drawable: x11.GLXDrawable,
};

fn x11_gl_create(view: *root.View, major: i32, minor: i32, profile: i32, double_buf: bool) usize {
    if (builtin.os.tag != .linux or is_android) return 0;
    const x11_mod = @import("x11.zig");

    const win_id: x11.Window = @intFromPtr(view.handle orelse return 0);

    // Get display from WorldImpl
    const world_impl: *x11_mod.WorldImpl = @ptrCast(@alignCast(view.world.impl orelse return 0));
    const display = world_impl.display;
    const screen = x11_mod.XDefaultScreen(display);

    // Choose FB config
    var attribs = [_]c_int{
        x11_mod.GLX_RENDER_TYPE,   x11_mod.GLX_RGBA_BIT,
        x11_mod.GLX_DRAWABLE_TYPE, x11_mod.GLX_WINDOW_BIT,
        x11_mod.GLX_RED_SIZE,      8,
        x11_mod.GLX_GREEN_SIZE,    8,
        x11_mod.GLX_BLUE_SIZE,     8,
        x11_mod.GLX_ALPHA_SIZE,    8,
        x11_mod.GLX_DEPTH_SIZE,    24,
        x11_mod.GLX_STENCIL_SIZE,  8,
        x11_mod.GLX_DOUBLEBUFFER,  @intFromBool(double_buf),
        0,
    };

    var n_configs: c_int = 0;
    const configs = x11_mod.glXChooseFBConfig(display, screen, &attribs, &n_configs) orelse {
        return x11_gl_create_legacy(view, display, screen, double_buf);
    };
    if (n_configs == 0) return x11_gl_create_legacy(view, display, screen, double_buf);

    const config = configs[0];

    // Try glXCreateContextAttribsARB for core profile
    const glx_ctx: ?x11_mod.GLXContext = blk: {
        if (major > 0) {
            const proc = x11_mod.glXGetProcAddress("glXCreateContextAttribsARB") orelse break :blk null;
            const fn_ptr: x11_mod.PFNGLXCREATECONTEXTATTRIBSARBPROC = @ptrCast(proc);
            const profile_bit: c_int = if (profile == @backingInt(root.ViewHintValue.opengl_core_profile))
                x11_mod.GLX_CONTEXT_CORE_PROFILE_BIT_ARB
            else
                x11_mod.GLX_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB;
            const ctx_attribs = [_]c_int{
                x11_mod.GLX_CONTEXT_MAJOR_VERSION_ARB, major,
                x11_mod.GLX_CONTEXT_MINOR_VERSION_ARB, @max(minor, 0),
                x11_mod.GLX_CONTEXT_PROFILE_MASK_ARB,  profile_bit,
                0,
            };
            break :blk fn_ptr(display, config, null, 1, &ctx_attribs);
        }
        break :blk null;
    };

    const ctx = glx_ctx orelse
        // GLX_RGBA_TYPE is the correct renderType for glXCreateNewContext.
        x11_mod.glXCreateNewContext(display, config, x11_mod.GLX_RGBA_TYPE, null, 1) orelse
        // Retry with indirect rendering (required for Xvfb and some software renderers).
        x11_mod.glXCreateNewContext(display, config, x11_mod.GLX_RGBA_TYPE, null, 0) orelse {
        std.debug.print("[x11_gl_create] glXCreateNewContext both direct and indirect failed\n", .{});
        return x11_gl_create_legacy(view, display, screen, double_buf);
    };

    _ = x11_mod.XFree(@ptrCast(configs));

    const glx = view.world.allocator.create(GlxCtx) catch {
        x11_mod.glXDestroyContext(display, ctx);
        return 0;
    };
    glx.* = .{ .display = display, .ctx = ctx, .drawable = win_id };
    return @intFromPtr(glx);
}

fn x11_gl_create_legacy(view: *root.View, display: *x11.Display, screen: c_int, double_buf: bool) usize {
    if (builtin.os.tag != .linux or is_android) return 0;
    const x11_mod = @import("x11.zig");

    var attribs = [_]c_int{
        x11_mod.GLX_RGBA,
        x11_mod.GLX_RED_SIZE,
        8,
        x11_mod.GLX_GREEN_SIZE,
        8,
        x11_mod.GLX_BLUE_SIZE,
        8,
        x11_mod.GLX_DEPTH_SIZE,
        24,
        if (double_buf) x11_mod.GLX_DOUBLEBUFFER else 0,
        0,
    };
    const vi = x11_mod.glXChooseVisual(display, screen, &attribs) orelse {
        std.debug.print("[x11_gl_create_legacy] glXChooseVisual returned null\n", .{});
        return 0;
    };
    const ctx = x11_mod.glXCreateContext(display, vi, null, 1) orelse {
        std.debug.print("[x11_gl_create_legacy] glXCreateContext returned null\n", .{});
        _ = x11_mod.XFree(@ptrCast(vi));
        return 0;
    };
    _ = x11_mod.XFree(@ptrCast(vi));

    const win_id: x11.Window = @intFromPtr(view.handle orelse return 0);
    const glx = view.world.allocator.create(GlxCtx) catch {
        x11_mod.glXDestroyContext(display, ctx);
        return 0;
    };
    glx.* = .{ .display = display, .ctx = ctx, .drawable = win_id };
    return @intFromPtr(glx);
}

fn x11_gl_destroy(view: *root.View) void {
    if (builtin.os.tag != .linux or is_android) return;
    const x11_mod = @import("x11.zig");
    const glx: *GlxCtx = @ptrFromInt(view.gl_context);
    _ = x11_mod.glXMakeCurrent(glx.display, 0, null);
    x11_mod.glXDestroyContext(glx.display, glx.ctx);
    view.world.allocator.destroy(glx);
}

fn x11_gl_enter(ctx_ptr: usize) void {
    if (builtin.os.tag != .linux or is_android) return;
    const x11_mod = @import("x11.zig");
    const glx: *GlxCtx = @ptrFromInt(ctx_ptr);
    _ = x11_mod.glXMakeCurrent(glx.display, glx.drawable, glx.ctx);
}

fn x11_gl_leave(ctx_ptr: usize, swap: bool) void {
    if (builtin.os.tag != .linux or is_android) return;
    const x11_mod = @import("x11.zig");
    const glx: *GlxCtx = @ptrFromInt(ctx_ptr);
    if (swap) x11_mod.glXSwapBuffers(glx.display, glx.drawable);
    _ = x11_mod.glXMakeCurrent(glx.display, 0, null);
}
