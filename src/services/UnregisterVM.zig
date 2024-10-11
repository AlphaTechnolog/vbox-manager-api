const std = @import("std");
const builtin = @import("builtin");

const CommandResult = struct {
    failed: bool,
    stdout: []u8,
    stderr: []u8,

    pub fn deinit(self: CommandResult, alloc: std.mem.Allocator) void {
        alloc.free(self.stdout);
        alloc.free(self.stderr);
    }
};

pub fn unregister(alloc: std.mem.Allocator, name: []const u8, delete: bool) !CommandResult {
    const args = [_][]const u8{
        "sudo",
        "VBoxManage",
        "unregistervm",
        name,
        if (delete) "--delete" else "",
    };

    const process = try std.process.Child.run(.{
        .allocator = alloc,
        .argv = &args,
    });

    errdefer {
        alloc.free(process.stdout);
        alloc.free(process.stderr);
    }

    if (builtin.mode == .Debug and process.term.Exited != 0) {
        std.debug.print("unregistervm failed with:\nstdout:\n{s}\nstderr:\n{s}\n", .{
            process.stdout,
            process.stderr,
        });
    }

    return CommandResult{
        .failed = process.term.Exited != 0,
        .stdout = process.stdout,
        .stderr = process.stderr,
    };
}
