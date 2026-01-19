#version 430

// CRT shader from libretro: https://github.com/libretro/glsl-shaders/blob/master/crt/shaders/crt-pi.glsl
#define SCANLINES
#define MASK_TYPE 1
#define CURVATURE_X 0.10
#define CURVATURE_Y 0.25
#define MASK_BRIGHTNESS 0.70
#define SCANLINE_WEIGHT 6
#define SCANLINE_GAP_BRIGHTNESS 0.12
#define BLOOM_FACTOR 1.5
#define INPUT_GAMMA 2.4
#define OUTPUT_GAMMA 2.2

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

layout (location = 67) uniform vec2 TextureSize;
layout (location = 68) uniform float time;

out vec4 finalColor;

float CalcScanLineWeight(float dist)
{
	return max(1.0-dist*dist*SCANLINE_WEIGHT, SCANLINE_GAP_BRIGHTNESS);
}

float CalcScanLine(float dy)
{
	float scanLineWeight = CalcScanLineWeight(dy);
	return scanLineWeight;
}

void crtMain()
{
	vec2 texcoord = fragTexCoord;
	{
		vec2 texcoordInPixels = texcoord * TextureSize;
#if defined(SHARPER)
		vec2 tempCoord = floor(texcoordInPixels) + 0.5;
		vec2 coord = tempCoord / TextureSize;
		vec2 deltas = texcoordInPixels - tempCoord;
		float scanLineWeight = CalcScanLine(deltas.y);
		vec2 signs = sign(deltas);
		deltas.x *= 2.0;
		deltas = deltas * deltas;
		deltas.y = deltas.y * deltas.y;
		deltas.x *= 0.5;
		deltas.y *= 8.0;
		deltas /= TextureSize;
		deltas *= signs;
		vec2 tc = coord + deltas;
#else
		float tempY = floor(texcoordInPixels.y) + 0.5;
		float yCoord = tempY / TextureSize.y;
		float dy = texcoordInPixels.y - tempY;
		float scanLineWeight = CalcScanLine(dy);
		float signY = sign(dy);
		dy = dy * dy;
		dy = dy * dy;
		dy *= 8.0;
		dy /= TextureSize.y;
		dy *= signY;
		vec2 tc = vec2(texcoord.x, yCoord + dy);
#endif

		vec3 colour = texture(texture0, tc).rgb;

#if defined(GAMMA)
#if defined(FAKE_GAMMA)
		colour = colour * colour;
#else
		colour = pow(colour, vec3(INPUT_GAMMA));
#endif
#endif

// keep mask inside GAMMA to gain some brightness after gamma out
#if MASK_TYPE == 0
		finalColor = vec4(colour, 1.0);
#else
#if MASK_TYPE == 1
		float whichMask = fract((gl_FragCoord.x*1.0001) * 0.5);
		vec3 mask;
		if (whichMask < 0.5)
			mask = vec3(MASK_BRIGHTNESS, 1.0, MASK_BRIGHTNESS);
		else
			mask = vec3(1.0, MASK_BRIGHTNESS, 1.0);
#elif MASK_TYPE == 2
		float whichMask = fract((gl_FragCoord.x*1.0001) * 0.3333333);
		vec3 mask = vec3(MASK_BRIGHTNESS, MASK_BRIGHTNESS, MASK_BRIGHTNESS);
		if (whichMask < 0.3333333)
			mask.x = 1.0;
		else if (whichMask < 0.6666666)
			mask.y = 1.0;
		else
			mask.z = 1.0;
#endif

#if defined(GAMMA)
	#if defined(FAKE_GAMMA)
		colour = sqrt(colour);
	#else
		colour = pow(colour, vec3(1.0/OUTPUT_GAMMA));
	#endif
	
#endif
// Leave scanlines out of GAMMA, 
// as it messes them (fract scanlines are TOO sensitive 
// and should be 0.0 to 1.0 range)  
#if defined(SCANLINES)
		scanLineWeight *= BLOOM_FACTOR;
		colour *= scanLineWeight;
#endif

		finalColor = vec4(colour * mask, 1.0);
#endif
	}
}

void main()
{
    // apply crt effect
    crtMain();

    finalColor = vec4(
        finalColor.r,
        // apply a blue(and green)-light filter to make colors warmer
        finalColor.g * 0.7,
        finalColor.b * 0.5,
        finalColor.a
    );
}
