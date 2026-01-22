// a screen shaker

const Self = @This();

size: f32,
time: f32,

pub fn init(size: f32, time: f32) Self {
    return .{
        .size = size,
        .time = time,
    };
}

pub fn tick(self: *Self, game: *Game) !void {
    self.time -= rl.getFrameTime();

    const unit: rl.Vector2 = .init(1, 0);
    game.camera.offset = game.camera.offset.add(.rotate(
        unit.scale(self.size),
        std.math.degreesToRadians(util.asf32(rl.getRandomValue(0, 360))),
    ));
}

pub fn draw(_: *const Self) void {}

pub fn shouldDespawn(self: *const Self) bool {
    return !Settings.screen_shake or (self.time < 0);
}

pub fn ticker(self: *Self) Ticker {
    // implement ticker
    return Ticker.wrap(self);
}

const Game = @import("game.zig");
const Ticker = @import("ticker.zig");
const Settings = @import("settings.zig");

const util = @import("util.zig");

const rl = @import("raylib");
const std = @import("std");
