// Shadow mapping utilities

#define SHADOW_MODE 1 // Shadow filter mode: 0 = Poisson PCF, 1 = PCSS blocker search [0 1]

const float SHADOW_DARKNESS = 0.66;
const float SHADOW_FADE_START = 0.58;
const float SHADOW_BIAS = 0.0012;
const float SHADOW_SLOPE_BIAS = 2.4;
const float SHADOW_DISTANCE_BIAS = 0.0015;
const float SHADOW_EDGE_FADE = 0.045;
const float SHADOW_TEXEL_SIZE = 1.0 / 2048.0;

const float SHADOW_POISSON_RADIUS = 1.65;
const float SHADOW_POISSON_NEAR_RADIUS = 1.15;
const int SHADOW_PCF_SAMPLES = 8;
const int PCSS_BLOCKER_SAMPLES = 8;
const int PCSS_FILTER_SAMPLES = 8;
const float PCSS_SEARCH_NEAR_RADIUS = 1.0;
const float PCSS_SEARCH_FAR_RADIUS = 2.6;
const float PCSS_LIGHT_SIZE = 20.0;
const float PCSS_MIN_RADIUS = 0.85;
const float PCSS_MAX_RADIUS = 2.0;
const float RAIN_EXPOSURE_MIN = 0.08;

float getShadowDayFactor(int worldTime) {
    float time = mod(float(worldTime), 24000.0);
    float sunrise = smoothstep(0.0, 3000.0, time);
    float sunset = 1.0 - smoothstep(12000.0, 13500.0, time);
    float dayMask = sunrise * sunset;

    // Moon shadows stay subtle so night scenes keep readability.
    return max(dayMask, (1.0 - dayMask) * 0.42);
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


float shadowHash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 rotateShadowOffset(vec2 offset, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return vec2(offset.x * c - offset.y * s, offset.x * s + offset.y * c);
}

vec2 getPoissonShadowOffset(int index) {
    if (index == 0) return vec2(-0.326, -0.406);
    if (index == 1) return vec2(-0.840, -0.074);
    if (index == 2) return vec2(-0.696,  0.457);
    if (index == 3) return vec2(-0.203,  0.621);
    if (index == 4) return vec2( 0.962, -0.195);
    if (index == 5) return vec2( 0.473, -0.480);
    if (index == 6) return vec2( 0.519,  0.767);
    return vec2( 0.185, -0.893);
}

float samplePoissonShadow(vec3 shadowPos, float bias, float radius, int sampleCount) {
    float angle = shadowHash12(shadowPos.xy * 2048.0 + shadowPos.z) * 6.2831853;
    float visibility = sampleShadowMap(shadowPos, vec2(0.0), bias) * 1.35;
    float weightSum = 1.35;

    for (int i = 0; i < 8; i++) {
        if (i < sampleCount) {
            vec2 offset = rotateShadowOffset(getPoissonShadowOffset(i), angle) * radius;
            float weight = mix(1.08, 0.78, float(i) / 7.0);
            visibility += sampleShadowMap(shadowPos, offset, bias) * weight;
            weightSum += weight;
        }
    }

    return visibility / weightSum;
}


float findAverageBlockerDepth(vec3 shadowPos, float bias, float searchRadius) {
    float angle = shadowHash12(shadowPos.xy * 2048.0 + shadowPos.z * 17.0) * 6.2831853;
    float blockerSum = 0.0;
    float blockerCount = 0.0;

    for (int i = 0; i < PCSS_BLOCKER_SAMPLES; i++) {
        vec2 offset = rotateShadowOffset(getPoissonShadowOffset(i), angle) * searchRadius;
        vec2 sampleUv = shadowPos.xy + offset * SHADOW_TEXEL_SIZE;
        if (sampleUv.x > 0.001 && sampleUv.x < 0.999 && sampleUv.y > 0.001 && sampleUv.y < 0.999) {
            float blockerDepth = texture2D(shadowtex0, sampleUv).r;
            if (blockerDepth < shadowPos.z - bias) {
                blockerSum += blockerDepth;
                blockerCount += 1.0;
            }
        }
    }

    if (blockerCount < 0.5) return -1.0;
    return blockerSum / blockerCount;
}

float getPCSSPenumbraRadius(float receiverDepth, float blockerDepth) {
    float depthDelta = max(receiverDepth - blockerDepth, 0.0);
    return clamp(depthDelta * PCSS_LIGHT_SIZE, PCSS_MIN_RADIUS, PCSS_MAX_RADIUS);
}

float samplePCSSShadow(vec3 shadowPos, float bias, float viewDistance, float farPlane) {
    float searchRadius = mix(PCSS_SEARCH_NEAR_RADIUS, PCSS_SEARCH_FAR_RADIUS, smoothstep(0.0, farPlane, viewDistance));
    float blockerDepth = findAverageBlockerDepth(shadowPos, bias, searchRadius);

    if (blockerDepth < 0.0) return 1.0;

    float penumbraRadius = getPCSSPenumbraRadius(shadowPos.z, blockerDepth);
    float distanceRadius = mix(SHADOW_POISSON_NEAR_RADIUS, SHADOW_POISSON_RADIUS, smoothstep(0.0, farPlane, viewDistance));
    float filterRadius = max(distanceRadius, penumbraRadius);

    return samplePoissonShadow(shadowPos, bias, filterRadius, PCSS_FILTER_SAMPLES);
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
    float visibility = 1.0;
#if SHADOW_MODE == 1
    visibility = samplePCSSShadow(shadowPos, bias, viewDistance, farPlane);
#else
    float distanceRadius = mix(SHADOW_POISSON_NEAR_RADIUS, SHADOW_POISSON_RADIUS, smoothstep(0.0, farPlane, viewDistance));
    visibility = samplePoissonShadow(shadowPos, bias, distanceRadius, SHADOW_PCF_SAMPLES);
#endif

    float distanceFade = 1.0 - smoothstep(farPlane * SHADOW_FADE_START, farPlane, viewDistance);
    float edgeFade = getShadowEdgeFade(shadowPos);
    float weatherFade = 1.0 - clamp(rainStrength, 0.0, 1.0) * 0.55;
    float timeFade = getShadowDayFactor(worldTime);
    float shadowStrength = distanceFade * edgeFade * weatherFade * timeFade;

    return mix(1.0, visibility, shadowStrength);
}

float getRainExposure(
    vec3 worldPos,
    float viewDistance,
    float farPlane,
    float sceneMask
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

    float bias = getShadowBias(shadowPos, viewDistance, farPlane) * 1.35;
    float visibility = samplePoissonShadow(shadowPos, bias, SHADOW_POISSON_NEAR_RADIUS, 5);

    float distanceFade = 1.0 - smoothstep(farPlane * 0.62, farPlane, viewDistance);
    float edgeFade = getShadowEdgeFade(shadowPos);
    float exposure = smoothstep(0.18, 0.82, visibility);

    return mix(1.0, clamp(exposure, RAIN_EXPOSURE_MIN, 1.0), distanceFade * edgeFade);
}

vec3 getSkyShadowTint(vec3 worldDir, int worldTime, float rainStrength) {
    vec3 skyColor = getSkyColor(worldDir, worldTime, rainStrength);
    float skyLuma = max(dot(skyColor, vec3(0.2126, 0.7152, 0.0722)), 1e-4);
    vec3 normalizedSky = skyColor / skyLuma;

    float dayMask = skyDayMask(worldTime);
    float nightMask = 1.0 - dayMask;
    float twilight = skyTwilightMask(worldTime);
    float rain = clamp(rainStrength, 0.0, 1.0);

    vec3 dayTint = vec3(0.76, 0.83, 0.94);
    vec3 nightTint = vec3(0.56, 0.62, 0.78);
    vec3 twilightTint = vec3(0.84, 0.74, 0.68);
    vec3 weatherTint = vec3(0.68, 0.72, 0.78);

    vec3 timeTint = mix(nightTint, dayTint, dayMask);
    timeTint = mix(timeTint, twilightTint, twilight * 0.42);
    timeTint = mix(timeTint, weatherTint, rain * 0.45);

    vec3 skyTint = clamp(normalizedSky * 0.58, vec3(0.52), vec3(1.08));
    vec3 tint = mix(timeTint, skyTint, 0.28 + rain * 0.10 + nightMask * 0.08);

    return clamp(tint, vec3(0.48), vec3(1.04));
}

vec3 applyShadow(vec3 color, float visibility, float sceneMask, vec3 worldDir, int worldTime, float rainStrength) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float darkSurfaceProtection = mix(0.48, 1.0, smoothstep(0.035, 0.34, luma));
    float shadowAmount = (1.0 - visibility) * SHADOW_DARKNESS * darkSurfaceProtection * sceneMask;
    vec3 shadowTint = getSkyShadowTint(worldDir, worldTime, rainStrength);
    return mix(color, color * shadowTint, shadowAmount);
}
