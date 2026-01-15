#version 430

#define screen_width 640
#define screen_height 480

#define nothing 0
#define rock 1
#define packed_sand 2
#define sand 3
#define lava 4
#define wood 5
#define burning_wood 6

#define mask_type 0x1F
#define shift_color 5

#define mask_flag 0xFF
#define mask_x 0x000FFF00
#define shift_x 8
#define mask_y 0xFFF00000
#define shift_y 20

#define place 0
#define explode 1

struct Command {
    uint func;
    uint parameter;
};

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 1) buffer buffer_a_layout {
    uint buffer_a[];
};

layout(std430, binding = 3) readonly restrict buffer buffer_commands_layout {
    uint count;
    Command commands[];
};

// see logic.glsl for attribution
const float phi = 1.61803398874989484820459;
float rand(vec2 xy, float seed) {
    return fract(tan(distance(xy * phi, xy) * seed) * xy.x);
}

void main() {
    Command cmd = commands[gl_GlobalInvocationID.x];

    // particle spec explains all this
    // it makes sense i swear
    uint flag = cmd.func & mask_flag;
    uint x = (cmd.func & mask_x) >> shift_x;
    uint y = (cmd.func & mask_y) >> shift_y;
    uint i = x + screen_width * y;
    switch (flag) {
        case place:
            buffer_a[i] = cmd.parameter;
            break;
        case explode:
            switch (buffer_a[i] & mask_type) {
                case packed_sand:
                    if (rand(vec2(x, y), 67) < 0.7) {
                        buffer_a[i] &= ~mask_type; // clear mask type
                        buffer_a[i] |= sand; // loosen packed sand
                    } else {
                        buffer_a[i] = 0; // clear about 30% of it
                    }
                    break;
                case wood:
                    buffer_a[i] = 0xC6C3B5 << shift_color; // nice ashy color
                    buffer_a[i] |= burning_wood; // burn the wood
                    break;
            }
            break;
    }
}
