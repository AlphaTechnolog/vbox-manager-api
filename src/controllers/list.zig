const std = @import("std");
const zap = @import("zap");
const sendError = @import("../utils.zig").sendErrors;

const ListVMS = @import("../services/ListVMS.zig");

pub fn showVMSList(alloc: std.mem.Allocator, req: *const zap.Request) !void {
    var result = ListVMS.fetch(alloc) catch |err| {
        if (err == error.UnableToObtainVMS) {
            return sendError(req, .{
                .is_error = true,
                .message = "Unable to obtain vms",
            }) catch return;
        }

        return sendError(req, .{
            .is_error = true,
            .message = "Unexpected error",
            .codename = @errorName(err),
        }) catch return;
    };

    defer {
        for (result.items) |*fmttedvm| {
            fmttedvm.deinit(alloc);
        }

        result.deinit();
    }

    var buf: [4024]u8 = undefined;

    const response = .{ .vbox_vms = result.items };

    if (zap.stringifyBuf(&buf, response, .{})) |json| {
        return try req.sendJson(json);
    }
}
