// credits screen

const Self = @This();

const credits = @embedFile("credits.txt");

send_back: bool,

pub fn init() Self {
    return .{
        .send_back = false,
    };
}

pub fn tick(_: *Self) !void {}

pub fn draw(self: *Self) void {
    rl.drawTexture(assets.inside, 0, 0, .white);
    util.drawText("CREDITS", 16, 16, 24, .white);
    util.drawText(credits, 16, 16 + 16 + 12, 12, .white);
    if (util.button(.init(16, consts.height - 16 - 16, 256, 16), "BACK")) {
        self.send_back = true;
    }
}

pub fn getNewState(self: *const Self) ?s.NewStateInfo {
    if (self.send_back) {
        return .{
            .new_state = .{
                .needs_init = .menu,
            },
            .deinit = true,
        };
    }

    return null;
}

pub fn deinit(_: *Self, _: std.mem.Allocator) void {}

const s = @import("state.zig");
const util = @import("util.zig");
const assets = @import("assets.zig");
const consts = @import("consts.zig");

const rl = @import("raylib");
const std = @import("std");
