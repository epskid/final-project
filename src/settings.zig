// the settings interface
const Self = @This();

previous_state: ?s.State,
should_return: bool,

pub fn init(previous_state: ?s.State) Self {
    return .{
        .previous_state = previous_state,
        .should_return = false,
    };
}

// whether to keep scaling to only integers
// when on, pixels may vary in size
pub var fractional_scaling: bool = true;

// show fps in top left
pub var show_fps: bool = false;

// skip all dialogue
pub var skip_dialogue: bool = false;

pub fn tick(_: *Self) !void {}

pub fn draw(self: *Self) void {
    rl.clearBackground(.beige);

    var rect: rl.Rectangle = .init(16, 16, 256, 16);

    {
        _ = rg.label(rect, "SETTINGS");

        rect.y += 16 + 4;
    }

    {
        const message = if (fractional_scaling) "FRACTIONAL SCALING [ON]" else "FRACTIONAL SCALING [OFF]";
        _ = rg.toggle(rect, message, &fractional_scaling);

        rect.y += 16 + 4;
    }

    {
        const message = if (show_fps) "SHOW FPS [ON]" else "SHOW FPS [OFF]";
        _ = rg.toggle(rect, message, &show_fps);

        rect.y += 16 + 4;
    }

    {
        const message = if (skip_dialogue) "SKIP DIALOGUE [ON]" else "SKIP DIALOGUE [OFF]";
        _ = rg.toggle(rect, message, &skip_dialogue);

        rect.y += 16 + 4;
    }

    {
        var new_volume = rl.getMasterVolume() * 100;
        _ = rg.label(rect, "MASTER VOLUME");

        rect.y += 16;

        var buf: [4]u8 = undefined;
        const vol = std.fmt.bufPrintZ(&buf, "{}", .{@as(i32, @intFromFloat(new_volume))}) catch unreachable;
        if (rg.sliderBar(rect, "", vol, &new_volume, 0, 100) == 1) {
            if (!rl.isSoundPlaying(assets.volume_sound)) rl.playSound(assets.volume_sound);
        }
        rl.setMasterVolume(new_volume / 100);

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
const assets = @import("assets.zig");

const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
