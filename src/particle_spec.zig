// all particle types
// mirrored in the compute shaders with consecutive numbers
// represented with a 5-bit integer for 32 possible particle types
pub const ParticleType = enum(u5) {
    none,
    rock,
    packed_sand,
    loose_sand,
    shifty_sand,
    lava,
    wood,
    burning_wood,
    lava_source,

    // pseudo particle types -- means something different tile-wise, but are made up of other particle types
    grate,
    barrier,
};

// the "logic" type for the compute shaders
pub const Particle = struct {
    pub const GLSLRepr = packed struct(u32) {
        // when this is packed into a 32 bit integer, it looks a "bit" (heh) like this:
        // 0b0000_0000_0000_0000_0000_0000_0000_0000
        //   |---------------------------| |-||----|
        //          color information       |  type
        //                                direction
        // 
        // color information is stored like an rgb color in hex format (0xFFFFFF is white, 0xFF0000 is red, etc.)
        // direction holds 8 possible directions the particle may want to go (top-left, top, etc.)
        // and type is the number corresponding to the ParticleType enum above
        // this information can be unpacked via bit manipulation, for example:
        // - mask the first 5 bits to get the type:
        //      repr & 0b11111 = type
        //      repr & 0x1F    = type
        // - mask and shift for direction:
        //      (repr & 0b11100000) >> 5 = direction
        //      (repr & 0xE0)       >> 5 = direction
        // and soforth.

        type: u5,
        color: u24,
        direction: u3,

        // convert from the 32 bit integer to the structure
        pub fn unpack(glsl_repr: GLSLRepr) Particle {
            @setRuntimeSafety(false); // bounds-checking causes significant performance issues here
            return .{
                .type = @enumFromInt(glsl_repr.type),
                .color = .init(
                    @intCast((glsl_repr.color & 0xFF0000) >> 16),
                    @intCast((glsl_repr.color & 0x00FF00) >> 8),
                    @intCast(glsl_repr.color & 0x00FF),
                    0xFF,
                ),
                .direction = glsl_repr.direction,
            };
        }
    };

    type: ParticleType,
    color: rl.Color,
    direction: u3 = 0,

    pub fn pack(particle: Particle) GLSLRepr {
        return .{
            .type = @intFromEnum(particle.type),
            .color = @intCast((@as(u32, @bitCast(particle.color.toInt())) & 0xFFFFFF00) >> 8),
            .direction = particle.direction,
        };
    }
};

// the command type
// structs must be "extern" to use in GLSL
pub const Command = extern struct {
    func: packed struct(u32) {
        // looks like:
        // 0b0000_0000_0000_0000_0000_0000_0000_0000
        //   |------------| |------------| |-------|
        //         y              x         command
        flag: enum(u8) {
            place,
            explode,
            walked,
        },
        x: u12,
        y: u12,
    },
    // the parameter to the function you're calling
    // i.e. the packed particle to place
    parameter: u32,
};

// the compute shader with all the parameters defined here
pub const Simulation = cs.RenderedComputeShader(
    Particle.GLSLRepr,
    Command,
    consts.width_tiles,
    consts.height_tiles,
    consts.width * consts.height,
    256,
);

const cs = @import("compute_shaders.zig");
const consts = @import("consts.zig");

const rl = @import("raylib");
const std = @import("std");
