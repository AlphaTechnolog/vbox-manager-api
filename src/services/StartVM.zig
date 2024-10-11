const std = @import("std");
const builtin = @import("builtin");

pub const StartError = anyerror || error{CommandFailed};

pub fn startWithName(alloc: std.mem.Allocator, name: []const u8) StartError!void {
    var cmd_buf: [1024]u8 = undefined;

    const cmd = try std.fmt.bufPrint(
        &cmd_buf,
        "nohup sudo VBoxHeadless --startvm '{s}' 2>&1 > /dev/null & disown",
        .{name},
    );

    const args = [_][]const u8{ "nohup", "bash", "-c", cmd };

    var child = std.process.Child.init(&args, alloc);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    child.cwd = null;
    child.cwd_dir = null;
    child.env_map = null;
    child.expand_arg0 = .no_expand;

    try child.spawn();
}
