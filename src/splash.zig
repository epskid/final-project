// the splash screen
const Self = @This();

const total_time = 3;

boot: rl.Sound,
splash: rl.Texture,
progress: f32,

pub fn init() !Self {
    const boot = try rl.loadSound("resources/sounds/sfx/boot.ogg");
    rl.playSound(boot);
    return .{
        .boot = boot,
        .splash = try util.texFromImg("resources/images/splash.png"),
        .progress = 0,
    };
}

pub fn tick(self: *Self) !void {
    if (rl.isKeyPressed(.escape)) self.progress = total_time;
    self.progress += rl.getFrameTime();
}

pub fn draw(self: *const Self) void {
    rl.drawTexture(self.splash, 0, 0, .white);
}

pub fn getNewState(self: *const Self) ?s.NewStateInfo {
    if (self.progress > total_time) {
        return .{
            .new_state = .{
                .needs_init = .menu,
            },
            .deinit = true,
        };
    }

    return null;
}

pub fn deinit(self: *Self, _: std.mem.Allocator) void {
    rl.unloadSound(self.boot);
    rl.unloadTexture(self.splash);
}

const Menu = @import("menu.zig");

const s = @import("state.zig");
const util = @import("util.zig");

const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
