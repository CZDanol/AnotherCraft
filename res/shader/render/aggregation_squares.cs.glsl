// 3 iterations with increasing size (workgroup is 8 so this should cover all the cases)
for(int i = 0; i < 3; i++)  {
	const int stepSize = 1 << i;

	// Alternate between X and Y steps
	for(uint dirI = 0; dirI < 2; dirI ++) {
		const uint dirI4 = dirI * 4;

		const uint dirMask = 0x0f << dirI4;
		const uint dirMaskInv = 0xf0 >> dirI4;

		// stepSize encoded for comparison against aggregation uint (which has x,y coordinates in the same byte)
		const uint dirStepSize = stepSize << dirI4;

		// For all three dimensions (all six faces)
		for(uint dimI = 0; dimI < 3; dimI++) {
			const uint dim = aggregationDim[dirI][dimI];

			// If we are not aligned to the grid, do not try to aggregate
			if(localPos[dim] % (stepSize * 2) != 0)
				continue;

			const ivec3 offset = dimVec[dim] * stepSize;
			const uint otherBd = bdcOffsetVec(offset);

			if(bdcId(otherBd) != blockId)
				continue;

			#pragma unroll
			for(uint faceI = 0; faceI < 2; faceI ++) {
				const uint faceId = (dimI << 1) | faceI; // dimI * 2 + faceI
				const uint faceMask = 1 << faceId;

				const uint thisAggregation = faThis(faceId);
				const uint otherAggregation = faOffsetVec(faceId, offset);

				if(
					(thisAggregation & dirMask) != dirStepSize // If this block is not aggregated enough for the next aggregation step
					|| (thisAggregation & dirMaskInv) != (otherAggregation & dirMaskInv) // or the other block is not aggregated the same in the other direction (for example we want to aggregate 2x + 1x together, but they are not of the same height)
					)
					continue;

				faThis(faceId) = thisAggregation + (otherAggregation & dirMask);
				faOffsetVec(faceId, offset) = 0;
			}
		}

		memoryBarrierShared();
		barrier();
	}
}