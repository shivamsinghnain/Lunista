#version 330 compatibility

#include "/lib/distort.glsl"

/*
const int colortex0Format = R11F_G11F_B10F;
*/

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

uniform sampler2D depthtex0;

uniform int worldTime;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform float far;

in vec2 texcoord;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
    vec4 homPos = projectionMatrix * vec4(position, 1.0);
    return homPos.xyz / homPos.w;
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

const vec3 sunlightColor = vec3(1.0, 0.95, 0.8);
const vec3 moonlightColor = vec3(0.1, 0.1, 0.3);

const float fogDensityDay = 1.0;
const float fogDensityNight = 1.5;

void main() {
    color = texture(colortex0, texcoord);

    float depth = texture(depthtex0, texcoord).r;
    float fogFactor;

    bool isNight = worldTime >= 13000 && worldTime < 24000;
    vec3 fogTint = isNight ? moonlightColor : sunlightColor;
    float fogDensity = isNight ? fogDensityNight : fogDensityDay;

    vec3 fogColor = isNight ? vec3(0.08, 0.08, 0.08) : vec3(0.6, 0.7, 0.8);

    vec3 finalFogColor = fogColor * fogTint;

    if (depth == 1.0) {
        float horizonFog = smoothstep(0.0, 1.0, (1.0 - texcoord.y) * 1.5);
        fogFactor = horizonFog * 0.6;
    } else {
        vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
        vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
        vec4 worldPos4 = gbufferModelViewInverse * vec4(viewPos, 1.0);
        vec3 worldPos = worldPos4.xyz;

        vec3 cameraPos = (gbufferModelViewInverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
        float worldDistance = distance(worldPos, cameraPos);

        fogFactor = 1.0 - exp(-fogDensity * (worldDistance / far));
    }

    fogFactor = clamp(fogFactor, 0.0, 1.0);
    fogFactor = smoothstep(0.0, 1.0, fogFactor);
    color.rgb = mix(color.rgb, finalFogColor, fogFactor);
}