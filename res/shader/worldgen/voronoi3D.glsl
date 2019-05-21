// Need to externally define VORONOI3D_MAX_POINTS_PER_REGION

shared vec3 voronoi3DRegionPointPositions[27][VORONOI3D_MAX_POINTS_PER_REGION];
shared uint voronoi3DRegionPointCounts[27];

/// Returns ivec3 - offset to the nearest voronoi point
ivec3 voronoi3D(ivec3 pos, uint seed, uint regionSize, uint maxPointsPerRegion, float metricExp) {
	const vec3 relPosF = vec3(pos) / float(regionSize);

	const ivec3 baseRegionPos = ivec3(floor(relPosF));
	const vec3 posInRegionF = fract(relPosF);

	// Calculate voronoi points in the 8-neighbourhood regions
	for(uint i = gl_LocalInvocationIndex; i < 27 * VORONOI3D_MAX_POINTS_PER_REGION; i += gl_WorkGroupSize.x * gl_WorkGroupSize.y * gl_WorkGroupSize.z) {
		const uint pointIx = i % VORONOI3D_MAX_POINTS_PER_REGION;
		const uint regionIx = i / VORONOI3D_MAX_POINTS_PER_REGION;

		const ivec3 regionOffset = ivec3(int(regionIx % 3) - 1, int(regionIx / 3) % 3 - 1, int(regionIx / 9) % 3 - 1);
		const ivec3 regionPos = baseRegionPos + regionOffset;
		const uint baseHash = hash(seed ^ globalSeed ^ pointIx, regionPos);

		if(pointIx == 0)
			voronoi3DRegionPointCounts[regionIx] = 1 + hash(baseHash ^ 0xf7f494e8) % maxPointsPerRegion;

		voronoi3DRegionPointPositions[regionIx][pointIx] =
			vec3(uvec3(baseHash ^ 0x3f2a6238, baseHash ^ 0x8bbc347b, baseHash ^ 0x81b12301) % 0x10000) / 0x10000 + vec3(regionOffset);
	}

	memoryBarrierShared();
	barrier();

	// Now calculate distance to nearest point
	{
		float distanceExp = 100000;
		vec3 nearestPtOffset;

		for(uint regionIx = 0; regionIx < 27; regionIx++) {
			const uint regionPointCount = voronoi3DRegionPointCounts[regionIx];

			for(uint pointIx = 0; pointIx < regionPointCount; pointIx ++) {
				const vec3 pointPos = voronoi3DRegionPointPositions[regionIx][pointIx];
				const vec3 offset = (pointPos - posInRegionF);

				const float distExp = dot(pow(abs(offset), vec3(metricExp)), vec3(1));

				if(distExp <= distanceExp) {
					distanceExp = distExp;
					nearestPtOffset = offset;
				}
			}
		}

		// In case there are multiple calls in the code, so that the shared memory does not get messy
		barrier();

		return ivec3(nearestPtOffset * regionSize);
	}
}