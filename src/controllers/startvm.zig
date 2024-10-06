const std = @import("std");
const zap = @import("zap");

pub fn startVM(alloc: std.mem.Allocator, req: *const zap.Request) !void {
    req.parseQuery();

    const parameters = try req.parametersToOwnedList(alloc, false);
    defer parameters.deinit();

    for (parameters.items) |param| {
        if (param.value) |val| {
            std.debug.print("{s} => {s}\n", .{
                param.key.str,
                val.String.str,
            });
        }
    }

    var buf: [100]u8 = undefined;

    if (zap.stringifyBuf(&buf, .{ .ok = true }, .{})) |json| {
        return req.sendJson(json);
    }
}
