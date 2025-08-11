#version 450 core

#include "/lib/upsample.glsl"

/*
const int colortex9Format = R11F_G11F_B10F;
const int colortex10Format = R11F_G11F_B10F;
*/

uniform sampler2D colortex9;    // Current level bloom
uniform sampler2D colortex10;    // Lowest-res bloom

in vec2 texcoord;

/* RENDERTARGETS: 9 */
layout(location = 0) out vec4 upsampledBloom;

void main() {

    vec2 upsampledUV = texcoord;
    vec3 upsampled = upsample(colortex10, upsampledUV);

    vec3 base = texture(colortex9, texcoord).rgb;

    vec3 combined = base + upsampled;

    upsampledBloom = vec4(combined, 1.0);
}