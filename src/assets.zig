// global asset loader

pub var font: rl.Font = undefined;

pub var player: rl.Texture2D = undefined;
pub var gun: rl.Texture2D = undefined;
pub var artifacts: rl.Texture2D = undefined;
pub var tileset: rl.Image = undefined;

pub var outside: rl.Texture2D = undefined;
pub var inside: rl.Texture2D = undefined;

pub var ui_sound: rl.Sound = undefined;
pub var volume_sound: rl.Sound = undefined;
pub var shoot_sound: rl.Sound = undefined;
pub var explosion_sound: rl.Sound = undefined;
pub var talk_sound: rl.Sound = undefined;
pub var artifact_sound: rl.Sound = undefined;

pub var menu_music: rl.Music = undefined;
pub var main_music: rl.Music = undefined;

pub fn load() !void {
    font = try rl.loadFontEx("resources/font/PixelIntv.otf", 12, null);
    rg.setFont(font);
    rg.setStyle(.default, .{ .default = .text_size }, 12);

    player = try util.texFromImg("resources/images/sprites/player.png");
    gun = try util.texFromImg("resources/images/sprites/gun.png");
    artifacts = try util.texFromImg("resources/images/sheets/artifacts.png");
    tileset = try rl.loadImage("resources/images/sheets/tileset.png");

    outside = try util.texFromImg("resources/images/backgrounds/start.png");
    inside = try util.texFromImg("resources/images/backgrounds/inside.png");

    ui_sound = try rl.loadSound("resources/sounds/sfx/select.ogg");
    volume_sound = try rl.loadSound("resources/sounds/sfx/volume.ogg");
    shoot_sound = try rl.loadSound("resources/sound/sfx/shoot.ogg");
    explosion_sound = try rl.loadSound("resources/sounds/sfx/explosion.ogg");
    talk_sound = try rl.loadSound("resources/sounds/sfx/talk.ogg");
    artifact_sound = try rl.loadSound("resources/sounds/sfx/artifact.ogg");

    menu_music = try rl.loadMusicStream("resources/sounds/music/menu.ogg");
    main_music = try rl.loadMusicStream("resources/sounds/music/main.ogg");
    main_music.looping = false;
}

pub fn unload() void {
    rl.unloadFont(font);

    rl.unloadTexture(player);
    rl.unloadTexture(gun);
    rl.unloadTexture(artifacts);
    rl.unloadImage(tileset);

    rl.unloadSound(ui_sound);
    rl.unloadSound(volume_sound);
    rl.unloadSound(shoot_sound);
    rl.unloadSound(explosion_sound);
    rl.unloadSound(talk_sound);
    rl.unloadSound(artifact_sound);

    rl.unloadMusicStream(menu_music);
    rl.unloadMusicStream(main_music);
}

const Player = @import("player.zig");

const util = @import("util.zig");

const rl = @import("raylib");
const rg = @import("raygui");
