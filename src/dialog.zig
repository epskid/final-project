const Self = @This();

const Conversation = struct {
    lines: std.mem.SplitIterator(u8, .scalar),
    remaining: usize,
};

raw: []u8,
dialog: std.AutoHashMap(usize, Conversation),
active: ?usize,
talk: usize = 0,

pub fn load(file: []const u8, idxs: []const u8, allocator: std.mem.Allocator) !Self {
    const raw = try rl.loadFileData(file);
    var dialog: std.AutoHashMap(usize, Conversation) = .init(allocator);

    var main_iter = std.mem.splitScalar(u8, raw, '\n');
    var idx: ?usize = null;
    while (main_iter.next()) |line| {
        if (std.mem.endsWith(u8, line, "::")) {
            idx = std.mem.indexOfScalar(u8, idxs, line[0]);
            try dialog.put(idx.?, .{
                .lines = main_iter,
                .remaining = 0,
            });
        } else {
            if (line.len > 0) dialog.getPtr(idx.?).?.*.remaining += 1;
        }
    }

    return .{
        .raw = raw,
        .dialog = dialog,
        .active = null,
    };
}

pub fn tick(self: *Self, game: *Game) void {
    if (settings.skip_dialogue) {
        self.active = null;
        return;
    }

    if (self.active) |idx| {
        const ptr = self.dialog.getPtr(idx).?;
        if (self.talk < ptr.lines.peek().?.len) {
            self.talk += 1;
        } else if (rl.getKeyPressed() != .null) {
            self.talk = 0;
            ptr.remaining -= 1;
            if (ptr.remaining == 0) self.active = null;
            _ = ptr.lines.next();
        }
    } else if (game.player.grounded and self.dialog.contains(game.level.active)) {
        if (self.dialog.get(game.level.active)) |convo| {
            if (convo.remaining > 0) self.active = game.level.active;
        }
    }
}

const size = 16;
pub fn draw(self: *const Self, allocator: std.mem.Allocator) !void {
    if (settings.skip_dialogue) return;

    if (self.active) |idx| {
        var line = self.dialog.get(idx).?;
        const line_z = try allocator.dupeZ(u8, line.lines.peek().?[0..self.talk]);
        defer allocator.free(line_z);
        const width = rl.measureText(line_z, 16);
        rl.drawText(
            line_z,
            consts.width / 2 - @divFloor(width, 2),
            consts.height / 2 - size / 2,
            size,
            .white,
        );
    }
}

pub fn unload(self: *Self) void {
    rl.unloadFileData(self.raw);
    self.dialog.deinit();
}

const Game = @import("game.zig");

const consts = @import("consts.zig");
const settings = @import("settings.zig");

const rl = @import("raylib");
const std = @import("std");
