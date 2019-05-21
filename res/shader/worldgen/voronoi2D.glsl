// Need to externally define VORONOI2D_MAX_POINTS_PER_REGION

shared vec2 voronoi2DRegionPointPositions[9][VORONOI2D_MAX_POINTS_PER_REGION];
shared uint voronoi2DRegionPointCounts[9];

const ivec2 voronoi2DRegionOffsets[9] = {
	ivec2(-1, -1), ivec2(0, -1), ivec2(1, -1),
	ivec2(-1, 0), ivec2(0, 0), ivec2(1, 0),
	ivec2(-1, 1), ivec2(0, 1), ivec2(1, 1)
};

/// Returns vec2 - first component is distance from the nearest point (0 .. 1), 2nd is ratio between distances from 2 closest points = 1st/2nd (0 .. 1)
vec4 voronoi2D(ivec2 pos, uint seed, uint regionSize, uint maxPointsPerRegion) {
	const vec2 relPosF = vec2(pos) / float(regionSize);

	const ivec2 baseRegionPos = ivec2(floor(relPosF));
	const vec2 posInRegionF = fract(relPosF);

	// Calculate voronoi points in the 8-neighbourhood regions
	for(uint i = gl_LocalInvocationIndex; i < 9 * VORONOI2D_MAX_POINTS_PER_REGION; i += gl_WorkGroupSize.x * gl_WorkGroupSize.y) {
		const uint pointIx = i % VORONOI2D_MAX_POINTS_PER_REGION;
		const uint regionIx = i / VORONOI2D_MAX_POINTS_PER_REGION;

		const ivec2 regionOffset = voronoi2DRegionOffsets[regionIx];
		const ivec2 regionPos = baseRegionPos + regionOffset;
		const uint baseHash = hash(uint(regionPos.y) ^ hash(uint(regionPos.x) ^ seed ^ globalSeed));

		if(pointIx == 0)
			voronoi2DRegionPointCounts[regionIx] = 1 + hash(baseHash ^ 0xf7f494e8) % maxPointsPerRegion;

		voronoi2DRegionPointPositions[regionIx][pointIx] =
			vec2(uvec2(hash(baseHash ^ pointIx ^ 0x3f2a6238), hash(baseHash ^ pointIx ^ 0x8bbc347b)) % 0x10000) / 0x10000 + vec2(regionOffset);
	}

	memoryBarrierShared();
	barrier();

	// Now calculate distance to nearest point
	{
		const float maxDistanceSqr = 4.5; // 9/2
		float distanceSqr = maxDistanceSqr, distance2ndSqr = maxDistanceSqr;
		vec2 nearestPtOffset;

		for(uint regionIx = 0; regionIx < 9; regionIx++) {
			const uint regionPointCount = voronoi2DRegionPointCounts[regionIx];

			for(uint pointIx = 0; pointIx < regionPointCount; pointIx ++) {
				const vec2 pointPos = voronoi2DRegionPointPositions[regionIx][pointIx];
				const vec2 offset = (pointPos - posInRegionF);
				const vec2 offsetSqr = offset * offset;

				const float distSqr = offsetSqr.x + offsetSqr.y;

				if(distSqr <= distanceSqr) {
					distance2ndSqr = distanceSqr;
					distanceSqr = distSqr;
					nearestPtOffset = offset;
				}
				else if(distSqr < distance2ndSqr)
					distance2ndSqr = distSqr;
			}
		}

		// In case there are multiple calls in the code, so that the shared memory does not get messy
		barrier();

		return vec4(sqrt(distanceSqr / maxDistanceSqr),	sqrt(distanceSqr / distance2ndSqr), nearestPtOffset * regionSize);
	}
}