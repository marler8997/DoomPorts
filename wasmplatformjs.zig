const c = @cImport({
    @cInclude("errno.h");
    @cInclude("stdio.h");
    @cInclude("sys/time.h");
});

const js = struct {
    extern fn logWrite(ptr: [*]const u8, len: usize) void;
    extern fn logFlush() void;
    extern fn getTimeMillis() u32;
};

export fn gettimeofday(
    time: *c.timeval,
    timezone: *c.timezone,
) c_int {
    _ = timezone;
    const ms = js.getTimeMillis();
    time.tv_sec = ms / 1000;
    time.tv_usec = (ms % 1000) * 1000;
    return 0;
}

pub export fn _fwrite_buf(ptr: [*]const u8, size: usize, stream: *c.FILE) usize {
    if (stream != c.stdout and stream != c.stderr)
        @panic("bad FILE pointer");

    var flushed: usize = 0;
    {
        var i: usize = 0;
        while (i < size) : (i += 1) {
            if (ptr[i] == '\n') {
                if (flushed < size) {
                    js.logWrite(ptr + flushed, size - flushed);
                    js.logFlush();
                    flushed = i + 1;
                }
            }
        }
    }
    if (flushed < size) {
        js.logWrite(ptr + flushed, size - flushed);
    }
    return size;
}
