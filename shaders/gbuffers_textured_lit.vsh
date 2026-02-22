#version 400 compatibility

attribute vec4 mc_Entity;

in vec2 mc_midTexCoord;

in vec4 at_tangent;
in vec4 at_midBlock;

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

uniform sampler2D noisetex;

uniform float viewWidth;
uniform float viewHeight;

uniform vec3 cameraPosition;

uniform int worldTime;
uniform float frameTimeCounter;

#define WIND_SPEED 0.75
#define WAVE_AMP 1.0
#define WIND_SHAPE 0.25

const float PI = 3.14159265359;

bool getFoliageTopVertex(float worldY) {
	float bottomY = (worldY + (at_midBlock.y / 64.0)) - 0.45;
	return worldY > bottomY;
}

vec4 getNoise(vec2 coord){
  ivec2 screenCoord = ivec2(coord * vec2(viewWidth, viewHeight)); // exact pixel coordinate onscreen
  ivec2 noiseCoord = screenCoord % 64; // wrap to range of noiseTextureResolution
  return texelFetch(noisetex, noiseCoord, 0);
}

float notsure(vec3 pos) {
	float num = PI / 4.0;
	float denom = cos(pow(WAVE_AMP, 2.0) * PI * pos.z) + 1e-6;

	float a = PI * pos.x + frameTimeCounter + (num / denom);

	return a;
}

float windFunction(vec3 pos) {
	return sin(WIND_SPEED * notsure(pos)) * cos(pow(WIND_SPEED, 3.0) * notsure(pos));

}

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

	vec4 pos = gl_Vertex;
	pos = gl_ModelViewMatrix * pos; // viewPos
	pos.xyz = (gbufferModelViewInverse * vec4(pos.xyz, 1.0)).xyz; // playerPos
	pos.xyz += cameraPosition;

	bool topVertex = getFoliageTopVertex(pos.y);

	if (mc_Entity.x == 10002 && topVertex) {
		pos.xz += windFunction(pos.xyz) * WIND_SHAPE;
	}

	if (mc_Entity.x == 10003 && topVertex || mc_Entity.x == 10004) {
		pos.xz += windFunction(pos.xyz) * WIND_SHAPE * 0.55;
	}

	if (mc_Entity.x == 10004 && topVertex) {
		pos.xz += windFunction(pos.xyz) * WIND_SHAPE * 0.5;
	}

	pos.xyz -= cameraPosition;
	pos.xyz = (gbufferModelView * vec4(pos.xyz, 1.0)).xyz;
	pos = gl_ProjectionMatrix * pos;

	gl_Position = pos;
}