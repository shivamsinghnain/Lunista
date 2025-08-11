#version 450 core

/*
const int colortex0Format = R11F_G11F_B10F;
const int colortex5Format = R11F_G11F_B10F;
*/

//#define BLOOM
//#define BLOOM_INTENSITY

uniform sampler2D colortex0;
uniform sampler2D colortex5; //Bloom

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

vec3 uncharted2Tonemap(vec3 x) {
  float A = 0.15;
  float B = 0.50;
  float C = 0.10;
  float D = 0.20;
  float E = 0.02;
  float F = 0.30;
  float W = 11.2;
  return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

vec3 uncharted2(vec3 color) {
  const float W = 11.2;
  float exposureBias = 2.0;
  vec3 curr = uncharted2Tonemap(exposureBias * color);
  vec3 whiteScale = 1.0 / uncharted2Tonemap(vec3(W));
  return curr * whiteScale;
}

#define BLOOM_INTENSITY 1.0 // [ 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 ]

void main() {
	vec3 hdrScene = texture(colortex0, texcoord).rgb;
	vec3 bloom = texture(colortex5, texcoord).rgb;

  vec3 finalBloom = bloom * BLOOM_INTENSITY;

	vec3 hdrFinalScene = hdrScene;

  #ifdef BLOOM
  hdrFinalScene = hdrScene + finalBloom;
  #endif

	vec3 hdrFinal = uncharted2(hdrFinalScene);

	vec3 finalScene = pow(hdrFinal, vec3(1.0 / 2.2));

  color = vec4(finalScene, 1.0);
}