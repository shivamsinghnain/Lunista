#version 330 compatibility

/*
const int colortex0Format = RGB16;
*/

uniform sampler2D colortex0;

uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform float far;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

vec3 lottes(vec3 x) {
  const vec3 a = vec3(1.6);
  const vec3 d = vec3(0.977);
  const vec3 hdrMax = vec3(8.0);
  const vec3 midIn = vec3(0.18);
  const vec3 midOut = vec3(0.267);

  const vec3 b =
      (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
      ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
  const vec3 c =
      (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) /
      ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);

  return pow(x, a) / (pow(x, a * d) * b + c);
}

void main() {
	color = texture(colortex0, texcoord);

	float depth = texture(depthtex0, texcoord).r;
	if (depth == 1.0) {
		color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
	    return;
	}

	vec3 ndc = vec3(texcoord * 2.0 - 1.0, depth);
	vec4 viewPos = gbufferProjectionInverse * vec4(ndc, 1.0);
	viewPos /= viewPos.w;

	vec4 worldPos4 = gbufferModelViewInverse * viewPos;
	vec3 worldPos = worldPos4.xyz;

	// TEMP DEBUG COLOR: fog intensity based on distance
	vec3 cameraPos = (gbufferModelViewInverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = distance(worldPos, cameraPos);
	float fogFactor = 1.0 - exp(-2.0 * dist / far);
	fogFactor = clamp(fogFactor, 0.0, 1.0);

	color.rgb = lottes(color.rgb);

	// Gamma correction
	color.rgb = pow(color.rgb, vec3(1.0 / 2.2));
}