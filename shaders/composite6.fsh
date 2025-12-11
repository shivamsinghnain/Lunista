#version 330 compatibility

#include /lib/downsample.glsl

/*
const int colortex9Format = RGB16F;
*/

uniform sampler2D colortex9; // Bright emissive extracted

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

/* RENDERTARGETS: 10 */
layout(location = 0) out vec4 bloomTile;

void main() {    

    vec2 srcResolution = vec2(viewWidth, viewHeight);

    // 0.03125
    float scale = 32.0;
    vec2 tileRes = srcResolution / scale;
    vec2 texelSize = 1.0 / tileRes;
    // vec2 uv = (texcoord - vec2(0.9375, 0.0)) * 32.0;
    vec2 uv = texcoord;
    bloomTile = vec4(downsample(colortex9, uv, texelSize), 1.0);
}