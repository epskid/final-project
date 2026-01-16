// the controls interface
const Self = @This();

previous_state: ?s.State,
should_return: bool,

pub fn init(previous_state: ?s.State) Self {
    return .{
        .previous_state = previous_state,
        .should_return = false,
    };
}

pub fn tick(_: *Self) !void {}

pub fn draw(self: *Self) void {
    rl.clearBackground(.beige);

    var rect: rl.Rectangle = .init(16, 16, 256, 16);

    {
        _ = rg.label(rect, "CONTROLS");

        rect.y += 16 + 4;
    }

    {
        _ = rg.label(rect, "Q - INTERACT");

        rect.y += 16 + 4;
    }

    {
        _ = rg.label(rect, "A/D - MOVE LEFT/RIGHT");

        rect.y += 16 + 4;
    }

    {
        _ = rg.label(rect, "SPACE - JUMP");

        rect.y += 16 + 4;
    }

    {
        _ = rg.label(rect, "MOUSE MOVE - AIM");

        rect.y += 16 + 4;
    }

    {
        _ = rg.label(rect, "LEFT MOUSE - FIRE");

        rect.y += 16 + 4;
    }

    {
        if (util.button(rect, "BACK")) {
            self.should_return = true;
        }

        rect.y += 16 + 4;
    }
}

pub fn getNewState(self: *const Self) ?s.NewStateInfo {
    if (self.should_return) {
        if (self.previous_state) |ps| {
            return .{
                .new_state = .{
                    .inited = ps,
                },
                .deinit = true,
            };
        }
    }

    return null;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    if (!self.should_return) {
        if (self.previous_state) |ps| ps.deinit(allocator);
    }
}

const s = @import("state.zig");
const util = @import("util.zig");
const consts = @import("consts.zig");

const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
