// a level holds maps, which are interconnected

const Self = @This();

// the connections a map has to others
const Connections = struct {
    up: ?usize = null,
    down: ?usize = null,
    left: ?usize = null,
    right: ?usize = null,
};

active: usize, // index of the current map
maps: []Map, // all maps in the level
graph: std.AutoHashMap(usize, Connections), // bidirectional graph of connections between maps
dialog: Dialog,
quota: usize,

fn toChar(ch: u8) ?u8 {
    return if (ch == ' ') null else ch;
}

pub fn load(path: [:0]const u8, game: *Game) !Self {
    const layout_path = try std.fmt.allocPrint(game.global_allocator, "{s}/layout.txt", .{path});
    defer game.global_allocator.free(layout_path);

    const layout = try rl.loadFileData(layout_path);
    defer rl.unloadFileData(layout);

    var maps = std.ArrayList(Map).empty;
    var graph = std.AutoHashMap(usize, Connections).init(game.global_allocator);
    var grid_bytes = std.mem.splitScalar(u8, layout, '\n');
    var grid_list = std.ArrayList([]const u8).empty;
    while (grid_bytes.next()) |row| {
        if (row.len == 0) continue;
        try grid_list.append(game.global_allocator, row);
    }
    const grid = try grid_list.toOwnedSlice(game.global_allocator);
    defer game.global_allocator.free(grid);
    var map_char_list = std.ArrayList(u8).empty;
    var quota: usize = 0;

    for (grid) |row| {
        for (row) |ch| {
            if (ch == ' ') continue;

            const map_path = try std.fmt.allocPrintSentinel(game.global_allocator, "{s}/maps/{c}.txt", .{ path, ch }, 0);
            defer game.global_allocator.free(map_path);

            const map = try Map.load(map_path);
            if (map.artifact) |af| quota += af.rarity.toScore();
            // 0 defines the starting map
            if (ch == '0') {
                try maps.insert(game.global_allocator, 0, map);
                try map_char_list.insert(game.global_allocator, 0, ch);
            } else {
                try maps.append(game.global_allocator, map);
                try map_char_list.append(game.global_allocator, ch);
            }
        }
    }

    const map_chars = try map_char_list.toOwnedSlice(game.global_allocator);
    defer game.global_allocator.free(map_chars);
    for (0.., grid) |y, row| {
        for (0.., row) |x, ch| {
            if (ch == ' ') continue;

            const my_idx = std.mem.indexOfScalar(u8, map_chars, ch).?;
            try graph.put(my_idx, .{
                .up = if (y == 0) null else if (toChar(grid[y - 1][x])) |up_ch| std.mem.indexOfScalar(u8, map_chars, up_ch).? else null,
                .down = if (y == (grid.len - 1)) null else if (toChar(grid[y + 1][x])) |up_ch| std.mem.indexOfScalar(u8, map_chars, up_ch).? else null,
                .left = if (x == 0) null else if (toChar(grid[y][x - 1])) |up_ch| std.mem.indexOfScalar(u8, map_chars, up_ch).? else null,
                .right = if (x == (grid[0].len - 1)) null else if (toChar(grid[y][x + 1])) |up_ch| std.mem.indexOfScalar(u8, map_chars, up_ch).? else null,
            });
        }
    }

    const dialog_path = try std.fmt.allocPrint(game.global_allocator, "{s}/dialog.txt", .{path});
    defer game.global_allocator.free(dialog_path);
    const dialog: Dialog = try .load(dialog_path, map_chars, game.global_allocator);

    return .{
        .active = 0,
        .quota = @divFloor(quota, 2),
        .maps = try maps.toOwnedSlice(game.global_allocator),
        .graph = graph,
        .dialog = dialog,
    };
}

pub fn spawn(self: *Self, game: *Game) void {
    // spawn the active map into the game
    game.map = &self.maps[self.active];
    game.map.spawn(game);
}

pub fn advance(self: *Self, game: *Game) bool {
    var pos = game.player.position;

    const new_idx_x = if (pos.x < -(consts.tile_size / 2)) self.graph.get(self.active).?.left else if (pos.x + (consts.tile_size / 2) > consts.width) self.graph.get(self.active).?.right else null;
    const new_idx_y = if (pos.y > (consts.height - (consts.tile_size / 2))) self.graph.get(self.active).?.down else if (pos.y < -(consts.tile_size / 2)) self.graph.get(self.active).?.up else null;

    // change maps and wrap positions
    const new_active = if (new_idx_x) |idx| blk: {
        if (pos.x < 0) {
            pos.x += consts.width;
        } else {
            pos.x -= consts.width;
        }
        break :blk idx;
    } else if (new_idx_y) |idx| blk: {
        if (pos.y < 0) {
            pos.y = consts.height - consts.tile_size;
        } else {
            pos.y = 0;
        }
        break :blk idx;
    } else return false;

    if (self.maps[new_active].isColliding(
        util.skinHitbox(util.moveHitbox(pos, game.player.getHitbox())),
        game.player.velocity.y,
    )) return false;

    self.switchRoom(new_active, game);
    game.player.position = pos;

    return true;
}

pub fn switchRoom(self: *Self, new_active: usize, game: *Game) void {
    // save the old particles
    self.maps[self.active].saveParticles(game);
    // free old map-local data
    game.freeLocal();
    self.active = new_active;
    // spawn new room
    self.spawn(game);
}

pub fn unload(self: *Self, game: *Game) void {
    self.dialog.unload();
    // free all maps
    for (self.maps) |*map| map.unload(game);
    game.global_allocator.free(self.maps);
    self.graph.deinit();
}

const Map = @import("map.zig");
const Game = @import("game.zig");
const Dialog = @import("dialog.zig");

const util = @import("util.zig");
const consts = @import("consts.zig");

const rl = @import("raylib");
const std = @import("std");
