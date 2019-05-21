#define PERLIN2D_MAX_OCTAVE_COUNT 8

#define PERLIN2D_WORKGROUP_SIZE 8
#define PERLIN2D_WORKGROUP_SIZE_BITS 3


// Interpolation function 6*t^5 - 15 * t^4 + 10 * t^3
float interpolate(float v1, float v2, float progress) {
	const float val = interpolationConst(progress);
	return mix(v1, v2, interpolationConst(progress));
}


// PERLIN2D_MAX_OCTAVE_COUNT octaves, 4 gradients for each
// X<<0 | Y<<1 | Z<<2 | Oct<<3
shared vec2 perlin2DcachedGradients[PERLIN2D_MAX_OCTAVE_COUNT * 4];

// PERLIN2D_MAX_OCTAVE_COUNT octaves, 4 interpolations, PERLIN2D_WORKGROUP_SIZE local size
// [interpolation][local<<0 | octave << 3]
shared vec2 perlin2DcachedDotData[4][PERLIN2D_MAX_OCTAVE_COUNT][PERLIN2D_WORKGROUP_SIZE];

vec2 perlin2DnodeGradient(uint seed, ivec2 pos) {
	uint t = seed ^ globalSeed;
	t = hash(t ^ uint(pos.x));
	t = hash(t ^ uint(pos.y));

	float x = float(t & 65535) / 65535 * 2 * 3.141592;
	return vec2(sin(x), -cos(x));
}

vec3 perlin2D(ivec2 pos, uint seed, uint firstOctaveSize, uint octaveCount, float[PERLIN2D_MAX_OCTAVE_COUNT] octaveWeights) {
	// Calculate node gradients: 4 for each octave, PERLIN2D_MAX_OCTAVE_COUNT octaves
	if(gl_LocalInvocationIndex < octaveCount * 4) {
		const uint octaveSize = firstOctaveSize << (gl_LocalInvocationIndex >> 2);
		const ivec2 octaveAnchorPos = ivec2(floor(vec2(pos) / octaveSize)); // Assuming workgroup size <= octave size
		const ivec2 offset = octaveAnchorPos + ivec2((gl_LocalInvocationIndex & 1), (gl_LocalInvocationIndex >> 1) & 1);

		perlin2DcachedGradients[gl_LocalInvocationIndex] = perlin2DnodeGradient(seed, offset);
	}

	memoryBarrierShared();
	barrier();

	for(uint invoIndex = gl_LocalInvocationIndex; invoIndex < octaveCount * 4 * PERLIN2D_WORKGROUP_SIZE; invoIndex += PERLIN2D_WORKGROUP_SIZE * PERLIN2D_WORKGROUP_SIZE) {
		const uint offsetId = (invoIndex & (PERLIN2D_WORKGROUP_SIZE - 1));
		const uint gradientId = (invoIndex >> PERLIN2D_WORKGROUP_SIZE_BITS) & 3;
		const uint octaveId = invoIndex >> (PERLIN2D_WORKGROUP_SIZE_BITS + 2);

		const uint octaveSize = firstOctaveSize << octaveId;
		const vec2 offset = fract(vec2(pos - ivec2(gl_LocalInvocationID.xy) + int(offsetId)) / octaveSize);

		const vec2 gradient = perlin2DcachedGradients[octaveId << 2 | gradientId];

		perlin2DcachedDotData[gradientId][octaveId][offsetId] = vec2(
			(offset.x - (gradientId & 1)) * gradient.x,
			(offset.y - ((gradientId >> 1) & 1)) * gradient.y
		);
	}

	memoryBarrierShared();
	barrier();

	// Now for each pixel actually compute the noise value
	vec3 result = vec3(0);
	for(uint octaveId = 0; octaveId < octaveCount; octaveId++) {
		const uint octaveSize = firstOctaveSize << octaveId;
		const float octaveSizeInvF = 1 / float(octaveSize);

		const vec2 offset = fract(vec2(pos) * octaveSizeInvF);

		const uvec2 locIx = gl_LocalInvocationID.xy;// | (octaveId << 3);

		const float dotProduct1 = perlin2DcachedDotData[0][octaveId][locIx.x].x + perlin2DcachedDotData[0][octaveId][locIx.y].y;
		const float dotProduct2 = perlin2DcachedDotData[1][octaveId][locIx.x].x + perlin2DcachedDotData[1][octaveId][locIx.y].y;

		const float dotProduct3 = perlin2DcachedDotData[2][octaveId][locIx.x].x + perlin2DcachedDotData[2][octaveId][locIx.y].y;
		const float dotProduct4 = perlin2DcachedDotData[3][octaveId][locIx.x].x + perlin2DcachedDotData[3][octaveId][locIx.y].y;

		const float interpolationConstX = interpolationConst(offset.x);
		const float interpolationConstY = interpolationConst(offset.y);

		const vec2 interpolation1 = mix(vec2(dotProduct1, dotProduct3), vec2(dotProduct2, dotProduct4), interpolationConstX);
		const float interpolation2 = mix(interpolation1.x, interpolation1.y, interpolationConstY);

		const float gradientX = mix(dotProduct2 - dotProduct1, dotProduct4 - dotProduct3, interpolationConstY) * interpolationConstGradient(offset.x) * octaveSizeInvF;
		const float gradientY = (interpolation1.y - interpolation1.x) * interpolationConstGradient(offset.y) * octaveSizeInvF;

		result += vec3(
			interpolation2, // Perlin value
			gradientX, gradientY
			) * octaveWeights[octaveId];
	}

	// In case there are multiple calls in the code, so that the shared memory does not get messy
	barrier();

	return result;
}