#version 330 compatibility

#include "/lib/distort.glsl"

attribute vec4 mc_Entity;

out vec2 texcoord;
out vec4 glcolor;

uniform float frameTimeCounter;

uniform vec3 cameraPosition;

in vec4 at_midBlock;

uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;

#define WIND_SPEED 0.75
#define WAVE_AMP 1.0
#define WIND_SHAPE 0.33

const float PI = 3.14159265359;

bool getFoliageTopVertex(float worldY) {
	float bottomY = (worldY + (at_midBlock.y / 64.0)) - 0.45;
	return worldY > bottomY;
}

//////////////////////////////////////////////////////////////////////////////////////
// https://scispace.com/pdf/interactive-grass-rendering-using-real-time-tessellation-4szv1ctx1k.pdf
float notsure(vec3 pos) {
	float num = PI / 4.0;
	float denom = cos(pow(WAVE_AMP, 2.0) * PI * pos.z) + 1e-6;

	float a = PI * pos.x + frameTimeCounter + (num / denom);

	return a;
}

float windFunction(vec3 pos) {
	return sin(WIND_SPEED * notsure(pos)) * cos(pow(WIND_SPEED, 3.0) * notsure(pos));

}
//////////////////////////////////////////////////////////////////////////////////////

void main() {
  texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
  glcolor = gl_Color;

  vec4 pos = gl_Vertex;
	pos = gl_ModelViewMatrix * pos; // viewPos
	pos.xyz = (shadowModelViewInverse * vec4(pos.xyz, 1.0)).xyz; // playerPos
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
	pos.xyz = (shadowModelView * vec4(pos.xyz, 1.0)).xyz;
	pos = gl_ProjectionMatrix * pos;

	gl_Position = pos;
  gl_Position.xyz = distortShadowClipPos(gl_Position.xyz);
}