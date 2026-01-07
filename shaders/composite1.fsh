#version 330 compatibility

/*
const int colortex0Format = RGB16F;
*/

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

#define CLOUD_3D_NOISE_TEXEL_SIZE_M 32.0 // 32m per texel
const float CLOUD_3D_NOISE_TEXTURE_SIZE_M = 128.0 * CLOUD_3D_NOISE_TEXEL_SIZE_M; // 4096m per tiling of the 3D texture
const float CLOUD_3D_NOISE_TEXTURE_SIZE_L = 512.0 * CLOUD_3D_NOISE_TEXEL_SIZE_M; // 4096m per tiling of the 3D texture

uniform sampler3D alligatorNoiseTex;

uniform sampler2D perlinNoiseTex;
uniform sampler2D worleyNoiseTex;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform vec3 cameraPosition;

uniform vec3 shadowLightPosition;

in vec2 texcoord;

const vec3 planetLightColor = vec3(23.47, 21.31, 20.79);

const float MAX_STEPS = 120;

const float CLOUD_ALTITUDE = 1200.0;
const float CLOUD_HEIGHT = 500.0;

const float GLOBAL_COVERAGE_AMOUNT = 0.5;

// float random3D(in vec3 p) {
//     return fract(sin(p.x * 456.0 + p.y * 56.0 + p.z * 741.0) * 100.0);
// }

// vec3 smoothv2(in vec3 v) {
//     return v * v * (3.0 - 2.0 * v);
// }

// float smoothNoise3D(in vec3 p) {
//     vec3 f = smoothv2(fract(p));

//     float a = random3D(floor(p));
//     float b = random3D(vec3(ceil(p.x), floor(p.y), floor(p.z)));
//     float c = random3D(vec3(floor(p.x), ceil(p.y), floor(p.z)));
//     float d = random3D(vec3(ceil(p.xy), floor(p.z)));

//     float bottom = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);

//     a = random3D(vec3(floor(p.x), floor(p.y), ceil(p.z)));
//     b = random3D(vec3(ceil(p.x), floor(p.y), ceil(p.z)));
//     c = random3D(vec3(floor(p.x), ceil(p.y), ceil(p.z)));
//     d = random3D(vec3(ceil(p.xy), ceil(p.z)));

//     float top = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);

//     return mix(bottom, top, f.z);
// }

// float fractalNoise3D(in vec3 p) {
//     float total = 0.5;
//     float amplitude = 1.0;
//     float frequency = 2.0;
//     float iterations = 4.0;
    
//     for (float i = 0; i < iterations; i++) {
//         total += (smoothNoise3D(p * frequency) - 0.5) * amplitude;
//         amplitude *= 0.5;
//         frequency *= 2.0;
//     }

//     return total;
// }

// float getCloud(vec3 p) {
//     return clamp((fractalNoise3D(p) * fractalNoise3D(p * 0.25) * fractalNoise3D(p * 0.12) * 4.0 - 0.5) * 1.5 + 0.5, 0.0, 1.0);
// }

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position) {
    vec4 homPos = projectionMatrix * vec4(position, 1.0);
    return homPos.xyz / homPos.w;
}

float beersLaw(float dist, float absorption) {
    return exp(-dist * absorption);
}

float remap2(float x, float edge0, float edge1) {
    return clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
}

bool getCloudUV(in vec3 rayOrigin, in vec3 rayDirection, out vec3 startPos, out vec3 endPos) {
    float upperCloudLayer = CLOUD_ALTITUDE + CLOUD_HEIGHT;
    float lowerCloudLayer = CLOUD_ALTITUDE;

    float t1 = max((upperCloudLayer - rayOrigin.y) / rayDirection.y, 0.0);
    float t2 = max((lowerCloudLayer - rayOrigin.y) / rayDirection.y, 0.0);
    if (abs(t1) == - abs(t2)) return false;

    startPos = rayOrigin + min(t1, t2) * rayDirection;
    endPos = rayOrigin + max(t1, t2) * rayDirection;

    return true;
}

float getDensity(vec3 rayPos) {
    vec4 alligatorNoise = textureLod(alligatorNoiseTex, rayPos / CLOUD_3D_NOISE_TEXTURE_SIZE_M, 0.0);

    float baseDensityFBM = alligatorNoise.g * 0.5 + alligatorNoise.b * 0.35 + alligatorNoise.a * 0.15; 
    float baseDensity = remap2(alligatorNoise.x, baseDensityFBM - 1.0, 1.0);
    
    vec4 perlinNoise = textureLod(perlinNoiseTex, rayPos.xz / CLOUD_3D_NOISE_TEXTURE_SIZE_L, 0.0);
    vec4 worleyNoise = textureLod(worleyNoiseTex, rayPos.xz / CLOUD_3D_NOISE_TEXTURE_SIZE_L, 0.0);

    float cloudCoverage = remap2(perlinNoise.x, GLOBAL_COVERAGE_AMOUNT - 1.0, 1.0);
    float cloudDensity = clamp(baseDensity - (1.0 - cloudCoverage), 0.0, 1.0);

    return cloudDensity;
}

vec4 raymarch(vec3 rayOrigin, vec3 rayDirection, vec3 planetLightColor) {
    vec3 startPos;
    vec3 endPos;

    // Check if the ray hits the cloud plane
    bool hitPlane = getCloudUV(rayOrigin, rayDirection, startPos, endPos);
    // If not exit early
    if (!hitPlane) {
        return vec4(0.0);
    }

    // main function
    vec3 scattering = vec3(0.0);
    float transmittance = 1.0;

    float scatteringCoefficient = 0.01;
    float absorptionCoefficient = 0.00;

    float extinctionCoefficient = scatteringCoefficient + absorptionCoefficient;

    vec3 raySteps = (endPos - startPos) / float(MAX_STEPS);
    float rayStepLength = length(raySteps);

    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 rayPos = startPos + raySteps * float(i);

        float sampleDensity = getDensity(rayPos) * rayStepLength;

        if (sampleDensity > 1e-6) {
            float transmittanceAtPoint = beersLaw(sampleDensity, scatteringCoefficient);

            vec3 scatteredLight = planetLightColor * scatteringCoefficient * 1.0;
            vec3 integratedScatteringAtPoint = (scatteredLight - scatteredLight * transmittanceAtPoint);

            scattering += integratedScatteringAtPoint * transmittance;
            transmittance *= transmittanceAtPoint;
        }
    }
    return vec4(scattering, transmittance);
}

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

void main() {
    color = texture(colortex0, texcoord);

    float depth = texture(depthtex0, texcoord).r;
  
    if (depth == 1.0) {
        vec3 screenPos = vec3(texcoord, depth);
        vec3 ndcPos = screenPos * 2.0 - 1.0;
        vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);
        vec3 playerFeetPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 eyePlayerPos = playerFeetPos - gbufferModelViewInverse[3].xyz;

        vec3 eyeCameraPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

        vec3 worldPos = playerFeetPos + cameraPosition;

        vec3 rayOrigin = eyeCameraPosition;
        vec3 rayDir = normalize(worldPos - rayOrigin);

        if (rayDir.y < 0.0) return;

        vec4 res = raymarch(rayOrigin, rayDir, planetLightColor);
        color.rgb = color.rgb * res.a + res.rgb;
    }
}