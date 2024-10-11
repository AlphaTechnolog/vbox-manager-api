//! Query parser is a simple way to serialize the query params, instead of using
//! zap's builtin because i've had some issues with it before, maybe we could refactor
//! this to use internal zap builtin in a future.
const std = @import("std");

const QueryEntry = struct {
    key: []u8,
    value: []u8,

    pub fn deinit(self: *const @This(), alloc: std.mem.Allocator) void {
        alloc.free(self.key);
        alloc.free(self.value);
    }
};

allocator: std.mem.Allocator,
raw: []const u8,
elements: std.ArrayList(QueryEntry),

const Self = @This();

pub fn init(allocator: std.mem.Allocator, raw: []const u8) !*Self {
    var instance = try allocator.create(Self);
    instance.allocator = allocator;
    instance.raw = raw;
    instance.elements = std.ArrayList(QueryEntry).init(instance.allocator);
    try instance.fillElements();
    return instance;
}

const ParseError = anyerror || error{InvalidToken};

fn fillElements(self: *Self) ParseError!void {
    var it = std.mem.tokenizeAny(u8, self.raw, "&");

    while (it.next()) |queryparam| {
        var cur = std.mem.tokenizeAny(u8, queryparam, "=");

        try self.elements.append(QueryEntry{
            .key = try self.allocator.dupe(u8, cur.next() orelse return error.InvalidToken),
            .value = try self.allocator.dupe(u8, cur.next() orelse return error.InvalidToken),
        });
    }
}

pub fn deinit(self: *const Self) void {
    for (self.elements.items) |*element| {
        element.deinit(self.allocator);
    }
    self.elements.deinit();
    self.allocator.destroy(self);
}
