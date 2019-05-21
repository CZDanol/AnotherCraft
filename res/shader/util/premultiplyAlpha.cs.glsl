#version 430

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba8, binding = 0) uniform image2DArray img;

void main() {
	const ivec3 resolution = imageSize(img);
	const ivec3 pos = ivec3(gl_GlobalInvocationID.xyz);

	if(pos.x >= resolution.x || pos.y >= resolution.y)
		return;

	vec4 color = imageLoad(img, pos);
	color.rgb *= color.a;
	imageStore(img, pos, color);
}