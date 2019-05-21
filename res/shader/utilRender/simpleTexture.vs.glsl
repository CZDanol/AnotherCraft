#version 430

uniform mat4 viewMatrix;

in vec2 uv;
out vec2 uv_;

void main() {
	gl_Position = viewMatrix * vec4(uv, 0, 1);
	uv_ = vec2(uv.x, 1 - uv.y);
}