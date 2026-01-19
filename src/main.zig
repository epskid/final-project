// entry point

pub fn main() !void {
    // intialize the allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer {
        // cool zig moment
        if (gpa.deinit() == .leak) {
            std.log.err("we leaked memory... whoops. it's okay though. the kernel will clean up and it will all be just fine.", .{});
        }
    }
    const allocator = gpa.allocator();

    // raylib settings
    rl.setConfigFlags(.{
        .window_resizable = true,
        .vsync_hint = true,
    });
    rl.initWindow(consts.width, consts.height, "FINAL PROJECT");
    defer rl.closeWindow();
    rl.setWindowMinSize(consts.width, consts.height);
    rl.setExitKey(.null);
    rl.setTargetFPS(60);
    util.toggleFullscreen();

    // load raygui style
    rg.loadStyle("resources/style.rgs");

    // raylib audio
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    // load assets
    try assets.load();
    defer assets.unload();

    // create the texture things are rendered to before post-processing and scaling
    var render = try rl.loadRenderTexture(consts.width, consts.height);
    defer render.unload();

    // initialize state
    var state: s.State = try .init(.splash, allocator);
    defer state.deinit(allocator);

    // initialize post-processing shader
    const pp = try rl.loadShader(null, "resources/shaders/post_processing.glsl");
    defer rl.unloadShader(pp);

    // main loop
    while (!rl.windowShouldClose() and !menu.should_close) {
        {
            // scale mouse coordinates to be inside screen space
            const scale = util.getScale();

            rl.setMouseOffset(
                @intFromFloat(((consts.width * scale) - util.asf32(rl.getScreenWidth())) / 2),
                @intFromFloat(((consts.height * scale) - util.asf32(rl.getScreenHeight())) / 2),
            );
            rl.setMouseScale(1 / scale, 1 / scale);
        }

        // tick everything
        try state.tick();

        {
            // render to the render texture

            render.begin();
            defer render.end();

            state.draw();

            if (Settings.show_fps) rl.drawFPS(0, 0);
        }

        // switch state
        if (try state.switchState(allocator)) |new_state| state = new_state;

        {
            // scale and process the texture

            rl.beginDrawing();
            defer rl.endDrawing();

            rl.beginShaderMode(pp);
            defer rl.endShaderMode();

            const scale = util.getScale();

            rl.clearBackground(.black);
            rl.drawTexturePro(
                render.texture,
                .init(
                    0.0,
                    0.0,
                    util.asf32(render.texture.width),
                    util.asf32(-render.texture.height),
                ),
                .init(
                    (util.asf32(rl.getScreenWidth()) - (util.asf32(consts.width) * scale)) * 0.5,
                    (util.asf32(rl.getScreenHeight()) - (util.asf32(consts.height) * scale)) * 0.5,
                    util.asf32(consts.width) * scale,
                    util.asf32(consts.height) * scale,
                ),
                .zero(),
                0.0,
                .white,
            );
        }
    }
}

const Settings = @import("settings.zig");

const s = @import("state.zig");
const menu = @import("menu.zig");
const util = @import("util.zig");
const consts = @import("consts.zig");
const assets = @import("assets.zig");

const rl = @import("raylib");
const rg = @import("raygui");
const std = @import("std");
