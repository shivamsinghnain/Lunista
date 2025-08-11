#version 450 core

in vec4 at_tangent;

out vec2 lmcoord;
out vec2 texcoord;
out vec4 glcolor;
out vec3 normal;

out vec3 vTangent;
out vec3 vBitangent;
out vec3 vNormal;

uniform mat4 gbufferModelViewInverse;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmcoord = (lmcoord * 33.05 / 32.0) - (1.05 / 32.0);
	glcolor = gl_Color;

	vNormal = gl_NormalMatrix * gl_Normal; // this gives us the normal in view space
	normal = mat3(gbufferModelViewInverse) * vNormal; // this converts the normal to world/player space
	
	vNormal = mat3(gbufferModelViewInverse) * vNormal; // this gives us the normal in view space

	vTangent = gl_NormalMatrix * at_tangent.xyz;
	vTangent = mat3(gbufferModelViewInverse) * vTangent; // this gives us the normal in view space

	vBitangent = cross(vTangent, vNormal) * (at_tangent.w < 0.0 ? -1.0 : 1.0);

	
}