const std = @import("std");
const zap = @import("zap");

const StartVMService = @import("../services/StartVM.zig");

const Body = struct {
    name: ?[]u8,

    pub fn fromJsonString(alloc: std.mem.Allocator, json: []const u8) !std.json.Parsed(Body) {
        return try std.json.parseFromSlice(Body, alloc, json, .{});
    }

    const DoStartError = StartVMService.StartError || error{InvalidName};

    pub fn doStart(self: *const Body, alloc: std.mem.Allocator) DoStartError!void {
        const name = self.name orelse return error.InvalidName;
        try StartVMService.startWithName(alloc, name);
    }
};

pub fn startVM(alloc: std.mem.Allocator, req: *const zap.Request) !void {
    const body = req.body orelse "{}";

    const parsed_body = Body.fromJsonString(alloc, body) catch |err| {
        var buf: [100]u8 = undefined;
        var json_buf: [256]u8 = undefined;

        const msg = std.fmt.bufPrint(&buf, "Unable to serialize body: {s}", .{
            @errorName(err),
        }) catch return;

        const response = .{
            .is_err = true,
            .message = msg,
        };

        if (zap.stringifyBuf(&json_buf, response, .{})) |json| {
            return req.sendJson(json);
        }

        return;
    };

    defer parsed_body.deinit();

    const serialized_body = parsed_body.value;

    serialized_body.doStart(alloc) catch |err| {
        var msg_buf: [256]u8 = undefined;

        const msg = std.fmt.bufPrint(&msg_buf, "Unable to start vm: {s}", .{
            @errorName(err),
        }) catch return;

        const response = .{
            .is_err = true,
            .message = msg,
        };

        var json_buf: [500]u8 = undefined;

        if (zap.stringifyBuf(&json_buf, response, .{})) |json| {
            return req.sendJson(json);
        }

        return;
    };

    const response = .{
        .is_err = false,
        .message = "VM started in the background",
    };

    var buf: [256]u8 = undefined;

    if (zap.stringifyBuf(&buf, response, .{})) |json| {
        return req.sendJson(json);
    }
}
