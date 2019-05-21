#version 430

/*
	Global postprocessing pass 1
	* combine with blended layers
	* compute SSAO
*/

layout(local_size_x = WORKGROUP_SIZE, local_size_y = WORKGROUP_SIZE) in;

#include "postprocessing/common.glsl"

layout(rgba8, binding = 0) uniform image2D inoutResult;

#if AMBIENT_OCCLUSION
	layout(r8, binding = 1) writeonly uniform image2D outSSAO;
#endif

#if GOD_RAYS
	layout(r8, binding = 2) writeonly uniform image2D outGodRays;
#endif

layout(binding = 0) uniform sampler2D inNormal;
layout(binding = 1) uniform sampler2D inDepth;
layout(binding = 2) uniform sampler2D inBlendLayers[MAX_BLEND_LAYER_COUNT];

layout(std140, binding = 0) uniform uniformData {
	mat4 viewMatrix, invertedViewMatrix;
	vec3 cameraPos;

	vec3 daylightDirection;
	vec3 skyColor, sunColor, horizonHaloColor, sunHorizonHaloColor;

	float viewDistance;
};

#include "util/hash.glsl"
#include "postprocessing/sky.cs.glsl"
#include "postprocessing/ssao.cs.glsl"

void main() {
	const ivec2 resolution = imageSize(inoutResult);
	const ivec2 pos = ivec2(gl_GlobalInvocationID.xy);

	if(pos.x >= resolution.x || pos.y >= resolution.y)
		return;

	const vec2 posF = vec2(pos);
	const vec2 resolutionF = vec2(resolution);
	const vec2 resolutionFInv = 1 / resolutionF;
	const vec2 screenSpacePos = vec2(pos) * resolutionFInv * 2 - 1;

	vec4 result = imageLoad(inoutResult, pos);

	#if SHOW_SINGLE_BLEND_LAYER == -1
		#pragma unroll
		for(int i = BLEND_LAYER_COUNT - 1; i >= 0; i--) {
			const vec4 col = texelFetch(inBlendLayers[i], pos, 0);
			result = col + result * (1 - col.a);
		}
	#else
		const vec4 col = texelFetch(inBlendLayers[SHOW_SINGLE_BLEND_LAYER], pos, 0);
		result = col;
	#endif

	result.rgb /= result.a;

	#if AMBIENT_OCCLUSION || GOD_RAYS || ATMOSPHERE
		const float depth = texelFetch(inDepth, pos, 0).r;

		const vec4 worldCoordsW = invertedViewMatrix * vec4(screenSpacePos, depth, 1);
		const vec3 worldCoords = worldCoordsW.xyz / worldCoordsW.w;
	#endif

	#if AMBIENT_OCCLUSION
		const ivec3 worldCoordsI = ivec3(worldCoords);
		const vec3 normal = texelFetchX(inNormal, pos, 0).rgb * 2 - 1;
		const float z = depthToZ(depth);

		imageStore(outSSAO, pos, vec4(ssao(z, worldCoords, normal), 0, 0, 0));
	#endif

	#if GOD_RAYS || ATMOSPHERE
		const vec3 viewNormal = normalize(worldCoords - cameraPos);
	#endif

	#if ATMOSPHERE
		const float distanceFromPlayer2D = distance(worldCoords.xy, cameraPos.xy);

		result.rgb = mix(result.rgb, skyWithoutSun(posF, viewNormal, true) * 0.6, pow(min(distanceFromPlayer2D / (viewDistance * 16 * 0.8), 1), 2));
		//result.a *= 1 - min(pow(distanceFromPlayer2D / (viewDistance * 16), 3), 1) * 0.8;

		const float coef2 = min(pow(distanceFromPlayer2D / (viewDistance * 16), 3), 1) * 0.8;
		result.rgb = mix(result.rgb, skyWithoutSun(posF, viewNormal, false), coef2);
		result.a *= 1 - coef2 * 0.1;
	#endif

	#if GOD_RAYS
		const float horizonCoef = clamp((viewNormal.z + 0.2) * 5, 0, 1);
		imageStore(outGodRays, pos, vec4((1 - result.a) * horizonCoef, 0, 0, 0));
	#endif

	imageStore(inoutResult, pos, result);
}