#version 330 compatibility

/*
const int colortex0Format = RGB16;
*/

//#define toneMap

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;


// //Lottes Tonemapping
// vec3 lottes(vec3 x) {
//   const vec3 a = vec3(1.6);
//   const vec3 d = vec3(0.977);
//   const vec3 hdrMax = vec3(8.0);
//   const vec3 midIn = vec3(0.18);
//   const vec3 midOut = vec3(0.267);

//   const vec3 b =
//       (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
//       ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
//   const vec3 c =
//       (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) /
//       ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);

//   return pow(x, a) / (pow(x, a * d) * b + c);
// }


//Aces Tonemapping
// vec3 aces(vec3 x) {
//   const float a = 2.51;
//   const float b = 0.03;
//   const float c = 2.43;
//   const float d = 0.59;
//   const float e = 0.14;
//   return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
// }

// vec3 ACESFitted(vec3 x) {
//     const float a = 2.0;  // reduced from 2.51
//     const float b = 0.0;
//     const float c = 2.0;  // reduced from 2.43
//     const float d = 0.4;  // reduced from 0.59
//     const float e = 0.05; // raised from 0.14
//     return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
// }

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

// vec3 UchimuraTonemap(vec3 x) {
//     const float P = 1.0;   // max display brightness
//     const float a = 1.0;   // contrast
//     const float m = 0.22;  // linear section start
//     const float l = 0.4;   // linear section length
//     const float c = 1.33;  // black level
//     const float b = 0.0;   // pedestal

//     vec3 r = ((x - m) * a + b) / ((x - m) * a + l) + c;
//     return clamp(r, 0.0, 1.0);
// }

// vec3 PBRNeutralToneMapping(vec3 color) {
//   const float startCompression = 0.8 - 0.04;
//   const float desaturation = 0.15;

//   float x = min(color.r, min(color.g, color.b));
//   float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
//   color -= offset;

//   float peak = max(color.r, max(color.g, color.b));
//   if (peak < startCompression) return color;

//   const float d = 1. - startCompression;
//   float newPeak = 1. - d * d / (peak + d - startCompression);
//   color *= newPeak / peak;

//   float g = 1. - 1. / (desaturation * (peak - newPeak) + 1.);
//   return mix(color, newPeak * vec3(1, 1, 1), g);
// }

void main() {
	color = texture(colortex0, texcoord);
	
	#ifdef toneMap
		color.rgb = uncharted2(color.rgb);
	#endif

	float depth = texture(depthtex0, texcoord).r;

	if (depth == 1.0) {
		color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
		return;
	}

	// Gamma correction
	color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
}