// global asset loader

pub var player: rl.Texture2D = undefined;
pub var gun: rl.Texture2D = undefined;
pub var artifacts: rl.Texture2D = undefined;
pub var tileset: rl.Image = undefined;

pub var start: rl.Texture2D = undefined;
pub var inside: rl.Texture2D = undefined;

pub var ui_sound: rl.Sound = undefined;
pub var volume_sound: rl.Sound = undefined;
pub var menu_music: rl.Music = undefined;
pub var main_music: rl.Music = undefined;

pub fn load() !void {
    player = try util.texFromImg("resources/sprites/player.png");
    gun = try util.texFromImg("resources/sprites/gun.png");
    artifacts = try util.texFromImg("resources/sprites/artifacts.png");
    tileset = try rl.loadImage("resources/tileset.png");

    start = try util.texFromImg("resources/sprites/start.png");
    inside = try util.texFromImg("resources/sprites/inside.png");

    ui_sound = try rl.loadSound("resources/sound/select.ogg");
    volume_sound = try rl.loadSound("resources/sound/volume.wav");
    menu_music = try rl.loadMusicStream("resources/sound/menu.ogg");
    main_music = try rl.loadMusicStream("resources/sound/main.ogg");
    main_music.looping = false;
}

pub fn unload() void {
    rl.unloadTexture(player);
    rl.unloadTexture(gun);
    rl.unloadTexture(artifacts);
    rl.unloadImage(tileset);

    rl.unloadSound(ui_sound);
    rl.unloadSound(volume_sound);
    rl.unloadMusicStream(menu_music);
    rl.unloadMusicStream(main_music);
}

const util = @import("util.zig");

const rl = @import("raylib");
