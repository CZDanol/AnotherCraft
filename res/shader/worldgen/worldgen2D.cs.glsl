#version 430

layout(local_size_x = 8, local_size_y = 8) in;

layout(r32f) uniform image2D outTexture;
uniform ivec3 chunkPos;
uniform uint globalSeed;

__WORLDGEN_BINDINGS__

#include "util/hash.glsl"
#include "worldgen/common.glsl"

#ifdef USE_PERLIN
#include "worldgen/perlinCommon.glsl"
#include "worldgen/perlin2D.glsl"
#endif

#ifdef USE_VORONOI
#include "worldgen/voronoi2D.glsl"
#endif

void main() {
	const ivec2 localPos = ivec2(gl_GlobalInvocationID.xy) - CHUNK_WIDTH;
	const ivec2 globalPos = chunkPos.xy + localPos;

	__WORLDGEN_CODE__
}