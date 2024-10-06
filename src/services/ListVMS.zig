const std = @import("std");
const builtin = @import("builtin");

const ListError = anyerror || error{
    UnableToObtainVMS,
    UnableToFetchStatus,
};

const FormattedVM = struct {
    name: []u8,
    uuid: []u8,
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

    /// Query is with the next form: `"{name}" {uuid}`.
    pub fn fromQuery(alloc: std.mem.Allocator, query: []const u8) !FormattedVM {
        var name = std.ArrayList(u8).init(alloc);
        var uuid = std.ArrayList(u8).init(alloc);

        defer {
            name.deinit();
            uuid.deinit();
        }

        var i: u8 = 0;
        var write_ptr: *std.ArrayList(u8) = &name;

        for (query) |c| {
            if (c == '"') {
                i += 1;
                continue;
            }

            if (c == '{' or c == '}' or (i == 2 and c == ' ')) {
                continue;
            }

            if (i == 2) {
                write_ptr = &uuid;
            }

            try write_ptr.append(c);
        }

        return FormattedVM{
            .name = try alloc.dupe(u8, name.items),
            .uuid = try alloc.dupe(u8, uuid.items),
            .status = val: {
                break :val FormattedVM.statusFromUUID(alloc, uuid.items) catch |err| {
                    if (err == error.UnableToFetchStatus)
                        break :val null;
                    return err;
                };
            },
        };
    }

    pub fn deinit(self: *FormattedVM, alloc: std.mem.Allocator) void {
        alloc.free(self.name);
        alloc.free(self.uuid);

        if (self.status) |status| {
            alloc.free(status);
        }
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

    errdefer vms.deinit();

    while (it.next()) |line| {
        try vms.append(try FormattedVM.fromQuery(alloc, line));
    }

    return vms;
}
