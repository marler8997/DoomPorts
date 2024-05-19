const builtin = @import("builtin");
const std = @import("std");

pub fn oom(e: error{OutOfMemory}) noreturn {
    @panic(@errorName(e));
}
pub fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    std.log.err(fmt, args);
    std.process.exit(0xff);
}

var windows_args_arena = if (builtin.os.tag == .windows)
    std.heap.ArenaAllocator.init(std.heap.page_allocator) else struct{}{};

pub fn cmdlineArgs() [][*:0]u8 {
    if (builtin.os.tag == .windows) {
        const slices = std.process.argsAlloc(windows_args_arena.allocator()) catch |err| switch (err) {
            error.OutOfMemory => oom(error.OutOfMemory),
            //error.InvalidCmdLine => @panic("InvalidCmdLine"),
            error.Overflow => @panic("Overflow while parsing command line"),
        };
        const args = windows_args_arena.allocator().alloc([*:0]u8, slices.len - 1) catch |e| oom(e);
        for (slices[1..], 0..) |slice, i| {
            args[i] = slice.ptr;
        }
        return args;
    }
    return std.os.argv.ptr[1 .. std.os.argv.len];
}

const WadHeader = extern struct {
    sig: [4]u8 align(1),
    num_files: u32 align(1),
    fat_offset: u32 align(1),
};
const FileEntry = extern struct {
    file_offset: u32 align(1),
    len: u32 align(1),
    name: [8]u8,
};

pub fn main() !void {
    const cmdline = cmdlineArgs();
    if (cmdline.len == 0) {
        try std.io.getStdErr().writer().writeAll("Usage: readwad WADFILE");
        std.process.exit(0);
    }
    if (cmdline.len != 1) {
        std.log.err("expected 1 cmdline argument but got {}", .{cmdline.len});
        std.process.exit(0xff);
    }
    const filepath = std.mem.span(cmdline[0]);

    var file = std.fs.cwd().openFile(filepath, .{}) catch |err| {
        std.log.err("open '{s}' failed: {s}", .{filepath, @errorName(err)});
        std.process.exit(0xff);
    };
    // defer file.close(); (unnecessary)

    const header = try file.reader().readStructEndian(WadHeader, .little);
    if (!std.mem.eql(u8, "IWAD", &header.sig )) {
        std.log.err("file did not begin with IWAD", .{});
        std.process.exit(0xff);
    }
    std.log.info("NumFiles: {}", .{header.num_files});
    std.log.info("FATOffset: {} (0x{0x})", .{header.fat_offset});

    try file.seekTo(header.fat_offset);

    var file_index: u32 = 0;
    while (true) : (file_index += 1) {
        if (file_index >= header.num_files)
            break;
        const entry = try file.reader().readStructEndian(FileEntry, .little);
        std.log.info(
            "Offset={} (0x{0x}) Len={} name '{}'",
            .{ entry.file_offset, entry.len, std.zig.fmtEscapes(&entry.name) },
        );
    }
}
