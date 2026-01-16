// the player class

const Self = @This();

const gun_distance = 10; // how far away the gun is from the player
const gun_cooldown_max = 0.5; // (seconds) time for gun to work again
const walk_speed = 300;
const jump_strength = consts.gravity / 4;
const suffocation_time = 3; // (seconds) time to suffocate
const sand_speed = 0.4; // sand speed multiplier
const tractor_beam_speed = 0.8; // tractor beam speed multiplier

suffocating: bool = false,
suffocation: ?f32 = null,
position: rl.Vector2,
velocity: rl.Vector2,
gun_position: rl.Vector2,
gun_cooldown: f32 = 0,
grounded: bool,
artifact: ?Artifact = null, // the artifact we're carrying
exploding: ?usize = null,
died: bool = false,

pub fn init() Self {
    rl.stopMusicStream(assets.main_music);
    rl.updateMusicStream(assets.main_music);
    return .{
        .position = .zero(),
        .velocity = .zero(),
        .gun_position = .zero(),
        .grounded = false,
    };
}

pub fn tick(self: *Self, game: *Game) !void {
    if (self.died) {
        rl.stopMusicStream(assets.main_music);
        rl.updateMusicStream(assets.main_music);
        if (rl.getKeyPressed() != .null) self.respawn(game);
        return;
    }
    if (self.exploding) |*ex| {
        ex.* -= 1;
        if (ex.* == 0) self.die();
        return;
    }

    const was_playing = rl.isMusicStreamPlaying(assets.main_music);
    if (game.level.active != 0 and !was_playing) {
        rl.playMusicStream(assets.main_music);
    }
    rl.updateMusicStream(assets.main_music);
    if (was_playing and !rl.isMusicStreamPlaying(assets.main_music)) {
        self.exploding = 60;
        const exp = try game.cloneLocal(Explosion, .init(self.position, 60, false));
        try game.spawn(exp.ticker());
        return;
    }

    const dt = rl.getFrameTime();

    // map movement keys and apply friction
    if (rl.isKeyDown(.a)) {
        self.velocity.x = -walk_speed;
    } else if (rl.isKeyDown(.d)) {
        self.velocity.x = walk_speed;
    } else if (self.grounded) {
        self.velocity.x /= 1.5;
    } else {
        self.velocity.x /= 1.1;
    }

    // jump if on ground
    if (self.grounded and rl.isKeyPressed(.space)) {
        self.velocity.y = -jump_strength;
    }

    // apply gravity
    self.velocity.y += consts.gravity * dt;

    // pick up an artifact
    if (game.map.artifact) |af| {
        if (rl.isKeyPressed(.q) and rl.checkCollisionRecs(
            util.mkTileHitboxAt(self.position),
            util.mkTileHitboxAt(af.position),
        )) {
            std.mem.swap(?Artifact, &self.artifact, &game.map.artifact);
        }
    }

    // put artifact in tractor beam
    if (game.map.tractor_beam) |*tb| {
        if (rl.isKeyPressed(.q) and rl.checkCollisionRecs(
            util.mkTileHitboxAt(self.position),
            tb.getHitbox(),
        )) {
            std.mem.swap(?Artifact, &self.artifact, &tb.artifact);
        }
    }

    // particle collisions
    {
        var sand_count: u32 = 0;
        var lava_count: u32 = 0;
        const player_x: isize = @intFromFloat(self.position.x);
        const player_y: isize = @intFromFloat(self.position.y);
        for (0..consts.tile_size) |xu| {
            for (0..consts.tile_size) |yu| {
                const x: isize = @intCast(xu);
                const y: isize = @intCast(yu);

                if (player_y + y < 0) continue else if (player_x + x < 0) continue else if (player_y + y > (consts.height - 1)) continue else if (player_x + x > (consts.width - 1)) continue;

                const glsl = game.particles[(@as(usize, @intCast(player_x + x)) + consts.width * @as(usize, @intCast(player_y + y)))];
                const particle = glsl.unpack();
                switch (particle.type) {
                    .loose_sand => sand_count += 1,
                    .lava => lava_count += 1,
                    else => {},
                }
            }
        }
        self.suffocating = sand_count > 200;
        if (self.suffocating) {
            if (self.suffocation) |*suf| {
                suf.* -= dt;
                if (suf.* < 0) {
                    self.die();
                    return;
                }
            } else {
                self.suffocation = suffocation_time;
            }
        } else if (self.suffocation) |*suf| {
            suf.* += 2 * dt;
            if (suf.* > suffocation_time) self.suffocation = null;
        }
        if (lava_count > 127) {
            self.die();
            return;
        }
    }

    // get slowed down in sand
    if (self.suffocating) self.velocity = self.velocity.scale(sand_speed);

    // get slowed falling in tractor beam
    if (game.map.tractor_beam) |tb| {
        if (self.velocity.y > 0) {
            if (rl.checkCollisionRecs(.init(self.position.x, self.position.y, consts.tile_size, consts.tile_size), tb.getHitbox())) {
                self.velocity.y *= tractor_beam_speed;
            }
        }
    }

    // run physics on the player
    // expand the hitbox if they're carrying an artifact
    const collision = util.moveAndCollide(
        &self.position,
        &self.velocity,
        .{
            .x = 0,
            .y = if (self.artifact != null) -consts.tile_size else 0,
            .width = consts.tile_size,
            .height = if (self.artifact != null) (2 * consts.tile_size) else consts.tile_size,
        },
        game.map,
    );

    // update states
    self.grounded = collision.grounded;

    // keep player in-bounds if nothing lies off screen
    // or advance them if there is
    if (!game.level.advance(game)) {
        const old_pos = self.position;
        self.position = self.position.clamp(
            .init(0, 0),
            .init(consts.width - consts.tile_size, consts.height - consts.tile_size),
        );
        if (old_pos.x != self.position.x) {
            self.velocity.x = 0;
        } else {
        }
        if (old_pos.y != self.position.y) {
            self.velocity.y = 0;

            if (self.position.y == (consts.height)) {
                self.die();
                return;
            }
        }
    }

    // keep artifact on head
    if (self.artifact) |*af| {
        af.position = self.position;
        af.position.y -= consts.tile_size;
    }

    // update the gun position
    self.gun_position = rl.getMousePosition().subtract(self.position).normalize();

    if (self.gun_cooldown == 0) {
        if (rl.isMouseButtonPressed(.left)) {
            self.gun_cooldown = gun_cooldown_max;

            // spawn a rocket
            const rocket = try game.cloneLocal(Rocket, .init(self.position.addValue(consts.tile_size / 2), self.gun_position.scale(20)));
            try game.spawn(rocket.ticker());

            // a wee bit of recoil
            self.velocity = self.velocity.subtract(self.gun_position.scale(100));
        }
    } else {
        // cool down the gun
        self.gun_cooldown = @max(0, self.gun_cooldown - dt);
    }
}

pub fn die(self: *Self) void {
    self.died = true;
}

pub fn respawn(self: *Self, game: *Game) void {
    game.level.switchRoom(0, game);
    self.* = .init();
    self.spawnAtTractor(game);
}

pub fn spawnAtTractor(self: *Self, game: *Game) void {
    self.position.x = game.map.tractor_beam.?.bottom.x;
    self.position.y = 0;
}

pub fn draw(self: *const Self) void {
    if (self.died) {
        const text = "YOU DIED -- PRESS ANY KEY TO CONTINUE";
        const size = 16;
        const width = rl.measureText(text, size);
        const pad = 4;
        rl.drawRectangle(
            consts.width / 2 - @divFloor(width, 2) - pad,
            consts.height / 2 - size / 2 - pad,
            width + pad * 2,
            size + pad * 2,
            consts.palette.x3B2027,
        );
        rl.drawText(
            text,
            consts.width / 2 - @divFloor(width, 2),
            consts.height / 2 - size / 2,
            size,
            consts.palette.xE64539,
        );
    }
    if (self.exploding != null) return;
    if (self.artifact) |af| af.draw();

    // flip things around based on which way the gun is pointing
    const facing: f32 = if (self.gun_position.x < 0) -1 else 1;
    const tint: rl.Color = if (self.suffocating or self.died) .init(0, 0, 0, 127) else .white;

    rl.drawTexturePro(
        assets.player,
        .init(
            0,
            0,
            facing * consts.tile_size,
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
        tint,
    );

    const pos = self.position
        .addValue(consts.tile_size / 2)
        .add(self.gun_position
        .scale(gun_distance)
        .scale((gun_cooldown_max - self.gun_cooldown) / gun_cooldown_max)); // move gun while cooling down

    rl.drawTexturePro(
        assets.gun,
        .init(
            0,
            0,
            consts.tile_size,
            facing * consts.tile_size,
        ),
        .init(
            pos.x,
            pos.y,
            consts.tile_size,
            consts.tile_size,
        ),
        .init(consts.tile_size / 2, consts.tile_size / 2),
        std.math.radiansToDegrees(std.math.atan2(self.gun_position.y, self.gun_position.x)),
        tint,
    );
}

const Game = @import("game.zig");
const Rocket = @import("rocket.zig");
const Artifact = @import("artifact.zig");
const Explosion = @import("explosion.zig");

const ps = @import("particle_spec.zig");
const util = @import("util.zig");
const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
const std = @import("std");
