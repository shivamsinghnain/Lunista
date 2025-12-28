const float PI = 3.14159265359;

// GGX / Trowbridge-Reitz Normal Distribution Function
float distributionGGX(in float roughness, in float NoH) {
    float a2 = roughness * roughness;

    float NoH2 = NoH * NoH;

    float num = a2;
    float denom = PI * pow((NoH2 * (a2 - 1.0) + 1.0), 2.0);
    return num / denom;
}

// Geometry function using GGX
float geometryGGX(in float roughness, in float NoX) {
    float a2 = roughness * roughness;
    
    float num = 2.0 * NoX;
    float denom = NoX + sqrt(a2 + (1.0 - a2) * pow(NoX, 2.0));
    return num / denom;
}

float G1_GGX(in float roughness, in float NoV, in float NoL) {
    return geometryGGX(roughness, NoV) * geometryGGX(roughness, NoL);
}

// Schlick's approximation for Dielectric materials
vec3 fresnalSchlick(in float cosTheta, in vec3 f0) {
    return f0 + (1.0 - f0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// Lazyni 2019 Fresnel for Conductors
vec3 SrgbToLinear(vec3 c) {
    return pow(c, vec3(2.2));
}

struct LabConductorData {
    vec3 f0;
    vec3 f82;
};

LabConductorData getLabConductorData(in int conductor, in vec3 albedo) {
    LabConductorData data;

    if (conductor == 230) {
        // Iron
        data.f0 = SrgbToLinear(vec3(0.78, 0.77, 0.74));
        data.f82 = SrgbToLinear(vec3(0.75, 0.76, 0.74));
        // Gold
    } else if (conductor == 231) {
        data.f0 = SrgbToLinear(vec3(1.00, 0.90, 0.61));
        data.f82 = SrgbToLinear(vec3(1.00, 0.92, 0.73));
        // Copper
    } else if (conductor == 234) {
        data.f0 = SrgbToLinear(vec3(1.00, 0.89, 0.73));
        data.f82 = SrgbToLinear(vec3(1.00, 0.90, 0.80));
        // Default
    } else if (conductor == 255) {
        data.f0 = albedo;
        data.f82 = albedo;
    } else {
        data.f0 = vec3(0.04);
        data.f82 = vec3(0.04);
    }

    return data;
}

vec3 fresnalLazanyi2019(in float cosTheta, in vec3 f0, in vec3 f82) {
    vec3 a = (823543.0 / 46656.0) * (f0 - f82) + (49.0 / 6.0) * (1.0 - f0);

    return f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0) - a * cosTheta * pow(1.0 - cosTheta, 6.0);
}

// https://advances.realtimerendering.com/s2017/DecimaSiggraph2017.pdf
float getNoHSquared(float NoL, float NoV, float VoL, float radius) {
  float radiusCos = cos(radius);
  float radiusTan = tan(radius);

  float RoL = 2.0 * NoL * NoV - VoL;
  if (RoL >= radiusCos) return 1.0;

  float rOverLengthT = radiusCos * radiusTan / sqrt(1.0 - RoL * RoL);
  float NoTr = rOverLengthT * (NoV - RoL * NoL);
  float VoTr = rOverLengthT * (2.0 * NoV * NoV - 1.0 - RoL * VoL);

  float triple = sqrt(
    clamp(
      1.0 - NoL * NoL - NoV * NoV - VoL * VoL + 2.0 * NoL * NoV * VoL,
      0.0,
      1.0
    )
  );

  float NoBr = rOverLengthT * triple,
    VoBr = rOverLengthT * (2.0 * triple * NoV);
  float NoLVTr = NoL * radiusCos + NoV + NoTr,
    VoLVTr = VoL * radiusCos + 1.0 + VoTr;
  float p = NoBr * VoLVTr,
    q = NoLVTr * VoLVTr,
    s = VoBr * NoLVTr;
  float xNum = q * (-0.5 * p + 0.25 * VoBr * NoLVTr);
  float xDenom =
    p * p +
    s * (s - 2.0 * p) +
    NoLVTr *
      ((NoL * radiusCos + NoV) * VoLVTr * VoLVTr +
        q * (-0.5 * (VoLVTr + VoL * radiusCos) - 0.5));
  float twoX1 = 2.0 * xNum / (xDenom * xDenom + xNum * xNum);
  float sinTheta = twoX1 * xDenom;
  float cosTheta = 1.0 - twoX1 * xNum;
  NoTr = cosTheta * NoTr + sinTheta * NoBr;
  VoTr = cosTheta * VoTr + sinTheta * VoBr;

  float newNoL = NoL * radiusCos + NoTr;
  float newVoL = VoL * radiusCos + VoTr;
  float NoH = NoV + newNoL;
  float HoH = 2.0 * newVoL + 2.0;
  return clamp(NoH * NoH / HoH, 0.0, 1.0);
}

// Main BRDF computation
vec3 computeBRDF(in vec3 N, in vec3 V, in vec3 L, in vec3 albedo, in float reflectance, in float roughness, in vec3 directLight) {
    vec3 outgoingLight = vec3(0.0);

    vec3 H = normalize(V + L);
    float cosTheta = clamp(dot(V, H), 0.0, 1.0);

    // float NoH = clamp(dot(N, H), 0.0, 1.0);
    float NoL = clamp(dot(N, L), 0.0, 1.0);
    float NoV = clamp(dot(N, V), 0.0, 1.0);
    float VoL = dot(V, L);

    float NoH = sqrt(getNoHSquared(NoL, NoV, VoL, 0.01));

    int conductor = int(reflectance * 255 + 0.5);

    float metallic = 0.0;
    vec3 F0 = vec3(0.00);
    vec3 F82 = vec3(0.00);
    vec3 F = vec3(0.0);

    if (conductor == 255) {
        F0 = albedo;
        metallic = 1.0;
        
        F = fresnalSchlick(cosTheta, F0);
    } else if (conductor >= 230 && conductor <= 254) {
        LabConductorData conductorData = getLabConductorData(conductor, albedo);

        F0 = conductorData.f0;
        F82 = conductorData.f82;
        metallic = 1.0;

        F = fresnalLazanyi2019(cosTheta, F0, F82);
    } else if (conductor <= 229 && conductor >= 1) {
        F0 = vec3(clamp(reflectance * 255.0, 0.0, 229.0) / 229.0);

        F = fresnalSchlick(cosTheta, F0);
    } else {
        F0 = vec3(0.04);

        F = fresnalSchlick(cosTheta, F0);
    }

    float NDF = distributionGGX(roughness, NoH);
    float G = G1_GGX(roughness, NoV, NoL);

    // Calculate diffuse
    vec3 kS = F;
    vec3 kD = 1.0 - kS;
    kD *= 1.0 - metallic;

    vec3 lambert = albedo / PI;
    vec3 diffuse = kD * lambert;

    // Calculate specular
    vec3 num = NDF * F * G;
    float denom = 4.0 * NoV * NoL + 1e-6;

    vec3 specular = num / denom;

    // Final BRDF
    vec3 brdf = diffuse + specular;

    outgoingLight += brdf * directLight * NoL;

    return outgoingLight;
}