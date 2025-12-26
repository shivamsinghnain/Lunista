const float PI = 3.14159265359;

float distributionGGX(in float roughness, in float NoH) {

    float a2 = roughness * roughness;
    float NoH2 = NoH * NoH;

    float nom = a2;
    float denom = PI * pow((NoH2 * (a2 - 1.0) + 1.0), 2.0);
    return nom / denom;
}

float geometryGGX(in float roughness, in float NoX) {
    float a2 = roughness * roughness;
    
    float nom = 2.0 * NoX;
    float denom = NoX + sqrt(a2 + (1.0 - a2) * pow(NoX, 2.0));
    return nom / denom;
}

float G1_GGX(in float roughness, in float NoV, in float NoL) {
    return geometryGGX(roughness, NoV) * geometryGGX(roughness, NoL);
}

vec3 fersnalSchlick(in float VoH, in vec3 f0) {
    return f0 + (vec3(1.0) - f0) * pow(clamp(1.0 - VoH, 0.0, 1.0), 5.0);
}

vec3 computeLabHCM(in int conductor, in vec3 albedo) {
    if (conductor == 230) {
        return vec3(0.560, 0.570, 0.580); // Iron
    } else if (conductor == 231) {
        return vec3(0.981, 0.781, 0.497); // Gold
    } else if (conductor == 234) {
        return vec3(0.955, 0.638, 0.538);
    } else {
        return albedo;
    }
}

vec3 computeBRDF(in vec3 N, in vec3 V, in vec3 L, in vec3 albedo, in float reflectance, in float roughness, in vec3 directLight) {
    vec3 outgoingLight = vec3(0.0);

    vec3 H = normalize(V + L);

    float NoH = max(dot(N, H), 1e-6);
    float NoL = max(dot(N, L), 1e-6);
    float NoV = max(dot(N, V), 1e-6);
    float VoH = max(dot(V, H), 1e-6);

    int labSpecG = int(reflectance * 255 + 0.5);

    float metallic;
    vec3 F0;

    if (labSpecG >= 230) {
        metallic = 1.0;
        F0 = albedo * computeLabHCM(labSpecG, albedo);
    } else if (labSpecG == 0) {
        metallic = 0.0;
        F0 = albedo;
    } else if (labSpecG <= 229) {
        metallic = 0.0;
        F0 = vec3(reflectance);
    }

    float D = distributionGGX(roughness, NoH);
    float G = G1_GGX(roughness, NoV, NoL);
    vec3 F = fersnalSchlick(VoH, F0);
    // vec3 F = fresnalCookTorrance(VoH, F0);

    // Calculate diffuse
    vec3 kS = F;
    vec3 kD = 1.0 - kS;
    kD *= 1.0 - metallic;

    vec3 lambert = albedo / PI;
    vec3 diffuse = kD * lambert;

    // Calculate specular
    vec3 nom = D * F * G;
    float denom = 4.0 * NoV * NoL;

    vec3 specular = nom / denom;

    // Final BRDF
    vec3 brdf = diffuse + specular;

    outgoingLight += directLight * brdf * NoL;

    return outgoingLight;
}