#version 430

#define screen_width 640
#define screen_height 480

#define nothing 0
#define rock 1
#define packed_sand 2
#define loose_sand 3
#define shifty_sand 4
#define lava 5
#define wood 6
#define burning_wood 7
#define lava_source 8

#define mask_type 0x1F

#define tile_size 16

layout (local_size_x = tile_size, local_size_y = tile_size, local_size_z = 1) in;

layout(std430, binding = 1) buffer buffer_a_layout {
    uint buffer_a[];
};
layout(std430, binding = 2) buffer buffer_b_layout {
    uint buffer_b[];
};

layout(location = 0) uniform uint time;

#define claimIfAvailable(x, y) (atomicCompSwap(buffer_b[(x) + screen_width * (y)], 0, 1) == 0)
#define unclaim(x, y) buffer_b[(x) + screen_width * (y)] = 0

#define get(x, y) (((x) >= screen_width) ? 0 : \
    (((x) < 0) ? 0 : \
     (((y) >= screen_height) ? 0 : \
      ((y < 0) ? 0 : buffer_a[(x) + screen_width * (y)]))))
#define set(x, y, value) if ( \
    ((x) >= 0) && ((x) <= (screen_width - 1)) \
    && ((y) >= 0) && ((y) <= (screen_height - 1))) buffer_a[(x) + screen_width * (y)] = value

// main update function for sand; can move into empty space or lava
#define fallTo(x, y) if ((((get((x), (y)) & mask_type) == nothing) || ((get((x), (y)) & mask_type) == lava) || ((get((x), (y)) & mask_type) == lava_source)) && claimIfAvailable(x, y)) { \
    set(x0, y0, 0); \
    if ((get((x), (y)) & mask_type) == nothing) set((x), (y), current); \
    break; \
}
// burning wood can only burn wood
// race conditions don't matter here
#define burnTo(x, y) if ((get((x), (y)) & mask_type) == wood) { \
    set(x0, y0, 0); \
    set((x), (y), current); \
    break; \
}
// main update function for sand; can move into empty space or lava
#define flowTo(x, y) if (( \
    ((get((x), (y)) & mask_type) != rock) \
    && ((get((x), (y)) & mask_type) != packed_sand) \
    && ((get((x), (y)) & mask_type) != shifty_sand) \
    && ((get((x), (y)) & mask_type) != lava) \
    && ((get((x), (y)) & mask_type) != lava_source) \
) && claimIfAvailable(x, y)) { \
    if ((get(x0, y0) & mask_type) != lava_source) set(x0, y0, 0); \
    set((x), (y), (current & ~mask_type) | lava); \
    break; \
}

// "gold noise"
const float phi = 1.61803398874989484820459;
float rand(vec2 xy, float seed) {
    return fract(tan(distance(xy * phi, xy) * seed) * xy.x);
}

const uint block_size = screen_width * tile_size;
void main() {
    int x0 = int(gl_GlobalInvocationID.x);
    int y0 = int(gl_GlobalInvocationID.y);
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

    float r = rand(vec2(x0, y0), 67 * float(time));
    int bias = (int(time % 2) * 2) - 1; // switch falling direcion each frame so piles aren't lopsided
    int random = (int(round(r)) * 2) - 1;
    switch (type) {
        case loose_sand:
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
        case lava_source:
        case lava:
            flowTo(x0, y0 + 1); // straight down
            flowTo(x0 + random, y0); // left/right
            flowTo(x0 - random, y0); // opposite of above
            flowTo(x0 + random, y0 + 1); // left/right + down
            flowTo(x0 - random, y0 + 1); // opposite of above
            break;
        case shifty_sand:
            if (
                ((get(x0 + 1, y0) & mask_type) == loose_sand)
                || ((get(x0 - 1, y0) & mask_type) == loose_sand)
                || ((get(x0, y0 + 1) & mask_type) == loose_sand)
                || ((get(x0, y0 - 1) & mask_type) == loose_sand)
            ) set(x0, y0, (current & ~mask_type) | loose_sand);
            break;
    }

    unclaim(x0, y0);
}
