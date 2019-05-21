#version 430

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(r16ui, binding = 0) uniform uimage3D chunk;
uniform ivec3 chunkPos;
uniform uint globalSeed;

__WORLDGEN_BINDINGS__

#include "util/hash.glsl"
#include "worldgen/common.glsl"

#ifdef USE_PERLIN
#include "worldgen/perlinCommon.glsl"
#include "worldgen/perlin3D.glsl"
#endif

#ifdef USE_VORONOI_3D
#include "worldgen/voronoi3D.glsl"
#endif

void main() {
	const ivec3 localPos = ivec3(ivec2(gl_GlobalInvocationID.xy) - CHUNK_WIDTH, gl_GlobalInvocationID.z);
	const ivec3 globalPos = chunkPos + localPos;

	__WORLDGEN_CODE__
}