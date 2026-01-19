// from https://github.com/raylib-zig/raylib-zig

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        .opengl_version = rlz.OpenglVersion.gl_4_3,
    });
    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");

    const build_metadata = b.createModule(.{
        .root_source_file = b.path("build.zig.zon"),
        .target = target,
        .optimize = optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    if (optimize != .Debug) exe_mod.strip = true; // fixed wierd pdb bug when building windows

    exe_mod.addImport("build.zig.zon", build_metadata);
    exe_mod.addImport("raylib", raylib);
    exe_mod.addImport("raygui", raygui);

    const run_step = b.step("run", "Run the app");

    const exe = b.addExecutable(.{
        .name = "final",
        .root_module = exe_mod,
        .use_lld = !((target.query.os_tag == .linux) or (target.query.os_tag == null)), // https://github.com/raylib-zig/raylib-zig/issues/219#issuecomment-2708936845
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    run_step.dependOn(&run_cmd.step);
}

const std = @import("std");
const rlz = @import("raylib_zig");
