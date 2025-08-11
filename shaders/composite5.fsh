#version 450 core

#include "/lib/downsample.glsl"

/*
const int colortex8Format = R11F_G11F_B10F;
*/

uniform sampler2D colortex8;

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

/* RENDERTARGETS: 9 */
layout(location = 0) out vec4 bloomTile;

void main() {

    vec2 srcResolution = vec2(viewWidth, viewHeight);

    // 0.0625
    float scale = 16.0;
    vec2 tileRes = srcResolution / scale;
    vec2 texelSize = 1.0 / tileRes;
    // vec2 uv = (texcoord - vec2(0.875, 0.0)) * 16.0;
    vec2 uv = texcoord;
    bloomTile = vec4(downsample(colortex8, uv, texelSize), 1.0);
}
  