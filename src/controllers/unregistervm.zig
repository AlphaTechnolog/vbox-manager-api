const std = @import("std");
const zap = @import("zap");

const Query = @import("../utils/query.zig");
const UnregisterService = @import("../services/UnregisterVM.zig");

const ExpectedParams = struct {
    name: ?[]u8 = null,
    delete: bool = false,

    const ParamsError = error{InvalidParams};

    pub fn fromParsedQuery(query: *const Query) ParamsError!ExpectedParams {
        var expected_params = ExpectedParams{};

        // query_param.key will be freed() by Query.deinit() so no need for us to
        // do something like alloc.free(expected_params.name) on a custom deinit.
        for (query.elements.items) |query_param| {
            if (std.mem.eql(u8, query_param.key, "name")) {
                expected_params.name = query_param.value;
            } else if (std.mem.eql(u8, query_param.key, "delete")) {
                expected_params.delete = std.mem.eql(u8, query_param.value, "yes");
            }
        }

        if (expected_params.name == null) {
            return error.InvalidParams;
        }

        return expected_params;
    }
};

pub fn unregisterVM(alloc: std.mem.Allocator, req: *const zap.Request) !void {
    const querystring = req.query orelse "";

    var query = Query.init(alloc, querystring) catch |err| {
        if (err == error.InvalidToken) {
            var buf: [100]u8 = undefined;

            const response = .{
                .is_err = true,
                .message = "Invalid query params",
            };

            req.setStatus(.bad_request);

            if (zap.stringifyBuf(&buf, response, .{})) |json| {
                return req.sendJson(json);
            }

            return;
        }

        return err;
    };

    defer query.deinit();

    const params = ExpectedParams.fromParsedQuery(query) catch |err| {
        // InvalidToken is already handled before.
        if (err == error.InvalidToken) unreachable;

        var buf: [100]u8 = undefined;

        const response = .{
            .is_err = true,
            .message = "Invalid given parameters",
        };

        req.setStatus(.bad_request);

        if (zap.stringifyBuf(&buf, response, .{})) |json| {
            return req.sendJson(json);
        }

        return;
    };

    const result = try UnregisterService.unregister(
        alloc,
        params.name.?,
        params.delete,
    );

    defer result.deinit(alloc);

    var response_buf: [2024]u8 = undefined;

    if (result.failed) {
        req.setStatus(.internal_server_error);

        const response = .{
            .is_err = true,
            .message = "Command failed with status != 0",
            .payload = .{
                .stdout = result.stdout,
                .stderr = result.stderr,
            },
        };

        if (zap.stringifyBuf(&response_buf, response, .{})) |json| {
            return req.sendJson(json);
        }

        return;
    }

    req.setStatus(.ok);

    const response = .{
        .is_err = false,
        .payload = .{
            .stdout = result.stdout,
            .stderr = result.stderr,
        },
    };

    if (zap.stringifyBuf(&response_buf, response, .{})) |json| {
        return req.sendJson(json);
    }

    return;
}
