const std = @import("std");
const zap = @import("zap");
const sendError = @import("../utils.zig").sendErrors;

pub fn createVM(alloc: std.mem.Allocator, req: *const zap.Request) !void {
    const body = req.body orelse "{}";

    const ExpectedBody = struct {
        name: []u8,
        ostype: []u8,
        iso: []u8,
        basefolder: []u8,
        network_iface: []u8,
        memory: struct {
            size: i32,
            vram: i32,
        },
        disk: struct {
            path: []u8,
            size: i32,
        },
        rdp: struct {
            enabled: bool,
            vnc_passwd: []u8,
        },
    };

    const parsed_body = std.json.parseFromSlice(
        ExpectedBody,
        alloc,
        body,
        .{},
    ) catch |err| {
        var msg_buf: [200]u8 = undefined;

        const msg = try std.fmt.bufPrint(&msg_buf, "Invalid body: {s}\n", .{
            @errorName(err),
        });

        return sendError(req, .{
            .is_error = true,
            .message = msg,
        }) catch return;
    };

    var buf: [2024]u8 = undefined;

    const response = .{ .body = parsed_body.value };

    if (zap.stringifyBuf(&buf, response, .{})) |json| {
        return try req.sendJson(json);
    }
}
