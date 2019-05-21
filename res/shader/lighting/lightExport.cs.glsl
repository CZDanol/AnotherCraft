#version 430

/*
	This shader prepares the light map for computations
	It sets the lightness levels from glow map + distributes the daylight in the vertical axis
*/

layout(local_size_x = 4, local_size_y = 4, local_size_z = 4) in;

layout(location = 0) uniform ivec3 offsetInArea;

layout(r16ui, binding = 0) writeonly uniform uimage2DArray areaLightMap;
layout(rgba8, binding = 4) readonly uniform image3D lightMap;

void main() {
	const ivec3 pos = ivec3(gl_GlobalInvocationID);
	const ivec3 localPos = ivec3(pos.xy + CHUNK_WIDTH, pos.z);
	const vec4 light = imageLoad(lightMap, localPos);

	// Inverting daylight value so that black color (outside light areas, most notably above) is full daylight instead of black
	const uvec4 lightU = uvec4(round(light * 15));
	const uint lightVal = lightU.r | (lightU.g << 4) | (lightU.b << 8) | (lightU.a << 12);

	imageStore(areaLightMap, pos + offsetInArea, uvec4(lightVal, 0, 0, 0));
} 