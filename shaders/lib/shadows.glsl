// Shadow mapping utilities

const float SHADOW_DARKNESS = 0.42;
const float SHADOW_FADE_START = 0.72;
const float SHADOW_BIAS = 0.0018;
const float SHADOW_TEXEL_SIZE = 1.0 / 2048.0;

float sampleShadowMap(vec3 shadowPos, vec2 offset) {
    float shadowDepth = texture2D(shadowtex0, shadowPos.xy + offset * SHADOW_TEXEL_SIZE).r;
    return step(shadowPos.z - SHADOW_BIAS, shadowDepth);
}

float getShadowVisibility(vec3 worldPos, float viewDistance, float farPlane, float sceneMask) {
    if (sceneMask < 0.5) return 1.0;

    vec4 shadowClip = shadowProjection * shadowModelView * vec4(worldPos, 1.0);
    vec3 shadowPos = shadowClip.xyz / shadowClip.w;
    shadowPos = shadowPos * 0.5 + 0.5;

    if (shadowPos.x <= 0.0 || shadowPos.x >= 1.0 ||
        shadowPos.y <= 0.0 || shadowPos.y >= 1.0 ||
        shadowPos.z <= 0.0 || shadowPos.z >= 1.0) {
        return 1.0;
    }

    float visibility = 0.0;
    visibility += sampleShadowMap(shadowPos, vec2(-1.0, -1.0));
    visibility += sampleShadowMap(shadowPos, vec2( 0.0, -1.0));
    visibility += sampleShadowMap(shadowPos, vec2( 1.0, -1.0));
    visibility += sampleShadowMap(shadowPos, vec2(-1.0,  0.0));
    visibility += sampleShadowMap(shadowPos, vec2( 0.0,  0.0));
    visibility += sampleShadowMap(shadowPos, vec2( 1.0,  0.0));
    visibility += sampleShadowMap(shadowPos, vec2(-1.0,  1.0));
    visibility += sampleShadowMap(shadowPos, vec2( 0.0,  1.0));
    visibility += sampleShadowMap(shadowPos, vec2( 1.0,  1.0));
    visibility /= 9.0;

    float distanceFade = 1.0 - smoothstep(farPlane * SHADOW_FADE_START, farPlane, viewDistance);
    return mix(1.0, visibility, distanceFade);
}

vec3 applyShadow(vec3 color, float visibility) {
    float shadowAmount = (1.0 - visibility) * SHADOW_DARKNESS;
    vec3 shadowTint = vec3(0.78, 0.84, 0.92);
    return mix(color, color * shadowTint, shadowAmount);
}