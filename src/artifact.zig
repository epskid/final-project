const Self = @This();

pub const Rarity = enum {
    common,
    rare,
    epic,
    legendary,

    pub fn toScore(self: Rarity) usize {
        return switch (self) {
            .common => 1,
            .rare => 2,
            .epic => 4,
            .legendary => 8,
        };
    }
};

position: rl.Vector2,
velocity: rl.Vector2,
rarity: Rarity,

pub fn init(position: rl.Vector2, velocity: rl.Vector2, rarity: Rarity) Self {
    return .{
        .position = position,
        .velocity = velocity,
        .rarity = rarity,
    };
}

pub fn tick(self: *Self, game: *Game) void {
    const dt = rl.getFrameTime();
    self.velocity.y += consts.gravity * dt;
    _ = util.moveAndCollide(
        &self.position,
        &self.velocity,
        .init(0, 0, consts.tile_size, consts.tile_size),
        game.map,
    );
}

pub fn draw(self: *const Self) void {
    rl.drawTexturePro(
        assets.artifacts,
        .init(
            util.asf32(@intFromEnum(self.rarity)) * consts.tile_size, // index the texture atlas
            0,
            consts.tile_size,
            consts.tile_size,
        ),
        .init(
            self.position.x,
            self.position.y,
            consts.tile_size,
            consts.tile_size,
        ),
        .zero(),
        0,
        .white,
    );
}

const Game = @import("game.zig");

const util = @import("util.zig");
const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
