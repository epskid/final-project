// the start menu
const Self = @This();

pub var should_close = false;

background: rl.Texture,
level_select: bool,
next_state: ?std.meta.Tag(s.State),
selected_level: ?usize,

pub fn init() !Self {
    return .{
        .background = try util.texFromImg("resources/sprites/background.png"),
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

    if (self.level_select) self.drawLevelSelect()
    else self.drawMain();
}

pub fn drawLevelSelect(self: *Self) void {
    var rect: rl.Rectangle = .init(16, 16, 256, 16);

    {
        _ = rg.label(rect, "LEVEL SELECT");

        rect.y += 16 + 4;
    }

    {
        if (rg.button(rect, "TUNNEL")) {
            self.selected_level = 0;
            self.next_state = .playing;
        }

        rect.y += 16 + 4;
    }

    {
        if (rg.button(rect, "TUNNEL... 2!")) {
            self.selected_level = 1;
            self.next_state = .playing;
        }

        rect.y += 16 + 4;
    }

    {
        if (rg.button(rect, "BACK")) {
            self.level_select = false;
        }

        rect.y += 16 + 4;
    }
}

pub fn drawMain(self: *Self) void {
    var rect: rl.Rectangle = .init(16, 16, 256, 16);

    {
        _ = rg.label(rect, "FINAL PROJECT");

        rect.y += 16 + 4;
    }

    {
        if (rg.button(rect, "PLAY")) {
            self.level_select = true;
        }

        rect.y += 16 + 4;
    }

    {
        if (rg.button(rect, "SETTINGS")) {
            self.next_state = .settings;
        }

        rect.y += 16 + 4;
    }

    {
        if (rg.button(rect, "CONTROLS")) {
            self.next_state = .controls;
        }

        rect.y += 16 + 4;
    }

    {
        if (rg.button(rect, "QUIT")) {
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
            .deinit = ns == .playing,
        };
    }

    return null;
}

pub fn deinit(self: *Self, _: std.mem.Allocator) void {
    rl.unloadTexture(self.background);
}

const s = @import("state.zig");
const util = @import("util.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
