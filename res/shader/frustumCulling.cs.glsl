#version 430

layout(local_size_x = 16, local_size_y = 16) in;

// Defines: CHUNK_WIDTH, CHUNK_HEIGHT, REGION_HEIGHT, MATRIX_COUNT

layout(std140, binding = 0) uniform uniformData {
	mat4 viewMatrix[MATRIX_COUNT];
	ivec3 firstChunkPos, lastChunkPos;
	vec3 cameraPos;
	float viewDistance;
};

layout(binding = 0) uniform atomic_uint recordCount;

struct Record {
	ivec3 chunkPos;
	uint regionBits[MATRIX_COUNT];
};

layout(binding = 0, std430) buffer outputBuffer {
	Record[] records;
};

const ivec3 pointOffset[4] = {
	ivec3(0,0,0), ivec3(CHUNK_WIDTH,0,0), ivec3(0,CHUNK_WIDTH,0), ivec3(CHUNK_WIDTH,CHUNK_WIDTH,0)
};

uint pointFlags(vec4 pointPos, uint matIx) {
	const vec4 screenPosW = viewMatrix[matIx] * pointPos;
	const vec3 screenPos = screenPosW.xyz / screenPosW.w;

	const uint wXor = screenPosW.w < 0 ? /*0b11110*/ 30 : 0;
	const uint flags = (screenPos.z <= 1 ? 1 : 0) | (screenPos.x <= 1 ? 2 : 0) | (screenPos.x >= -1 ? 4 : 0) | (screenPos.y <= 1 ? 8 : 0) | (screenPos.y >= -1 ? 16 : 0);

	// If the w < 0, the xy flags are inverted
	return flags ^ wXor;
}

void main() {
	const ivec3 chunkPos = firstChunkPos + ivec3(ivec2(gl_GlobalInvocationID.xy) * CHUNK_WIDTH, 0);
	const vec3 chunkPosF = vec3(chunkPos);

	if(chunkPos.x >= lastChunkPos.x || chunkPos.y >= lastChunkPos.y)
		return;

	ivec3 pos = chunkPos;

	/// Bit field of what regions of the chunk are in frustum
	uint regionsInFrustum[MATRIX_COUNT];

	#pragma unroll
	for(uint matIx = 0; matIx < MATRIX_COUNT; matIx++)
		regionsInFrustum[matIx] = 0;

	/*
		The idea for this frustum culling is that each region must project at least one point:
		* to the left of the right edge of the screen
		* and at least one point to the right of the left edge of the screen
		* and the same for the top and bottom edges
		* and at least one point must be before the camera

		For each of this five conditions (<x, >x, <y, >y, >z), there is a bit flag
		The bit flags are the same between the top points in a region and the bottom points of the region above, so we use that
	*/
	uint topSidePointFlags[MATRIX_COUNT];
	for(uint matIx = 0; matIx < MATRIX_COUNT; matIx++)			
			topSidePointFlags[matIx] = 0;

	for(uint pointIx = 0; pointIx < 4; pointIx++) {
		const vec4 pointPos = vec4(pos + pointOffset[pointIx], 1);

		#pragma unroll
		for(uint matIx = 0; matIx < MATRIX_COUNT; matIx++)			
			topSidePointFlags[matIx] |= pointFlags(pointPos, matIx);
	}

	for(uint regionIx = 0; pos.z < CHUNK_HEIGHT; regionIx++) {
		uint bottomSidePointFlags[MATRIX_COUNT];

		#pragma unroll
		for(uint matIx = 0; matIx < MATRIX_COUNT; matIx++) {
			bottomSidePointFlags[matIx] = topSidePointFlags[matIx];
			topSidePointFlags[matIx] = 0;
		}

		pos.z += REGION_HEIGHT;

		for(uint pointIx = 0; pointIx < 4; pointIx ++) {
			const vec4 pointPos = vec4(pos + pointOffset[pointIx], 1);

			#pragma unroll
			for(uint matIx = 0; matIx < MATRIX_COUNT; matIx++)
				topSidePointFlags[matIx] |= pointFlags(pointPos, matIx);
		}

		#pragma unroll
		for(uint matIx = 0; matIx < MATRIX_COUNT; matIx++) {
			const uint flags = bottomSidePointFlags[matIx] | topSidePointFlags[matIx];
			regionsInFrustum[matIx] |= (flags == /*0b11111*/ 31 ? 1 : 0) << regionIx;
		}
	}

	bool anyRegionVisible = false;
	#pragma unroll
	for(uint matIx = 0; matIx < MATRIX_COUNT; matIx++)
		anyRegionVisible = anyRegionVisible || (regionsInFrustum[matIx] != 0);

	if(!anyRegionVisible)
		return;

	Record rec;
	rec.chunkPos = chunkPos;

	#pragma unroll
	for(uint matIx = 0; matIx < MATRIX_COUNT; matIx++)
		rec.regionBits[matIx] = regionsInFrustum[matIx];

	const uint recordIx = atomicCounterIncrement(recordCount);
	records[recordIx] = rec;
}