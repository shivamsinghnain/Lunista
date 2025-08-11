#version 450 core

#include "/lib/downsample.glsl"

/*
const int colortex6Format = R11F_G11F_B10F;
*/

uniform sampler2D colortex6; // Bright emissive extracted

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 bloomTile;

void main() {

    vec2 srcResolution = vec2(viewWidth, viewHeight);

    // 0.25
    float scale = 4.0;
    vec2 tileRes = srcResolution / scale;
    vec2 texelSize = 1.0 / tileRes;
    //   vec2 uv = (texcoord - vec2(0.5, 0.0)) * 4.0;
    vec2 uv = texcoord;
    bloomTile = vec4(downsample(colortex6, uv, texelSize), 1.0);
}