// Fake wet-surface reflection utilities

const vec3 WET_REFLECTION_COLOR = vec3(0.204, 0.137, 0.651); // #3423A6
const vec3 WET_COOL_HIGHLIGHT   = vec3(0.68, 0.78, 1.00);
const float WET_SPECULAR_F0 = 0.045;
const float WET_FLOOR_SPECULAR_POWER = 96.0;
const float WET_WALL_SPECULAR_POWER = 42.0;
const float WET_WALL_STREAK_STRENGTH = 0.72;
const float WET_WALL_DARKEN_STRENGTH = 0.16;
const float WET_TERRAIN_REFLECTION_STRENGTH = 0.18;
const float WET_TERRAIN_REFLECTION_OFFSET = 0.032;

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

float getWetWallRunoffStreak(vec2 uv, float frameTimeCounter) {
    float columnA = sin(uv.x * 210.0 + sin(uv.y * 13.0) * 1.8);
    float columnB = sin(uv.x * 89.0 + 2.4);
    float columnMask = smoothstep(0.52, 0.98, columnA * 0.65 + columnB * 0.35);
    float fallingA = fract(uv.y * 7.0 - frameTimeCounter * 0.23 + columnA * 0.08);
    float fallingB = fract(uv.y * 13.0 - frameTimeCounter * 0.37 + columnB * 0.05);
    float drops = smoothstep(0.72, 1.0, fallingA) * 0.65 + smoothstep(0.84, 1.0, fallingB) * 0.35;
    return columnMask * drops;
}

float getWetWallLowerAccumulation(vec2 uv) {
    float lowerScreen = 1.0 - smoothstep(0.18, 0.72, uv.y);
    float unevenness = sin(uv.x * 37.0) * 0.08 + sin(uv.x * 91.0 + uv.y * 5.0) * 0.05;
    return clamp(lowerScreen + unevenness, 0.0, 1.0);
}

float getWetWallFacingMask(vec3 worldDir) {
    vec3 wallNormal = normalize(vec3(-worldDir.x, 0.0, -worldDir.z));
    float sideFacing = 0.55 + 0.45 * abs(wallNormal.x);
    float grazingView = smoothstep(0.15, 0.95, 1.0 - abs(worldDir.y));
    return clamp(sideFacing * grazingView, 0.0, 1.0);
}

float getWetScreenEdgeFade(vec2 uv) {
    vec2 edge = smoothstep(vec2(0.015), vec2(0.085), uv) *
                smoothstep(vec2(0.015), vec2(0.085), vec2(1.0) - uv);
    return edge.x * edge.y;
}

vec3 sampleWetTerrainRoughReflection(sampler2D sceneTexture, vec2 uv, vec2 reflectionOffset) {
    vec3 reflection = texture2D(sceneTexture, uv + reflectionOffset).rgb * 0.40;
    reflection += texture2D(sceneTexture, uv + reflectionOffset * vec2(0.55, 1.35)).rgb * 0.22;
    reflection += texture2D(sceneTexture, uv + reflectionOffset + vec2(0.006, 0.002)).rgb * 0.19;
    reflection += texture2D(sceneTexture, uv + reflectionOffset - vec2(0.006, 0.002)).rgb * 0.19;
    return reflection;
}

vec3 getWetLightDirection(int worldTime) {
    float time = mod(float(worldTime), 24000.0);
    float sunAngle = (time - 6000.0) / 24000.0 * 6.2831853;
    vec3 sunDir = normalize(vec3(sin(sunAngle), cos(sunAngle), 0.22));
    vec3 moonDir = -sunDir;
    float dayMask = getDayMask(worldTime);
    return normalize(mix(moonDir, sunDir, dayMask));
}

vec3 getWetSpecularColor(int worldTime, float rainStrength) {
    float dayMask = getDayMask(worldTime);
    vec3 lightColor = mix(MOON_LIGHT_COLOR, getSunColor(dayMask), dayMask);
    vec3 rainTint = mix(WET_COOL_HIGHLIGHT, WET_REFLECTION_COLOR, 0.22);
    return mix(lightColor, rainTint, clamp(rainStrength, 0.0, 1.0) * 0.25);
}

vec3 getWetApproxNormal(vec3 worldDir, float terrainWetMask, float terrainWallMask) {
    float floorMask = clamp(terrainWetMask, 0.0, 1.0);
    float wallMask = clamp(terrainWallMask, 0.0, 1.0);
    vec3 floorNormal = vec3(0.0, 1.0, 0.0);
    vec3 wallNormal = normalize(vec3(-worldDir.x, 0.16, -worldDir.z));
    float wallBlend = wallMask * (1.0 - floorMask);
    return normalize(mix(floorNormal, wallNormal, wallBlend));
}

float getWetSpecularBRDF(vec3 normal, vec3 viewDir, vec3 lightDir, float roughness) {
    vec3 halfDir = normalize(viewDir + lightDir);
    float noV = clamp(dot(normal, viewDir), 0.0, 1.0);
    float noL = clamp(dot(normal, lightDir), 0.0, 1.0);
    float noH = clamp(dot(normal, halfDir), 0.0, 1.0);
    float voH = clamp(dot(viewDir, halfDir), 0.0, 1.0);
    float specPower = mix(WET_FLOOR_SPECULAR_POWER, WET_WALL_SPECULAR_POWER, roughness);
    float fresnel = WET_SPECULAR_F0 + (1.0 - WET_SPECULAR_F0) * pow(1.0 - voH, 5.0);
    float specular = pow(noH, specPower) * noL * smoothstep(0.02, 0.35, noV);
    return specular * fresnel;
}

vec3 applyWetSpecularBRDF(
    vec3 color,
    vec3 worldDir,
    float depth,
    float sceneMask,
    float terrainWetMask,
    float terrainWallMask,
    float rainStrength,
    int worldTime,
    float intensity
) {
    float rain = clamp(rainStrength, 0.0, 1.0);
    float floorMask = clamp(terrainWetMask, 0.0, 1.0);
    float wallMask = clamp(terrainWallMask, 0.0, 1.0);
    float wetMask = combineWetSurfaceMask(color, depth, sceneMask, floorMask, wallMask) * rain * intensity;
    if (wetMask <= 0.001) return color;

    vec3 normal = getWetApproxNormal(worldDir, floorMask, wallMask);
    vec3 viewDir = normalize(-worldDir);
    vec3 lightDir = getWetLightDirection(worldTime);
    float wallAmount = wallMask * (1.0 - floorMask);
    float roughness = clamp(wallAmount * 0.7 + (1.0 - floorMask) * 0.2, 0.0, 1.0);
    float specular = getWetSpecularBRDF(normal, viewDir, lightDir, roughness);
    float lumaProtection = 1.0 - smoothstep(0.82, 1.35, getLuminance(color));
    vec3 specularColor = getWetSpecularColor(worldTime, rain);

    color += specularColor * specular * wetMask * lumaProtection * 1.85;
    return color;
}

vec3 applyWetWallRunoff(
    vec3 color,
    vec2 uv,
    vec3 worldDir,
    float depth,
    float sceneMask,
    float terrainWallMask,
    float rainStrength,
    float frameTimeCounter,
    float intensity
) {
    float rain = clamp(rainStrength, 0.0, 1.0);
    float wallMask = clamp(terrainWallMask, 0.0, 1.0);
    float surfaceMask = getWetSurfaceMask(color, depth, sceneMask);
    float wallWet = surfaceMask * wallMask * rain * intensity;
    if (wallWet <= 0.001) return color;

    float runoff = getWetWallRunoffStreak(uv, frameTimeCounter);
    float lowerAccumulation = getWetWallLowerAccumulation(uv);
    float facing = getWetWallFacingMask(worldDir);
    float luma = getLuminance(color);
    float darkenMask = smoothstep(0.08, 0.72, luma);
    vec3 wallTint = mix(WET_REFLECTION_COLOR, WET_COOL_HIGHLIGHT, 0.28);

    color = mix(color, color * mix(vec3(0.90, 0.94, 1.02), WET_REFLECTION_COLOR, 0.20),
                wallWet * lowerAccumulation * darkenMask * WET_WALL_DARKEN_STRENGTH);
    color += wallTint * wallWet * facing * runoff * WET_WALL_STREAK_STRENGTH * (0.025 + lowerAccumulation * 0.035);

    return color;
}

vec3 applyWetTerrainScreenReflection(
    vec3 color,
    sampler2D sceneTexture,
    vec2 uv,
    vec3 worldDir,
    float depth,
    float sceneMask,
    float terrainWetMask,
    float terrainWallMask,
    vec3 skyReflectionColor,
    float rainStrength,
    float frameTimeCounter,
    float intensity
) {
    float rain = clamp(rainStrength, 0.0, 1.0);
    float floorMask = clamp(terrainWetMask, 0.0, 1.0);
    float wallMask = clamp(terrainWallMask, 0.0, 1.0);
    float floorOnly = floorMask * (1.0 - wallMask * 0.65);
    float surfaceMask = getWetSurfaceMask(color, depth, sceneMask);
    float wetMask = surfaceMask * floorOnly * rain * intensity;
    if (wetMask <= 0.001) return color;

    vec3 viewDir = normalize(-worldDir);
    float grazing = pow(1.0 - clamp(viewDir.y, 0.0, 1.0), 2.0);
    float streak = getWetReflectionStreak(uv * vec2(1.0, 0.65), frameTimeCounter);
    vec2 reflectionOffset = vec2(worldDir.x * 0.018, WET_TERRAIN_REFLECTION_OFFSET + grazing * 0.035);
    vec2 reflectionUv = clamp(uv + reflectionOffset, vec2(0.001), vec2(0.999));
    float edgeFade = getWetScreenEdgeFade(reflectionUv);

    vec3 roughReflection = sampleWetTerrainRoughReflection(sceneTexture, uv, reflectionOffset);
    float reflectionLuma = getLuminance(roughReflection);
    float reflectionMask = smoothstep(0.18, 1.05, reflectionLuma) * edgeFade;
    vec3 matchedReflection = mix(roughReflection * vec3(0.78, 0.90, 1.06), skyReflectionColor, 0.22 + grazing * 0.18);

    float reflectionAmount = wetMask * reflectionMask * (0.35 + grazing * 0.65) * WET_TERRAIN_REFLECTION_STRENGTH;
    color = mix(color, matchedReflection, reflectionAmount);
    color += mix(WET_COOL_HIGHLIGHT, skyReflectionColor, 0.45) * wetMask * streak * grazing * 0.025;

    return color;
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
    vec3 worldNormal,
    float viewDistance,
    vec3 skyReflectionColor,
    float rainStrength,
    float frameTimeCounter,
    float intensity
) {
    float mask = clamp(waterMask, 0.0, 1.0) * sceneMask;
    if (mask <= 0.001) return color;

    vec3 waterNormal = normalize(worldNormal);
    float verticalWater = smoothstep(0.30, 0.86, 1.0 - abs(waterNormal.y));
    float nearWater = 1.0 - smoothstep(6.0, 24.0, viewDistance);
    float waterfallMask = verticalWater * nearWater;

    float ripple = getWetReflectionStreak(uv * vec2(0.72, 1.35), frameTimeCounter);
    float flowA = sin((uv.y - frameTimeCounter * 0.060) * 42.0 + uv.x * 9.0);
    float flowB = sin((uv.y - frameTimeCounter * 0.038) * 19.0 - uv.x * 15.0);
    float flow = (flowA * 0.55 + flowB * 0.45) * 0.5 + 0.5;
    float rainBoost = mix(1.0, 1.18, clamp(rainStrength, 0.0, 1.0));
    vec3 waterTint = vec3(0.44, 0.62, 0.86);
    vec3 deepWaterTint = mix(vec3(0.07, 0.14, 0.24), waterTint, 0.38);
    vec3 softReflection = mix(skyReflectionColor, waterTint, 0.42);
    vec2 roughOffset = vec2(0.0012, 0.0008) * (1.0 + rainStrength);
    vec3 roughReflection =
        texture2D(sceneTexture, uv + roughOffset).rgb * 0.25 +
        texture2D(sceneTexture, uv - roughOffset).rgb * 0.25 +
        texture2D(sceneTexture, uv + roughOffset.yx).rgb * 0.25 +
        texture2D(sceneTexture, uv - roughOffset.yx).rgb * 0.25;
    float reflectionLuma = getLuminance(roughReflection);
    float reflectionBrightness = smoothstep(0.30, 0.95, reflectionLuma) * (1.0 - smoothstep(1.05, 1.55, reflectionLuma));

    color = mix(color, color * vec3(0.86, 0.95, 1.06), mask * 0.22 * (1.0 - waterfallMask * 0.55));
    color = mix(color, mix(color * deepWaterTint, color * vec3(0.55, 0.72, 0.95), 0.38 + flow * 0.18), mask * waterfallMask * 0.34);
    vec3 skyMatchedReflection = mix(roughReflection * vec3(0.62, 0.78, 0.96), skyReflectionColor, 0.32 + waterfallMask * 0.34);
    float reflectionAmount = mask * intensity * reflectionBrightness * mix(0.10, 0.025, waterfallMask);
    color = mix(color, skyMatchedReflection, reflectionAmount);
    color += softReflection * mask * intensity * rainBoost * (0.025 + ripple * 0.018) * (1.0 - waterfallMask * 0.72);
    color += waterTint * mask * waterfallMask * (0.010 + flow * 0.012);

    return color;
}
