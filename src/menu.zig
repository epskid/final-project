// the start menu
const Self = @This();

pub var should_close = false;

background: rl.Texture,
level_select: bool,
next_state: ?std.meta.Tag(s.State),
selected_level: ?usize,

pub fn init() !Self {
    return .{
        .background = try util.texFromImg("resources/images/backgrounds/menu.png"),
        .level_select = false,
        .next_state = null,
        .selected_level = null,
    };
}

pub fn tick(self: *Self) !void {
    if (!rl.isMusicStreamPlaying(assets.menu_music)) {
        rl.playMusicStream(assets.menu_music);
    }
    rl.updateMusicStream(assets.menu_music);

    self.next_state = null;
}

pub fn draw(self: *Self) void {
    rl.drawTexture(
        self.background,
        0,
        0,
        .white,
    );

    if (self.level_select) self.drawLevelSelect() else self.drawMain();
}

pub var unlocked: usize = 0;
const levels = [_][:0]const u8{ "PILOT", "TUNNEL", "SHIFTY" };
pub fn drawLevelSelect(self: *Self) void {
    var rect: rl.Rectangle = .init(16, 16, 256, 16);

    util.drawText("FINAL-PROJECT/MISSION-SELECT", 16, 16, 24, .white);
    rect.y += 24 + 4;

    for (0.., levels) |i, name| {
        // hold down backslash to acess all levels (secret cheat code!!)
        if (!rl.isKeyDown(.backslash) and (i > unlocked)) rg.disable();

        if (util.button(rect, name)) {
            self.selected_level = i;
            self.next_state = .playing;
        }

        rect.y += 16 + 4;
    }

    if ((unlocked >= levels.len) and util.button(rect, "CLOSING")) {
        self.next_state = .ending;
    }

    rect.y += 16 + 4;

    rg.enable();

    {
        if (util.button(rect, "BACK")) {
            self.level_select = false;
        }

        rect.y += 16 + 4;
    }
}

const version_string = std.fmt.comptimePrint("v{s} (Zig v{s})", .{
    @import("build.zig.zon").version,
    @import("builtin").zig_version_string,
});
pub fn drawMain(self: *Self) void {
    var rect: rl.Rectangle = .init(16, 16, 256, 16);

    util.drawText("FINAL-PROJECT", 16, 16, 24, .white);
    util.drawText(version_string, consts.width - util.measureText(version_string, 12), 0, 12, .gray);

    rect.y += 24 + 4;

    {
        if (util.button(rect, "PLAY")) {
            self.level_select = true;
        }

        rect.y += 16 + 4;
    }

    {
        if (util.button(rect, "SETTINGS")) {
            self.next_state = .settings;
        }

        rect.y += 16 + 4;
    }

    {
        if (util.button(rect, "CONTROLS")) {
            self.next_state = .controls;
        }

        rect.y += 16 + 4;
    }

    {
        if (util.button(rect, "CREDITS")) {
            self.next_state = .credits;
        }

        rect.y += 16 + 4;
    }

    {
        if (util.button(rect, "QUIT")) {
            should_close = true;
        }

        rect.y += 16 + 4;
    }
}

pub fn getNewState(self: *const Self) ?s.NewStateInfo {
    if (self.next_state) |ns| {
        rl.stopMusicStream(assets.menu_music);
        rl.updateMusicStream(assets.menu_music);
        return .{
            .new_state = .{
                .needs_init = ns,
            },
            .deinit = (ns == .playing) or (ns == .credits) or (ns == .ending),
        };
    }

    return null;
}

pub fn deinit(self: *Self, _: std.mem.Allocator) void {
    rl.unloadTexture(self.background);
}

const s = @import("state.zig");
const util = @import("util.zig");
const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
