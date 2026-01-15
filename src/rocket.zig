// the rockets from the rocket launcher

const Self = @This();

const min_range = consts.tile_size * 2; // minimum range for a tail explosion to be created
const min_range_squared = min_range * min_range; // square it so we don't need expensive square roots

initial_position: rl.Vector2,
position: rl.Vector2,
velocity: rl.Vector2,
hit_wall: bool,

pub fn init(
    position: rl.Vector2,
    velocity: rl.Vector2,
) Self {
    return .{
        .initial_position = position,
        .position = position,
        .velocity = velocity,
        .hit_wall = false,
    };
}

pub fn tick(self: *Self, game: *Game) !void {
    // move
    self.position = self.position.add(self.velocity).clamp(.zero(), .init(consts.width, consts.height));
    // check for collisions
    self.hit_wall = game.map.isColliding(.init(
        self.position.x,
        self.position.y,
        consts.tile_size / 4,
        consts.tile_size / 4,
    ));

    // check range
    if (self.hit_wall) {
        // spawn big terminal explosion
        const exp = try game.cloneLocal(Explosion, .init(self.position, 60, false));
        try game.spawn(exp.ticker());
    } else if (self.position.distanceSqr(self.initial_position) >= min_range_squared) {
        // spawn small little trail explosion
        const exp = try game.cloneLocal(Explosion, .init(self.position, 25, true));
        try game.spawn(exp.ticker());
    }
}

pub fn draw(_: *const Self) void {}

pub fn shouldDespawn(self: *const Self) bool {
    return self.hit_wall or (self.position.y >= consts.height) or (self.position.y <= 0) or (self.position.x >= consts.width) or (self.position.x <= 0);
}

pub fn ticker(self: *Self) Ticker {
    // implement ticker
    return Ticker.wrap(self);
}

const Game = @import("game.zig");
const Ticker = @import("ticker.zig");
const Explosion = @import("explosion.zig");

const ps = @import("particle_spec.zig");
const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
const std = @import("std");
