#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float frameTimeCounter;

varying vec2 texCoord;
varying vec2 lmCoord;
varying vec4 glColor;
varying vec3 viewNormal;
varying float isWater;

/* DRAWBUFFERS:02 */

const vec3 WATER_TINT = vec3(0.62, 0.82, 1.00);
const vec3 WATER_SKY_REFLECTION = vec3(0.58, 0.74, 1.0);
const float WATER_MIN_ALPHA = 0.42;
const float WATER_MAX_ALPHA = 0.72;
const float WATER_WAVE_NORMAL_STRENGTH = 0.16;

float waterRipple(vec2 uv, float time) {
    float waveA = sin((uv.x + time * 0.018) * 72.0 + uv.y * 19.0);
    float waveB = sin((uv.y - time * 0.014) * 53.0 - uv.x * 23.0);
    return waveA * 0.5 + waveB * 0.5;
}

vec3 getWaterWaveNormal(vec2 uv, float time, vec3 baseNormal) {
    float waveX = sin((uv.x + time * 0.020) * 54.0 + uv.y * 17.0);
    float waveY = cos((uv.y - time * 0.016) * 49.0 - uv.x * 21.0);
    vec3 waveNormal = normalize(vec3(waveX, waveY, 1.0 / WATER_WAVE_NORMAL_STRENGTH));
    return normalize(baseNormal + waveNormal * WATER_WAVE_NORMAL_STRENGTH);
}

float getWaterSpecular(vec3 normal, float ripple) {
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    vec3 lightDir = normalize(vec3(-0.25, 0.35, 0.90));
    vec3 halfDir = normalize(viewDir + lightDir);
    float spec = pow(max(dot(normal, halfDir), 0.0), 48.0);
    return spec * (0.55 + ripple * 0.25);
}

void main() {
    vec4 albedo = texture2D(texture, texCoord) * glColor;
    if (albedo.a < 0.05) discard;

    vec3 lightColor = texture2D(lightmap, lmCoord).rgb;
    float ripple = waterRipple(texCoord, frameTimeCounter) * isWater;
    vec3 waterNormal = getWaterWaveNormal(texCoord, frameTimeCounter, normalize(viewNormal));
    float facing = clamp(abs(waterNormal.z), 0.0, 1.0);
    float fresnel = pow(1.0 - facing, 2.0) * isWater;
    float specular = getWaterSpecular(waterNormal, ripple) * isWater;

    vec3 baseColor = albedo.rgb * lightColor;
    vec3 waterColor = mix(baseColor, baseColor * WATER_TINT, 0.34);
    waterColor += WATER_TINT * (0.018 + fresnel * 0.030 + ripple * 0.008) * isWater;
    waterColor += WATER_SKY_REFLECTION * (fresnel * 0.055 + specular * 0.050) * isWater;

    vec3 outColor = mix(baseColor, waterColor, isWater);
    float waterAlpha = clamp(max(albedo.a, WATER_MIN_ALPHA) + fresnel * 0.10, WATER_MIN_ALPHA, WATER_MAX_ALPHA);
    float outAlpha = mix(albedo.a, waterAlpha, isWater);

    gl_FragData[0] = vec4(outColor, outAlpha);

    // colortex2 material masks: R = wet floor, G = wall, B = lava, A = water.
    gl_FragData[1] = vec4(0.0, 0.0, 0.0, isWater);
}
