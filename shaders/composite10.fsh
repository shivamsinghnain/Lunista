#version 330 compatibility

#include "/lib/upsample.glsl"

/*
const int colortex6Format = RGB16F;
const int colortex7Format = RGB16F;
*/

uniform sampler2D colortex6;    // Current level bloom
uniform sampler2D colortex7;    // Lower-res bloom

in vec2 texcoord;

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 upsampledBloom;

void main() {

    vec2 upsampledUV = texcoord; 
    vec3 upsampled = upsample(colortex7, upsampledUV);

    vec3 base = texture(colortex6, texcoord).rgb;

    vec3 combined = base + upsampled;

    upsampledBloom = vec4(combined, 1.0);
}