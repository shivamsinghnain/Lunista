#version 450 core

#include "/lib/downsample.glsl"

/*
const int colortex5Format = R11F_G11F_B10F;
*/

uniform sampler2D colortex5; // Bright emissive extracted

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 bloomTile;

void main() {

  vec2 srcResolution = vec2(viewWidth, viewHeight);

  // 0.5
  float scale = 2.0;
  vec2 tileRes = srcResolution / scale;
  vec2 texelSize = 1.0 / tileRes;
  // vec2 uv = texcoord * 2.0;
  vec2 uv = texcoord;
  bloomTile = vec4(downsample(colortex5, uv, texelSize), 1.0);

  bloomTile = max(bloomTile, 0.00001); // Prevent zero bloom tiles
}