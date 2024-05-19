const builtin = @import("builtin");
const std = @import("std");

const wasmplatform = switch (@import("build_options").platform) {
    .js => @import("wasmplatformjs.zig"),
    .badge => @import("wasmplatformbadge.zig"),
};

const c = @cImport({
    @cInclude("errno.h");
    @cInclude("stdio.h");
    @cInclude("sys/time.h");
});

const ctrace = std.log.scoped(.ctrace);
const heap = std.log.scoped(.heap);
const fileio = std.log.scoped(.fileio);

export fn __zassert_fail(
    expression: [*:0]const u8,
    file: [*:0]const u8,
    line: c_int,
    func: [*:0]const u8,
) callconv(.C) void {
    std.log.err("assert failed '{s}' ('{s}' line {d} function '{s}')", .{ expression, file, line, func });
    abort();
}

export fn abort() noreturn {
    @panic("abort");
}
export fn exit(exit_code: c_int) noreturn {
    _ = exit_code;
    //std.process.exit(@intCast(exit_code));
    @panic("exit");
}

export fn _formatCInt(buf: [*]u8, value: c_int, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCUint(buf: [*]u8, value: c_uint, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCLong(buf: [*]u8, value: c_long, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCUlong(buf: [*]u8, value: c_ulong, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCLonglong(buf: [*]u8, value: c_longlong, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}
export fn _formatCUlonglong(buf: [*]u8, value: c_ulonglong, base: u8) callconv(.C) usize {
    return std.fmt.formatIntBuf(buf[0..100], value, base, .lower, .{});
}

const FileID = enum(u2) {
    stdin, stdout, stderr,
    doom1wad,
};
const FileFlags = packed struct(c_uint) {
    id: FileID,
    read: bool,
    write: bool,
    _: u28 = undefined,
};

const global = struct {
    var home = [0:0]u8{ };
    var gpa = switch (builtin.cpu.arch) {
        .thumb => std.heap.ArenaAllocator.init(std.heap.page_allocator),
        else => std.heap.GeneralPurposeAllocator(.{
            //.MutexType = std.Thread.Mutex,
        }){},
    };
    //var gpa = std.heap.WasmAllocator{ };
    const max_file_count = 4;
    var files_reserved: [max_file_count]bool = [_]bool{false} ** max_file_count;
    var files: [max_file_count]c.FILE = ([_]c.FILE{
        .{ .errno = 0, .flags = @bitCast(FileFlags{ .id = .stdin , .read = true , .write = false }), .offset = undefined },
        .{ .errno = 0, .flags = @bitCast(FileFlags{ .id = .stdout, .read = false, .write = true  }), .offset = undefined },
        .{ .errno = 0, .flags = @bitCast(FileFlags{ .id = .stderr, .read = false, .write = true  }), .offset = undefined },
    }) ++ ([_]c.FILE{undefined} ** (max_file_count-3));
    fn reserveFile() *c.FILE {
        var i: usize = 0;
        while (i < files_reserved.len) : (i += 1) {
            if (!@atomicRmw(bool, &files_reserved[i], .Xchg, true, .seq_cst)) {
                return &files[i];
            }
        }
        @panic("out of file handles");
    }
    fn releaseFile(file: *c.FILE) void {
        const i = (@intFromPtr(file) - @intFromPtr(&files[0])) / @sizeOf(usize);
        if (!@atomicRmw(bool, &files_reserved[i], .Xchg, false, .seq_cst)) {
            std.debug.panic("released FILE (i={} ptr={*}) that was not reserved", .{ i, file });
        }
    }

};
export const stdin: *c.FILE = &global.files[0];
export const stdout: *c.FILE = &global.files[1];
export const stderr: *c.FILE = &global.files[2];

export var errno: c_int = 0;

const alloc_align = 16;
const alloc_metadata_len = std.mem.alignForward(usize, @sizeOf(usize), alloc_align);

export fn malloc(size: usize) ?[*]align(alloc_align) u8 {
    if (size == 0) {
        heap.debug("malloc 0", .{});
        return null;
    }
    const full_len = alloc_metadata_len + size;

    // we get these errors without this:
    //    error: struct 'posix.system__struct_2961' has no member named 'MAP'
    //    error: struct 'posix.system__struct_2961' has no member named 'E'
    if (builtin.cpu.arch == .thumb) {
        @panic("todo: GPA allocator on thumb");
    }

    // TODO: can/should we use the WASM allocator?
    const buf = global.gpa.allocator().alignedAlloc(u8, alloc_align, full_len) catch |err| switch (err) {
        error.OutOfMemory => {
            ctrace.debug("malloc return null", .{});
            return null;
        },
    };
    @as(*usize, @ptrCast(buf.ptr)).* = full_len;
    const result: [*]align(alloc_align) u8 = @ptrFromInt(@intFromPtr(buf.ptr) + alloc_metadata_len);
    heap.debug("malloc {*} - {*} ({} or 0x{2x})", .{result, result + size, size});
    return result;
}

fn getGpaBuf(ptr: [*]u8) []align(alloc_align) u8 {
    const start = @intFromPtr(ptr) - alloc_metadata_len;
    const len = @as(*usize, @ptrFromInt(start)).*;
    return @alignCast(@as([*]u8, @ptrFromInt(start))[0 .. len]);
}

export fn free(ptr: ?[*]align(alloc_align) u8) callconv(.C) void {
    heap.debug("free {*}", .{ptr});
    const p = ptr orelse return;

    // we get these errors without this:
    //    error: struct 'posix.system__struct_2961' has no member named 'MAP'
    //    error: struct 'posix.system__struct_2961' has no member named 'E'
    if (builtin.cpu.arch == .thumb) {
        @panic("todo: GPA allocator on thumb");
    }

    global.gpa.allocator().free(getGpaBuf(p));
}

export fn getenv(name: [*:0]const u8) callconv(.C) ?[*:0]u8 {
    ctrace.debug("getenv '{s}'", .{name});
    const name_slice = std.mem.span(name);
    if (std.mem.eql(u8, name_slice, "HOME"))
        return &global.home;
    return null;
}

export fn strlen(s: [*:0]const u8) callconv(.C) usize {
    ctrace.debug("strlen {*}", .{s});
    const result = std.mem.len(s);
    ctrace.debug("strlen return {}", .{result});
    return result;
}
export fn strchr(s: [*:0]const u8, char: c_int) callconv(.C) ?[*:0]const u8 {
    ctrace.debug("strchr {*} c='{}'", .{s, char});
    var next = s;
    while (true) : (next += 1) {
        if (next[0] == char) return next;
        if (next[0] == 0) return null;
    }
}

const doom1wad = @embedFile("doom1wad");

export fn fopen(filename_ptr: [*:0]const u8, mode_ptr: [*:0]const u8) callconv(.C) ?*c.FILE {
    var filename = std.mem.span(filename_ptr);
    const mode = std.mem.span(mode_ptr);
    fileio.debug("fopen '{s}' mode={s}", .{filename, mode});
    if (std.mem.startsWith(u8, filename, "./")) {
        filename = filename[2..];
    }

    if (std.mem.eql(u8, filename, "doom1.wad")) {
        if (!std.mem.eql(u8, mode, "rb"))
            std.debug.panic("todo: handle fopen mode '{s}'", .{mode});
        const file = global.reserveFile();
        file.* = .{
            .errno = 0,
            .flags = @bitCast(FileFlags{ .id = .doom1wad, .read = true, .write = false }),
            .offset = 0,
        };
        return file;
    }

    errno = c.ENOENT;
    return null;
}
export fn fclose(stream: *c.FILE) callconv(.C) c_int {
    fileio.debug("fclose {*}", .{stream});
    global.releaseFile(stream);
    return 0;
}

fn getFileFlags(stream: *c.FILE) *FileFlags {
    return @as(*FileFlags, @ptrCast(&stream.flags));
}

export fn feof(stream: *c.FILE) callconv(.C) c_int {
    const flags = getFileFlags(stream);
    if (!flags.read) @panic("todo: feof on file without read permissions");
    if (flags.id != .doom1wad) @panic("todo: feof not doom1wad");
    return if (stream.offset >= doom1wad.len) 1 else 0;
}

export fn fwrite(ptr: [*]const u8, size: usize, nmemb: usize, stream: *c.FILE) callconv(.C) usize {
    fileio.debug("fwrite {*} size={} n={} stream={*}", .{ptr, size, nmemb, stream});
    const total = size * nmemb;
    const result = wasmplatform._fwrite_buf(ptr, total, stream);
    if (result == total) return nmemb;
    return result / size;
}

export fn fread(ptr: [*]u8, size: usize, nmemb: usize, stream: *c.FILE) callconv(.C) usize {
    const total = size * nmemb;
    const flags = getFileFlags(stream);
    fileio.debug("fread {s} len={}", .{@tagName(flags.id), total});
    const result = _fread_buf(ptr, total, stream);
    if (result == 0) {
        fileio.debug("  => 0", .{});
        return 0;
    }
    if (result == total) {
        fileio.debug("  => {}", .{nmemb});
        return nmemb;
    }
    // TODO: if length read is not aligned then we need to leave it
    //       in an internal read buffer inside FILE
    //       for now we'll crash if it's not aligned
    const return_val: usize = @divExact(result, size);
    fileio.debug("  => {}", .{return_val});
    return return_val;
}

const SEEK_SET = 0;
export fn fseek(stream: *c.FILE, offset: c_long, whence: c_int) callconv(.C) c_int {
    const flags = getFileFlags(stream);
    fileio.debug("fseek {s} offset={} whence={}", .{@tagName(flags.id), offset, whence});
    if (whence != SEEK_SET) std.debug.panic("todo: fseek whence {}", .{whence});

    if (stream.errno != 0) @panic("todo: handle errno");
    if (flags.id != .doom1wad) @panic("todo: handle fread with file other than doom1wad");
    if (offset > doom1wad.len) @panic("todo: handle fseek too big");
    stream.offset = @intCast(offset);
    return 0;
}

export fn ftell(stream: *c.FILE) callconv(.C) c_long {
    _ = stream;
    @panic("ftell not implemented");
}

export fn _fread_buf(ptr: [*]u8, size: usize, stream: *c.FILE) callconv(.C) usize {
    const flags = getFileFlags(stream);
    if (!flags.read) @panic("todo: handle reading from file without read permissions");
    if (stream.errno != 0) @panic("todo: handle errno");
    if (flags.id != .doom1wad) @panic("todo: handle fread with file other than doom1wad");

    const remaining = doom1wad.len;
    const len = @min(size, remaining);
    @memcpy(ptr[0 .. len], doom1wad[stream.offset..][0..len]);
    stream.offset += len;
    return len;
}
