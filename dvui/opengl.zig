const std = @import("std");
const builtin = @import("builtin");
const dvui = @import("dvui");
pub const c = @import("gl.zig");

extern "opengl32" fn wglGetProcAddress(name: [*:0]const u8) callconv(.winapi) ?*const anyopaque;

const gl_ext_names = [_][:0]const u8{
    "glAttachShader",        "glBindBuffer",              "glBindFramebuffer",      "glBindVertexArray",
    "glBufferData",          "glCompileShader",           "glCreateProgram",        "glCreateShader",
    "glDeleteBuffers",       "glDeleteFramebuffers",      "glDeleteProgram",        "glDeleteShader",
    "glDeleteVertexArrays",  "glEnableVertexAttribArray", "glFramebufferTexture2D", "glGenBuffers",
    "glGenFramebuffers",     "glGenVertexArrays",         "glGetProgramInfoLog",    "glGetProgramiv",
    "glGetShaderInfoLog",    "glGetShaderiv",             "glGetUniformLocation",   "glLinkProgram",
    "glShaderSource",        "glUniform1i",               "glUniformMatrix4fv",     "glUseProgram",
    "glVertexAttribPointer",
};

fn GlTrampoline(comptime name: [:0]const u8) type {
    const F = @TypeOf(@field(c, name));
    const info = @typeInfo(F).@"fn";
    const R = info.return_type.?;
    const P = info.param_types;
    const cc = info.attrs.@"callconv";
    return struct {
        var ptr: ?*const F = null;
        fn get() *const F {
            if (ptr) |p| return p;
            const p: *const F = @ptrCast(wglGetProcAddress(name) orelse @panic("missing GL function " ++ name));
            ptr = p;
            return p;
        }
        fn f0() callconv(cc) R {
            return get()();
        }
        fn f1(a: P[0].?) callconv(cc) R {
            return get()(a);
        }
        fn f2(a: P[0].?, b: P[1].?) callconv(cc) R {
            return get()(a, b);
        }
        fn f3(a: P[0].?, b: P[1].?, d: P[2].?) callconv(cc) R {
            return get()(a, b, d);
        }
        fn f4(a: P[0].?, b: P[1].?, d: P[2].?, e: P[3].?) callconv(cc) R {
            return get()(a, b, d, e);
        }
        fn f5(a: P[0].?, b: P[1].?, d: P[2].?, e: P[3].?, g: P[4].?) callconv(cc) R {
            return get()(a, b, d, e, g);
        }
        fn f6(a: P[0].?, b: P[1].?, d: P[2].?, e: P[3].?, g: P[4].?, h: P[5].?) callconv(cc) R {
            return get()(a, b, d, e, g, h);
        }
        const call = switch (P.len) {
            0 => f0,
            1 => f1,
            2 => f2,
            3 => f3,
            4 => f4,
            5 => f5,
            6 => f6,
            else => @compileError("unsupported arity for " ++ name),
        };
    };
}

comptime {
    if (builtin.os.tag == .windows) {
        for (gl_ext_names) |name| @export(&GlTrampoline(name).call, .{ .name = name });
    }
}

const is_gles = builtin.abi.isAndroid();
const shader_header = if (is_gles) "#version 300 es\nprecision highp float;\n" else "#version 330 core\n";

pub const vertex_shader_src = shader_header ++
    \\layout (location = 0) in vec2 aPos;
    \\layout (location = 1) in vec2 aTexCoord;
    \\layout (location = 2) in vec4 aColor;
    \\out vec2 TexCoord;
    \\out vec4 Color;
    \\uniform mat4 projection;
    \\void main() {
    \\    gl_Position = projection * vec4(aPos, 0.0, 1.0);
    \\    TexCoord = aTexCoord;
    \\    Color = aColor;
    \\}
;

pub const fragment_shader_src = shader_header ++
    \\in vec2 TexCoord;
    \\in vec4 Color;
    \\out vec4 FragColor;
    \\uniform sampler2D ourTexture;
    \\uniform bool hasTexture;
    \\void main() {
    \\    if (hasTexture) {
    \\        FragColor = texture(ourTexture, TexCoord) * Color;
    \\    } else {
    \\        FragColor = Color;
    \\    }
    \\}
;

pub const GLState = struct {
    shader_program: c.GLuint = 0,
    vao: c.GLuint = 0,
    vbo: c.GLuint = 0,
    ebo: c.GLuint = 0,
    target_fbo: c.GLuint = 0,
    target_size: ?dvui.Size.Physical = null,

    pub fn init() !GLState {
        var self = GLState{};
        const vs = c.glCreateShader(c.GL_VERTEX_SHADER);
        const vs_src_ptr: ?[*]const u8 = vertex_shader_src.ptr;
        const vs_len: c_int = @intCast(vertex_shader_src.len);
        c.glShaderSource(vs, 1, &vs_src_ptr, &vs_len);
        c.glCompileShader(vs);

        var success: c.GLint = 0;
        c.glGetShaderiv(vs, c.GL_COMPILE_STATUS, &success);
        if (success == c.GL_FALSE) {
            var info_log: [512]u8 = undefined;
            c.glGetShaderInfoLog(vs, 512, null, &info_log);
            std.log.err("Vertex Shader Compilation Failed: {s}", .{std.mem.sliceTo(&info_log, 0)});
            return error.ShaderCompilationFailed;
        }

        const fs = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        const fs_src_ptr: ?[*]const u8 = fragment_shader_src.ptr;
        const fs_len: c_int = @intCast(fragment_shader_src.len);
        c.glShaderSource(fs, 1, &fs_src_ptr, &fs_len);
        c.glCompileShader(fs);

        c.glGetShaderiv(fs, c.GL_COMPILE_STATUS, &success);
        if (success == c.GL_FALSE) {
            var info_log: [512]u8 = undefined;
            c.glGetShaderInfoLog(fs, 512, null, &info_log);
            std.log.err("Fragment Shader Compilation Failed: {s}", .{std.mem.sliceTo(&info_log, 0)});
            return error.ShaderCompilationFailed;
        }

        self.shader_program = c.glCreateProgram();
        c.glAttachShader(self.shader_program, vs);
        c.glAttachShader(self.shader_program, fs);
        c.glLinkProgram(self.shader_program);

        c.glGetProgramiv(self.shader_program, c.GL_LINK_STATUS, &success);
        if (success == c.GL_FALSE) {
            var info_log: [512]u8 = undefined;
            c.glGetProgramInfoLog(self.shader_program, 512, null, &info_log);
            std.log.err("Shader Program Linking Failed: {s}", .{std.mem.sliceTo(&info_log, 0)});
            return error.ShaderProgramLinkingFailed;
        }

        c.glDeleteShader(vs);
        c.glDeleteShader(fs);

        c.glGenVertexArrays(1, &self.vao);
        c.glGenBuffers(1, &self.vbo);
        c.glGenBuffers(1, &self.ebo);

        c.glBindVertexArray(self.vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, self.ebo);

        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(dvui.Vertex), @ptrFromInt(@offsetOf(dvui.Vertex, "pos")));
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(dvui.Vertex), @ptrFromInt(@offsetOf(dvui.Vertex, "uv")));
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(2, 4, c.GL_UNSIGNED_BYTE, c.GL_TRUE, @sizeOf(dvui.Vertex), @ptrFromInt(@offsetOf(dvui.Vertex, "col")));
        c.glEnableVertexAttribArray(2);

        return self;
    }

    pub fn deinit(self: *GLState) void {
        if (self.target_fbo != 0) c.glDeleteFramebuffers(1, &self.target_fbo);
        c.glDeleteProgram(self.shader_program);
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
        c.glDeleteBuffers(1, &self.ebo);
    }

    pub fn renderTarget(self: *GLState, texture: ?dvui.TextureTarget) void {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
        if (self.target_fbo != 0) c.glDeleteFramebuffers(1, &self.target_fbo);
        self.target_fbo = 0;
        self.target_size = null;
        const t = texture orelse return;
        self.target_fbo = bindTargetFbo(@intCast(@intFromPtr(t.ptr)));
        self.target_size = .{ .w = @floatFromInt(t.width), .h = @floatFromInt(t.height) };
    }

    pub fn drawClippedTriangles(self: *GLState, screen_width: u32, screen_height: u32, texture: ?dvui.Texture, vtx: []const dvui.Vertex, idx: []const u16, clipr: ?dvui.Rect.Physical) !void {
        const width: u32 = if (self.target_size) |s| @intFromFloat(s.w) else screen_width;
        const height: u32 = if (self.target_size) |s| @intFromFloat(s.h) else screen_height;
        const flip: f32 = if (self.target_size != null) -1 else 1;
        c.glViewport(0, 0, @intCast(width), @intCast(height));
        c.glUseProgram(self.shader_program);

        const projection = [16]f32{
            2.0 / @as(f32, @floatFromInt(width)), 0,                                             0,  0,
            0,                                    -flip * 2.0 / @as(f32, @floatFromInt(height)), 0,  0,
            0,                                    0,                                             -1, 0,
            -1,                                   flip,                                          0,  1,
        };
        const proj_loc = c.glGetUniformLocation(self.shader_program, "projection");
        c.glUniformMatrix4fv(proj_loc, 1, c.GL_FALSE, &projection);

        const has_tex_loc = c.glGetUniformLocation(self.shader_program, "hasTexture");
        if (texture) |t| {
            c.glUniform1i(has_tex_loc, 1);
            c.glBindTexture(c.GL_TEXTURE_2D, @intCast(@intFromPtr(t.ptr)));
        } else {
            c.glUniform1i(has_tex_loc, 0);
        }

        c.glBindVertexArray(self.vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(vtx.len * @sizeOf(dvui.Vertex)), vtx.ptr, c.GL_STREAM_DRAW);

        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, self.ebo);
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(idx.len * @sizeOf(u16)), idx.ptr, c.GL_STREAM_DRAW);

        if (clipr) |r| {
            c.glEnable(c.GL_SCISSOR_TEST);
            // GL scissor is bottom-left origin
            const y = if (self.target_size != null) r.y else @as(f32, @floatFromInt(height)) - r.y - r.h;
            c.glScissor(@intCast(@as(i32, @intFromFloat(r.x))), @intCast(@as(i32, @intFromFloat(y))), @intCast(@as(i32, @intFromFloat(r.w))), @intCast(@as(i32, @intFromFloat(r.h))));
        } else {
            c.glDisable(c.GL_SCISSOR_TEST);
        }

        c.glDrawElements(c.GL_TRIANGLES, @intCast(idx.len), c.GL_UNSIGNED_SHORT, null);
    }
};

fn bindTargetFbo(tex: c.GLuint) c.GLuint {
    var fbo: c.GLuint = 0;
    c.glGenFramebuffers(1, &fbo);
    c.glBindFramebuffer(c.GL_FRAMEBUFFER, fbo);
    c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, c.GL_TEXTURE_2D, tex, 0);
    return fbo;
}

pub fn createTexture(pixels: ?[*]const u8, options: dvui.Texture.CreateOptions) !dvui.Texture {
    var tex: c.GLuint = 0;
    c.glGenTextures(1, &tex);
    if (tex == 0) return error.TextureCreate;
    c.glBindTexture(c.GL_TEXTURE_2D, tex);
    const interp: c.GLint = if (options.interpolation == .linear) c.GL_LINEAR else c.GL_NEAREST;
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, interp);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, interp);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, if (options.wrap_u == .repeat) c.GL_REPEAT else c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, if (options.wrap_v == .repeat) c.GL_REPEAT else c.GL_CLAMP_TO_EDGE);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intCast(options.width), @intCast(options.height), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, pixels);
    return .{
        .ptr = @ptrFromInt(tex),
        .width = options.width,
        .height = options.height,
        .format = options.format,
        .interpolation = options.interpolation,
        .wrap_u = options.wrap_u,
        .wrap_v = options.wrap_v,
    };
}

pub fn createTarget(options: dvui.Texture.CreateOptions) !dvui.TextureTarget {
    const t: dvui.TextureTarget = .cast(try createTexture(null, options));
    clearTarget(t);
    return t;
}

pub fn clearTarget(target: dvui.TextureTarget) void {
    var prev: c.GLint = 0;
    c.glGetIntegerv(c.GL_FRAMEBUFFER_BINDING, &prev);
    var fbo = bindTargetFbo(@intCast(@intFromPtr(target.ptr)));
    c.glClearColor(0, 0, 0, 0);
    c.glClear(c.GL_COLOR_BUFFER_BIT);
    c.glBindFramebuffer(c.GL_FRAMEBUFFER, @intCast(prev));
    c.glDeleteFramebuffers(1, &fbo);
}

pub fn readTarget(target: dvui.TextureTarget, pixels_out: [*]u8) void {
    c.glBindTexture(c.GL_TEXTURE_2D, @intCast(@intFromPtr(target.ptr)));
    if (is_gles) {
        var prev: c.GLint = 0;
        c.glGetIntegerv(c.GL_FRAMEBUFFER_BINDING, &prev);
        var fbo = bindTargetFbo(@intCast(@intFromPtr(target.ptr)));
        c.glReadPixels(0, 0, @intCast(target.width), @intCast(target.height), c.GL_RGBA, c.GL_UNSIGNED_BYTE, pixels_out);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, @intCast(prev));
        c.glDeleteFramebuffers(1, &fbo);
    } else {
        c.glGetTexImage(c.GL_TEXTURE_2D, 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, pixels_out);
    }
}
