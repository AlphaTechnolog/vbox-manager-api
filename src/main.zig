const std = @import("std");
const builtin = @import("builtin");
const zap = @import("zap");

const ListController = @import("./controllers/list.zig");
const CreateVMController = @import("./controllers/createvm.zig");
const StartVMController = @import("./controllers/startvm.zig");
const StopVMController = @import("./controllers/stopvm.zig");

var alloc: std.mem.Allocator = undefined;

fn handleRequest(req: zap.Request) void {
    const path = req.path orelse "/";

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
        else => return,
    }
}

pub fn main() !void {
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

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Listening at port 8080\n", .{});

    zap.start(.{
        .threads = 2,
        .workers = 1,
    });
}
