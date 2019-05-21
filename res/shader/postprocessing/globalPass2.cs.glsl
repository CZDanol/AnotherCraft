#version 430

/*
	Global postprocessing pass 1
	* apply DOF
	* calculate sky
	* apply SSAO
*/


layout(local_size_x = WORKGROUP_SIZE, local_size_y = WORKGROUP_SIZE) in;

#include "postprocessing/common.glsl"

layout(rgba8, binding = 0) uniform writeonly image2D outResult;

layout(binding = 0) uniform sampler2D inColor;
layout(binding = 1) uniform sampler2D inDepth;
layout(binding = 2) uniform sampler2D inDof;
layout(binding = 3) uniform sampler2D inGodRays;
layout(binding = 4) uniform sampler2D inSSAO;

layout(std140, binding = 0) uniform uniformData {
	mat4 invertedViewMatrix;
	vec3 cameraPos;
	float viewDistance;

	vec3 daylightDirection;
	vec3 skyColor, sunColor, horizonHaloColor, sunHorizonHaloColor;

	float sunSize /* px-related size */, sunHaloPow;

	vec3 sunPosPx;
};

#define SKY_WITH_SUN
#include "postprocessing/sky.cs.glsl"

void main() {
	const ivec2 resolution = textureSize(inColor, 0);
	const ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	const vec2 posF = vec2(pos);

	if(pos.x >= resolution.x || pos.y >= resolution.y)
		return;

	const vec2 resolutionF = vec2(resolution);
	const vec2 resolutionFInv = 1 / resolutionF;
	const vec2 screenSpacePos = posF * resolutionFInv * 2 - 1;

	vec4 result = texelFetch(inColor, pos, 0);

	#if DEPTH_OF_FIELD
		float depth01 = texelFetch(inDepth, pos, 0).r;
	#endif

	#if T_JUNCTION_HIDING
		if(result.a <= 0.9) {
			const vec4 p1 = texelFetchOffset(inColor, pos, 0, ivec2(-2,0));
			const vec4 p2 = texelFetchOffset(inColor, pos, 0, ivec2(2,0));
			const vec4 p3 = texelFetchOffset(inColor, pos, 0, ivec2(0,-2));
			const vec4 p4 = texelFetchOffset(inColor, pos, 0, ivec2(0,2));

			if(p1.a + p2.a + p3.a + p4.a >= 3) {
				result = (p1 + p2 + p3 + p4) / 4;

				#if DEPTH_OF_FIELD
					const float d1 = texelFetchOffset(inDepth, pos, 0, ivec2(-2,0)).r;
					const float d2 = texelFetchOffset(inDepth, pos, 0, ivec2(2,0)).r;
					const float d3 = texelFetchOffset(inDepth, pos, 0, ivec2(0,-2)).r;
					const float d4 = texelFetchOffset(inDepth, pos, 0, ivec2(0,2)).r;
					depth01 = (d1 + d2 + d3 + d4) / 4;
				#endif
			}			
		}
	#endif

	#if AMBIENT_OCCLUSION
		result.rgb *= texelFetch(inSSAO, pos, 0).x;
	#endif

	#if DEPTH_OF_FIELD
		const vec4 worldCoordsW = invertedViewMatrix * vec4(screenSpacePos, depth01 * 2 - 1, 1);
		const vec3 worldCoords = worldCoordsW.xyz / worldCoordsW.w;
		
		const float distanceFromPlayer2D = distance(worldCoords.xy, cameraPos.xy);
		result = mix(result, texelFetch(inDof, pos, 0), pow(min(1, distanceFromPlayer2D / 512), 1.5));
	#endif

	const float sourceAlpha = result.a;

	// Sky
	if(result.a < 1) {
		const vec4 pW = invertedViewMatrix * vec4(screenSpacePos, 0.5, 1);
		const vec3 p = pW.xyz / pW.w;

		const vec3 viewNormal = normalize(p - cameraPos);
		result = vec4(mix(sky(posF, viewNormal), result.rgb, result.a), 1);
	}

	#if GOD_RAYS
		if(sunPosPx.z > 0) {
			const int sampleCount = 16;
			const float sampleCountInv = 1 / float(sampleCount);

			const vec2 diff = posF - sunPosPx.xy;
			const float diffLen = length(diff);
			const vec2 diffNorm = diff / diffLen;

			vec2 samplePos = sunPosPx.xy * resolutionFInv;
			vec2 samplePosDx = diffNorm * sunSize * sampleCountInv * resolutionFInv * min(1, diffLen / sunSize);

			float effect = 0;
			for(int i = 0; i < sampleCount; i++) {
				const float sampleVal = texture(inGodRays, samplePos).r;
				effect += sampleVal;

				samplePos += samplePosDx;
			}
			
			result.rgb += effect * sampleCountInv * sunColor * pow(min(1, sunSize / diffLen), sunHaloPow * 0.3) * (sourceAlpha * 0.4 + 0.2);
		}
	#endif

	imageStore(outResult, pos, result);
}