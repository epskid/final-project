// code for the explosions from the rocket launcher

const Self = @This();

position: rl.Vector2,
size: f32,
max_size: f32,
trail: bool,

pub fn init(
    position: rl.Vector2,
    max_size: f32,
    trail: bool,
) Self {
    return .{
        .position = position,
        .size = 1,
        .max_size = max_size,
        .trail = trail,
    };
}

pub fn tick(self: *Self, game: *Game) !void {
    // if it's a terminal (non-trail) explosion, check for collisions with the player
    if (!self.trail and rl.checkCollisionCircleRec(self.position, self.size, .init(
        game.player.position.x,
        game.player.position.y,
        consts.tile_size,
        consts.tile_size,
    ))) {
        // move the player away along the radius
        game.player.velocity = game.player.position
            .addValue(consts.tile_size / 2)
            .subtract(self.position)
            .normalize()
            .scale(35 * self.size);
    }

    self.size *= 2; // grow

    if (self.shouldDespawn()) {
        // if we've reached our max size, explode nearby particles

        const rad: u32 = if (!self.trail) @intFromFloat(self.max_size) else 10;

        // fill a circle
        for (0..@intCast(rad * 2)) |y_rel_mapped| {
            const y_rel = @as(i32, @intCast(y_rel_mapped)) - @as(i32, @intCast(rad)); // (0 to 2r) -> (-r to r)
            const y = @as(i32, @intFromFloat(self.position.y)) + y_rel; // get absolute y position
            if ((y < 0) or (y >= (consts.height - 1))) continue; // skip this iteration if it's off screen

            // get the size of a horizontal slice of the circle at the current y-value with the circle formula:
            // x^2 + y^2 = r^2
            // x = sqrt(r^2 - y^2)
            const x_slice: i32 = @intCast(std.math.sqrt((rad * rad) - @as(u32, @intCast(y_rel * y_rel))));
            for (0..@intCast(x_slice * 2)) |x_rel_mapped| {
                const x_rel = @as(i32, @intCast(x_rel_mapped)) - x_slice; // yet again
                const x = @as(i32, @intFromFloat(self.position.x)) + x_rel; // make it absolute
                if ((x < 0) or (x > (consts.width - 1))) continue; // skip off-screen

                // push the explosion command
                game.simulation.compute.pushCommand(.{
                    .func = .{
                        .flag = .explode,
                        .x = @intCast(x),
                        .y = @intCast(y),
                    },
                    .parameter = 0,
                });

                // update map
                var map_x: f32 = @as(f32, @floatFromInt(x)) / consts.tile_size;
                map_x = if (x_rel < 0) @ceil(map_x) else @floor(map_x);
                var map_y: f32 = @as(f32, @floatFromInt(y)) / 16;
                map_y = if (y_rel < 0) @ceil(map_y) else @floor(map_y);
                const idx = map_x + consts.width_tiles * map_y;
                if (idx < game.map.tiles.len) {
                    if (game.map.tiles[@intFromFloat(idx)] != .rock) game.map.tiles[@intFromFloat(idx)] = null;
                }
            }
        }

        // flush commands
        game.simulation.compute.writeCommands();
    }
}

pub fn draw(self: *const Self) void {
    if (!self.trail) rl.drawCircleV(self.position, self.size, .orange) // draw growing animation for terminal explosions
    else rl.drawCircleV(self.position, (self.max_size - self.size) / 3, .orange); // draw shrinking animation for trails
}

pub fn shouldDespawn(self: *const Self) bool {
    return self.size > self.max_size;
}

pub fn ticker(self: *Self) Ticker {
    // implement the ticker interface
    return Ticker.wrap(self);
}

const Game = @import("game.zig");
const Ticker = @import("ticker.zig");

const ps = @import("particle_spec.zig");
const consts = @import("consts.zig");

const rl = @import("raylib");
const std = @import("std");
