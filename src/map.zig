// the current room is called a map

const Self = @This();

fn isSolid(tile: ps.ParticleType) enum { yes, no, semisolid } {
    return switch (tile) {
        .rock, .packed_sand, .wood, .shifty_sand => .yes,
        .grate => .semisolid,
        else => .no,
    };
}

fn isBreakable(tile: ps.ParticleType) bool {
    return switch (tile) {
        .rock, .grate => false,
        else => true,
    };
}

tiles: [consts.width_tiles * consts.height_tiles]ps.ParticleType,
artifact: ?Artifact = null,
particles: ?[]ps.Particle.GLSLRepr = null,
tractor_beam: ?TractorBeam = null,

pub fn load(path: [:0]const u8) !Self {
    // load a map
    var self: Self = .{
        .tiles = undefined,
    };
    @memset(&self.tiles, .none);

    const text = try rl.loadFileData(path);
    defer rl.unloadFileData(text);

    var lines = std.mem.splitScalar(u8, text, '\n');
    var y: usize = 0;
    while (lines.next()) |line| {
        for (0.., line) |x, ch| {
            const vec: rl.Vector2 = .init(util.asf32(x) * consts.tile_size, util.asf32(y) * consts.tile_size);
            self.tiles[x + (consts.width_tiles * y)] = switch (ch) {
                'r' => .rock,
                'S' => .loose_sand,
                's' => .packed_sand,
                '?' => .shifty_sand,
                'w' => .wood,
                'l' => .lava,
                'L' => .lava_source,
                '#' => .grate,
                '@' => {
                    self.artifact = .init(vec, .zero(), .common);
                    continue;
                },
                '%' => {
                    self.artifact = .init(vec, .zero(), .rare);
                    continue;
                },
                '+' => {
                    self.artifact = .init(vec, .zero(), .epic);
                    continue;
                },
                '$' => {
                    self.artifact = .init(vec, .zero(), .legendary);
                    continue;
                },
                '^' => {
                    self.tractor_beam = .init(vec.addValue(consts.tile_size));
                    continue;
                },
                else => continue,
            };
        }

        y += 1;
    }

    return self;
}

pub fn spawn(self: *Self, game: *Game) void {
    if (self.particles) |particles| {
        // if we have previous particles, spawn them
        for (0.., particles) |i, particle| {
            game.simulation.compute.pushCommand(.{
                .func = .{
                    .flag = .place,
                    .x = @intCast(i % consts.width),
                    .y = @intCast(i / consts.width),
                },
                .parameter = @bitCast(particle),
            });
        }

        game.global_allocator.free(particles);
        self.particles = null;
    } else {
        // otherwise spawn particles into the game based on the tiles
        var x: usize = 0;
        var y: usize = 0;

        // iterate every tile
        for (self.tiles) |tile| {
            // iterate every pixel in the tile
            for (0..consts.tile_size) |w| {
                for (0..consts.tile_size) |h| {
                    var place: u32 = 0;

                    // sample the pixel color from the tileset
                    if (tile != .none) blk: {
                        var color = assets.tileset.getColor(@intCast(w + (@as(usize, @intCast(@intFromEnum(tile) - 1)) * consts.tile_size)), @intCast(h));
                        if (color.a == 0) break :blk;

                        if (tile == .loose_sand or tile == .packed_sand) {
                            color = color.brightness(util.asf32(rl.getRandomValue(-20, 20)) / 100);
                        }
                        // more variation for shifty sand
                        if (tile == .shifty_sand) {
                            color = color.brightness(util.asf32(rl.getRandomValue(-20, 50)) / 100);
                        }
                        // pack the particle into a GLSL comparible format
                        place = @bitCast(ps.Particle.pack(.{
                            .type = switch (tile) {
                                .grate => .rock,
                                inline else => |other| other,
                            },
                            .color = color,
                        }));
                    }

                    // place the pixel
                    game.simulation.compute.pushCommand(.{
                        .func = .{
                            .flag = .place,
                            .x = @intCast((x * consts.tile_size) + w),
                            .y = @intCast((y * consts.tile_size) + h),
                        },
                        .parameter = place,
                    });
                }
            }

            x += 1;
            if (x == consts.width_tiles) {
                x = 0;
                y += 1;
            }
        }
    }

    // flush all commands
    game.simulation.compute.writeCommands();
}

pub fn loadTiles(self: *Self, game: *const Game) void {
    @setRuntimeSafety(false);

    var counters: [@typeInfo(ps.ParticleType).@"enum".fields.len]u8 = undefined;
    for (0..self.tiles.len) |tile_i| {
        if (!isBreakable(self.tiles[tile_i])) continue;

        @memset(&counters, 0);
        const x_start = (tile_i % consts.width_tiles) * consts.tile_size;
        const y_start = (tile_i / consts.width_tiles) * consts.tile_size;
        for (x_start..(x_start + consts.tile_size)) |x| {
            for (y_start..(y_start + consts.tile_size)) |y| {
                const particle = game.particles[x + consts.width * y];
                counters[particle.type] +|= 1;
            }
        }
        const max_idx = std.mem.indexOfMax(u8, counters[1..]);
        if (counters[max_idx + 1] > 127) {
            self.tiles[tile_i] = @enumFromInt(max_idx + 1);
        } else {
            self.tiles[tile_i] = .none;
        }
    }
}

pub fn saveParticles(self: *Self, game: *Game) void {
    // save the particles if we have the memory for it
    const particles = game.global_allocator.alloc(ps.Particle.GLSLRepr, consts.width * consts.height) catch |err| {
        std.log.warn("wasn't able to save simulation state: {}", .{err});
        return;
    };
    game.simulation.compute.readA(particles);
    self.particles = particles;
}

pub fn isColliding(self: *const Self, hitbox: rl.Rectangle, y_velocity: ?f32) bool {
    // iterate every tile
    for (0.., self.tiles) |i, tile| {
        const x: f32 = @floatFromInt((i % consts.width_tiles) * consts.tile_size);
        const y: f32 = @floatFromInt((i / consts.width_tiles) * consts.tile_size);
        const solid = isSolid(tile);
        const semisolid = if (y_velocity) |y_vel| (solid == .semisolid) and (hitbox.y + hitbox.height) < (y + 1) and (y_vel > 0) else solid == .semisolid;
        if (semisolid or (solid == .yes)) {
            if (rl.checkCollisionRecs(hitbox, .init(
                x,
                y,
                consts.tile_size,
                consts.tile_size,
            ))) return true;
        }
    }

    return false;
}

pub fn unload(self: *Self, game: *Game) void {
    if (self.particles) |particles| {
        game.global_allocator.free(particles);
    }
}

const Game = @import("game.zig");
const Artifact = @import("artifact.zig");
const TractorBeam = @import("tractor_beam.zig");

const ps = @import("particle_spec.zig");
const util = @import("util.zig");
const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
const std = @import("std");
