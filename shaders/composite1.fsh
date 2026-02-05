#version 330 compatibility

/*
const int colortex0Format = RGB16F;
*/

//////////////////////////////////////////////////////////////////////////////////////

in vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

uniform sampler2D perlinNoiseTex;
uniform sampler2D worleyNoiseTex;

uniform sampler3D alligatorNoiseTex;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform int worldTime;

uniform vec3 shadowLightPosition;

//////////////////////////////////////////////////////////////////////////////////////

bool isNight = worldTime >= 13000 && worldTime < 24000;

const int MAX_STEPS = 64;
const int NUM_STEPS = 24;

#define CLOUD_3D_NOISE_TEXEL_SIZE_M 48.0
const float CLOUD_3D_NOISE_TEXTURE_SIZE_M = 128.0 * CLOUD_3D_NOISE_TEXEL_SIZE_M;

#define CLOUD_2D_NOISE_TEXEL_SIZE_M 64.0
const float CLOUD_2D_NOISE_TEXTURE_SIZE_M = 256.0 * CLOUD_2D_NOISE_TEXEL_SIZE_M; 

const float SCATTERING_COEFFICIENT = 0.01;
const float ABSORPTION_COEFFICIENT = 0.00;
const float EXTINCTION_COEFFICIENT = SCATTERING_COEFFICIENT + ABSORPTION_COEFFICIENT;

const float CLOUD_ALTITUDE = 1200.0;
const float CLOUD_HEIGHT = 500.0;

const float PI = 3.14159265359;

const float GLOBAL_COVERAGE_AMOUNT = 0.9;

vec3 PLANET_LIGHT_COLOR = isNight ? vec3(0.1, 0.1, 0.3) : vec3(23.47, 21.31, 20.79);

//////////////////////////////////////////////////////////////////////////////////////

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

//////////////////////////////////////////////////////////////////////////////////////

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

    float t1 = (upperCloudLayer - rayOrigin.y) / rayDirection.y;
    float t2 = (lowerCloudLayer - rayOrigin.y) / rayDirection.y;

    if (abs(t1) == -abs(t2)) return false;

    startPos = rayOrigin + min(t1, t2) * rayDirection;
    endPos = rayOrigin + max(t1, t2) * rayDirection;

    return true;
}

float getDensity(vec3 rayPos) {
    vec4 alligatorNoise = textureLod(alligatorNoiseTex, rayPos / CLOUD_3D_NOISE_TEXTURE_SIZE_M, 0.0);

    float baseDensityFBM = dot(alligatorNoise.yzw, vec3(0.15, 0.15, 0.7)); 
    float baseDensity = remap2(alligatorNoise.x, baseDensityFBM - 1.0, 1.0);
    
    vec4 perlinNoise = textureLod(perlinNoiseTex, rayPos.xz / CLOUD_2D_NOISE_TEXTURE_SIZE_M, 0.0);
    vec4 worleyNoise = textureLod(worleyNoiseTex, rayPos.xz / CLOUD_2D_NOISE_TEXTURE_SIZE_M, 0.0);

    float cloudCoverage = remap2(perlinNoise.x, GLOBAL_COVERAGE_AMOUNT - 1.0, 1.0);
    float cloudDensity = clamp(baseDensity - (1.0 - cloudCoverage), 0.0, 1.0);

    return cloudDensity;
}

float henyeyGreenstien(float cosTheta, float g) {
    return (1.0 / (4.0 * PI)) * ((1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * cosTheta, 1.5));
}

float DualLobeHG(float cosTheta, float aniso1, float aniso2, float alpha) {
    return mix(henyeyGreenstien(cosTheta, aniso1), henyeyGreenstien(cosTheta, aniso2), alpha);
}

float getOpticalDepth(vec3 primaryRayPos, vec3 planetPos) {
    vec3 lightPos = primaryRayPos + planetPos * 1000;
    vec3 rayStep = (lightPos - primaryRayPos) / float(NUM_STEPS);
    float rayStepLength = length(rayStep);

    float opticalDepth = 0.0;

    for (int i = 0; i < NUM_STEPS; i++) {
        vec3 rayPos = primaryRayPos + rayStep * float(i);

        float sampleDensity = getDensity(rayPos);
        opticalDepth += sampleDensity * rayStepLength;
    }

    return opticalDepth;
}

vec3 getCloudScatteringLight(in vec3 rayPos, in vec3 lightPos, in vec3 viewDir) {
    float opticalDepth = getOpticalDepth(rayPos, lightPos);
    float cosTheta = dot(lightPos, viewDir);

    float attenuation = 0.5;
    float contribution = 0.5;
    float phaseAttenuation = 0.5;

    const int scatteringOctaves = 8;

    float a = 1.0;
    float b = 1.0;
    float c = 1.0;
    float g = 0.85;

    vec3 luminance = vec3(0.0);

    for (int i = 0; i < scatteringOctaves; i++) {
        float phaseFunction = DualLobeHG(cosTheta, g * c, -0.5 * c, 0.5);

        float beers = beersLaw(opticalDepth, EXTINCTION_COEFFICIENT * a);

        luminance += b * PLANET_LIGHT_COLOR * phaseFunction * beers * SCATTERING_COEFFICIENT;
        
        a *= attenuation;
        b *= contribution;
        c *= (1.0 - phaseAttenuation);
    }

    return luminance;
}

vec4 raymarch(vec3 rayOrigin, vec3 rayDirection, vec3 lightPos) {
    vec3 startPos;
    vec3 endPos;

    // Check if the ray hits the cloud plane
    bool hitPlane = getCloudUV(rayOrigin, rayDirection, startPos, endPos);
    // If not exit early
    if (!hitPlane) {
        discard;
    }

    // main function
    vec3 scattering = vec3(0.0);
    float transmittance = 1.0;

    // From bottom cloud pane to top in number of MAX_STEPS defined, e.i if MAX_STEPS = 120; then rayPos will take 120 steps to move to endPos from startPos;
    vec3 rayStep = (endPos - startPos) / float(MAX_STEPS);

    // Distance between each step;
    float rayStepLength = length(rayStep);

    for (int i = 0; i < MAX_STEPS; i++) {
        // startPos moves towards endPos in defined number of rayStep, current_step_index(i) moves the rayPos from one position to the next;
        vec3 rayPos = startPos + rayStep * float(i + 0.5);

        // sample density;
        float sampleDensity = getDensity(rayPos) * rayStepLength;

        // if sampleDensity is more than 0.0 only then do the math;
        if (sampleDensity > 0.0) {
            // sample transmittanceAtPoint
            float transmittanceAtPoint = beersLaw(sampleDensity, SCATTERING_COEFFICIENT);

            // sample scatteredLight
            vec3 scatteredLight = getCloudScatteringLight(rayPos, lightPos, rayDirection);
            
            vec3 integratedScatteringAtPoint = (scatteredLight - scatteredLight * transmittanceAtPoint) / EXTINCTION_COEFFICIENT;
            scattering += transmittance * integratedScatteringAtPoint;
            transmittance *= transmittanceAtPoint;

            if (transmittance == 0.0) {
                break;
            }
        }
    }
    return vec4(scattering, transmittance);
}

//////////////////////////////////////////////////////////////////////////////////////

void main() {
    color = texture(colortex0, texcoord);

    float depth = texture(depthtex0, texcoord).r;
  
    if (depth == 1.0) {
        vec3 screenPos = vec3(texcoord, depth);
        vec3 ndcPos = screenPos * 2.0 - 1.0;
        vec3 viewPos = projectAndDivide(gbufferProjectionInverse, ndcPos);
        vec3 playerFeetPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        vec3 eyePlayerPos = playerFeetPos - gbufferModelViewInverse[3].xyz;

        vec3 rayOrigin = eyePlayerPos;
        vec3 rayDir = normalize(rayOrigin);

        vec3 lightPos = mat3(gbufferModelViewInverse) * normalize(shadowLightPosition);

        if (rayDir.y < 0.0) return;

        vec4 res = raymarch(rayOrigin, rayDir, lightPos);

        float cloudFog = 1.0 / rayDir.y;
        vec4 clouds = vec4(color.rgb * res.a + res.rgb, 1.0);

        color.rgb = mix(color.rgb, clouds.rgb, clouds.a / cloudFog);
    }
}