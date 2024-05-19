
fn rescale(comptime T: type, val: anytype, old_scale: f32, new_scale: f32) T {
    const f: f32 = @floatFromInt(val);
    const ratio = f / old_scale;
    return @intFromFloat(ratio * new_scale);
}

pub fn scaleBitmap(
    dst_width: comptime_int,
    dst_height: comptime_int,
    src_width: comptime_int,
    src_height: comptime_int,
    dst: []u8,
    src: []const u8,
) void {
    for (0 .. dst_height) |dst_y| {
        const dst_off = dst_y * dst_width;
        const src_y = rescale(usize, dst_y, dst_height, src_height);
        const src_off = src_y * src_width;
        for (0 .. dst_width) |dst_x| {
            const src_x = rescale(usize, dst_x, dst_width, src_width);
            dst[dst_off + dst_x] = src[src_off + src_x];
        }
    }
}
