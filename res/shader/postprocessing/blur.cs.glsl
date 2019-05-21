#version 430

layout(local_size_x = WORKGROUP_SIZE, local_size_y = WORKGROUP_SIZE) in;

#include "util/preprocessor.glsl"

#define DIR_HORIZONTAL 0
#define DIR_VERTICAL 1

#define KERNEL_4G1 0
#define KERNEL_4G2 1
#define KERNEL_4G3 2

// 9*9 gauss, sigma 1
#if BLUR_KERNEL == KERNEL_4G1
#define BLUR_RADIUS 4
const float kernel[9] = {0.000229,0.005977,0.060598,0.241732,0.382928,0.241732,0.060598,0.005977,0.000229};

// 9*9 gauss, sigma 2
#elif BLUR_KERNEL == KERNEL_4G2
#define BLUR_RADIUS 4
const float kernel[9] = {0.028532, 0.067234, 0.124009, 0.179044, 0.20236, 0.179044, 0.124009, 0.067234, 0.028532};

// 9*9 gauss, sigma 3
#elif BLUR_KERNEL == KERNEL_4G3
#define BLUR_RADIUS 4
const float kernel[9] = {0.063327, 0.093095, 0.122589, 0.144599, 0.152781, 0.144599, 0.122589, 0.093095, 0.063327};

// 9*9 gauss, sigma 4
#elif BLUR_KERNEL == KERNEL_4G4
#define BLUR_RADIUS 4
const float kernel[9] = {0.081812, 0.101701, 0.118804, 0.130417, 0.134535, 0.130417, 0.118804, 0.101701, 0.081812};

#endif

#if BLUR_DIRECTION == DIR_HORIZONTAL
#define IVEC2(blurComp, othComp) ivec2(blurComp, othComp)
#define CACHE(blurComp, othComp) cache[othComp][blurComp]
#define blurDim x
#define othDim y

#else
#define IVEC2(blurComp, othComp) ivec2(othComp, blurComp)
#define CACHE(blurComp, othComp) cache[blurComp][othComp]
#define blurDim y
#define othDim x

#endif

#if BLUR_COMPONENTS == 1
#define TYPE float
#define LAYOUT r8
#define components r

#elif BLUR_COMPONENTS == 3
#define TYPE vec3
#define LAYOUT rgb8
#define components rgb

#elif BLUR_COMPONENTS == 4
#define TYPE vec4
#define LAYOUT rgba8
#define components rgba

#endif

layout(binding = 0) uniform sampler2D inData;
layout(LAYOUT, binding = 0) writeonly uniform image2D outBlurredData;

#if BILATERAL
	#define BILATERAL_CACHE(blurComp, othComp) CONCAT(bilateral, CACHE(blurComp, othComp))

	#if BILATERAL_MSAA
		#define texelFetchBE(pos) texelFetch(inBilateralSource, pos, 0)
		#define sampler2DBE sampler2DMS
	#else
		#define texelFetchBE(pos) texelFetch(inBilateralSource, pos / ((BILATERAL_LEVEL + 1) * (BILATERAL_LEVEL + 1)), BILATERAL_LEVEL)
		#define sampler2DBE sampler2D
	#endif

	layout(binding = 1) uniform sampler2DBE inBilateralSource;
	
	shared float BILATERAL_CACHE(gl_WorkGroupSize.blurDim + BLUR_RADIUS * 2, gl_WorkGroupSize.othDim);
#endif

#if ALPHA_PREMULTIPLY
	#define IFE_ALPHA_PREMULTIPLY(then, else) then
#else
	#define IFE_ALPHA_PREMULTIPLY(then, else) else
#endif

shared TYPE CACHE(gl_WorkGroupSize.blurDim + BLUR_RADIUS * 2, gl_WorkGroupSize.othDim);

void main() {
	const ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	const ivec2 groupOrigin = ivec2(gl_GlobalInvocationID.xy - gl_LocalInvocationID.xy);
	const ivec2 resolution = ivec2(textureSize(inData, 0));
	const ivec2 effectiveWorkGroupSize = min(ivec2(gl_WorkGroupSize.xy), resolution - groupOrigin);

	const bool isInImage = pos.x < resolution.x && pos.y < resolution.y;

	#if BILATERAL
		const float thisBEValue = texelFetchBE(pos).r;
	#endif

	if(isInImage) {
		// Load image to the cache
		const TYPE val = texelFetch(inData, pos, 0).components;
		CACHE(gl_LocalInvocationID.blurDim + BLUR_RADIUS, gl_LocalInvocationID.othDim) = val * IFE_ALPHA_PREMULTIPLY(vec4(val.aaa, 1), 1);

		#if BILATERAL
			BILATERAL_CACHE(gl_LocalInvocationID.blurDim + BLUR_RADIUS, gl_LocalInvocationID.othDim) = thisBEValue;
		#endif

		// Also store to the cache BLUR_RADIUS pixels around the workgroup borders
		for(int i = int(gl_LocalInvocationID.blurDim); i < BLUR_RADIUS; i += effectiveWorkGroupSize.blurDim) {
			const ivec2 pos1 = IVEC2(max(0, groupOrigin.blurDim + i - BLUR_RADIUS), pos.othDim);
			const TYPE val1 = texelFetch(inData, pos1, 0).components;
			CACHE(i, gl_LocalInvocationID.othDim) = val1 * IFE_ALPHA_PREMULTIPLY(vec4(val1.aaa, 1), 1);

			const ivec2 pos2 = IVEC2(min(resolution.blurDim - 1, groupOrigin.blurDim + i + effectiveWorkGroupSize.blurDim),	pos.othDim);
			const TYPE val2 = texelFetch(inData, pos2, 0).components;
			CACHE(i + BLUR_RADIUS + effectiveWorkGroupSize.blurDim, gl_LocalInvocationID.othDim) = val2 * IFE_ALPHA_PREMULTIPLY(vec4(val2.aaa, 1), 1);

			#if BILATERAL
				BILATERAL_CACHE(i, gl_LocalInvocationID.othDim) = texelFetchBE(pos1).r;
				BILATERAL_CACHE(i + BLUR_RADIUS + gl_WorkGroupSize.blurDim, gl_LocalInvocationID.othDim) = texelFetchBE(pos2).r;
			#endif
		}
	}

	memoryBarrierShared();
	barrier();

	if(isInImage) {
		TYPE result = TYPE(0);
		#if BILATERAL
			float weightSum = 0;
		#endif

		for(uint i = 0; i < BLUR_RADIUS * 2 + 1; i++) {
			#if BILATERAL
				const float coef = kernel[i] * max(0, 1 - distance(thisBEValue, BILATERAL_CACHE(gl_LocalInvocationID.blurDim + i, gl_LocalInvocationID.othDim)) * BILATERAL_COEF);
				weightSum += coef;
			#else
				const float coef = kernel[i];
			#endif

			result += CACHE(gl_LocalInvocationID.blurDim + i, gl_LocalInvocationID.othDim) * coef;
		}

		#if BILATERAL
			result /= weightSum;
		#endif

		#if ALPHA_PREMULTIPLY
			result.rgb /= result.a;
		#endif

		imageStore(outBlurredData, pos, vec4(result));
	}
}