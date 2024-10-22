const std = @import("std");
const builtin = @import("builtin");
const zap = @import("zap");

const ListController = @import("./controllers/list.zig");
const CreateVMController = @import("./controllers/createvm.zig");
const StartVMController = @import("./controllers/startvm.zig");
const StopVMController = @import("./controllers/stopvm.zig");
const UnregisterVMController = @import("./controllers/unregistervm.zig");

var alloc: std.mem.Allocator = undefined;

fn enableCors(req: *const zap.Request) !void {
    try req.setHeader("Access-Control-Allow-Origin", "*");
    try req.setHeader("Access-Control-Allow-Methods", "*");
    try req.setHeader("Access-Control-Allow-Headers", "*");
}

fn handleRequest(req: zap.Request) void {
    const path = req.path orelse "/";

    enableCors(&req) catch |err| {
        req.setStatus(.internal_server_error);

        var msg_buf: [100]u8 = undefined;

        const msg = std.fmt.bufPrint(&msg_buf, "Unable to enable cors policies: {s}", .{
            @errorName(err),
        }) catch return;

        var response_buf: [512]u8 = undefined;

        const response = .{
            .is_err = true,
            .message = msg,
        };

        if (zap.stringifyBuf(&response_buf, response, .{})) |json| {
            return req.sendJson(json) catch return;
        }
    };

    switch (req.methodAsEnum()) {
        .GET => {
            if (std.mem.eql(u8, path, "/list")) {
                return ListController.showVMSList(alloc, &req) catch return;
            }
        },
        .POST => {
            if (std.mem.eql(u8, path, "/create")) {
                return CreateVMController.createVM(alloc, &req) catch return;
            }

            if (std.mem.startsWith(u8, path, "/start")) {
                return StartVMController.startVM(alloc, &req) catch return;
            }

            if (std.mem.eql(u8, path, "/stop")) {
                return StopVMController.stopVM(alloc, &req) catch return;
            }
        },
        .DELETE => {
            if (std.mem.eql(u8, path, "/unregistervm")) {
                return UnregisterVMController.unregisterVM(alloc, &req) catch return;
            }
        },
        else => return,
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Running build in {s} mode\n", .{
        @tagName(builtin.mode),
    });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.debug.panic("memleak\n", .{});
    };

    alloc = gpa.allocator();

    var listener = zap.HttpListener.init(.{
        .port = 8080,
        .on_request = handleRequest,
        .log = builtin.mode == .Debug,
    });

    try listener.listen();

    try stdout.print("Listening at port 8080\n", .{});

    zap.start(.{
        .threads = 2,
        .workers = 1,
    });
}
