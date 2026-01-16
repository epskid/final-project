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

const skin_width = 0.1;
pub inline fn moveAndCollide(position: *rl.Vector2, velocity: *rl.Vector2, hitbox_with_skin: rl.Rectangle, map: *const Map) MoveAndCollideResult {
    // update position and velocity based on collisions and return some helpful data

    const hitbox: rl.Rectangle = .init(
        hitbox_with_skin.x + skin_width,
        hitbox_with_skin.y + skin_width,
        hitbox_with_skin.width - (skin_width * 2),
        hitbox_with_skin.height - (skin_width * 2),
    );

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

const Map = @import("map.zig");
const Settings = @import("settings.zig");

const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
const rg = @import("raygui");
