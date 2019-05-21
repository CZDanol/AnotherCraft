#version 430

in vec4 pos;
in uint color;

out vec4 color_;

const vec4 colors[] = {
	vec4(1,0,0,1),
	vec4(0,1,0,1),
	vec4(0,0,1,1),
	vec4(1,1,0,1),
	vec4(1,0,1,1),
	vec4(0,1,1,1),
	vec4(0,0,0,1),
};

void main() {
	gl_Position = pos;
	color_ = colors[color];
}