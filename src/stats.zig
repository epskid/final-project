const Self = @This();

tip_string: [:0]const u8,
score_quota_string: [:0]u8,
grade_string: [:0]u8,
deaths_string: [:0]u8,
send_back: bool,

fn getGrade(score: usize, quota: usize) u8 {
    const ratio = util.asf32(score) / util.asf32(quota);
    if (ratio > 1) return 'S';
    if (ratio > 0.8) return 'A';
    if (ratio > 0.7) return 'B';
    if (ratio > 0.6) return 'C';
    if (ratio > 0.4) return 'D';
    return 'F';
}

pub fn init(
    allocator: std.mem.Allocator,
    index: usize,
    score: usize,
    quota: usize,
    deaths: usize,
) !Self {
    const grade = getGrade(score, quota);
    if (grade != 'F') Menu.unlocked = index + 1;

    return .{
        .tip_string = if (grade == 'F') "GET A NON 'F' GRADE TO UNLOCK THE NEXT LEVEL" else "THE NEXT LEVEL IS AVAILABLE",
        .score_quota_string = try std.fmt.allocPrintSentinel(allocator, "SCORE/QUOTA: {}/{}", .{ score, quota }, 0),
        .grade_string = try std.fmt.allocPrintSentinel(allocator, "LETTER GRADE: {c}", .{grade}, 0),
        .deaths_string = try std.fmt.allocPrintSentinel(allocator, "USED: {}", .{deaths + 1}, 0),
        .send_back = false,
    };
}

pub fn tick(_: *Self) !void {
    if (!rl.isMusicStreamPlaying(assets.menu_music)) {
        rl.playMusicStream(assets.menu_music);
    }
    rl.updateMusicStream(assets.menu_music);
}

const font_size = 24;
pub fn draw(self: *Self) void {
    rl.drawTexture(assets.inside, 0, 0, .white);

    const sq_width = util.measureText(self.score_quota_string, font_size);
    const g_width = util.measureText(self.grade_string, font_size);
    const t_width = util.measureText(self.tip_string, font_size / 2);
    const d_width = util.measureText(self.deaths_string, font_size);

    util.drawText(
        self.score_quota_string,
        consts.width / 2 - @divFloor(sq_width, 2),
        consts.height / 2 - (3 * font_size) / 2,
        font_size,
        .white,
    );
    util.drawText(
        self.grade_string,
        consts.width / 2 - @divFloor(g_width, 2),
        consts.height / 2 - font_size / 2,
        font_size,
        .white,
    );
    util.drawText(
        self.tip_string,
        consts.width / 2 - @divFloor(t_width, 2),
        consts.height / 2 + font_size / 2,
        font_size / 2,
        .gray,
    );
    util.drawText(
        self.deaths_string,
        consts.width / 2 - @divFloor(d_width, 2),
        consts.height / 2 + (3 * font_size) / 2,
        font_size,
        .white,
    );

    if (util.button(.init(16, consts.height - 16 - 16, 256, 16), "BACK TO MENU")) {
        self.send_back = true;
    }
}

pub fn getNewState(self: *const Self) ?s.NewStateInfo {
    if (self.send_back) {
        return .{
            .new_state = .{
                .needs_init = .menu,
            },
            .deinit = true,
        };
    }

    return null;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.score_quota_string);
    allocator.free(self.grade_string);
    allocator.free(self.deaths_string);
}

const Menu = @import("menu.zig");

const s = @import("state.zig");
const util = @import("util.zig");
const assets = @import("assets.zig");
const consts = @import("consts.zig");

const rl = @import("raylib");
const std = @import("std");
