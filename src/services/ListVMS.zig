const std = @import("std");
const builtin = @import("builtin");

const ListError = anyerror || error{
    UnableToObtainVMS,
    UnableToFetchStatus,
};

const FormattedVM = struct {
    name: ?[]u8,
    uuid: ?[]u8,
    status: ?[]u8,

    fn statusFromUUID(alloc: std.mem.Allocator, uuid: []u8) ListError![]u8 {
        var buf: [1024]u8 = undefined;

        const cmd = try std.fmt.bufPrint(
            &buf,
            "VBoxManage showvminfo {s} | grep -i state | xargs | sed 's/State: //g'",
            .{uuid},
        );

        const argv = [_][]const u8{
            "sudo",
            "bash",
            "-c",
            cmd,
        };

        const process = try std.process.Child.run(.{
            .allocator = alloc,
            .argv = &argv,
        });

        defer alloc.free(process.stderr);

        if (process.term.Exited == 1) {
            if (builtin.mode == .Debug) {
                std.debug.print("Unable to fetch status for {s}: {s}\n", .{
                    uuid,
                    process.stderr,
                });
            }

            alloc.free(process.stdout);

            return error.UnableToFetchStatus;
        }

        return process.stdout;
    }

    pub fn fromQuery(alloc: std.mem.Allocator, query: []const u8) !FormattedVM {
        var it = std.mem.tokenizeAny(u8, query, " ");

        const name = val: {
            const res = it.next();

            if (res) |v| {
                break :val try alloc.dupe(u8, v[1 .. v.len - 1]);
            }

            break :val null;
        };

        const uuid = val: {
            const res = it.next();

            if (res) |v| {
                break :val try alloc.dupe(u8, v[1 .. v.len - 1]);
            }

            break :val null;
        };

        return FormattedVM{
            .name = name,
            .uuid = uuid,
            .status = val: {
                const xuuid = uuid orelse break :val null;

                break :val FormattedVM.statusFromUUID(alloc, xuuid) catch |err| {
                    if (err == error.UnableToFetchStatus)
                        break :val null;
                    return err;
                };
            },
        };
    }

    pub fn deinit(self: *FormattedVM, alloc: std.mem.Allocator) void {
        if (self.name) |name| alloc.free(name);
        if (self.uuid) |uuid| alloc.free(uuid);
        if (self.status) |status| alloc.free(status);
    }
};

const FormattedVMS = std.ArrayList(FormattedVM);

pub fn fetch(alloc: std.mem.Allocator) ListError!FormattedVMS {
    const argv = [_][]const u8{ "sudo", "VBoxManage", "list", "vms" };

    const result = try std.process.Child.run(.{
        .argv = &argv,
        .allocator = alloc,
    });

    defer {
        alloc.free(result.stderr);
        alloc.free(result.stdout);
    }

    if (result.term.Exited == 1) {
        if (builtin.mode == .Debug) {
            std.debug.print("Unable to obtain vms: {s}\n", .{result.stderr});
        }
        return error.UnableToObtainVMS;
    }

    const stdout = result.stdout;

    var it = std.mem.tokenizeAny(u8, stdout, "\n");
    var vms = FormattedVMS.init(alloc);

    while (it.next()) |line| {
        try vms.append(try FormattedVM.fromQuery(alloc, line));
    }

    return vms;
}
