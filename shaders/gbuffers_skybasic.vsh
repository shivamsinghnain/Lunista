#version 450 core

out vec4 glcolor;

void main() {
	gl_Position = ftransform();
	glcolor = gl_Color;
}
