//const builtin = @import("builtin");
const std = @import("std");
const cart = @import("cart-api");

//const c = @cImport({
    // We can't use DOOM_IMPLEMENTATION here bacause Zig doesn't compile
    // C code, we need to do that inside a C file.
//    @cInclude("PureDOOM.h");
//});
// zig's translate c thinks doom_update takes "..." instead of no args
extern fn doom_update() void;

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
extern fn doom_init(argc: c_int, argv: [*c][*c]u8, flags: c_int) void;
// call after calling doom_init
extern fn doom_get_screen_buffer() [*]const u8;

comptime {
    _ = @import("libc.zig");
}

fn log(
    comptime level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = level;
    _ = scope;
    _ = format;
    _ = args;
//    if (scope == .ctrace) return;
//    if (scope == .heap) return;
//    const level_txt = comptime message_level.asText();
//    const prefix = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
//    const log_fmt = level_txt ++ prefix ++ format;
//    const writer = JsLogWriter{ .context = {} };
//    std.fmt.format(writer, log_fmt, args) catch unreachable;
//    js.logFlush();
}
pub const std_options: std.Options = .{
    .logFn = log,
};
//extern fn check_libc_types() void;
//extern fn doom_get_screen_palette() [*]const u8;
//export fn get_screen_palette() [*]const u8 {
//    const addr = doom_get_screen_palette();
//    //std.log.info("palette addr is {*}", .{addr});
//    return addr;
//}

//var scaled: [160*128]u8 = undefined;
export fn start() void {
    //check_libc_types();
    //std.log.info("calling doom_init...", .{});
    //doom_init(
    //    0, // argc
    //    null, // argv
    //    0, // flags
    //);
    //std.log.info("doom_init done", .{});
    //return doom_get_screen_buffer();
}

extern fn D_DoomMain() void;

export fn update() void {
    cart.text(.{ .str = "DOOM", .x = 10, .y = 10, .text_color = .{ .r = 31, .g = 0, .b = 0 }});

    D_DoomMain();
    //doom_update();
    //_ = c.doom_get_framebuffer(1);
//    const fb = c.doom_get_framebuffer(1);
//    @import("scale.zig").scaleBitmap(
//        160, 128,
//        320, 200,
//        &scaled,
//        fb[0 .. 320*200],
//    );
}
