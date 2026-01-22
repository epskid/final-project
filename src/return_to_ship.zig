// a little return to ship alert

const Self = @This();

const blink_period = 0.5;
const size = 24;
const return_to_ship = "!!! RETURN TO SHIP !!!";

on: bool,
timer: f32,

pub fn init() Self {
    rl.playSound(assets.artifact_sound);
    return .{
        .on = true,
        .timer = 0,
    };
}

pub fn tick(self: *Self, _: *Game) !void {
    self.timer += rl.getFrameTime();

    if (self.timer > blink_period) {
        self.on = !self.on;
        self.timer = 0;
        if (self.on) rl.playSound(assets.artifact_sound);
    }
}

pub fn draw(self: *const Self) void {
    if (!self.on) return;

    const w = util.measureText(return_to_ship, size);
    const pad = 4;
    rl.drawRectangle(
        0,
        consts.height / 2 - size / 2 - pad,
        consts.width,
        size + 2 * pad,
        .init(67, 67, 67, 127),
    );
    util.drawText(
        return_to_ship,
        consts.width / 2 - @divTrunc(w, 2),
        consts.height / 2 - size / 2,
        size,
        .red,
    );
}

pub fn shouldDespawn(_: *const Self) bool {
    return false;
}

pub fn ticker(self: *Self) Ticker {
    return Ticker.wrap(self);
}

const Game = @import("game.zig");
const Ticker = @import("ticker.zig");

const util = @import("util.zig");
const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
