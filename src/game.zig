// central game logic

const Self = @This();

const particle_simulation_timescale = 8;

map: *Map,
level: Level,
player: Player,
tickers: std.ArrayList(Ticker),
global_allocator: std.mem.Allocator,
map_arena: std.heap.ArenaAllocator,
simulation: ps.Simulation,
particles: []ps.Particle.GLSLRepr,
score: usize,

pub fn init(allocator: std.mem.Allocator) !Self {
    // load the particle simulation
    return .{
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
        .particles = try allocator.alloc(ps.Particle.GLSLRepr, consts.width * consts.height),
        .score = 0,
    };
}

pub fn loadLevel(self: *Self, level: usize) !void {
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
    self.level.dialog.tick(self);
    if (self.level.dialog.active != null) return;

    // tick the tickers
    var i = self.tickers.items.len;
    while (i > 0) {
        i -= 1;
        try self.tickers.items[i].tick(self);
        if (self.tickers.items[i].shouldDespawn()) {
            _ = self.tickers.swapRemove(i); // not a memory leak 'cause all tickers are deactivated on room change
        }
    }

    if (self.map.artifact) |*af| af.tick(self);
    if (self.map.tractor_beam) |*tb| tb.tick(self);

    // tick particle simulation
    inline for (0..particle_simulation_timescale) |_| {
        // two for the checkerboard pattern
        self.simulation.compute.tick();
        self.simulation.compute.tick();
    }

    self.simulation.compute.readA(self.particles);

    try self.player.tick(self);
}

pub fn draw(self: *const Self) void {
    // draw the current scene
    if (self.level.active == 0) rl.drawTexture(assets.start, 0, 0, .white) else rl.drawTexture(assets.inside, 0, 0, .white);

    if (!self.player.died and !self.player.suffocating) self.player.draw();
    if (self.map.artifact) |af| af.draw();
    if (self.map.tractor_beam) |tb| tb.draw();

    const vignette_radius = if (self.player.suffocation) |suf| (0.7 * (suf / 3) - 0.05) else 1.0;
    rl.setShaderValue(self.simulation.render, 2, &vignette_radius, .float);
    self.simulation.draw();

    for (self.tickers.items) |ticker| ticker.draw();

    if (self.player.died or self.player.suffocating) self.player.draw();

    if (Settings.show_fps) rl.drawFPS(32, 32);

    const score_str = std.fmt.allocPrintSentinel(self.global_allocator, "SCORE: {}", .{self.score}, 0) catch unreachable;
    defer self.global_allocator.free(score_str);
    rl.drawText(score_str, 16, 16, 16, .white);

    self.level.dialog.draw(self.global_allocator) catch unreachable;
}

pub fn getNewState(_: *const Self) ?s.NewStateInfo {
    if (rl.isKeyDown(.escape)) return .{
        .new_state = .{
            .needs_init = .settings,
        },
        .deinit = false,
    } else return null;
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
const Level = @import("level.zig");
const Player = @import("player.zig");
const Ticker = @import("ticker.zig");
const Settings = @import("settings.zig");

const s = @import("state.zig");
const ps = @import("particle_spec.zig");
const util = @import("util.zig");
const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
const std = @import("std");
