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
#define shift_color 5

in vec2 fragTexCoord;
out vec4 finalColor;

layout(std430, binding = 1) readonly buffer buffer_a_layout {
    uint buffer_a[];
};

layout(location = 1) uniform float time;
layout(location = 2) uniform float vignette_radius;
const float blur = 0.1;

const float phi = 1.61803398874989484820459;
float rand(vec2 xy, float seed) {
    return fract(tan(distance(xy * phi, xy) * seed) * xy.x);
}

vec4 vignette(vec4 color) {
    return mix(
        color,
        vec4(color.rgb, 0.5),
        smoothstep(vignette_radius, vignette_radius + blur, distance(fragTexCoord, vec2(0.5, 0.5)))
    );
}

void main()
{
    ivec2 coords = ivec2(fragTexCoord * vec2(screen_width, screen_height));
    uint particle = buffer_a[coords.x + coords.y * screen_width];

    // see particle spec fo explaination of bit antics
    uint type = particle & mask_type;

    if (type == nothing) {
        finalColor = vec4(0, 0, 0, 0);
    } else {
        uint particle_color = particle >> shift_color;

        // unpack color from 24-bit integer
        vec3 rgb = vec3(
            (particle_color & 0xFF0000) >> 16,
            (particle_color & 0x00FF00) >> 8,
            particle_color & 0x0000FF
        ) / 255.0; // map color to float

        if (type == loose_sand) {
            // overlay some noise to differentiate loose and packed sand
            rgb *= 0.75 + (0.25 * rand(vec2(coords), time));
        }
        if ((type == lava) || (type == lava_source)) {
            // overlay some noise on the lava
            rgb *= 0.75 + (0.25 * rand(vec2(coords), time / 10));
        }

        finalColor = vec4(rgb, 1);
    }

    // https://github.com/Apfelstrudel-Technologien/raylibVignette
    finalColor = vignette(finalColor);
}
