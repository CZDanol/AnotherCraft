#define PERLIN3D_MAX_OCTAVE_COUNT 8

// PERLIN3D_MAX_OCTAVE_COUNT octaves, 8 gradients for each
// X<<0 | Y<<1 | Z<<2 | Oct<<3
shared vec3 perlin3DcachedGradients[PERLIN3D_MAX_OCTAVE_COUNT * 8];

// 8 interpolations, PERLIN3D_MAX_OCTAVE_COUNT octaves, 8 local size
shared vec3 perlin3DcachedDotData[8][PERLIN3D_MAX_OCTAVE_COUNT][8];

vec3 perlin3DnodeGradient(uint seed, ivec3 pos) {
	uint t = seed ^ globalSeed;
	t = hash(t ^ uint(pos.x));
	t = hash(t ^ uint(pos.y));
	t = hash(t ^ uint(pos.z));

	vec3 result = vec3(
		1 - float((t << 1) & 2),
		1 - float(t & 2),
		1 - float((t >> 1) & 2)
		);

	result[(t >> 3) % 3] = 0; // One dimension is always 0
	return result;
}

float perlin3D(ivec3 pos, uint seed, uint firstOctaveSize, uint octaveCount, float[PERLIN3D_MAX_OCTAVE_COUNT] octaveWeights) {
	// Calculate node gradients: 8 for each octave, OCTAVE_COUNT octaves

	if(gl_LocalInvocationIndex < 8 * octaveCount) {
		const int octaveSize = int(firstOctaveSize) << (gl_LocalInvocationIndex >> 3); // Smallest octave size is 8, doubles each octave
		const ivec3 octaveAnchorPos = ivec3(floor(vec3(pos) / octaveSize)); // Assuming workgroup size <= octave size
		const ivec3 offset = octaveAnchorPos + ivec3((gl_LocalInvocationIndex & 1), (gl_LocalInvocationIndex >> 1) & 1, (gl_LocalInvocationIndex >> 2) & 1);

		perlin3DcachedGradients[gl_LocalInvocationIndex] = perlin3DnodeGradient(seed, offset);
	}

	memoryBarrierShared();
	barrier();

	/*
		Optimize the dot product used in the noise
		The dot product is used as: dot(offset + vec3(C, C, C), perlin3DcachedGradients[C]); where C are constants
		Dot is: Lx*Rx + Ly*Ry + Lz*Rz

		For each X, Y, Z planes in the workgroup, the Ld*Rd part is same (d - dimesion)
		So we can precalculate it
	*/
	if(gl_LocalInvocationIndex < octaveCount * 64) {
		const uint offsetId = (gl_LocalInvocationIndex & 7);
		const uint gradientId = (gl_LocalInvocationIndex >> 3) & 7;
		const uint octaveId = gl_LocalInvocationIndex >> 6;

		const uint octaveSize = firstOctaveSize << octaveId;
		const vec3 offset = fract(vec3(pos - ivec3(gl_LocalInvocationID) + int(offsetId)) / octaveSize); // pos - gl_LocalInvocationID = workgroup origin

		const vec3 gradient = perlin3DcachedGradients[octaveId << 3 | gradientId];

		perlin3DcachedDotData[gradientId][octaveId][offsetId] = vec3(
			(offset.x - (gradientId & 1)) * gradient.x,
			(offset.y - ((gradientId >> 1) & 1)) * gradient.y,
			(offset.z - ((gradientId >> 2) & 1)) * gradient.z
		);
	}

	memoryBarrierShared();
	barrier();

	// Now for each pixel actually compute the noise value
	float result = 0;
	for(uint octaveId = 0; octaveId < octaveCount; octaveId++) {
		const uint octaveSize = firstOctaveSize << octaveId;
		const vec3 offset = fract(vec3(pos) / octaveSize);

		const uvec3 locIx = gl_LocalInvocationID;// | (octaveId << 3);

		const float dotProduct1 = perlin3DcachedDotData[0][octaveId][locIx.x].x + perlin3DcachedDotData[0][octaveId][locIx.y].y + perlin3DcachedDotData[0][octaveId][locIx.z].z;
		const float dotProduct2 = perlin3DcachedDotData[1][octaveId][locIx.x].x + perlin3DcachedDotData[1][octaveId][locIx.y].y + perlin3DcachedDotData[1][octaveId][locIx.z].z;

		const float dotProduct3 = perlin3DcachedDotData[2][octaveId][locIx.x].x + perlin3DcachedDotData[2][octaveId][locIx.y].y + perlin3DcachedDotData[2][octaveId][locIx.z].z;
		const float dotProduct4 = perlin3DcachedDotData[3][octaveId][locIx.x].x + perlin3DcachedDotData[3][octaveId][locIx.y].y + perlin3DcachedDotData[3][octaveId][locIx.z].z;

		const float dotProduct5 = perlin3DcachedDotData[4][octaveId][locIx.x].x + perlin3DcachedDotData[4][octaveId][locIx.y].y + perlin3DcachedDotData[4][octaveId][locIx.z].z;
		const float dotProduct6 = perlin3DcachedDotData[5][octaveId][locIx.x].x + perlin3DcachedDotData[5][octaveId][locIx.y].y + perlin3DcachedDotData[5][octaveId][locIx.z].z;

		const float dotProduct7 = perlin3DcachedDotData[6][octaveId][locIx.x].x + perlin3DcachedDotData[6][octaveId][locIx.y].y + perlin3DcachedDotData[6][octaveId][locIx.z].z;
		const float dotProduct8 = perlin3DcachedDotData[7][octaveId][locIx.x].x + perlin3DcachedDotData[7][octaveId][locIx.y].y + perlin3DcachedDotData[7][octaveId][locIx.z].z;

		const vec4 interpolation1 = mix(
			vec4(dotProduct1, dotProduct3, dotProduct5, dotProduct7),
			vec4(dotProduct2, dotProduct4, dotProduct6, dotProduct8),
			interpolationConst(offset.x)
		);
		const vec2 interpolation2 = mix(
			vec2(interpolation1[0], interpolation1[2]),
			vec2(interpolation1[1], interpolation1[3]),
			interpolationConst(offset.y)
		);
		const float interpolation3 = mix(
			interpolation2.x,
			interpolation2.y,
			interpolationConst(offset.z)
		);

		result += interpolation3 * octaveWeights[octaveId];
	}
	
	// In case there are multiple calls in the code, so that the shared memory does not get messy
	barrier();

	return result;
}