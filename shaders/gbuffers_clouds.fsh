#version 120

uniform sampler2D texture;
uniform float rainStrength;
uniform int worldTime;
uniform mat4 gbufferModelViewInverse;

varying vec2 texCoord;
varying vec4 vertexColor;
varying vec3 viewDir;

#include "/lib/sky.glsl"

/* DRAWBUFFERS:0 */


float sampleCloudAlpha(vec2 uv) {
    return texture2D(texture, uv).a;
}

float getCloudThickness(vec2 uv) {
    vec2 offset = vec2(0.0035, 0.0025);
    float center = sampleCloudAlpha(uv);
    float neighbors =
        sampleCloudAlpha(uv + offset) +
        sampleCloudAlpha(uv - offset) +
        sampleCloudAlpha(uv + offset.yx) +
        sampleCloudAlpha(uv - offset.yx);
    return clamp(center * 0.55 + neighbors * 0.1125, 0.0, 1.0);
}

float getCloudSelfShadow(vec2 uv, float rain) {
    vec2 lightOffset = vec2(-0.006, 0.004);
    float litAlpha = sampleCloudAlpha(uv + lightOffset);
    float shadeAlpha = sampleCloudAlpha(uv - lightOffset * 0.75);
    float densityDiff = clamp(shadeAlpha - litAlpha, 0.0, 1.0);
    return densityDiff * mix(1.0, 1.35, rain);
}

void main() {
    vec4 cloudSample = texture2D(texture, texCoord) * vertexColor;
    if (cloudSample.a < 0.03) discard;

    vec3 worldDir = normalize((gbufferModelViewInverse * vec4(normalize(viewDir), 0.0)).xyz);
    float rain = clamp(rainStrength, 0.0, 1.0);
    float thickness = getCloudThickness(texCoord);
    float selfShadow = getCloudSelfShadow(texCoord, rain);
    float edgeLight = 1.0 - smoothstep(0.35, 0.92, thickness);
    vec3 skyMatchedCloud = getSkyCloudColor(worldDir, cloudSample.rgb, thickness, selfShadow, edgeLight, worldTime, rainStrength);

    gl_FragData[0] = vec4(skyMatchedCloud, cloudSample.a);
}
