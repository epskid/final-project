const Self = @This();

const width = 64;
const num_rings = 8;

bottom: rl.Vector2,
artifact: ?Artifact,
scoring_applied: bool,

pub fn init(
    bottom: rl.Vector2,
) Self {
    return .{
        .bottom = bottom,
        .artifact = null,
        .scoring_applied = false,
    };
}

pub fn tick(self: *Self, game: *Game) void {
    if (self.artifact) |*af| {
        if (!self.scoring_applied) {
            game.score += af.rarity.toScore();
            self.scoring_applied = true;
        }

        af.position.y -= 100 * rl.getFrameTime();

        if (af.position.y < -consts.tile_size) {
            self.artifact = null;
            self.scoring_applied = false;
        }
    }
}

pub fn draw(self: *const Self) void {
    const height = self.bottom.y;
    const ring_distance = height / num_rings;
    const ring_offset: f32 = @floatCast(@mod(rl.getTime() * 60, ring_distance));

    for (0..num_rings) |ring_num_u| {
        const ring_num: f32 = @floatFromInt(ring_num_u);
        rl.drawEllipseLinesV(
            .init(self.bottom.x, -ring_offset + (ring_num * ring_distance) + ring_distance),
            width * (((ring_num + 1) - (ring_offset / ring_distance)) / 8),
            8,
            consts.palette.x92E8C0
        );
    }

    if (self.artifact) |af| af.draw();
}

pub fn getHitbox(self: *const Self) rl.Rectangle {
    return .init(self.bottom.x - (width / 2), 0, width, self.bottom.y);
}

const Game = @import("game.zig");
const Artifact = @import("artifact.zig");

const ps = @import("particle_spec.zig");
const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
const std = @import("std");
