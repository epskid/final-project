// central game logic

const Self = @This();

const particle_simulation_timescale = 8;

index: usize,
camera: rl.Camera2D,
map: *Map,
level: Level,
player: Player,
tickers: std.ArrayList(Ticker),
global_allocator: std.mem.Allocator,
map_arena: std.heap.ArenaAllocator,
simulation: ps.Simulation,
hash_before: [consts.height_tiles]u32,
particles: []ps.Particle.GLSLRepr,
hash_after: [consts.height_tiles]u32,
score: usize,
deaths: usize,

pub fn init(allocator: std.mem.Allocator) !Self {
    // load the particle simulation
    return .{
        .index = 0,
        .camera = .{
            .offset = .zero(),
            .target = .zero(),
            .rotation = 0,
            .zoom = 1,
        },
        .map = undefined,
        .level = undefined,
        .player = .init(),
        .tickers = .empty,
        .global_allocator = allocator,
        .map_arena = .init(allocator),
        .simulation = try ps.Simulation.load(
            "resources/shaders/logic.glsl",
            "resources/shaders/transfer.glsl",
            "resources/shaders/render.glsl",
        ),
        .hash_before = undefined,
        .particles = try allocator.alloc(ps.Particle.GLSLRepr, consts.width * consts.height),
        .hash_after = undefined,
        .score = 0,
        .deaths = 0,
    };
}

pub fn loadLevel(self: *Self, level: usize) !void {
    self.index = level;
    const level_path = try std.fmt.allocPrintSentinel(
        self.global_allocator,
        "resources/levels/{}",
        .{level},
        0,
    );
    defer self.global_allocator.free(level_path);
    self.level = try .load(level_path, self);
    self.level.spawn(self); // spawn the starting map from the level
    self.player.spawnAtTractor(self);
}

pub fn cloneLocal(self: *Self, comptime T: type, value: T) !*T {
    // clone a value to the map-local arena
    const result = try self.map_arena.allocator().create(T);
    result.* = value;
    return result;
}

pub fn spawn(self: *Self, ticker: Ticker) !void {
    // spawn a ticker
    try self.tickers.append(self.map_arena.allocator(), ticker);
}

pub fn tick(self: *Self) !void {
    self.camera.offset = .zero();

    if (!self.player.died) {
        self.level.dialog.tick(self);

        if (self.level.dialog.active != null) return;

        // tick the tickers
        var i = self.tickers.items.len;
        while (i > 0) {
            i -= 1;
            try self.tickers.items[i].tick(self);
            if (self.tickers.items[i].shouldDespawn()) {
                _ = self.tickers.swapRemove(i); // not a memory leak 'cause all tickers are freed on room change
            }
        }

        if (self.map.artifact) |*af| af.tick(self);
        if (self.map.tractor_beam) |*tb| tb.tick(self);

        // tick particle simulation
        inline for (0..particle_simulation_timescale) |_| {
            self.simulation.compute.tick();
        }

        self.simulation.compute.readA(self.particles);

        self.map.loadTiles(self);
    }

    try self.player.tick(self);
}

pub fn draw(self: *const Self) void {
    if (Settings.screen_shake) rl.beginMode2D(self.camera);
    defer if (Settings.screen_shake) rl.endMode2D();

    // draw the current scene
    if (self.level.active == 0) rl.drawTexture(assets.outside, 0, 0, .white) else rl.drawTexture(assets.inside, 0, 0, .white);

    if (!self.player.died and !self.player.suffocating) self.player.draw();
    if (self.map.artifact) |af| af.draw();
    if (self.map.tractor_beam) |tb| tb.draw();

    const vignette_radius = if (self.player.suffocation) |suf| (0.7 * (suf / 3) - 0.05) else 1.0;
    rl.setShaderValue(self.simulation.render, 2, &vignette_radius, .float);
    self.simulation.draw();

    for (self.tickers.items) |ticker| ticker.draw();

    if (self.player.died or self.player.suffocating) self.player.draw();

    const score_str = std.fmt.allocPrintSentinel(self.global_allocator, "QUOTA: {}/{}", .{ self.score, self.level.quota }, 0) catch unreachable;
    defer self.global_allocator.free(score_str);
    util.drawText(score_str, 32, 32, 24, .white);

    self.level.dialog.draw(self.global_allocator) catch unreachable;
}

pub fn getNewState(self: *const Self) ?s.NewStateInfo {
    if (rl.isKeyDown(.escape)) {
        return .{
            .new_state = .{
                .needs_init = .settings,
            },
            .deinit = false,
        };
    } else if (self.map.tractor_beam) |tb| {
        if ((self.player.position.y < 0) and (self.player.position.x > (tb.bottom.x - TractorBeam.width)) and (self.player.position.x < (tb.bottom.x + TractorBeam.width))) {
            rl.stopMusicStream(assets.main_music);
            rl.updateMusicStream(assets.main_music);

            const result = blk: {
                const stats = Stats.init(
                    self.global_allocator,
                    self.index,
                    self.score,
                    self.level.quota,
                    self.deaths,
                ) catch |e| break :blk e;
                const stats_dupe = self.global_allocator.create(Stats) catch |e| break :blk e;
                stats_dupe.* = stats;
                break :blk s.NewStateInfo{
                    .new_state = .{
                        .inited = .{
                            .stats = stats_dupe,
                        },
                    },
                    .deinit = true,
                };
            } catch |err| {
                std.log.err("failed to initialize stats: {}\n", .{err});
                std.log.warn("kickin' to menu\n", .{});
                return .{
                    .new_state = .{
                        .needs_init = .menu,
                    },
                    .deinit = true,
                };
            };

            return result;
        }
    }

    return null;
}

pub fn freeLocal(self: *Self) void {
    // clear tickers (they're map-local) and free all map allocated memory
    self.tickers.clearAndFree(self.map_arena.allocator());
    _ = self.map_arena.reset(.free_all);
}

pub fn deinit(self: *Self, _: std.mem.Allocator) void {
    self.freeLocal();
    self.level.unload(self);
    self.simulation.unload();
    self.global_allocator.free(self.particles);
}

const Map = @import("map.zig");
const Stats = @import("stats.zig");
const Level = @import("level.zig");
const Player = @import("player.zig");
const Ticker = @import("ticker.zig");
const Settings = @import("settings.zig");
const TractorBeam = @import("tractor_beam.zig");

const s = @import("state.zig");
const ps = @import("particle_spec.zig");
const util = @import("util.zig");
const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
const std = @import("std");
