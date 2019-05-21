// aggregation_squares is included before, this is just a finall pass

// Try both X and Y
for(uint dirI = 0; dirI < 2; dirI++) {
	const uint dirI4 = dirI * 4;

	const uint dirMask = 0x0f << dirI4;
	const uint dirMaskInv = 0xf0 >> dirI4;

	// For all three dimensions (all six faces)
	for(uint dimI = 0; dimI < 3; dimI++) {
		// Dunno why but this does not work when usin gstatic array???
		const uint arr[2][3] = {{1,0,0}, {2,2,1}};
		const uint dim = arr[dirI][dimI];

		for(uint faceI = 0; faceI < 2; faceI++) {
			const uint faceId = (dimI << 1) | faceI; // dimI * 2 + faceI
			const uint faceMask = 1 << faceId;

			uint thisAggregation = faThis(faceId);
			if(thisAggregation == 0)
				continue;

			// If there is the same block to the left that also has visible the face, do not try to aggregate (it might screw things up)
			if(localPos[dim] > 0) {
				const uint otherBd = bdcOffsetVec(-dimVec[dim]);
				if(bdcId(otherBd) == blockId && (bdcData(otherBd) & faceMask) != 0)
					continue;
			}
			
			ivec3 pos = localPos, origin = localPos;
			pos[dim] += int((thisAggregation >> dirI4) & 0xf);

			while(pos[dim] < LOCAL_SIZE) {
				const uint otherBd = bdcVec(pos);
				const uint otherAggregation = faVec(faceId, pos);

				// If the other block is not the same ID, break
				if(bdcId(otherBd) != blockId)
					break;

				// If the aggregation size in other direction does not match, start a new aggregation block
				if((thisAggregation & dirMaskInv) == (otherAggregation & dirMaskInv)) {
					faVec(faceId, pos) = 0;
					thisAggregation += (otherAggregation & dirMask);

				} else if(otherAggregation != 0) {
					faVec(faceId, origin) = thisAggregation;
					thisAggregation = otherAggregation;
					origin = pos;

				} else
					break;

				pos[dim] += int((otherAggregation >> dirI4) & 0xf);
			}
			
			faVec(faceId, origin) = thisAggregation;
		}
	}

	memoryBarrierShared();
	barrier();
}