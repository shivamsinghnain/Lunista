#version 330 compatibility

#include /lib/downsample.glsl

/*
const int colortex7Format = R11F_G11F_B10F;
*/

uniform sampler2D colortex7;

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

/* RENDERTARGETS: 8 */
layout(location = 0) out vec4 bloomTile;

void main() {

    vec2 srcResolution = vec2(viewWidth, viewHeight);

    // 0.125
    float scale = 8.0;
    vec2 tileRes = srcResolution / scale;
    vec2 texelSize = 1.0 / tileRes;
    // vec2 uv = (texcoord - vec2(0.75, 0.0)) * 8.0;
    vec2 uv = texcoord;
    bloomTile = vec4(downsample(colortex7, uv, texelSize), 1.0);
}
