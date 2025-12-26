#version 330 compatibility

/*
const int colortex0Format = RGB16F;
*/

uniform sampler2D colortex0;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
	vec3 hdrScene = texture(colortex0, texcoord).rgb;

	hdrScene = hdrScene / (hdrScene + vec3(1.0));
	hdrScene = pow(hdrScene, vec3(1.0 / 2.2));

  color = vec4(hdrScene, 1.0);
}