// the player class

const Self = @This();

const gun_distance = 10; // how far away the gun is from the player
const gun_cooldown_max = 0.5; // (seconds) time for gun to work again
const walk_speed = 300;
const jump_strength = consts.gravity / 4;
const suffocation_time = 3; // (seconds) time to suffocate
const sand_speed = 0.4; // sand speed multiplier
const tractor_beam_speed = 0.7; // tractor beam speed multiplier

suffocating: bool,
suffocation: ?f32,
position: rl.Vector2,
velocity: rl.Vector2,
gun_position: rl.Vector2,
gun_cooldown: f32,
grounded: bool,
artifact: ?Artifact,
exploding: ?usize,
died: bool,

pub fn init() Self {
    rl.stopMusicStream(assets.main_music);
    rl.updateMusicStream(assets.main_music);
    return .{
        .suffocating = false,
        .suffocation = null,
        .position = .zero(),
        .velocity = .zero(),
        .gun_position = .zero(),
        .gun_cooldown = 0,
        .grounded = false,
        .artifact = null,
        .exploding = null,
        .died = false,
    };
}

pub fn getHitbox(self: *const Self) rl.Rectangle {
    // hitbox expands when holding an artifact
    return .init(
        0,
        if (self.artifact != null) -consts.tile_size else 0,
        consts.tile_size,
        if (self.artifact != null) (2 * consts.tile_size) else consts.tile_size,
    );
}

// 500Hz lowpass filter when suffocating
const SuffocatingFilter = util.LowpassFilter(500);

pub fn tick(self: *Self, game: *Game) !void {
    if (self.died) {
        rl.stopMusicStream(assets.main_music);
        rl.updateMusicStream(assets.main_music);
        if (rl.getKeyPressed() != .null) {
            game.deaths += 1;
            self.respawn(game);
        }
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
        // explode when the music stops
        self.exploding = 60;
        const exp = try game.cloneLocal(Explosion, .init(self.position.addValue(consts.tile_size / 2), 60, false));
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
    if (self.artifact == null) {
        if (game.map.artifact) |af| {
            if (rl.checkCollisionRecs(
                util.mkTileHitboxAt(self.position),
                util.mkTileHitboxAt(af.position),
            )) {
                self.artifact = game.map.artifact;
                game.map.artifact = null;

                const alert = try game.cloneLocal(ReturnToShip, .init());
                try game.spawn(alert.ticker());
            }
        }
    }

    // put artifact in tractor beam
    if (game.map.tractor_beam) |*tb| {
        if ((self.artifact != null) and rl.checkCollisionRecs(
            util.mkTileHitboxAt(self.position),
            tb.getHitbox(),
        )) {
            tb.artifact = self.artifact;
            self.artifact = null;
        }
    }

    // particle collisions
    // can probably made more efficient but this implementation keeps up 60fps on debug mode
    // if it ain't broke don't fix it
    const prev_suffoc = self.suffocating;
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
        self.suffocating = sand_count > 100;
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

    // add audio filters
    if (!prev_suffoc and self.suffocating) {
        rl.attachAudioStreamProcessor(assets.main_music.stream, SuffocatingFilter.process);
    } else if (!self.suffocating) {
        rl.detachAudioStreamProcessor(assets.main_music.stream, SuffocatingFilter.process);
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
        self.getHitbox(),
        game.map,
    );

    // update states
    self.grounded = collision.grounded;

    // bounce the player inbounds if they can't get to the next map
    if (!game.level.advance(game)) {
        const min: rl.Vector2 = .init(-consts.tile_size, -consts.tile_size);
        const max: rl.Vector2 = .init(consts.width, consts.height);
        if (self.position.x < min.x or self.position.x > max.x) {
            self.velocity.x = -self.velocity.x;
            while (self.position.x < min.x or self.position.x > max.x) {
                _ = util.moveAndCollide(
                    &self.position,
                    &self.velocity,
                    self.getHitbox(),
                    game.map,
                );
            }
        }
        if (self.position.y < min.y or self.position.y > max.y) {
            self.velocity.y = -self.velocity.y * 0.1;
            while (self.position.y < min.y or self.position.y > max.y) {
                _ = util.moveAndCollide(
                    &self.position,
                    &self.velocity,
                    self.getHitbox(),
                    game.map,
                );
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

    // tell the compute shader if we're standing in one place
    if (self.grounded and @abs(self.velocity.x) < 0.1) {
        if ((self.position.x >= (consts.tile_size / 2)) and (self.position.x < (consts.width - consts.tile_size / 2))) {
            game.simulation.compute.pushCommand(.{
                .func = .{
                    .flag = .walked,
                    .x = @intFromFloat(self.position.x + (consts.tile_size / 2)),
                    .y = @intFromFloat(self.position.y + consts.tile_size + 1),
                },
                .parameter = 0,
            });
            game.simulation.compute.writeCommands();
        }
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
    self.position.x = game.map.tractor_beam.?.bottom.x - consts.tile_size / 2;
    self.position.y = 0;
}

pub fn draw(self: *const Self) void {
    if (self.died) {
        const text = "YOU DIED. SAD!";
        const size = 24;
        const width = util.measureText(text, size);
        const pad = 4;
        rl.drawRectangle(
            0,
            consts.height / 2 - size / 2 - pad,
            consts.width,
            size + pad * 2,
            consts.palette.x3B2027,
        );
        util.drawText(
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
const ReturnToShip = @import("return_to_ship.zig");

const ps = @import("particle_spec.zig");
const util = @import("util.zig");
const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
const std = @import("std");
