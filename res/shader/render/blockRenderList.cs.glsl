#version 450

/*
	This shader looks on the block id map for the chunk render region (stored in GPU as 3D texture),
	decides what blocks should be rendered and returns them in the list (only blocks not surrounded by full blocks)
	with appropriate face flags (what faces of the blocks should be rendered)
*/

// Defines: ACTIVE_AREA_WIDTH, CHUNK_HEIGHT, AGGREGATION

#define LOCAL_SIZE 8

layout(local_size_x = LOCAL_SIZE, local_size_y = LOCAL_SIZE, local_size_z = LOCAL_SIZE) in;

#include "util/defines.glsl"

#define BLOCK_TRANSPARENT_FACES_BIT (1 << 6)
#define BLOCK_NONUNIFORM_BIT (1 << 7)
#define BLOCK_OPEN_TOP_BIT (1 << 8)

layout(r16ui, binding = 0) readonly uniform uimage3D blockIDMaps[4];
layout(location = 0) uniform ivec3 mapsOffset;

layout(binding = 0, std430) buffer BlockList {
	uint[] blockList;
};

layout(binding = 1, std430) buffer Records {
	uvec4[] records; /// [x : 4b, y : 4b, z : 8b, face flags : 8b] [left, right, top, bottom][front, back] repeat: 6x8b]
};
layout(binding = 0) uniform atomic_uint recordCount;

// First two bytes: blockID, second two bytes: (or actually 8 bits): face flags
shared uint blockDataCache[LOCAL_SIZE+2][LOCAL_SIZE+2][LOCAL_SIZE+2];

#define bdcXYZ(X, Y, Z) blockDataCache[1 + Z][1 + Y][1 + X]
#define bdcVec(vec) blockDataCache[1 + vec.z][1 + vec.y][1 + vec.x]

#define bdcOffsetXYZ(X, Y, Z) blockDataCache[arrIx.z + Z][arrIx.y + Y][arrIx.x + X]
#define bdcOffsetVec(vec) blockDataCache[arrIx.z + vec.z][arrIx.y + vec.y][arrIx.x + vec.x]

#define bdcId(data) (data & 0xffff)
#define bdcData(data) ((data >> 16) & 0xffff)

/// For each face in the workgroup, aggregation packed into a single byte (but till using uint): y:4b x:4b
shared uint faceAggregation[6][LOCAL_SIZE][LOCAL_SIZE][LOCAL_SIZE];

#define faThis(face) faceAggregation[face][localPos.z][localPos.y][localPos.x]
#define faVec(face, vec) faceAggregation[face][vec.z][vec.y][vec.x]
#define faOffsetXYZ(face, X, Y, Z) faceAggregation[face][localPos.z + Z][localPos.y + Y][localPos.x + X]
#define faOffsetVec(face, vec) faceAggregation[face][localPos.z + vec.z][localPos.y + vec.y][localPos.x + vec.x]

// In what direction the X/Y aggregation is growing for each of the 3 dimensions (LEFT/RIGHT | FRONT/BACK | TOP/BOTTOM)
const uint aggregationDim[2][3] = {{1,0,0}, {2,2,1}};
const ivec3 dimVec[3] = {ivec3(1,0,0), ivec3(0,1,0), ivec3(0,0,1)};

void loadToCache(ivec3 localPos) {
	ivec3 globalPos = localPos + ivec3(gl_WorkGroupID * gl_WorkGroupSize);

	const ivec2 idmPosx = mapsOffset.xy + globalPos.xy;
	const int idmIx = (idmPosx.y / ACTIVE_AREA_WIDTH) * 2 + (idmPosx.x / ACTIVE_AREA_WIDTH);
	const ivec2 idmPos = idmPosx % ACTIVE_AREA_WIDTH;

	const int z = mapsOffset.z + globalPos.z;
	const uint blockId = imageLoad(blockIDMaps[idmIx], ivec3(idmPos, z)).r;
	const uint blockData =
		z == -1
			? 63 << 16 // Do not render bottom of the chunk -> all faces are full
		: z == CHUNK_HEIGHT
			? 0 // Render top of the chunk
		:
			blockList[blockId] & 0xffff0000; // Else the last two bytes contain faces settings

	const ivec3 arrIx = localPos + 1;
	blockDataCache[arrIx.z][arrIx.y][arrIx.x] = blockId | blockData;
}

const ivec3 faceOffsets[6] = {
	ivec3(-1,0,0), ivec3(1,0,0),
	ivec3(0,-1,0), ivec3(0,1,0),
	ivec3(0,0,-1), ivec3(0,0,1)
};

void main() {
	const ivec3 localPos = ivec3(gl_LocalInvocationID);
	const uvec3 globalPos = gl_GlobalInvocationID;
	const ivec3 arrIx = localPos + 1;

	// First load data to cache
	{
		loadToCache(localPos);

		if(gl_LocalInvocationID.z < 6) {
			const uint offset = (gl_LocalInvocationID.z & 1) == 0 ? -1 : LOCAL_SIZE;
			const ivec3 vec =
				gl_LocalInvocationID.z < 2 ?
					ivec3(localPos.xy, offset)
				: gl_LocalInvocationID.z < 4 ?
					ivec3(localPos.x, offset, localPos.y)
				:
					ivec3(offset, localPos.xy);

			loadToCache(vec);
		}
	}

	memoryBarrierShared();
	barrier();

	const uint bd = blockDataCache[arrIx.z][arrIx.y][arrIx.x];
	const uint blockId = bd & 0xffff;
	const uint blockData = (bd >> 16) & 0xffff;

	// Air - no need to do anything else
	if(blockId == 0)
		return;

	const bool isOpenTopFace = (blockData & BLOCK_OPEN_TOP_BIT) != 0;

	uint visibleFaces = 0;
	for(uint i = 0; i < 6; i++) {
		const uint otherBd = bdcOffsetVec(faceOffsets[i]);
		const uint otherBlockId = bdcId(otherBd);
		const uint otherBlockData = bdcData(otherBd);

		// bits 0-5 contain information of which block faces of the block are fully covered
		// ^1 - we're looking on the opposite face (when lookin left -> check right face) | opposite faces differ in the bit 0
		const bool isVisibleFace =
			((otherBlockData >> (i ^ 1)) & 1) == 0 // Neighbour is not full face
			|| ((otherBlockData & BLOCK_TRANSPARENT_FACES_BIT) != 0 && (otherBlockId != blockId)) // Or the neighbour is a transparent face
			|| (i == FACE_TOP && isOpenTopFace && (otherBlockId != blockId)) // Or the block is open top (top joins only to the same block id)
			;

		visibleFaces |= (isVisibleFace ? 1 : 0) << i;
	}

	#if AGGREGATION
		// We will be editing blockDataCache, so ensure that everyone if finished by now
		barrier();

		// We reuse the block data for the aggregation (now blockId & aggregated faces are stored there)
		blockDataCache[arrIx.z][arrIx.y][arrIx.x] = blockId | (visibleFaces << 16);

		// Set aggregation to 1x1 for visible faces and 0x0 for invisible ones
		for(uint i = 0; i < 6; i++)
			faThis(i) = ((visibleFaces >> i) & 1) * 0x11;

		memoryBarrierShared();
		barrier();
	#endif

	// Lines aggregation does not go 2D, but tries to aggregate faces in a single line
	#if AGGREGATION == AGGREGATION_LINES
		#include "render/aggregation_lines.cs.glsl"

	#elif AGGREGATION == AGGREGATION_SQUARES
		#include "render/aggregation_squares.cs.glsl"

	#elif AGGREGATION == AGGREGATION_SQUARES_EXT
		#include "render/aggregation_squares.cs.glsl"
		#include "render/aggregation_squaresExt.cs.glsl"

	#endif

	// No faces rendered - do not render the block
	if(visibleFaces == 0)
		return;

	#if AGGREGATION
		#define PACKED_AGGREGATION(face, offset) (faThis(face) << offset)
	#else
		#define PACKED_AGGREGATION(face, offset) (0x11 << offset)
	#endif

	const uvec4 data = uvec4(
		globalPos.x | (globalPos.y << 4) | (globalPos.z << 8) | (visibleFaces << 16),
		PACKED_AGGREGATION(0, 0) | PACKED_AGGREGATION(1, 8) | PACKED_AGGREGATION(2, 16) | PACKED_AGGREGATION(3, 24),
		PACKED_AGGREGATION(4, 0) | PACKED_AGGREGATION(5, 8),
		0);

	// If this block has aggregated all sides, nothing is actually rendered, so we don't need to send it to the CPU at all
	if(data[1] == 0 && data[2] == 0 && (blockData & BLOCK_NONUNIFORM_BIT) == 0)
		return;

	const uint recordIx = atomicCounterIncrement(recordCount);
	records[recordIx] = data;
}