#version 330 compatibility

#include /lib/upsample.glsl

/*
const int colortex7Format = R11F_G11F_B10F;
const int colortex8Format = R11F_G11F_B10F;
*/

uniform sampler2D colortex7;    // Current level bloom
uniform sampler2D colortex8;    // Lower-res bloom

in vec2 texcoord;

/* RENDERTARGETS: 7 */
layout(location = 0) out vec4 upsampledBloom;

void main() {

    vec2 upsampledUV = texcoord;
    vec3 upsampled = upsample(colortex8, upsampledUV);

    vec3 base = texture(colortex7, texcoord).rgb;

    vec3 combined = base + upsampled;

    upsampledBloom = vec4(combined, 1.0);
}