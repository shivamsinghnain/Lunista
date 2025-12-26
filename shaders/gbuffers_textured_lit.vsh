#version 330 compatibility

in vec4 at_tangent;

out vec2 lmcoord;
out vec2 texcoord;
out vec3 glcolor;
out float occlusion;

out vec3 tangent;
out vec3 bitangent;
out vec3 normal;

uniform mat4 gbufferModelViewInverse;

void main() {
	gl_Position = ftransform();
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmcoord = (lmcoord * 33.05 / 32.0) - (1.05 / 32.0);
	glcolor = gl_Color.rgb;
	occlusion = gl_Color.a;

	normal = gl_NormalMatrix * gl_Normal;
	normal = mat3(gbufferModelViewInverse) * normal; // this gives us normal in player space;

	tangent = gl_NormalMatrix * at_tangent.xyz;
	tangent = mat3(gbufferModelViewInverse) * tangent; // this gives us the tangent in player space

	bitangent = cross(tangent, normal) * (at_tangent.w < 0.0 ? -1.0 : 1.0);
}