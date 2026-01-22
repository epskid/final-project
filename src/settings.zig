// the settings interface
const Self = @This();

previous_state: ?s.State,
should_return: bool,
return_to_menu: bool,

pub fn init(previous_state: ?s.State) Self {
    return .{
        .previous_state = previous_state,
        .should_return = false,
        .return_to_menu = false,
    };
}

// whether to keep scaling to only integers
// when on, pixels may vary in size
pub var fractional_scaling: bool = true;

// do post-processing shaders
pub var post_malone: bool = true;

// show fps in top left
pub var show_fps: bool = false;

// show a timer
pub var show_timer: bool = false;

// skip all dialogue
pub var skip_dialogue: bool = false;

// screen shake
pub var screen_shake: bool = true;

pub fn tick(_: *Self) !void {}

inline fn toggler(setting: *bool, name: [:0]const u8, rect: *rl.Rectangle) void {
    const message = if (setting.*) name ++ " [ON]" else name ++ " [OFF]";
    _ = rg.toggle(rect.*, message, setting);
    rect.y += 16 + 4;
}

pub fn draw(self: *Self) void {
    rl.drawTexture(assets.inside, 0, 0, .white);

    var rect: rl.Rectangle = .init(16, 16, 256, 16);

    util.drawText("SETTINGS", 16, 16, 24, .white);
    rect.y += 24 + 4;

    if (util.button(rect, "TOGGLE FULLSCREEN")) util.toggleFullscreen();
    rect.y += 16 + 4;

    toggler(&fractional_scaling, "FRACTIONAL SCALING", &rect);
    toggler(&post_malone, "POST PROCESSING", &rect);
    toggler(&show_fps, "SHOW FPS", &rect);
    toggler(&show_timer, "SHOW TIMER", &rect);
    toggler(&skip_dialogue, "SKIP DIALOGUE", &rect);
    toggler(&screen_shake, "SCREEN SHAKE", &rect);

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

    if (util.button(rect, "BACK")) {
        self.should_return = true;
    }

    if (self.previous_state) |pv| switch (pv) {
        .playing => if (util.button(.init(16, consts.height - 16 - 16, 256, 16), "BACK TO MENU (PROGRESS IS LOST!)")) {
            self.return_to_menu = true;
        },
        else => {},
    };
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

    if (self.return_to_menu) {
        return .{
            .new_state = .{
                .needs_init = .menu,
            },
            .deinit = true,
        };
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
