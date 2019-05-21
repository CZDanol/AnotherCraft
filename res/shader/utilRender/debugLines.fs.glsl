#version 430

in vec4 color_;

layout(location = 0) out vec4 color;

void main() {
	color = color_;
}