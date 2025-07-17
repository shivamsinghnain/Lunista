#version 330 compatibility

/*
const int colortex8Format = R11F_G11F_B10F;
const int colortex9Format = R11F_G11F_B10F;
*/

uniform sampler2D colortex8;    // Current level bloom
uniform sampler2D colortex9;    // Lower-res bloom

uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

/* RENDERTARGETS: 8 */
layout(location = 0) out vec4 upsampledBloom;

vec2 srcResolution = vec2(viewWidth, viewHeight);
vec2 filterRadius = 1.0 / srcResolution;

vec3 upsample(sampler2D srcTexture, vec2 uv) {
    float x = filterRadius.x;
    float y = filterRadius.y;

    vec2 texCoord = uv;

    // Take 9 samples around current texel:
    // a - b - c
    // d - e - f
    // g - h - i
    // === ('e' is the current texel) ===
    vec3 a = texture(srcTexture, vec2(texCoord.x - x, texCoord.y + y)).rgb;
    vec3 b = texture(srcTexture, vec2(texCoord.x,     texCoord.y + y)).rgb;
    vec3 c = texture(srcTexture, vec2(texCoord.x + x, texCoord.y + y)).rgb;

    vec3 d = texture(srcTexture, vec2(texCoord.x - x, texCoord.y)).rgb;
    vec3 e = texture(srcTexture, vec2(texCoord.x,     texCoord.y)).rgb;
    vec3 f = texture(srcTexture, vec2(texCoord.x + x, texCoord.y)).rgb;

    vec3 g = texture(srcTexture, vec2(texCoord.x - x, texCoord.y - y)).rgb;
    vec3 h = texture(srcTexture, vec2(texCoord.x,     texCoord.y - y)).rgb;
    vec3 i = texture(srcTexture, vec2(texCoord.x + x, texCoord.y - y)).rgb;

    // Apply weighted distribution, by using a 3x3 tent filter:
    //  1   | 1 2 1 |
    // -- * | 2 4 2 |
    // 16   | 1 2 1 |
    vec3 upsample = e*4.0;
    upsample += (b+d+f+h)*2.0;
    upsample += (a+c+g+i);
    upsample *= 1.0 / 16.0;
    return upsample;
}

void main() {

    vec2 upsampledUV = texcoord;
    vec3 upsampled = upsample(colortex9, upsampledUV);

    vec3 base = texture(colortex8, texcoord).rgb;

    vec3 combined = base + upsampled;

    upsampledBloom = vec4(combined, 1.0);
}