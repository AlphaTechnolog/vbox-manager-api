const std = @import("std");
const zap = @import("zap");

const ExpectedBody = struct {
    savestate: bool,
    name: []const u8,
};

pub fn stopVM(alloc: std.mem.Allocator, req: *const zap.Request) !void {
    const body = req.body orelse {
        var buf: [100]u8 = undefined;

        const response = .{
            .is_err = true,
            .message = "Please provide a body information",
        };

        if (zap.stringifyBuf(&buf, response, .{})) |json| {
            req.setStatus(.bad_request);
            return req.sendJson(json);
        }

        return;
    };

    const parsed = std.json.parseFromSlice(ExpectedBody, alloc, body, .{}) catch |err| {
        var buf: [256]u8 = undefined;
        var msg_buf: [100]u8 = undefined;

        const msg = std.fmt.bufPrint(&msg_buf, "Unable to serialize body: {s}", .{
            @errorName(err),
        }) catch return;

        const response = .{
            .is_err = true,
            .message = msg,
        };

        if (zap.stringifyBuf(&buf, response, .{})) |json| {
            req.setStatus(.bad_request);
            return req.sendJson(json);
        }

        return;
    };

    defer parsed.deinit();

    const payload = parsed.value;

    const args = [_][]const u8{
        "sudo",
        "VBoxManage",
        "controlvm",
        payload.name,
        if (payload.savestate) "savestate" else "poweroff",
    };

    const process = try std.process.Child.run(.{
        .argv = &args,
        .allocator = alloc,
    });

    defer {
        alloc.free(process.stdout);
        alloc.free(process.stderr);
    }

    if (process.term.Exited != 0) {
        const response = .{
            .is_err = true,
            .message = "Command failed (status != 0)",
            .payload = .{
                .stdout = process.stdout,
                .stderr = process.stderr,
            },
        };

        var response_buf: [2056]u8 = undefined;

        req.setStatus(.internal_server_error);

        if (zap.stringifyBuf(&response_buf, response, .{})) |json| {
            return req.sendJson(json);
        }

        return req.sendJson("{\"error\": \"Unable to send error!\"}");
    }

    var response_buf: [2056]u8 = undefined;

    const response = .{
        .is_err = false,
        .payload = .{
            .stdout = process.stdout,
            .stderr = process.stderr,
        },
    };

    req.setStatus(.ok);

    if (zap.stringifyBuf(&response_buf, response, .{})) |json| {
        return req.sendJson(json);
    }

    return req.sendJson("{\"error\": \"Unable to send error!\"}");
}
