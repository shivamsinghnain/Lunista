#version 330 compatibility

attribute vec4 mc_Entity;

in vec2 mc_midTexCoord;

in vec4 at_tangent;

out vec2 lmcoord;
out vec2 texcoord;
out vec3 glcolor;
out float occlusion;

out vec3 tangent;
out vec3 bitangent;
out vec3 normal;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;

uniform vec3 cameraPosition;

uniform int worldTime;
uniform float frameTimeCounter;

#define GRASS_SPEED 0.43

void main() {
	// gl_Position = ftransform();
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

	vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;

	// if (mc_Entity.x == 10001) {
	// 	vec4 worldPos = gbufferModelViewInverse * vec4(viewPos.xyz, 1.0);
	// 	worldPos.xyz += cameraPosition;
	// 	worldPos.xyz += worldPos.xyz + sin(worldTime * 0.1) * 0.1;
	// }

	if (mc_Entity.x == 10002) {
		if (texcoord.y < mc_midTexCoord.y) {
			vec4 worldPos = gbufferModelViewInverse * vec4(viewPos.xyz, 1.0); 
			worldPos.xyz += cameraPosition;

			worldPos.xz += sin(worldPos.zx * frameTimeCounter * 0.03 * GRASS_SPEED) * 0.02 + sin(worldPos.xz * frameTimeCounter * 0.05 * GRASS_SPEED) * 0.03;
			worldPos.y += sin(worldPos.x * frameTimeCounter * 0.015 * GRASS_SPEED) * 0.01 + sin(worldPos.z * frameTimeCounter * 0.025 * GRASS_SPEED) * 0.015;

			worldPos.xyz -= cameraPosition;
			viewPos = gbufferModelView * vec4(worldPos.xyz, 1.0);
		}
	}

	gl_Position = gl_ProjectionMatrix * viewPos;
}