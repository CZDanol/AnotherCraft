#version 430

layout(local_size_x = 64) in;

layout(r16ui, binding = 0) uniform uimage3D chunk;
uniform ivec3 chunkPos;
uniform uint globalSeed;
uniform uint itemCount;

__WORLDGEN_BINDINGS__

#include "util/hash.glsl"
#include "worldgen/common.glsl"

void main() {
	const uint ix = gl_GlobalInvocationID.x;

	if(ix >= itemCount)
		return;

	__WORLDGEN_CODE__
}