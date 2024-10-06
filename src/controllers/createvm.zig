const std = @import("std");
const builtin = @import("builtin");
const zap = @import("zap");
const sendError = @import("../utils.zig").sendErrors;

const Body = struct {
    name: []u8,
    ostype: []u8,
    iso: []u8,
    basefolder: []u8,
    network_iface: []u8,
    memory: struct {
        size: i32,
        vram: i32,
    },
    disk: struct {
        path: []u8,
        size: i32,
    },
    rdp: struct {
        enabled: bool,
        vnc_passwd: []u8,
    },
};

const ShellResult = struct {
    failed: bool,
    allocator: std.mem.Allocator,
    stdout: ?[]u8,
    stderr: ?[]u8,

    pub fn deinit(self: *ShellResult) void {
        if (self.stdout) |stdout| self.allocator.free(stdout);
        if (self.stderr) |stderr| self.allocator.free(stderr);
    }
};

fn silentExec(alloc: std.mem.Allocator, shell: []const u8) !ShellResult {
    const argv = [_][]const u8{
        "sudo",
        "bash",
        "-c",
        shell,
    };

    const process = try std.process.Child.run(.{
        .allocator = alloc,
        .argv = &argv,
    });

    if (process.term.Exited == 1) {
        alloc.free(process.stdout);

        return ShellResult{
            .failed = true,
            .allocator = alloc,
            .stdout = null,
            .stderr = process.stderr,
        };
    }

    return ShellResult{
        .failed = false,
        .allocator = alloc,
        .stdout = process.stdout,
        .stderr = process.stderr,
    };
}

// TODO: Validate ostype & disk path
fn createWithShell(alloc: std.mem.Allocator, payload: *const Body) !ShellResult {
    var creation_command = std.ArrayList(u8).init(alloc);
    defer creation_command.deinit();

    const writer = creation_command.writer();

    // Create Virtual Machine
    try writer.print(
        "VBoxManage createvm --name '{s}' --ostype '{s}' --register --basefolder '{s}' && ",
        .{
            payload.name,
            payload.ostype,
            payload.basefolder,
        },
    );

    // Setup memory
    try writer.print(
        "VBoxManage modifyvm '{s}' --ioapic on && ",
        .{payload.name},
    );

    try writer.print(
        "VBoxManage modifyvm '{s}' --memory '{d}' --vram '{d}' && ",
        .{
            payload.name,
            payload.memory.size,
            payload.memory.vram,
        },
    );

    // Setup network
    try writer.print(
        "VBoxManage modifyvm '{s}' --nic1 bridged --bridgeadapter1 '{s}' && ",
        .{
            payload.name,
            payload.network_iface,
        },
    );

    // Create disk
    try writer.print(
        "VBoxManage createhd --filename '{s}' --size '{d}' --format VDI && ",
        .{
            payload.disk.path,
            payload.disk.size,
        },
    );

    try writer.print(
        "VBoxManage storagectl '{s}' --name 'SATA Controller' --add sata --controller IntelAhci && ",
        .{payload.name},
    );

    try writer.print(
        "VBoxManage storageattach '{s}' --storagectl 'SATA Controller' --port 0 --device 0 --type hdd --medium '{s}' && ",
        .{
            payload.name,
            payload.disk.path,
        },
    );

    try writer.print(
        "VBoxManage storagectl '{s}' --name 'IDE Controller' --add ide --controller PIIX4 && ",
        .{payload.name},
    );

    try writer.print(
        "VBoxManage storageattach '{s}' --storagectl 'IDE Controller' --port 1 --device 0 --type dvddrive --medium '{s}' && ",
        .{
            payload.name,
            payload.iso,
        },
    );

    try writer.print(
        "VBoxManage modifyvm '{s}' --boot1 dvd --boot2 disk --boot3 none --boot4 none && ",
        .{payload.name},
    );

    // Try to port forward ssh
    try writer.print(
        "VBoxManage modifyvm '{s}' --natpf1 'ssh,tcp,,2222,,22'",
        .{payload.name},
    );

    // RDP Access & VNC Server
    if (payload.rdp.enabled) {
        try writer.print(
            "&& VBoxManage modifyvm '{s}' --vrde on && ",
            .{payload.name},
        );

        try writer.print(
            "VBoxManage modifyvm '{s}' --vrdemulticon on --vrdeport 10001 && ",
            .{payload.name},
        );

        try writer.print(
            "VBoxManage modifyvm '{s}' --vrde-property 'VNCPassword={s}'",
            .{
                payload.name,
                payload.rdp.vnc_passwd,
            },
        );
    }

    // The caller is responsable for calling free on `ShellResult`.
    return try silentExec(alloc, creation_command.items);
}

pub fn createVM(alloc: std.mem.Allocator, req: *const zap.Request) !void {
    const body = req.body orelse "{}";

    const parsed_body = std.json.parseFromSlice(
        Body,
        alloc,
        body,
        .{},
    ) catch |err| {
        var msg_buf: [200]u8 = undefined;

        const msg = try std.fmt.bufPrint(&msg_buf, "Invalid body: {s}\n", .{
            @errorName(err),
        });

        return sendError(req, .{
            .is_error = true,
            .message = msg,
        }) catch return;
    };

    defer parsed_body.deinit();

    var shell_result = createWithShell(alloc, &parsed_body.value) catch |err| {
        var msg_buf: [100]u8 = undefined;

        const msg = std.fmt.bufPrint(&msg_buf, "Unable to create vm: {s}\n", .{
            @errorName(err),
        }) catch return;

        const response = .{
            .is_err = true,
            .message = msg,
        };

        var response_buf: [456]u8 = undefined;

        if (zap.stringifyBuf(&response_buf, response, .{})) |json| {
            req.setStatus(.internal_server_error);
            req.sendJson(json) catch return;
        }

        return;
    };

    defer shell_result.deinit();

    var buf: [2056]u8 = undefined;

    const response = .{
        .is_err = shell_result.failed,
        .output = if (shell_result.failed) shell_result.stderr.? else shell_result.stdout.?,
    };

    if (zap.stringifyBuf(&buf, response, .{})) |json| {
        return try req.sendJson(json);
    }
}
