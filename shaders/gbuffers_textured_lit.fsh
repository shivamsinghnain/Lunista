#version 330 compatibility

//#define normalMapping

uniform sampler2D gtexture;
uniform sampler2D normals; // LabPBR normal map
uniform sampler2D specular; // LabPBR specular map

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec3 glcolor;
in float occlusion;

in vec3 tangent;
in vec3 bitangent;
in vec3 normal;

/* RENDERTARGETS: 0,1,2,3,4 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 labNormalTex;
layout(location = 4) out vec4 labSpecularTex;

void main() {
	color = texture(gtexture, texcoord);
	color.rgb *= glcolor;
	
	if (color.a < alphaTestRef) {
		discard;
	}

	// Vanilla Ambient Occlusion
	float vanillaAO = pow(occlusion, 2.2);

	// Sample LabPBR normal map
	vec4 labNormal = texture(normals, texcoord);

	// LabAO
	float labAO = labNormal.b;

	labNormal.xy = labNormal.xy * 2.0 - 1.0;
	labNormal.z = sqrt(1.0 - dot(labNormal.xy, labNormal.xy));
	labNormal.xyz = normalize(vec3(labNormal.xy, labNormal.z));

	mat3 TBN = mat3(normalize(tangent), normalize(bitangent), normalize(normal));
	vec3 worldNormal = normalize(TBN * labNormal.xyz);

	// Sample LabPBR specular map
	vec4 labSpecular = texture(specular, texcoord);
	labSpecular.r = pow(1.0 - labSpecular.r, 2.0);

	// Output to g-buffers
	color.rgb = pow(color.rgb, vec3(2.2));
	lightmapData = vec4(lmcoord, vanillaAO, 1.0);
	encodedNormal = vec4(normal * 0.5 + 0.5, labAO);
	labNormalTex = vec4(worldNormal * 0.5 + 0.5, labNormal.a);
	labSpecularTex = labSpecular;
}