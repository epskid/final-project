// state management

pub const NewStateInfo = struct {
    new_state: union(enum) {
        needs_init: std.meta.Tag(State),
        inited: State,
    },
    deinit: bool,

    pub fn getTag(self: NewStateInfo) std.meta.Tag(State) {
        return switch (self.new_state) {
            .needs_init => |ni| ni, // we are the knights who say
            .inited => |it| std.meta.activeTag(it),
        };
    }
};

// provides a layer for interfacing with all state types
pub const State = union(enum) {
    // state types
    splash: ?*Splash,
    menu: ?*Menu,
    controls: ?*Controls,
    settings: ?*Settings,
    playing: ?*Game,
    stats: ?*Stats,
    credits: ?*Credits,
    ending: ?*Ending,

    pub fn tick(self: State) !void {
        switch (self) {
            inline else => |maybe| if (maybe) |*confirmed| try confirmed.*.tick(),
        }
    }

    pub fn draw(self: State) void {
        switch (self) {
            inline else => |maybe| if (maybe) |*confirmed| confirmed.*.draw(),
        }
    }

    pub fn init(state: std.meta.Tag(State), allocator: std.mem.Allocator) !State {
        switch (state) {
            .splash => {
                const splash = try allocator.create(Splash);
                splash.* = try .init();
                return .{ .splash = splash };
            },
            .menu => {
                const menu = try allocator.create(Menu);
                menu.* = try .init();
                return .{ .menu = menu };
            },
            .controls => {
                const controls = try allocator.create(Controls);
                controls.* = .init(null);
                return .{ .controls = controls };
            },
            .settings => {
                const settings = try allocator.create(Settings);
                settings.* = .init(null);
                return .{ .settings = settings };
            },
            .playing => {
                const game = try allocator.create(Game);
                game.* = try .init(allocator);
                return .{ .playing = game };
            },
            .credits => {
                const credits = try allocator.create(Credits);
                credits.* = .init();
                return .{ .credits = credits };
            },
            .ending => {
                const end = try allocator.create(Ending);
                end.* = try .init();
                return .{ .ending = end };
            },
            else => unreachable,
        }
    }

    pub fn deinit(self: State, allocator: std.mem.Allocator) void {
        // warning! invalidates usage of .draw and .tick!

        switch (self) {
            inline else => |maybe| if (maybe) |*confirmed| {
                confirmed.*.deinit(allocator);
                allocator.destroy(confirmed.*);
            },
        }
    }

    fn getNewState(self: State) ?NewStateInfo {
        switch (self) {
            inline else => |maybe| if (maybe) |confirmed| return confirmed.getNewState(),
        }

        return null;
    }

    pub fn switchState(self: State, allocator: std.mem.Allocator) !?State {
        const should = self.getNewState() orelse return null;
        const previous_state = std.meta.activeTag(self);
        if (previous_state == should.getTag()) return null;

        const result = switch (should.new_state) {
            .needs_init => |ni| blk: {
                const new_state = try State.init(ni, allocator);
                switch (new_state) {
                    .playing => |game| switch (self) {
                        .menu => |menu| try game.?.loadLevel(menu.?.selected_level.?),
                        else => {},
                    },
                    inline .controls, .settings => |maybe| if (maybe) |confirmed| {
                        std.debug.assert(!should.deinit);
                        confirmed.*.previous_state = self;
                    },
                    else => {},
                }
                break :blk new_state;
            },
            .inited => |it| it,
        };

        if (should.deinit) self.deinit(allocator);

        return result;
    }
};

const Menu = @import("menu.zig");
const Game = @import("game.zig");
const Stats = @import("stats.zig");
const Splash = @import("splash.zig");
const Ending = @import("ending.zig");
const Credits = @import("credits.zig");
const Controls = @import("controls.zig");
const Settings = @import("settings.zig");

const std = @import("std");
