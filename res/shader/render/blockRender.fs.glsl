#version 430

#include "util/defines.glsl"
#include "render/blockRender_common.glsl"
#include "postprocessing/common.glsl"

#define TEXTURING (!DEPTH_ONLY || (ALPHA_CHANNEL == ALPHA_CHANNEL_ALPHA_TEST))
#define USES_ALPHA (ALPHA_CHANNEL == ALPHA_CHANNEL_TRANSPARENCY || ALPHA_CHANNEL == ALPHA_CHANNEL_ALPHA_TEST)

#if ALPHA_CHANNEL != ALPHA_CHANNEL_ALPHA_TEST && ALPHA_CHANNEL != ALPHA_CHANNEL_TRANSPARENCY
	layout(early_fragment_tests) in;
#endif

#if TEXTURING
	layout(binding = 1) uniform sampler2DArray tex;
	uniform vec2 uvScaling;

	flat in uint layer_;
	UV_QUALIFIERS in vec2 uv_;
#endif

#if SURFACE_DATA == SURFACE_DATA_AGGREGATION
	flat in vec3 aggregationColor_;
#endif

#if NEAR_DEPTH_TEST
	layout(binding = 0) uniform sampler2DX nearDepthTestTex;
#endif

#if !DEPTH_ONLY 
	flat in vec3 norm_;

	layout(location = 0) out vec4 color;
	layout(location = 1) out vec4 normal;
#endif

#if DEPTH_ONLY
void main() {
	#if ALPHA_CHANNEL == ALPHA_CHANNEL_ALPHA_TEST
		// Force nearest filtering (for performance)
		const vec4 color = texelFetch(tex, ivec3(uv_ * textureSize(tex, 0).xy, layer_), 0);

		if(color.a < 0.8)
			discard;
	#endif
}

#else
void main() {
	#if NEAR_DEPTH_TEST
		const ivec2 coord = ivec2(gl_FragCoord.xy);

		bool dc = false;
		#pragma unroll
		for(int i = 0; i < MSAA_SAMPLES; i++)
			dc = dc || (gl_FragCoord.z <= texelFetchX(nearDepthTestTex, coord, i).r + 0.005 * (1 - gl_FragCoord.z));

		if(dc)
			discard;
	#endif

	#if SURFACE_DATA == SURFACE_DATA_UV
		vec4 color_ = vec4(fract(uv_), 0, 1);

	#elif BETTER_TEXTURING
		const vec2 texSize = vec2(textureSize(tex, 0).xy);
		const vec2 lod = textureQueryLod(tex, uv_);

		vec2 adjUv;

		if(lod.y < 0) {
			const vec2 samplePos = uv_ * texSize - 0.5;
			const vec2 samplePosFract = fract(samplePos);
			const vec2 adjSamplePos = samplePos - samplePosFract + clamp(0.5 - (samplePosFract - 0.5) * min(-1, -1 + lod.y * 4), 0, 1);
			adjUv = (adjSamplePos + 0.5) / texSize;
		} else
			adjUv = uv_;

		vec4 color_ =	textureLod(tex, vec3(adjUv, layer_), lod.x);

	#else
		vec4 color_ =	texture(tex, vec3(uv_, layer_));
	#endif

	#if SURFACE_DATA == SURFACE_DATA_AGGREGATION
		const vec2 arb = abs(0.5 - fract(uv_));
		if(arb.x > 0.3 || arb.y > 0.3)
			color_.rgb = (color_.rgb + aggregationColor_) * 0.5;
	#endif

	#if ALPHA_CHANNEL == ALPHA_CHANNEL_TRANSPARENCY
		color = color_;
	#elif ALPHA_CHANNEL == ALPHA_CHANNEL_ALPHA_TEST
		if(color_.a <= 0.5)
			discard;

		color = vec4(color_.rgb / color_.a, 1);
	#else
		color = vec4(color_.rgb, 1);
	#endif

	#if ALPHA_CHANNEL == ALPHA_CHANNEL_GLOW
		normal = vec4(norm_, 1 - color_.a);
	#else
		normal = vec4(norm_, 0);
	#endif
}
#endif