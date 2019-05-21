#version 430

/*
	This shader propagates the light iteratively to neighbour blocks
*/

#define LOCAL_ACTIVE_AREA_WIDTH (CHUNK_WIDTH * 3)
#define ITERATION_COUNT 4

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(r16ui, binding = 0) readonly uniform uimage3D blockIDMaps[4];
layout(rgba8, binding = 4) uniform image3D lightMap;

layout(location = 0) uniform ivec2 mapsOffset;
layout(location = 1) uniform uint offset;

layout(binding = 0, std430) buffer BlockList {
	uint[] blockList;
};

shared vec4 lightValues[gl_WorkGroupSize.z][gl_WorkGroupSize.y][gl_WorkGroupSize.x];
shared bool changed;

void main() {
	const ivec3 pos = ivec3((gl_GlobalInvocationID.xyz + offset) % uvec3(LOCAL_ACTIVE_AREA_WIDTH, LOCAL_ACTIVE_AREA_WIDTH, CHUNK_HEIGHT));

	// Topology info
	const bool isOnLeftEdge = pos.x == 0 || gl_LocalInvocationID.x == 0;
	const bool isOnRightEdge = pos.x == LOCAL_ACTIVE_AREA_WIDTH - 1 || gl_LocalInvocationID.x == gl_WorkGroupSize.x - 1;

	const bool isOnFrontEdge = pos.y == 0 || gl_LocalInvocationID.y == 0;
	const bool isOnBackEdge = pos.y == LOCAL_ACTIVE_AREA_WIDTH - 1 || gl_LocalInvocationID.y == gl_WorkGroupSize.y - 1;

	const bool isOnBottomEdge = pos.z == 0 || gl_LocalInvocationID.z == 0;
	const bool isOnTopEdge = pos.z == CHUNK_HEIGHT - 1 || gl_LocalInvocationID.z == gl_WorkGroupSize.z - 1;

	// Light setup
	const ivec3 idmPosx = ivec3(mapsOffset, 0) + pos;
	const int idmIx = (idmPosx.y / ACTIVE_AREA_WIDTH) * 2 + (idmPosx.x / ACTIVE_AREA_WIDTH);
	const ivec3 idmPos = ivec3(idmPosx.xy % ACTIVE_AREA_WIDTH, idmPosx.z);

	const uint blockId = imageLoad(blockIDMaps[idmIx], idmPos).r;
	const uint blockData = blockList[blockId];
	const uint lightProperties = blockData; // First 2 bytes of the block data is light properties

	const float lightDecrease = float(1 + (lightProperties & 0xf)) / MAX_LIGHT_VALUE;

	vec4 lightValue = imageLoad(lightMap, pos);
	lightValues[gl_LocalInvocationID.z][gl_LocalInvocationID.y][gl_LocalInvocationID.x] = lightValue;

	changed = false;

	memoryBarrierShared();
	barrier();

	for(uint i = 0; i < ITERATION_COUNT; i++) {
		const vec4 maxX = max(
			isOnLeftEdge ? vec4(0) : lightValues[gl_LocalInvocationID.z][gl_LocalInvocationID.y][gl_LocalInvocationID.x - 1],
			isOnRightEdge ? vec4(0) : lightValues[gl_LocalInvocationID.z][gl_LocalInvocationID.y][gl_LocalInvocationID.x + 1]
		);

		const vec4 maxY = max(
			isOnFrontEdge ? vec4(0) : lightValues[gl_LocalInvocationID.z][gl_LocalInvocationID.y - 1][gl_LocalInvocationID.x],
			isOnBackEdge ? vec4(0) : lightValues[gl_LocalInvocationID.z][gl_LocalInvocationID.y + 1][gl_LocalInvocationID.x]
		);

		const vec4 maxZ = max(
			isOnBottomEdge ? vec4(0) : lightValues[gl_LocalInvocationID.z - 1][gl_LocalInvocationID.y][gl_LocalInvocationID.x],
			isOnTopEdge ? vec4(0) : lightValues[gl_LocalInvocationID.z + 1][gl_LocalInvocationID.y][gl_LocalInvocationID.x]
		);

		const vec4 maxXY = max(maxX, maxY);
		const vec4 maxXYZ = max(maxXY, maxZ);

		const vec4 oldLightValue = lightValue;
		lightValue = max(lightValue, maxXYZ - lightDecrease);

		if(oldLightValue != lightValue)
			changed = true;

		barrier();

		lightValues[gl_LocalInvocationID.z][gl_LocalInvocationID.y][gl_LocalInvocationID.x] = lightValue;

		memoryBarrierShared();
		barrier();

		if(!changed)
			break;
	}

	imageStore(lightMap, pos, lightValue);
}