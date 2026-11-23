const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zpugl_mod = b.addModule("zpugl", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const library_path = b.option(std.Build.LazyPath, "library_path", "system library path");

    if (target.result.abi.isAndroid()) {
        const ndk = b.option([]const u8, "android_ndk", "Android NDK root") orelse @panic("zpugl: android needs -Dandroid_ndk");
        const glue = b.pathJoin(&.{ ndk, "sources/android/native_app_glue" });
        zpugl_mod.addIncludePath(.{ .cwd_relative = glue });
        zpugl_mod.addCSourceFile(.{ .file = .{ .cwd_relative = b.pathJoin(&.{ glue, "android_native_app_glue.c" }) } });
        zpugl_mod.link_libc = true;
        if (library_path) |p| zpugl_mod.addLibraryPath(p);
        for ([_][]const u8{ "android", "log", "EGL", "GLESv3" }) |lib| zpugl_mod.linkSystemLibrary(lib, .{ .use_pkg_config = .no });
    } else if (target.result.os.tag == .linux) {
        if (library_path) |p| zpugl_mod.addLibraryPath(p);
        const pkg_config: std.Build.Module.SystemLib.UsePkgConfig = if (target.query.isNative()) .yes else .no;
        zpugl_mod.linkSystemLibrary("X11", .{ .use_pkg_config = pkg_config });
        zpugl_mod.linkSystemLibrary("Xcursor", .{ .use_pkg_config = pkg_config });
        zpugl_mod.linkSystemLibrary("Xrender", .{ .use_pkg_config = pkg_config });
        zpugl_mod.linkSystemLibrary("GL", .{ .use_pkg_config = pkg_config });
    }

    if (target.result.os.tag == .macos) {
        if (b.lazyDependency("objc", .{ .target = target, .optimize = optimize })) |objc_dep| {
            zpugl_mod.addImport("objc", objc_dep.module("objc"));
        }
        zpugl_mod.linkFramework("Cocoa", .{});
        zpugl_mod.linkFramework("OpenGL", .{});
        zpugl_mod.linkFramework("QuartzCore", .{});
        zpugl_mod.linkFramework("AudioToolbox", .{});
    }

    if (target.result.os.tag == .ios) {
        const sdk = b.option([]const u8, "sdk_root", "SDK root (iOS)") orelse @panic("zpugl: ios needs -Dsdk_root=$(xcrun --sdk iphoneos --show-sdk-path)");
        if (b.lazyDependency("objc", .{ .target = target, .optimize = optimize, .@"add-paths" = false })) |objc_dep| {
            const objc_mod = objc_dep.module("objc");
            for ([_]*std.Build.Module{ zpugl_mod, objc_mod }) |m| {
                m.addSystemFrameworkPath(.{ .cwd_relative = "/System/Library/Frameworks" });
                m.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ sdk, "usr/include" }) });
                m.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
            }
            zpugl_mod.addImport("objc", objc_mod);
        }
        zpugl_mod.link_libc = true;
        for ([_][]const u8{ "UIKit", "QuartzCore", "Metal", "Foundation", "CoreFoundation" }) |f| zpugl_mod.linkFramework(f, .{});
    }

    // Triangle test
    const triangle = b.addExecutable(.{
        .name = "zpugl-triangle",
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/triangle.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    triangle.root_module.addImport("zpugl", zpugl_mod);
    triangle.root_module.link_libc = true; // dlopen/dlsym in triangle.zig
    if (target.result.os.tag == .macos) {
        triangle.root_module.linkFramework("Cocoa", .{});
        triangle.root_module.linkFramework("OpenGL", .{});
    } else if (target.result.os.tag == .linux) {
        triangle.root_module.linkSystemLibrary("X11", .{});
        triangle.root_module.linkSystemLibrary("GL", .{});
    }

    b.installArtifact(triangle);
    const run_triangle = b.addRunArtifact(triangle);
    run_triangle.stdio = .inherit;
    run_triangle.addPassthruArgs();
    const triangle_step = b.step("run-triangle", "Run the zpugl triangle test");
    triangle_step.dependOn(&run_triangle.step);

    const tests = b.addTest(.{ .root_module = zpugl_mod });
    b.step("test", "Run the zpugl tests").dependOn(&b.addRunArtifact(tests).step);

    // check-cross: compile-only check for all supported target triples.
    // Linux/Windows ABI types are declared inline in x11.zig/win32.zig so no
    // sysroot or C headers are needed — we build as a static lib (no link step).
    const check_cross_step = b.step("check-cross", "Compile-check zpugl for all target triples");

    // macOS targets need zig-objc which calls addAppleSDK at build-script
    // time; that requires an Apple SDK on the build host, so we restrict
    // the macOS cross-check to macOS hosts only. Linux/Windows targets
    // declare their ABI types inline in x11.zig/win32.zig and need no
    // sysroot to compile.
    const host_is_macos = @import("builtin").os.tag == .macos;
    const cross_queries = if (host_is_macos) &[_]std.Target.Query{
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
        .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
        .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
        .{ .cpu_arch = .x86_64, .os_tag = .macos },
    } else &[_]std.Target.Query{
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
        .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
        .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    };

    for (cross_queries) |q| {
        const ct = b.resolveTargetQuery(q);
        const mod = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = ct,
            .optimize = optimize,
        });
        // macOS needs zig-objc import
        if (q.os_tag == .macos) {
            if (b.lazyDependency("objc", .{ .target = ct, .optimize = optimize })) |objc_dep| {
                mod.addImport("objc", objc_dep.module("objc"));
            }
        }
        const lib = b.addLibrary(.{
            .name = b.fmt("zpugl-{s}-{s}", .{
                @tagName(q.cpu_arch.?),
                @tagName(q.os_tag.?),
            }),
            .linkage = .static,
            .root_module = mod,
        });
        check_cross_step.dependOn(&lib.step);
    }
}
