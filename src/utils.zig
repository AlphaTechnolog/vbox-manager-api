const std = @import("std");
const zap = @import("zap");

pub fn sendErrors(req: *const zap.Request, opts: anytype) !void {
    var buf: [1024]u8 = undefined;

    if (zap.stringifyBuf(&buf, opts, .{})) |json| {
        return try req.sendJson(json);
    }
}
