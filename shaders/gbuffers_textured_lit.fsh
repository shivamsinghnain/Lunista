#version 330 compatibility

//#define normalMapping

uniform sampler2D gtexture;
uniform sampler2D normals; // LabPBR normal map
uniform sampler2D specular; // LabPBR specular map

uniform float alphaTestRef = 0.1;

in vec2 lmcoord;
in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;

in vec3 vNormal;
in vec3 vTangent;
in vec3 vBitangent;

/* RENDERTARGETS: 0,1,2,3,6 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 lightmapData;
layout(location = 2) out vec4 encodedNormal;
layout(location = 3) out vec4 labSpecular;
layout(location = 4) out vec4 labNormal;

void main() {
	color = texture(gtexture, texcoord) * glcolor;
	if (color.a < alphaTestRef) {
		discard;
	}

	color.rgb = pow(color.rgb, vec3(2.2));

	mat3 TBN = mat3(normalize(vTangent), normalize(vBitangent), normalize(vNormal));

	// Sample LabPBR normal map
	labNormal = texture(normals, texcoord);

	// Sample LabPBR specular map
	labSpecular = texture(specular, texcoord);

	//Decode XY from RG
	vec2 sampledNormalXY = labNormal.rg * 2.0 - 1.0;

	//Reconstruct Z
	float sampledNormalZ = sqrt(1.0 - dot(sampledNormalXY, sampledNormalXY));

	// Vanilla Ambient Occlusion
	float vanillaAO = glcolor.a;

	vec3 tangentNormal = normalize(vec3(sampledNormalXY, sampledNormalZ));
	vec3 worldNormal = normalize(TBN * tangentNormal);

	// Output
	lightmapData = vec4(lmcoord, 0.0, 1.0);
	encodedNormal = vec4(normal * 0.5 + 0.5, vanillaAO);

	#ifdef normalMapping
	encodedNormal = vec4(worldNormal * 0.5 + 0.5, vanillaAO);
	#endif
}