# zpugl

Zig port of [pugl](https://gitlab.com/lv2/pugl) — a minimal cross-platform windowing library for audio plugins and standalone applications.
zpugl creates native OS windows and delivers input events to a callback. You get a window, a graphics context, and a stream of events.

Intended for:

- Audio plugin GUIs (VST3, CLAP, AU) that need to embed into a host window
- Standalone plugin hosts that need to hand a window handle to a plugin
- Lightweight applications that want direct control over rendering

### World

A `World` owns the connection to the OS windowing system (X11 Display, Win32 HINSTANCE, etc.). One world per process is typical.

```zig
const world = try zpugl.World.init(allocator, .program, .{});
defer world.deinit();
```

### View

A `View` is a single native window or embedded sub-window. It has an event callback, optional size hints, and a graphics backend (`.gl`, `.metal`, `.vulkan` or `.stub`).

```zig
const view = try zpugl.View.init(world, onEvent);
view.setBackend(.gl);
_ = view.setSizeHint(.default_size, 800, 600);
try view.realize();    // creates the native window
_ = view.show(.raise);
```

### Event loop

```zig
while (running) {
    _ = world.update(0.016); // block up to 16ms for events
}
```

### Event callback

```zig
fn onEvent(view: *zpugl.View, event: *const zpugl.Event) zpugl.Status {
    switch (event.*) {
        .expose  => |e| { _ = e; /* draw here */ },
        .close   => std.process.exit(0),
        .key_press => |k| std.debug.print("key {x}\n", .{k.key}),
        else     => {},
    }
    return .success;
}
```

The `.expose` event fires inside an active GL context when using `.gl` backend — `glDraw*` calls work directly without extra setup.

## Sub-windows and plugin embedding

### As a plugin — embedding into a host window

The plugin host passes you a native parent handle. Set it before `realize`:

```zig
// parent_handle is whatever the host gave you:
//   macOS: NSView*  cast to usize
//   Windows: HWND   cast to usize
//   Linux: XID (c_ulong) cast to usize
view.setParent(parent_handle);
try view.realize();
// No show() needed — child windows follow parent visibility
```

After `realize`, `@intFromPtr(view.handle.?)` is your native child window handle. You don't need to pass it back to the host — the OS has already parented it.

### As a host — giving a handle to a plugin

Create a view with the stub backend (no GL context needed — just a native window):

```zig
view.setBackend(.stub);
view.setParent(0); // top-level
try view.realize();
_ = view.show(.raise);

// Hand to plugin:
const native: usize = @intFromPtr(view.handle.?);
plugin.set_parent(native); // CLAP: clap_window_t.ptr, VST3: IPlugView::attached()
```

The plugin creates its own child window inside yours. zpugl's event loop (`world.update`) keeps your window processing messages, which the OS propagates to the plugin's child window automatically.

## Graphics backends

### `.gl` — OpenGL

Creates a platform GL context (NSOpenGLContext / WGL / GLX). The context is made current automatically around each `.expose` event. Call `glDraw*` directly in the expose handler.

Configure the context before `realize`:

```zig
_ = view.setHint(.context_version_major, 3);
_ = view.setHint(.context_version_minor, 3);
_ = view.setHint(.context_profile, @intFromEnum(zpugl.ViewHintValue.opengl_core_profile));
_ = view.setHint(.double_buffer, @intFromEnum(zpugl.ViewHintValue.true));
```

### `.stub` — no graphics context

Creates a native window with no GL context, for

- Hosting a plugin that provides its own rendering
- Embedding a third-party UI framework (e.g. JUCE, iPlug2) that manages its own context
- You only need the window handle, not rendering

### `.metal` / `.vulkan`

`view.getContext()` returns what you need to create your own device and swapchain: the `CAMetalLayer` for `.metal`, and for `.vulkan` the `CAMetalLayer` (macOS, MoltenVK), the `HWND` (Windows) or the X11 `Window` (Linux). Rendering is up to you.

## Platform notes

| Platform | Windowing          | Window type        | GL              |
| -------- | ------------------ | ------------------ | --------------- |
| macOS    | Cocoa (zig-objc)   | NSView in NSWindow | NSOpenGLContext |
| iOS      | UIKit (zig-objc)   | UIView             | none (Metal)    |
| Windows  | Win32              | HWND               | WGL             |
| Linux    | X11                | XID (Window)       | GLX             |
| Android  | NativeActivity     | ANativeWindow      | EGL / GLES 3    |


Cross-compiling to Linux needs no headers (X11/GL types are declared in Zig); pass `-Dlibrary_path=<dir with libX11/libXcursor/libXrender/libGL .so>` for the link step.

Build options:

- iOS: `-Dsdk_root=$(xcrun --sdk iphoneos --show-sdk-path)`
- Android: `-Dandroid_ndk=<ndk root>`, optionally `-Dlibrary_path=<sysroot lib dir>`

## Build

```sh
zig build run-triangle                    # GL triangle demo
zig build run-triangle -- --backend=metal # gl | metal | vulkan | stub
zig build check-cross                     # compile-check Linux, Windows (and macOS on macOS hosts)
```

To use as a dependency:

```sh
zig fetch --save git+https://github.com/nat3Github/zig-lib-zpugl
```

```zig
// in your build.zig
const zpugl = b.dependency("zpugl", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("zpugl", zpugl.module("zpugl"));
```

## License

ISC. See [LICENSE](LICENSE).
