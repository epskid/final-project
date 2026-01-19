// miscellanious utility functions

pub inline fn asf32(i: anytype) f32 {
    // because casting is super verbose in zig
    return @as(f32, @floatFromInt(i));
}

pub inline fn getScale() f32 {
    // get scale of rendered output to window size
    const min = @min(asf32(rl.getScreenWidth()) / consts.width, asf32(rl.getScreenHeight()) / consts.height);

    return if (Settings.fractional_scaling) min else @floor(min);
}

pub inline fn mkTileHitboxAt(pos: rl.Vector2) rl.Rectangle {
    return .init(
        pos.x,
        pos.y,
        consts.tile_size,
        consts.tile_size,
    );
}

pub inline fn skinHitbox(hitbox: rl.Rectangle) rl.Rectangle {
    return .init(
        hitbox.x + consts.skin_width,
        hitbox.y + consts.skin_width,
        hitbox.width - (consts.skin_width * 2),
        hitbox.height - (consts.skin_width * 2),
    );
}

inline fn mkHitbox(pos: rl.Vector2, hitbox: rl.Rectangle) rl.Rectangle {
    // utility function for use within another utility function
    return .init(
        hitbox.x + pos.x,
        hitbox.y + pos.y,
        hitbox.width,
        hitbox.height,
    );
}

pub const MoveAndCollideResult = struct {
    grounded: bool,
};

pub inline fn moveAndCollide(position: *rl.Vector2, velocity: *rl.Vector2, hitbox_with_skin: rl.Rectangle, map: *const Map) MoveAndCollideResult {
    // update position and velocity based on collisions and return some helpful data

    const hitbox: rl.Rectangle = skinHitbox(hitbox_with_skin);

    const dt = rl.getFrameTime();
    const dv_max = velocity.scale(dt); // get maximum displacement allowed
    const step = velocity.normalize(); // get a unit vector in the direction of velocity for step sizing

    var grounded = false;

    // find maximum change in y-direction
    var dy: f32 = 0;
    // take big steps until a collision or we exceed maximum movement
    while ((dy < dv_max.y) and !map.isColliding(mkHitbox(position.add(.init(0, dy)), hitbox))) dy += step.y;
    // clamp to max step
    if (dy >= dv_max.y) dy = dv_max.y;
    // back up until there are no more collisions
    while (map.isColliding(mkHitbox(position.add(.init(0, dy)), hitbox))) {
        dy -= step.y * dt;
        velocity.y = 0; // we've hit something, stop y-movement
        if (step.y > 0) {
            grounded = true; // if we were moving down before, the collision must be with the ground
        }
    }

    // apply y displacement
    position.y += dy;

    // same thing for x
    var dx: f32 = 0;
    while ((dx < dv_max.x) and !map.isColliding(mkHitbox(position.add(.init(dx, 0)), hitbox))) dx += step.x;
    if (dx >= dv_max.x) {
        dx = dv_max.x;
    }
    while (map.isColliding(mkHitbox(position.add(.init(dx, 0)), hitbox))) {
        dx -= step.x * dt;
        velocity.x = 0;
    }

    position.x += dx;

    return .{
        .grounded = grounded,
    };
}

pub inline fn texFromImg(file: [:0]const u8) !rl.Texture2D {
    const img = try rl.loadImage(file);
    defer rl.unloadImage(img);
    return try rl.loadTextureFromImage(img);
}

pub inline fn button(bounds: rl.Rectangle, text: [:0]const u8) bool {
    const result = rg.button(bounds, text);
    if (result) {
        rl.stopSound(assets.ui_sound);
        rl.playSound(assets.ui_sound);
    }
    return result;
}

pub fn drawText(text: [:0]const u8, x: i32, y: i32, size: i32, color: rl.Color) void {
    rl.drawTextEx(assets.font, text, .init(asf32(x), asf32(y)), asf32(size), 1, color);
}

pub fn measureText(text: [:0]const u8, size: i32) i32 {
    return @intFromFloat(rl.measureTextEx(assets.font, text, asf32(size), 1).x);
}

pub fn LowpassFilter(comptime frequency_hz: f32) type {
    return struct {
        var low = [_]f32{ 0.0, 0.0 };
        var cutoff = frequency_hz / 44100;

        // https://github.com/raysan5/raylib/blob/master/examples/audio/audio_stream_effects.c
        pub fn process(buffer: ?*anyopaque, len: c_uint) callconv(.c) void {
            var buffer_data: [*]f32 = @ptrCast(@alignCast(buffer orelse return));

            const k = cutoff / (cutoff + 0.1591549431); // RC filter formula
            for (0..len) |i_half| {
                const i = i_half * 2;

                const l = buffer_data[i];
                const r = buffer_data[i + 1];

                low[0] += k * (l - low[0]);
                low[1] += k * (r - low[1]);
                buffer_data[i] = low[0];
                buffer_data[i + 1] = low[1];
            }
        }
    };
}

pub fn toggleFullscreen() void {
    if (!rl.isWindowFullscreen()) {
        const mon = rl.getCurrentMonitor();
        const mon_w = rl.getMonitorWidth(mon);
        const mon_h = rl.getMonitorHeight(mon);
        rl.setWindowSize(mon_w, mon_h);
    }
    rl.toggleFullscreen();
}

const Map = @import("map.zig");
const Settings = @import("settings.zig");

const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
const rg = @import("raygui");
