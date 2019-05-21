#version 430

uniform sampler2DMS tex;

in vec2 uv_;

layout(location = 0) out vec4 color;

void main() {
	color = texelFetch(tex, ivec2(uv_), 1);
}