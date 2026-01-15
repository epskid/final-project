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

#define tile_size 16

layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(std430, binding = 1) buffer buffer_a_layout {
    uint buffer_a[];
};

layout(location = 0) uniform uint time;

#define get(x, y) buffer_a[(x) + screen_width * (y)]
#define set(x, y, value) buffer_a[(x) + screen_width * (y)] = value

// main update function for sand; can move into empty space or lava
#define fallTo(x, y) if ((y >= (screen_height - 1)) || (((get((x), (y)) & mask_type) == nothing) || ((get((x), (y)) & mask_type) == lava))) { \
    set(x0, y0, 0); \
    set((x), (y), current); \
    break; \
}
// burning wood can only burn itself
#define burnTo(x, y) if ((get((x), (y)) & mask_type) == wood) { \
    set(x0, y0, 0); \
    set((x), (y), current); \
    break; \
}
// main update function for sand; can move into empty space or lava
#define flowTo(x, y) if ((y >= (screen_height - 1)) \
    || ( \
        ((get((x), (y)) & mask_type) != rock) \
        && ((get((x), (y)) & mask_type) != packed_sand) \
        && ((get((x), (y)) & mask_type) != lava) \
    ) \
) { \
    if (r < 0.66) set(x0, y0, 0); \
    set((x), (y), current); \
    break; \
}

// "gold noise"
// a simple random noise function for glsl
// https://stackoverflow.com/a/28095165
const float phi = 1.61803398874989484820459;
float rand(vec2 xy, float seed) {
    return fract(tan(distance(xy * phi, xy) * seed) * xy.x);
}

void main() {
    uint x0 = gl_GlobalInvocationID.x;
    uint y0 = gl_GlobalInvocationID.y;
    uint current = get(x0, y0); // see particle spec for bit layout
    uint type = current & mask_type;

    switch (type) {
        // these are fixed in place, so computation can be skipped
        case nothing:
        case rock:
        case packed_sand:
        case wood:
            return;
    }

    // race condition solution -- update alternating checkboards each tick
    if ((x0 + y0) % 2 != (time % 2)) return;

    float r = rand(vec2(x0, y0), 67 * float(time));
    int bias = (int(time % 2) * 2) - 1; // switch falling direcion each frame so piles aren't lopsided
    int random = (int(round(r)) * 2) - 1;
    switch (type) {
        case sand:
            fallTo(x0, y0 + 1); // straight down
            fallTo(x0 + bias, y0 + 1); // down left/right
            fallTo(x0 - bias, y0 + 1); // down opposite of above
            break;
        case burning_wood:
            // 5% chance to decay each frame
            if (r < 0.05) {
                set(x0, y0, 0);
                break;
            }

            // 10% chance to burn
            if (r > 0.9) {
                burnTo(x0 - bias, y0);
                burnTo(x0 + bias, y0);
                burnTo(x0, y0 - random);
                burnTo(x0, y0 + random);
            }

            // otherwise behave like anti-gravity sand
            fallTo(x0, y0 + random);
            fallTo(x0, y0 - random);
            fallTo(x0 + random, y0 - random);
            fallTo(x0 - random, y0 + random);
            break;
        case lava:
            if (r < 0.7) {
                flowTo(x0, y0 + 1); // straight down
                flowTo(x0 + random, y0); // down left/right
                flowTo(x0 - random, y0); // down opposite of above
            }
            break;
    }
}
