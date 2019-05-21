#version 430

uniform sampler2D tex;

in vec2 uv_;

layout(location = 0) out vec4 color;

void main() {
	color = texture(tex, uv_);
}