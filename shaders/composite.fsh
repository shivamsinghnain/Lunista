#version 330 compatibility

#include "/lib/shadow.glsl"
#include "/lib/brdf.glsl"

/*
const int colortex0Format = RGB16F;
const int colortex1Format = RGBA8;
const int colortex2Format = RGBA8;
*/

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;

uniform sampler2D depthtex0;

uniform int worldTime;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

bool isNight = worldTime >= 13000 && worldTime < 24000;

const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor = vec3(0.05, 0.15, 0.3);
const vec3 ambientColor = vec3(0.1);

const float sunPathRotation = -23.47;

vec3 planetLight = isNight ? vec3(0.1, 0.1, 0.3) : vec3(23.47, 21.31, 20.79);

vec3 projectAndDivide(mat4 projectionMatrix, vec3 position){
  vec4 homPos = projectionMatrix * vec4(position, 1.0);
  return homPos.xyz / homPos.w;
}

void main() {
	color = texture(colortex0, texcoord);
	float depth = texture(depthtex0, texcoord).r;
  
	if (depth == 1.0) {
		return;
	}

  // Sample lightmap
	vec3 lightmap = texture(colortex1, texcoord).rgb; // we only need the r and g components
  float vanillaAO = lightmap.b;

  // Sample encoded normal
	vec4 encodedNormal = texture(colortex2, texcoord);
	encodedNormal.rgb = normalize((encodedNormal.rgb - 0.5) * 2.0); // we normalize to make sure it is of unit length
  float labAO = encodedNormal.a;

  // Sample LabPBR normal map
  vec4 labNormal = texture(colortex3, texcoord);
  labNormal.rgb = normalize((labNormal.rgb - 0.5) * 2.0);

  // Sample labPBR specular map
  vec4 labSpecular = texture(colortex4, texcoord);
  float roughness = max(labSpecular.r, 0.001);
  float reflectance  = labSpecular.g * 255.0;

	vec3 blocklight = lightmap.r * blocklightColor;
	vec3 skylight = lightmap.g * skylightColor;
  vec3 ambient = ambientColor;

	vec3 NDCPos = vec3(texcoord.xy, depth) * 2.0 - 1.0;
	vec3 viewPos = projectAndDivide(gbufferProjectionInverse, NDCPos);
	vec3 feetPlayerPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
	vec3 shadowViewPos = (shadowModelView * vec4(feetPlayerPos, 1.0)).xyz;
	vec4 shadowClipPos = shadowProjection * vec4(shadowViewPos, 1.0);
	
	vec3 shadow = getSoftShadow(shadowClipPos, encodedNormal.rgb);

  // Convert frag position to player space
  vec3 eyePlayerPos = mat3(gbufferModelViewInverse) * viewPos;  
  vec3 fragPos = eyePlayerPos;

  // Converts shadowLightPosition to player space.
  vec3 lightPos = mat3(gbufferModelViewInverse) * shadowLightPosition;

  // Camera position in player space
  vec3 eyeCameraPosition = cameraPosition + gbufferModelViewInverse[3].xyz;
  vec3 viewCameraPos = cameraPosition - eyeCameraPosition; 

  vec3 lightDir = normalize(lightPos - fragPos);
  vec3 viewDir = normalize(viewCameraPos - fragPos);

  vec3 brdf = computeBRDF(labNormal.rgb, viewDir, lightDir, color.rgb, reflectance, roughness, planetLight);

  vec3 dirLight = brdf * shadow;
  vec3 indirLight = (blocklight + skylight + ambient) * vanillaAO * labAO;

  color.rgb *= dirLight + indirLight;

  color = vec4(color.rgb, 1.0);
  }