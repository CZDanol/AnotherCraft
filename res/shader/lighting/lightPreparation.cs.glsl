#version 430

/*
	This shader prepares the light map for computations
	It sets the lightness levels from glow map + distributes the daylight in the vertical axis
*/

layout(local_size_x = 8, local_size_y = 8) in;

layout(location = 0) uniform ivec2 mapsOffset;

layout(r16ui, binding = 0) readonly uniform uimage3D blockIDMaps[4];
layout(rgba8, binding = 4) writeonly uniform image3D lightMap;

layout(binding = 0, std430) buffer BlockList {
	uint[] blockList;
};

void main() {
	const ivec2 idmPosx = mapsOffset + ivec2(gl_GlobalInvocationID.xy);
	const uint idmIx = (idmPosx.y / ACTIVE_AREA_WIDTH) * 2 + (idmPosx.x / ACTIVE_AREA_WIDTH);
	const ivec2 idmPos = idmPosx % ACTIVE_AREA_WIDTH;

	uint z = CHUNK_HEIGHT;
	int daylightValue = MAX_LIGHT_VALUE;

	while(z-- > 0) {
		const uint blockId = imageLoad(blockIDMaps[idmIx], ivec3(idmPos, z)).r;
		const uint blockData = blockList[blockId];
		const uint lightProperties = blockData; // First 2 bytes of the block data is light properties

		/// First four bits is the opacity
		daylightValue = max(0, daylightValue - int(lightProperties & 0xf));
		imageStore(lightMap, ivec3(gl_GlobalInvocationID.xy, z), vec4((lightProperties & 0xf0) >> 4, (lightProperties & 0xf00) >> 8, (lightProperties & 0xf000) >> 12, daylightValue) / MAX_LIGHT_VALUE);
	}
}