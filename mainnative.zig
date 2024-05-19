const builtin = @import("builtin");
const std = @import("std");

const c = @cImport({
    // We can't use DOOM_IMPLEMENTATION here bacause Zig doesn't compile
    // C code, we need to do that inside a C file.
    @cInclude("PureDOOM.h");
});
// zig's translate c thinks doom_update takes "..." instead of no args
extern fn doom_update() void;

pub fn main() !void {
    std.log.info("calling doom_init...", .{});
    c.doom_init(
        0, // argc
        null, // argv
        0, // flags
    );
    std.log.info("doom_init done", .{});
    while (true) {
        //c.doom_update();
        std.log.info("calling doom_update", .{});
        doom_update();
    }
}
