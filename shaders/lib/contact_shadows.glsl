// Near-field screen-space contact shadow utilities

const int CONTACT_SHADOW_SAMPLES = 8;
const float CONTACT_SHADOW_RADIUS = 0.0028;
const float CONTACT_SHADOW_MAX_DISTANCE = 4.5;
const float CONTACT_SHADOW_THICKNESS = 0.42;
const float CONTACT_SHADOW_NEAR_FADE = 1.2;
const float CONTACT_SHADOW_FAR_FADE = 42.0;

vec3 reconstructContactViewPosition(vec2 uv, float depth, mat4 projectionInverse) {
    vec4 clipPos = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = projectionInverse * clipPos;
    return viewPos.xyz / viewPos.w;
}

vec2 getContactShadowOffset(int index) {
    if (index == 0) return vec2(-0.326, -0.406);
    if (index == 1) return vec2(-0.840, -0.074);
    if (index == 2) return vec2(-0.696,  0.457);
    if (index == 3) return vec2(-0.203,  0.621);
    if (index == 4) return vec2( 0.962, -0.195);
    if (index == 5) return vec2( 0.473, -0.480);
    if (index == 6) return vec2( 0.519,  0.767);
    return vec2( 0.185, -0.893);
}

float getContactShadowAmount(
    sampler2D depthTexture,
    vec2 uv,
    float depth,
    vec3 viewPos,
    float sceneMask,
    mat4 projectionInverse,
    float viewDistance
) {
    if (sceneMask < 0.5 || depth >= 1.0) return 0.0;

    float distanceFade = (1.0 - smoothstep(CONTACT_SHADOW_FAR_FADE * 0.65, CONTACT_SHADOW_FAR_FADE, viewDistance));
    distanceFade *= smoothstep(0.0, CONTACT_SHADOW_NEAR_FADE, viewDistance);
    if (distanceFade <= 0.001) return 0.0;

    float radiusScale = mix(0.65, 1.55, clamp(viewDistance / CONTACT_SHADOW_FAR_FADE, 0.0, 1.0));
    float occlusion = 0.0;
    float weightSum = 0.0;

    for (int i = 0; i < CONTACT_SHADOW_SAMPLES; i++) {
        vec2 offset = getContactShadowOffset(i) * CONTACT_SHADOW_RADIUS * radiusScale;
        vec2 sampleUv = clamp(uv + offset, vec2(0.001), vec2(0.999));
        float sampleDepth = texture2D(depthTexture, sampleUv).r;
        if (sampleDepth < 1.0) {
            vec3 sampleViewPos = reconstructContactViewPosition(sampleUv, sampleDepth, projectionInverse);
            float frontDelta = sampleViewPos.z - viewPos.z;
            float sampleDistance = length(sampleViewPos - viewPos);
            float closeMask = 1.0 - smoothstep(0.35, CONTACT_SHADOW_MAX_DISTANCE, sampleDistance);
            float thicknessMask = 1.0 - smoothstep(CONTACT_SHADOW_THICKNESS, CONTACT_SHADOW_THICKNESS * 3.0, abs(frontDelta));
            float frontMask = smoothstep(0.015, CONTACT_SHADOW_THICKNESS, frontDelta);
            float weight = mix(1.05, 0.72, float(i) / float(CONTACT_SHADOW_SAMPLES - 1));
            occlusion += frontMask * thicknessMask * closeMask * weight;
            weightSum += weight;
        }
    }

    if (weightSum <= 0.001) return 0.0;
    return clamp(occlusion / weightSum, 0.0, 1.0) * distanceFade;
}

vec3 applyContactShadow(
    vec3 color,
    sampler2D depthTexture,
    vec2 uv,
    float depth,
    vec3 viewPos,
    float sceneMask,
    mat4 projectionInverse,
    float viewDistance,
    vec3 worldDir,
    int worldTime,
    float rainStrength,
    float intensity
) {
    float contact = getContactShadowAmount(depthTexture, uv, depth, viewPos, sceneMask, projectionInverse, viewDistance);
    if (contact <= 0.001) return color;

    vec3 tint = getSkyShadowTint(worldDir, worldTime, rainStrength);
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float surfaceProtection = smoothstep(0.05, 0.34, luma);
    float amount = contact * intensity * surfaceProtection;

    return mix(color, color * tint, amount);
}