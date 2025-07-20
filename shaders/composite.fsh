#version 330 compatibility

#include /lib/distort.glsl

/*
const int colortex0Format = R11F_G11F_B10F;
const int colortex5Format = R11F_G11F_B10F;
*/

//#define materialAO
//#define materialEmissive

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex12;

uniform sampler2D depthtex0;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

uniform sampler2D shadowcolor0;

uniform sampler2D noisetex;

uniform int worldTime;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
  vec4 homPos = projectionMatrix * vec4(position, 1.0);
  return homPos.xyz / homPos.w;
}

/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 bloom;

bool isNight = worldTime >= 13000 && worldTime < 24000;

const vec3 blocklightColor = vec3(1.0, 0.6, 0.2);
const vec3 skylightColor = vec3(0.05, 0.15, 0.3);

const vec3 sunlightColor = vec3(1.0, 0.95, 0.8) * 20;
const vec3 moonlightColor = vec3(0.1, 0.1, 0.3) * 20;
vec3 directLightColor = isNight ? moonlightColor : sunlightColor;

const vec3 ambientColorDay = vec3(0.15);
const vec3 ambientColorNight = vec3(0.01);
vec3 ambient = isNight ? ambientColorNight : ambientColorDay;

#define EMISSIVE_INTENSITY 7.5 // [1-10]

const float pi = 3.14159265358979323846;

vec3 getShadow(vec3 shadowScreenPos){
  float transparentShadow = step(shadowScreenPos.z, texture(shadowtex0, shadowScreenPos.xy).r); // sample the shadow map containing everything

  /*
  note that a value of 1.0 means 100% of sunlight is getting through
  not that there is 100% shadowing
  */

  if(transparentShadow == 1.0){
    /*
    since this shadow map contains everything,
    there is no shadow at all, so we return full sunlight
    */
    return vec3(1.0);
  }

  float opaqueShadow = step(shadowScreenPos.z, texture(shadowtex1, shadowScreenPos.xy).r); // sample the shadow map containing only opaque stuff

  if(opaqueShadow == 0.0){
    // there is a shadow cast by something opaque, so we return no sunlight
    return vec3(0.0);
  }

  // contains the color and alpha (transparency) of the thing casting a shadow
  vec4 shadowColor = texture(shadowcolor0, shadowScreenPos.xy);


  /*
  we use 1 - the alpha to get how much light is let through
  and multiply that light by the color of the caster
  */
  return shadowColor.rgb * (1.0 - shadowColor.a);
}

vec4 getNoise(vec2 coord){
  ivec2 screenCoord = ivec2(coord * vec2(viewWidth, viewHeight)); // exact pixel coordinate onscreen
  ivec2 noiseCoord = screenCoord % 64; // wrap to range of noiseTextureResolution
  return texelFetch(noisetex, noiseCoord, 0);
}

vec3 getSoftShadow(vec4 shadowClipPos, vec3 normal){
  const float range = SHADOW_SOFTNESS / 2.0; // how far away from the original position we take our samples from
  const float increment = range / SHADOW_QUALITY; // distance between each sample

  const float shadowMapPixelSize = 1.0 / shadowMapResolution;

  const vec3 biasAdjustFactor = vec3(shadowMapPixelSize * 3.0, shadowMapPixelSize * 3.0, -0.00006103515625);

  float noise = getNoise(texcoord).r;

  float theta = noise * radians(360.0); // random angle using noise value
  float cosTheta = cos(theta);
  float sinTheta = sin(theta);

  mat2 rotation = mat2(cosTheta, -sinTheta, sinTheta, cosTheta); // matrix to rotate the offset around the original position by the angle

  vec3 shadowAccum = vec3(0.0); // sum of all shadow samples
  int samples = 0;

  for(float x = -range; x <= range; x += increment){
    for (float y = -range; y <= range; y+= increment){

      vec2 offset = rotation * vec2(x, y) / shadowMapResolution; // offset in the rotated direction by the specified amount. We divide by the resolution so our offset is in terms of pixels
      vec4 offsetShadowClipPos = shadowClipPos + vec4(offset, 0.0, 0.0); // add offset

      // Old Bias
      // offsetShadowClipPos.z -= 0.001; // apply bias

      offsetShadowClipPos.xyz = distortShadowClipPos(offsetShadowClipPos.xyz); // apply distortion
      vec3 shadowNDCPos = offsetShadowClipPos.xyz / offsetShadowClipPos.w; // convert to NDC space
      vec3 shadowScreenPos = shadowNDCPos * 0.5 + 0.5; // convert to screen space

      vec3 shadowNormal = mat3(shadowModelView) * normal;
      shadowScreenPos += shadowNormal * biasAdjustFactor;

      shadowAccum += getShadow(shadowScreenPos); // take shadow sample
      samples++;
    }
  }

  return shadowAccum / float(samples); // divide sum by count, getting average shadow
}


// Distribution (D)
float distributionGGX(float NoH, float roughness) {

  float a = roughness * roughness;
  float a2 = a * a;

  float NoH2 = NoH * NoH;

  float b = (NoH2 * (a2 - 1.0) + 1.0);

  float nom = a2;
  float denom = pi * (b * b);

  return nom / denom;
}

// Fresnal (F)
vec3 Fschlick(float cosTheta, vec3 f0) {
  return f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0);
}


// Geometry (G)
float kDirect(float a) {
  float k2 = (a + 1.0) * (a + 1.0);
  return k2 / 8.0;
}

// float schlickGGX(float NoV, float k) {

//   float a = k * k;
//   float aK = a / 2.0;
//   return max(NoV, 0.0001) / (NoV * (1.0 - aK) + aK);
// }

float Gggx(float NoV, float alpha) {
  float nom = 2.0 * NoV;
  float a2 = alpha * alpha;

  float denom = max(NoV, 0.0001) + sqrt(a2 + (1.0 - a2) * (NoV * NoV));
  return nom / denom;
}

float geometrySmith(float NoV, float NoL, float k)
{
    float ggx1 = Gggx(NoV, k);
    float ggx2 = Gggx(NoL, k);
	
    return ggx1 * ggx2;
}

vec3 BRDF(vec3 n, vec3 l, vec3 v, float roughness, vec3 f0, vec3 albedo, float metallic) {

  vec3 h = normalize(v + l);

  float NoV = max(dot(n, v), 0.0);
  float NoL = max(dot(n, l), 0.0);
  float NoH = max(dot(n, h), 0.0);
  float VoH = max(dot(v, h), 0.0);

  float k = kDirect(roughness);

  float D = distributionGGX(NoH, roughness);
  vec3 F = Fschlick(VoH, f0);
  float G = geometrySmith(NoV, NoL, roughness);

  vec3 spec = (D * F * G) / (4.0 * max(NoV, 0.0001) * max(NoL, 0.0001)); // 0.0001 to avoid division by zero

  // vec3 kS = F;
  // vec3 kD = vec3(1.0) - kS;
  // kD *= 1.0 - metallic; // if metallic, we don't use diffuse

  vec3 rhoD = albedo;

  rhoD *= vec3(1.0 - F);
  rhoD *= 1.0 - metallic; // if metallic, we don't use diffuse

  vec3 diff = rhoD / pi * NoL; // lambertian diffuse


  // vec3 diffuse = kD * diff;

  return diff + spec;
}

void main() {
	color = texture(colortex0, texcoord);

	float depth = texture(depthtex0, texcoord).r;
  
	if (depth == 1.0) {
		return;
	}

	vec2 lightmap = texture(colortex1, texcoord).rg; // we only need the r and g components
	vec4 encodedNormal = texture(colortex2, texcoord);
	vec3 normal = normalize((encodedNormal.rgb - 0.5) * 2.0); // we normalize to make sure it is of unit length

	vec3 blocklight = lightmap.r * blocklightColor;
	vec3 skylight = lightmap.g * (isNight ? vec3(0.01, 0.01, 0.02) : skylightColor);

	vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
	
	vec3 shadow = getSoftShadow(shadowClipPos, normal);

  // LabPBR Ambient Occlusion
  vec3 labNormal = texture(colortex12, texcoord).rgb;
  float labAO = labNormal.b;

  // Vanilla Ambient Occlusion
  float vanillaAO = encodedNormal.a;
  vanillaAO = pow(vanillaAO, 2.5);

  // Convert frag position to scene space
  vec3 eyePlayerPos = mat3(gbufferModelViewInverse) * viewPos;  
  vec3 fragPos = eyePlayerPos;

  // Converts shadowLightPosition to scene space.
  vec3 lightPos = mat3(gbufferModelViewInverse) * shadowLightPosition; 

  // Camera position in scene space
  vec3 eyeCameraPosition = cameraPosition + gbufferModelViewInverse[3].xyz;
  vec3 viewCameraPos = cameraPosition - eyeCameraPosition; 

  vec3 lightDir = normalize(lightPos - fragPos);
  vec3 viewDir = normalize(viewCameraPos - fragPos);

  vec4 labSpecular = texture(colortex3, texcoord);
  float labEmissive = fract(labSpecular.a);

  float labRoughness = labSpecular.r;
  labRoughness = pow(1.0 - labRoughness, 2.0); // Convert to linear roughness

  vec3 emissiveColor = color.rgb;
  vec3 emissiveFinal = emissiveColor * labEmissive * EMISSIVE_INTENSITY;

  float metallic = labSpecular.g >= (230.0/255) ? 1.0 : 0.0;

  vec3 metalF0;
  if (labSpecular.g == 230.0) {
    metalF0 = vec3(0.560, 0.570, 0.580); // Iron 
  } else if (labSpecular.g == 231.0) {
    metalF0 = vec3(1.000, 0.710, 0.290); // Gold
  } else if (labSpecular.g == 232.0) {
    metalF0 = vec3(0.910, 0.920, 0.920); // Aluminum
  } else if (labSpecular.g == 234.0) {
    metalF0 = vec3(0.950, 0.640, 0.540); // Copper
  } else {
    metalF0 = color.rgb;
  }

  vec3 labF0 = metallic < 0.5 ? vec3(labSpecular.g / (229.0/255)) : metalF0;
  // vec3 f0 = mix(labF0, color.rgb, metallic);

  vec3 albedo = color.rgb;

  vec3 brdfMicrofacet = BRDF(normal, lightDir, viewDir, labRoughness, labF0, albedo, metallic) * directLightColor;  

  vec3 directLight = brdfMicrofacet * shadow;

  vec3 indirectLight = (blocklight + skylight + ambient) * vanillaAO;

  #ifdef materialAO

    indirectLight *= labAO;

  #endif

	color.rgb *= indirectLight + directLight;

  #ifdef materialEmissive
  color.rgb += emissiveFinal;
  #endif

  float brightness = dot(emissiveFinal.rgb, vec3(0.2126, 0.7152, 0.0722));

  if (brightness > 0.04 && brightness < 4.5) {
    bloom = vec4(emissiveFinal.rgb, 1.0); 
  } else {
    bloom = vec4(0.0, 0.0, 0.0, 1.0);
  };
}