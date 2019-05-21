#version 450
#extension GL_ARB_shader_draw_parameters : require

#include "util/defines.glsl"
#include "render/blockRender_common.glsl"
#include "util/hash.glsl"

#define TEXTURING ((!DEPTH_ONLY) || (ALPHA_CHANNEL == ALPHA_CHANNEL_ALPHA_TEST))

layout(location = 0) uniform mat4 viewMatrix;
layout(location = 1) uniform float worldTime;

layout(location = 0) in vec3 pos_;
layout(location = 1) in uint uvPacked;

layout(location = 2) in uint layerI1;
layout(location = 3) in uint layerI2;

layout(binding = 0, std430) buffer Offsets {
	vec3[] offsets;
};

uniform vec3 coordinatesOffset;

#if TEXTURING
	flat out uint layer_;
	UV_QUALIFIERS out vec2 uv_;
#endif

#if !DEPTH_ONLY
	layout(location = 4) in float normX;
	layout(location = 5) in float normY;
	layout(location = 6) in float normZ;

	flat out vec3 norm_;
#endif

#if SURFACE_DATA == SURFACE_DATA_AGGREGATION
	flat out vec3 aggregationColor_;
#endif

// This is 0 - 2 instead of 0 - 2PI
float sinAlternative(float progress) {
	const float prog = mod(progress, 4);
	const float prog2 = prog * prog;
 	return 2.6666 * prog - 2 * prog2 + 0.3333 * prog * prog2;
}

void main() {
	const vec3 pos = pos_ + offsets[gl_DrawIDARB];

	const vec2 uv = vec2(float(uvPacked & 0xf), float((uvPacked >> 4) & 0xf));

	#if WAVING == WAVING_WIND_TOP
		// UVI y - zero is always top side, 1 is always bottom side
		const float wavingEffect = (uv.y == 0) ? 0.3 : 0;

		const vec2 relPos = (pos.xy - coordinatesOffset.xy) / 8;
		const float sn = sinAlternative(worldTime * 0.3 + relPos.x + relPos.y);

		gl_Position = viewMatrix * vec4(pos.xy + sn * wavingEffect, pos.z, 1);

	#elif WAVING == WAVING_WIND_WHOLE
		const vec3 relPos = pos - coordinatesOffset;
		const float sn = sinAlternative(worldTime * 0.5 + (relPos.x + relPos.y + relPos.z) * 0.2) * 0.1;
		gl_Position = viewMatrix * vec4(pos + sn, 1);

	#elif (WAVING == WAVING_LIQUID_SURFACE) || (WAVING == WAVING_LIQUID_TOP)
		#if WAVING == WAVING_LIQUID_TOP
			const float wavingEffect = (uv.y == 0) ? 1 : 0;
		#else
			const float wavingEffect = 1;
		#endif

		// We cannot divide by less than 8 because of the face aggregation
		const vec2 coords = (pos.xy - coordinatesOffset.xy) / 8;
		const vec2 prog = fract(coords);
		const ivec2 coordsI = ivec2(floor(coords));

		const float c1 = worldTime * 0.5;
		const float c2 = 0.01;

		const float val1 = sinAlternative(c1 + float(hash(0x315512, coordsI) & 0xfff) * c2);
		const float val2 = sinAlternative(c1 + float(hash(0x315512, coordsI + ivec2(1,0)) & 0xfff) * c2);
		const float val3 = sinAlternative(c1 + float(hash(0x315512, coordsI + ivec2(0,1)) & 0xfff) * c2);
		const float val4 = sinAlternative(c1 + float(hash(0x315512, coordsI + ivec2(1,1)) & 0xfff) * c2);

		const vec2 interpolation1 = mix(vec2(val1, val3), vec2(val2, val4), prog.x);
		const float val = mix(interpolation1.x, interpolation1.y, prog.y);

		const float sn = (val * 0.3 - 0.3) * wavingEffect;
		gl_Position = viewMatrix * vec4(pos.xy, pos.z + sn, 1);

	#else
		gl_Position = viewMatrix * vec4(pos, 1);

	#endif

	#if SURFACE_DATA == SURFACE_DATA_AGGREGATION
		const uint hash1 = hash(0x321f1, ivec3(pos_));
		const uint hash2 = hash(hash1);
		const uint hash3 = hash(hash2);
		aggregationColor_ = vec3(uvec3(hash1, hash2, hash3) & 7) / 7;
	#endif

	#if TEXTURING
		layer_ = layerI1 | (layerI2 << 8);
		uv_ = uv;
	#endif

	#if !DEPTH_ONLY
		norm_ = vec3(normX, normY, normZ);
	#endif
}