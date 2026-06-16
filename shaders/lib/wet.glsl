// Fake wet-surface reflection utilities

const vec3 WET_REFLECTION_COLOR = vec3(0.204, 0.137, 0.651); // #3423A6
const vec3 WET_COOL_HIGHLIGHT   = vec3(0.68, 0.78, 1.00);

vec3 applyGlobalWetHighlight(
    vec3 color,
    float sceneMask,
    float rainStrength,
    float intensity
) {
    float rain = clamp(rainStrength, 0.0, 1.0);
    float luma = getLuminance(color);
    float highlightMask = smoothstep(0.35, 1.10, luma);
    float shadowProtection = smoothstep(0.08, 0.28, luma);
    float wetAmount = rain * intensity * sceneMask * shadowProtection;
    vec3 wetTint = mix(WET_COOL_HIGHLIGHT, WET_REFLECTION_COLOR, 0.18);

    color = mix(color, color * WET_REFLECTION_COLOR, wetAmount * 0.045);
    color += wetTint * highlightMask * wetAmount * 0.055;

    return color;
}

float getWetSurfaceMask(vec3 color, float depth, float sceneMask) {
    float luma = getLuminance(color);
    float skyMask = 1.0 - sceneMask;
    float nearSurfaceMask = 1.0 - smoothstep(0.985, 1.0, depth);
    float brightSurfaceMask = smoothstep(0.18, 0.85, luma);
    return clamp((1.0 - skyMask) * nearSurfaceMask * brightSurfaceMask, 0.0, 1.0);
}

float combineWetSurfaceMask(vec3 color, float depth, float sceneMask, float terrainWetMask, float terrainWallMask) {
    float floorMask = clamp(terrainWetMask, 0.0, 1.0);
    float wallMask = clamp(terrainWallMask, 0.0, 1.0);
    float normalMask = max(floorMask, wallMask * 0.18);
    return getWetSurfaceMask(color, depth, sceneMask) * normalMask;
}

float getWetReflectionStreak(vec2 uv, float frameTimeCounter) {
    float streakA = sin((uv.y + frameTimeCounter * 0.015) * 95.0 + uv.x * 13.0);
    float streakB = sin((uv.y - frameTimeCounter * 0.010) * 47.0 - uv.x * 19.0);
    float streak = streakA * 0.5 + streakB * 0.5;
    return smoothstep(0.35, 1.0, streak);
}

vec3 applyFakeWetReflection(
    vec3 color,
    vec2 uv,
    float depth,
    float sceneMask,
    float terrainWetMask,
    float terrainWallMask,
    float rainStrength,
    float frameTimeCounter,
    float intensity
) {
    float rain = clamp(rainStrength, 0.0, 1.0);
    float floorMask = clamp(terrainWetMask, 0.0, 1.0);
    float wallMask = clamp(terrainWallMask, 0.0, 1.0);
    float wetMask = combineWetSurfaceMask(color, depth, sceneMask, floorMask, wallMask) * rain * intensity;
    float luma = getLuminance(color);
    float highlightMask = smoothstep(0.45, 1.15, luma);
    float streak = getWetReflectionStreak(uv, frameTimeCounter) * mix(0.25, 1.0, floorMask);

    vec3 wetTint = mix(WET_COOL_HIGHLIGHT, WET_REFLECTION_COLOR, 0.22);
    color = mix(color, color * WET_REFLECTION_COLOR, wetMask * 0.10);
    color += wetTint * wetMask * highlightMask * (0.06 + streak * 0.045);

    return color;
}

vec3 applyWaterSurface(
    vec3 color,
    sampler2D sceneTexture,
    vec2 uv,
    float sceneMask,
    float waterMask,
    float rainStrength,
    float frameTimeCounter,
    float intensity
) {
    float mask = clamp(waterMask, 0.0, 1.0) * sceneMask;
    if (mask <= 0.001) return color;

    float ripple = getWetReflectionStreak(uv * vec2(1.0, 0.72), frameTimeCounter);
    float rainBoost = mix(1.0, 1.25, clamp(rainStrength, 0.0, 1.0));
    vec3 waterTint = vec3(0.58, 0.76, 1.0);
    vec3 softReflection = mix(WET_COOL_HIGHLIGHT, waterTint, 0.65);
    vec2 roughOffset = vec2(0.0018, 0.0012) * (1.0 + rainStrength * 1.5);
    vec3 roughReflection =
        texture2D(sceneTexture, uv + roughOffset).rgb * 0.25 +
        texture2D(sceneTexture, uv - roughOffset).rgb * 0.25 +
        texture2D(sceneTexture, uv + roughOffset.yx).rgb * 0.25 +
        texture2D(sceneTexture, uv - roughOffset.yx).rgb * 0.25;
    float reflectionBrightness = smoothstep(0.25, 1.05, getLuminance(roughReflection));

    color = mix(color, color * vec3(0.88, 0.96, 1.08), mask * 0.28);
    color = mix(color, roughReflection * vec3(0.72, 0.88, 1.08), mask * intensity * reflectionBrightness * 0.12);
    color += softReflection * mask * intensity * rainBoost * (0.045 + ripple * 0.04);

    return color;
}
