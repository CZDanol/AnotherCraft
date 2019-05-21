#version 450
#extension GL_ARB_bindless_texture : require

/*
	Local (applied to each depth peeling layer) postprocessing pass 1:
	* shading is applied
	* ambient occlusion is calculated and sent for blurring
*/

#include "util/preprocessor.glsl"
#include "postprocessing/common.glsl"
#include "util/defines.glsl"

#define FLT_MAX 3.402823466e+38
#define FLT_MIN 1.175494351e-38

layout(local_size_x = WORKGROUP_SIZE, local_size_y = WORKGROUP_SIZE) in;

layout(binding = 0) uniform sampler2DX inColor;
layout(binding = 1) uniform sampler2DX inNormal;
layout(binding = 2) uniform sampler2DX inDepth;

#if SHADOW_MAPPING
	layout(binding = 3) uniform sampler2DShadow inShadowMap;
#endif

layout(rgba8, binding = 0) writeonly uniform image2D outResult;

#if DATA_EXPORT
	layout(r32f, binding = 1) writeonly uniform image2D outDepth;
	layout(rgba8, binding = 2) writeonly uniform image2D outNormal;
#endif

layout(std140, binding = 0) uniform uniformData {
	uvec4 lightMaps[(AREAS_ARRAY_WIDTH * AREAS_ARRAY_WIDTH + 1) / 2];
	ivec2 mapsOrigin;

	vec3 cameraPos;
	mat4 viewMatrix, invertedViewMatrix, shadowSamplingMatrix;

	vec3 daylightDirection;
	vec3 directionalDaylightColor;
	vec3 ambientDaylightColor;
	vec3 ambientLightColor;

	float artificialLightEffectReduction;
};

#include "postprocessing/shading.cs.glsl"

void main() {
	const ivec2 resolution = textureSizeX(inColor);
	const ivec2 pos = ivec2(gl_GlobalInvocationID.xy);

	if(pos.x >= resolution.x || pos.y >= resolution.y)
		return;

	const vec2 resolutionF = vec2(resolution);
	const vec2 resolutionFInv = 1 / resolutionF;
	const vec2 posF = vec2(pos);
	const vec2 screenSpacePos = posF * resolutionFInv * 2 - 1;

	vec4 result = vec4(0,0,0,0);
	float aDepth = -1;
	vec4 aNormal01;
	vec3 avgNormal01 = vec3(0);

	/// Antialiasing & shading
	for(int i = 0; i < MSAA_SAMPLES; i++) {
		const vec4 color = texelFetchX(inColor, pos, i);

		#if !(DATA_EXPORT || GOD_RAYS_EXPORT)
			if(color.a == 0)
				continue;
		#endif

		const vec4 normal01 = texelFetchX(inNormal, pos, i);
		const float depth = texelFetchX(inDepth, pos, i).x * 2 - 1;

		aDepth = max(depth, aDepth);
		aNormal01 = depth == aDepth ? normal01 : aNormal01;
		//aNormal01 = depth != 1 ? normal01 : aNormal01;
		//aDepth += depth;
		avgNormal01 += normal01.xyz;

		#if DATA_EXPORT || GOD_RAYS_EXPORT
			if(color.a == 0)
				continue;
		#endif

		const vec3 normal = normal01.xyz * 2 - 1;

		#if SURFACE_DATA == SURFACE_DATA_NORMAL
			vec4 c = vec4(normal / 2 + 0.5, color.a);

		#elif SURFACE_DATA == SURFACE_DATA_DEPTH
			vec4 c = vec4((depthToZ(depth) * 0.1).xxx, color.a);

		#elif SURFACE_DATA == SURFACE_DATA_WHITE
			vec4 c = vec4(1,1,1,color.a);

		#elif SURFACE_DATA == SURFACE_DATA_WORLDCOORDS
			const vec4 worldCoordsW1 = invertedViewMatrix * vec4(screenSpacePos, depth, 1);
			const vec3 worldCoords1 = worldCoordsW1.xyz / worldCoordsW1.w;
			vec4 c = vec4(abs(0.5 - fract(worldCoords1)) * 2, color.a);

		#else
			vec4 c = color;

		#endif

		#if SHADING == SHADING_DEFERRED_MSAA
			const vec4 worldCoordsW = invertedViewMatrix * vec4(screenSpacePos, depth, 1);
			const vec3 worldCoords = worldCoordsW.xyz / worldCoordsW.w;

			c.rgb *= shading(worldCoords, normal, normal01.a);
		#endif

		// Alpha is premultiplied
		result += c;
	}

	avgNormal01 /= MSAA_SAMPLES;
	//aDepth /= MSAA_SAMPLES;

	#if DATA_EXPORT
		imageStore(outDepth, pos, vec4(aDepth));
		imageStore(outNormal, pos, aNormal01);
	#endif

	if(result.a == 0) {
		imageStore(outResult, pos, vec4(0,0,0,0));
		return;
	}

	result /= MSAA_SAMPLES;
	//result.rgb /= result.a;

	#if SHADING == SHADING_DEFERRED_SIMPLE
		{
			const vec4 worldCoordsW = invertedViewMatrix * vec4(screenSpacePos, aDepth, 1);
			const vec3 worldCoords = worldCoordsW.xyz / worldCoordsW.w;

			result.rgb *= shading(worldCoords, avgNormal01 * 2 - 1, aNormal01.a);
		}
	#endif

	imageStore(outResult, pos, result);
}