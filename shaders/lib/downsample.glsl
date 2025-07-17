vec3 downsample(sampler2D srcTexture, vec2 uv, vec2 texelSize) {

  float x = texelSize.x;
  float y = texelSize.y;

  vec2 texCoord = uv;

  vec3 a = texture(srcTexture, vec2(texCoord.x - 2*x, texCoord.y + 2*y)).rgb;
  vec3 b = texture(srcTexture, vec2(texCoord.x,       texCoord.y + 2*y)).rgb;
  vec3 c = texture(srcTexture, vec2(texCoord.x + 2*x, texCoord.y + 2*y)).rgb;

  vec3 d = texture(srcTexture, vec2(texCoord.x - 2*x, texCoord.y)).rgb;
  vec3 e = texture(srcTexture, vec2(texCoord.x,       texCoord.y)).rgb;
  vec3 f = texture(srcTexture, vec2(texCoord.x + 2*x, texCoord.y)).rgb;

  vec3 g = texture(srcTexture, vec2(texCoord.x - 2*x, texCoord.y - 2*y)).rgb;
  vec3 h = texture(srcTexture, vec2(texCoord.x,       texCoord.y - 2*y)).rgb;
  vec3 i = texture(srcTexture, vec2(texCoord.x + 2*x, texCoord.y - 2*y)).rgb;

  vec3 j = texture(srcTexture, vec2(texCoord.x - x, texCoord.y + y)).rgb;
  vec3 k = texture(srcTexture, vec2(texCoord.x + x, texCoord.y + y)).rgb;
  vec3 l = texture(srcTexture, vec2(texCoord.x - x, texCoord.y - y)).rgb;
  vec3 m = texture(srcTexture, vec2(texCoord.x + x, texCoord.y - y)).rgb;

  vec3 downsample = e*0.125;
  downsample += (a+c+g+i)*0.03125;
  downsample += (b+d+f+h)*0.0625;
  downsample += (j+k+l+m)*0.125;

  return downsample;
}