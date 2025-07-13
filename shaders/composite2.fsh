#version 330 compatibility

/*
const int colortex0Format = R11F_G11F_B10F;
const int colortex5Format = R11F_G11F_B10F;
*/

uniform sampler2D colortex0;
uniform sampler2D colortex5; // Bright emissive extracted

uniform float viewWidth;

in vec2 texcoord;

/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 blurredHorizontal;

const float weight[5] = float[] (0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216);

void main() {
  color = texture(colortex0, texcoord);

  float texelSize = 1.0 / viewWidth;
  vec3 result = texture(colortex5, texcoord).rgb * weight[0];

  for(int i = 1; i < 5; ++i) {
    result += texture(colortex5, texcoord + vec2(texelSize * i, 0.0)).rgb * weight[i];
    result += texture(colortex5, texcoord - vec2(texelSize * i, 0.0)).rgb * weight[i];
  }

  blurredHorizontal = vec4(result, 1.0);
}