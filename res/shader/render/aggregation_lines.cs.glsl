// For all three dimensions (all six faces)
for(uint dim = 0; dim < 3; dim++) {
	const uint xDim = aggregationDim[0][dim];

	const uint face1Id = dim * 2;
	const uint face2Id = face1Id + 1;

	const uint face1Mask = 1 << face1Id;
	const uint face2Mask = 1 << face2Id;

	// Two faces for each dimension (left/right, front/back etc)
	// We can aggregate only faces the block has visible
	uint aggregableFaces = visibleFaces & (face1Mask | face2Mask);

	// If there is the same block on the left/whatever, we won't be aggregating the faces he has visible (because he will be doing that)
	if(localPos[xDim] > 0) {
		const uint otherBd = bdcOffsetVec(-dimVec[xDim]);
		if(bdcId(otherBd) == blockId)
			aggregableFaces &= ~bdcData(otherBd);
	}

	if(aggregableFaces == 0)
		continue;

	ivec3 pos = localPos;
	// We try aggregating on the X face axis
	for(int i = pos[xDim] + 1; i < LOCAL_SIZE; i++) {
		pos[xDim] ++;
		const uint otherBd = bdcVec(pos);

		// We stop aggregating faces that the block has hidden
		aggregableFaces &= bdcData(otherBd);

		// If we hit a different block or cannot aggregate further, stop
		if(bdcId(otherBd) != blockId || aggregableFaces == 0)
			break;

		// Successfull face aggregation: increase X aggregation for this block, set the aggregation to zero for the other block
		if((aggregableFaces & face1Mask) != 0) {
			faThis(face1Id) += 0x01;
			faVec(face1Id, pos) = 0;
		}

		if((aggregableFaces & face2Mask) != 0) {
			faThis(face2Id) += 0x01;
			faVec(face2Id, pos) = 0;
		}
	}
}

memoryBarrierShared();
barrier();

// And again for the y dimension
for(uint dim = 0; dim < 3; dim++) {
	const uint yDim = aggregationDim[1][dim];

	const uint face1Id = dim * 2;
	const uint face2Id = face1Id + 1;

	const uint face1Mask = 1 << face1Id;
	const uint face2Mask = 1 << face2Id;

	// Two faces for each dimension (left/right, front/back etc)
	// We can aggregate only faces the block has visible
	uint aggregableFaces = visibleFaces & (face1Mask | face2Mask);

	// If there is the same block on the left/whatever, we won't be aggregating the faces he has visible (because he will be doing that)
	if(localPos[yDim] > 0) {
		const uint otherBd = bdcOffsetVec(-dimVec[yDim]);
		if(bdcId(otherBd) == blockId)
			aggregableFaces &= ~bdcData(otherBd);
	}

	if(aggregableFaces == 0)
		continue;

	uint thisAggregation1 = faThis(face1Id);
	uint thisAggregation2 = faThis(face2Id);

	ivec3 pos = localPos;
	// We try aggregating on the X face axis
	for(int i = pos[yDim] + 1; i < LOCAL_SIZE; i++) {
		pos[yDim] ++;
		const uint otherBd = bdcVec(pos);

		// We stop aggregating faces that the block has hidden
		aggregableFaces &= bdcData(otherBd);

		const uint otherAggregation1 = faVec(face1Id, pos);
		const uint otherAggregation2 = faVec(face2Id, pos);
		aggregableFaces &= ((otherAggregation1 & 0xf) == (thisAggregation1 & 0xf) ? face1Mask : 0) | ((otherAggregation2 & 0xf) == (thisAggregation2 & 0xf) ? face2Mask : 0);

		// If we hit a different block or cannot aggregate further, stop
		if(bdcId(otherBd) != blockId || aggregableFaces == 0)
			break;

		// Successfull face aggregation: increase X aggregation for this block, set the aggregation to zero for the other block
		if((aggregableFaces & face1Mask) != 0) {
			thisAggregation1 += 0x10;
			faVec(face1Id, pos) = 0;
		}

		if((aggregableFaces & face2Mask) != 0) {
			thisAggregation2 += 0x10;
			faVec(face2Id, pos) = 0;
		}
	}

	faThis(face1Id) = thisAggregation1;
	faThis(face2Id) = thisAggregation2;
}

memoryBarrierShared();
barrier();