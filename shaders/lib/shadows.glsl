// Shadow mapping utilities

const float SHADOW_DARKNESS = 0.34;
const float SHADOW_FADE_START = 0.58;
const float SHADOW_BIAS = 0.0012;
const float SHADOW_SLOPE_BIAS = 2.4;
const float SHADOW_DISTANCE_BIAS = 0.0015;
const float SHADOW_EDGE_FADE = 0.045;
const float SHADOW_TEXEL_SIZE = 1.0 / 2048.0;

float getShadowDayFactor(int worldTime) {
    float time = mod(float(worldTime), 24000.0);
    float sunrise = smoothstep(0.0, 3000.0, time);
    float sunset = 1.0 - smoothstep(12000.0, 13500.0, time);
    float dayMask = sunrise * sunset;

    // Moon shadows stay subtle so night scenes keep readability.
    return max(dayMask, (1.0 - dayMask) * 0.18);
}

float getShadowBias(vec3 shadowPos, float viewDistance, float farPlane) {
    float receiverSlope = max(abs(dFdx(shadowPos.z)), abs(dFdy(shadowPos.z)));
    float distanceBias = smoothstep(0.0, farPlane, viewDistance) * SHADOW_DISTANCE_BIAS;
    return SHADOW_BIAS + receiverSlope * SHADOW_SLOPE_BIAS + distanceBias;
}

float sampleShadowMap(vec3 shadowPos, vec2 offset, float bias) {
    float shadowDepth = texture2D(shadowtex0, shadowPos.xy + offset * SHADOW_TEXEL_SIZE).r;
    return step(shadowPos.z - bias, shadowDepth);
}

float getShadowEdgeFade(vec3 shadowPos) {
    float edgeDist = min(min(shadowPos.x, 1.0 - shadowPos.x), min(shadowPos.y, 1.0 - shadowPos.y));
    return smoothstep(0.0, SHADOW_EDGE_FADE, edgeDist);
}

float getShadowVisibility(
    vec3 worldPos,
    float viewDistance,
    float farPlane,
    float sceneMask,
    int worldTime,
    float rainStrength
) {
    if (sceneMask < 0.5) return 1.0;

    vec4 shadowClip = shadowProjection * shadowModelView * vec4(worldPos, 1.0);
    vec3 shadowPos = shadowClip.xyz / shadowClip.w;
    shadowPos = shadowPos * 0.5 + 0.5;

    if (shadowPos.x <= 0.0 || shadowPos.x >= 1.0 ||
        shadowPos.y <= 0.0 || shadowPos.y >= 1.0 ||
        shadowPos.z <= 0.0 || shadowPos.z >= 1.0) {
        return 1.0;
    }

    float bias = getShadowBias(shadowPos, viewDistance, farPlane);
    float visibility = 0.0;
    visibility += sampleShadowMap(shadowPos, vec2(-1.0, -1.0), bias) * 0.75;
    visibility += sampleShadowMap(shadowPos, vec2( 0.0, -1.0), bias);
    visibility += sampleShadowMap(shadowPos, vec2( 1.0, -1.0), bias) * 0.75;
    visibility += sampleShadowMap(shadowPos, vec2(-1.0,  0.0), bias);
    visibility += sampleShadowMap(shadowPos, vec2( 0.0,  0.0), bias) * 1.25;
    visibility += sampleShadowMap(shadowPos, vec2( 1.0,  0.0), bias);
    visibility += sampleShadowMap(shadowPos, vec2(-1.0,  1.0), bias) * 0.75;
    visibility += sampleShadowMap(shadowPos, vec2( 0.0,  1.0), bias);
    visibility += sampleShadowMap(shadowPos, vec2( 1.0,  1.0), bias) * 0.75;
    visibility /= 8.25;

    float distanceFade = 1.0 - smoothstep(farPlane * SHADOW_FADE_START, farPlane, viewDistance);
    float edgeFade = getShadowEdgeFade(shadowPos);
    float weatherFade = 1.0 - clamp(rainStrength, 0.0, 1.0) * 0.55;
    float timeFade = getShadowDayFactor(worldTime);
    float shadowStrength = distanceFade * edgeFade * weatherFade * timeFade;

    return mix(1.0, visibility, shadowStrength);
}

vec3 applyShadow(vec3 color, float visibility, float sceneMask) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float darkSurfaceProtection = smoothstep(0.06, 0.42, luma);
    float shadowAmount = (1.0 - visibility) * SHADOW_DARKNESS * darkSurfaceProtection * sceneMask;
    vec3 shadowTint = vec3(0.80, 0.86, 0.94);
    return mix(color, color * shadowTint, shadowAmount);
}