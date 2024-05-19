const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
    // We can't use DOOM_IMPLEMENTATION here bacause Zig doesn't compile
    // C code, we need to do that inside a C file.
    @cInclude("PureDOOM.h");
});
// zig's translate c thinks doom_update takes "..." instead of no args
extern fn doom_update() void;

// call after calling doom_init
extern fn doom_get_screen_buffer() [*]const u8;

comptime {
    _ = @import("libc.zig");
}

const js = struct {
    extern fn logWrite(ptr: [*]const u8, len: usize) void;
    extern fn logFlush() void;
};


const JsLogWriter = std.io.Writer(void, error{}, jsLogWrite);
fn jsLogWrite(context: void, bytes: []const u8) !usize {
    _ = context;
    js.logWrite(bytes.ptr, bytes.len);
    return bytes.len;
}
fn log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (scope == .ctrace) return;
    if (scope == .heap) return;
    const level_txt = comptime message_level.asText();
    const prefix = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    const log_fmt = level_txt ++ prefix ++ format;
    const writer = JsLogWriter{ .context = {} };
    std.fmt.format(writer, log_fmt, args) catch unreachable;
    js.logFlush();
}
pub const std_options: std.Options = .{
    .logFn = log,
};

extern fn check_libc_types() void;

extern fn doom_get_screen_palette() [*]const u8;
export fn get_screen_palette() [*]const u8 {
    const addr = doom_get_screen_palette();
    //std.log.info("palette addr is {*}", .{addr});
    return addr;
}

export fn init() [*]const u8 {
    check_libc_types();
    std.log.info("calling doom_init...", .{});
    c.doom_init(
        0, // argc
        null, // argv
        0, // flags
    );
    std.log.info("doom_init done", .{});
    return doom_get_screen_buffer();
}

export fn update() void {
    doom_update();
    _ = c.doom_get_framebuffer(1);
}
