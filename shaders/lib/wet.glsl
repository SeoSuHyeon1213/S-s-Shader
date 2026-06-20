// Fake wet-surface reflection utilities

const vec3 WET_REFLECTION_COLOR = vec3(0.204, 0.137, 0.651); // #3423A6
const vec3 WET_COOL_HIGHLIGHT   = vec3(0.68, 0.78, 1.00);
const float WET_SPECULAR_F0 = 0.045;
const float WET_SPECULAR_PI = 3.14159265;
const float WET_FLOOR_SPECULAR_POWER = 96.0;
const float WET_WALL_SPECULAR_POWER = 42.0;
const float WET_WALL_STREAK_STRENGTH = 0.72;
const float WET_WALL_DARKEN_STRENGTH = 0.16;
const float WET_TERRAIN_REFLECTION_STRENGTH = 0.34;
const float WET_TERRAIN_REFLECTION_OFFSET = 0.026;
const float WATER_PLANAR_FALLBACK_STRENGTH = 0.18;
const float WATER_ABSORPTION_DISTANCE = 42.0;

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


float getRainPuddleMask(vec2 uv, float frameTimeCounter) {
    float large = sin(uv.x * 18.0 + sin(uv.y * 7.0) * 1.7);
    float medium = sin(uv.y * 31.0 - uv.x * 11.0 + 1.3);
    float small = sin((uv.x + uv.y) * 67.0 + frameTimeCounter * 0.35);
    float puddle = large * 0.50 + medium * 0.35 + small * 0.15;
    return smoothstep(0.08, 0.72, puddle);
}

vec3 sampleRainPuddleReflection(sampler2D sceneTexture, vec2 uv, vec2 reflectionOffset, float roughness) {
    vec2 r = reflectionOffset;
    vec2 blur = vec2(0.0045, 0.0025) * roughness;
    vec3 reflection = texture2D(sceneTexture, clamp(uv + r, vec2(0.001), vec2(0.999))).rgb * 0.34;
    reflection += texture2D(sceneTexture, clamp(uv + r + blur, vec2(0.001), vec2(0.999))).rgb * 0.18;
    reflection += texture2D(sceneTexture, clamp(uv + r - blur, vec2(0.001), vec2(0.999))).rgb * 0.18;
    reflection += texture2D(sceneTexture, clamp(uv + r + blur.yx, vec2(0.001), vec2(0.999))).rgb * 0.15;
    reflection += texture2D(sceneTexture, clamp(uv + r - blur.yx, vec2(0.001), vec2(0.999))).rgb * 0.15;
    return reflection;
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

float getWetMaterialResponse(float terrainWetMask, float terrainWallMask) {
    return clamp(max(terrainWetMask, terrainWallMask), 0.0, 1.0);
}

float getWetMaterialRoughness(float terrainWetMask, float terrainWallMask) {
    float floorMask = clamp(terrainWetMask, 0.0, 1.0);
    float wallMask = clamp(terrainWallMask, 0.0, 1.0);
    float response = getWetMaterialResponse(floorMask, wallMask);
    float wallAmount = clamp(wallMask / max(floorMask + wallMask, 0.001), 0.0, 1.0);

    float glossyStoneOrGlass = smoothstep(0.58, 0.92, response);
    float softFoliageOrCrop = 1.0 - smoothstep(0.20, 0.42, response);
    float woodSoilBand = 1.0 - abs(response - 0.42) / 0.26;
    woodSoilBand = clamp(woodSoilBand, 0.0, 1.0);

    float roughness = mix(0.64, 0.30, glossyStoneOrGlass);
    roughness = mix(roughness, 0.56, woodSoilBand * 0.55);
    roughness = mix(roughness, 0.88, softFoliageOrCrop);
    roughness += wallAmount * 0.12;
    return clamp(roughness, 0.18, 0.94);
}

float getWetMaterialF0(float terrainWetMask, float terrainWallMask) {
    float response = getWetMaterialResponse(terrainWetMask, terrainWallMask);
    float glossyStoneOrGlass = smoothstep(0.58, 0.90, response);
    float softFoliageOrCrop = 1.0 - smoothstep(0.18, 0.38, response);
    float f0 = mix(0.035, 0.072, glossyStoneOrGlass);
    f0 = mix(f0, 0.024, softFoliageOrCrop);
    return clamp(f0, 0.018, 0.085);
}

float getWetMaterialSpecularWeight(float terrainWetMask, float terrainWallMask) {
    float response = getWetMaterialResponse(terrainWetMask, terrainWallMask);
    float softFoliageOrCrop = 1.0 - smoothstep(0.18, 0.42, response);
    float glossyStoneOrGlass = smoothstep(0.58, 0.88, response);
    return clamp(mix(0.48, 1.18, glossyStoneOrGlass) * mix(1.0, 0.42, softFoliageOrCrop), 0.18, 1.22);
}

float getWetSpecularBRDF(vec3 normal, vec3 viewDir, vec3 lightDir, float roughness, float f0) {
    vec3 halfDir = normalize(viewDir + lightDir);
    float noV = clamp(dot(normal, viewDir), 0.0, 1.0);
    float noL = clamp(dot(normal, lightDir), 0.0, 1.0);
    float noH = clamp(dot(normal, halfDir), 0.0, 1.0);
    float voH = clamp(dot(viewDir, halfDir), 0.0, 1.0);

    float alpha = max(roughness * roughness, 0.025);
    float alpha2 = alpha * alpha;
    float denom = noH * noH * (alpha2 - 1.0) + 1.0;
    float distribution = alpha2 / max(WET_SPECULAR_PI * denom * denom, 0.0001);

    float k = (roughness + 1.0);
    k = (k * k) * 0.125;
    float geometryV = noV / max(noV * (1.0 - k) + k, 0.0001);
    float geometryL = noL / max(noL * (1.0 - k) + k, 0.0001);
    float geometry = geometryV * geometryL;

    float fresnel = f0 + (1.0 - f0) * pow(1.0 - voH, 5.0);
    float specular = distribution * geometry * fresnel;
    return specular * noL * smoothstep(0.02, 0.30, noV);
}

vec3 applyWetSpecularBRDF(
    vec3 color,
    vec3 worldDir,
    float depth,
    float sceneMask,
    float terrainWetMask,
    float terrainWallMask,
    vec3 worldNormal,
    float normalMask,
    float rainStrength,
    int worldTime,
    float intensity
) {
    float rain = clamp(rainStrength, 0.0, 1.0);
    float floorMask = clamp(terrainWetMask, 0.0, 1.0);
    float wallMask = clamp(terrainWallMask, 0.0, 1.0);
    float wetMask = combineWetSurfaceMask(color, depth, sceneMask, floorMask, wallMask) * rain * intensity;
    if (wetMask <= 0.001) return color;

    vec3 fallbackNormal = getWetApproxNormal(worldDir, floorMask, wallMask);
    vec3 normal = normalize(mix(fallbackNormal, normalize(worldNormal), clamp(normalMask, 0.0, 1.0)));
    vec3 viewDir = normalize(-worldDir);
    vec3 lightDir = getWetLightDirection(worldTime);
    float roughness = getWetMaterialRoughness(floorMask, wallMask);
    float f0 = getWetMaterialF0(floorMask, wallMask);
    float materialWeight = getWetMaterialSpecularWeight(floorMask, wallMask);
    float specular = getWetSpecularBRDF(normal, viewDir, lightDir, roughness, f0) * materialWeight;
    float lumaProtection = 1.0 - smoothstep(0.82, 1.35, getLuminance(color));
    vec3 specularColor = getWetSpecularColor(worldTime, rain);

    color += specularColor * specular * wetMask * lumaProtection * 2.35;
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


vec3 applyWetGroundLayer(
    vec3 color,
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
    float floorOnly = floorMask * (1.0 - wallMask * 0.82);
    float surfaceMask = getWetSurfaceMask(color, depth, sceneMask);
    float wetMask = surfaceMask * floorOnly * rain * intensity;
    if (wetMask <= 0.001) return color;

    float puddle = getRainPuddleMask(uv * vec2(1.0, 0.72), frameTimeCounter);
    vec3 viewDir = normalize(-worldDir);
    float grazing = pow(1.0 - clamp(viewDir.y, 0.0, 1.0), 2.0);
    float luma = getLuminance(color);
    float darken = wetMask * mix(0.24, 0.42, puddle) * (1.0 - smoothstep(0.78, 1.25, luma));
    float sheen = wetMask * (0.055 + grazing * 0.22) * mix(0.40, 1.0, puddle);

    vec3 wetBase = color * vec3(0.58, 0.68, 0.72);
    vec3 coolFilm = mix(vec3(getLuminance(color)), skyReflectionColor, 0.42);
    color = mix(color, wetBase, darken);
    color = mix(color, coolFilm, sheen * 0.32);
    color += mix(WET_COOL_HIGHLIGHT, skyReflectionColor, 0.58) * sheen * 0.105;

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
    float floorOnly = floorMask * (1.0 - wallMask * 0.78);
    float surfaceMask = getWetSurfaceMask(color, depth, sceneMask);
    float puddle = getRainPuddleMask(uv * vec2(1.0, 0.72), frameTimeCounter);
    float wetMask = surfaceMask * floorOnly * rain * intensity;
    if (wetMask <= 0.001) return color;

    vec3 viewDir = normalize(-worldDir);
    float grazing = pow(1.0 - clamp(viewDir.y, 0.0, 1.0), 2.0);
    float streak = getWetReflectionStreak(uv * vec2(1.0, 0.65), frameTimeCounter);
    float puddleMask = clamp(mix(0.45, 1.0, puddle) * smoothstep(0.08, 0.85, rain), 0.0, 1.0);
    float roughness = clamp(0.42 + rain * 0.28 + (1.0 - puddleMask) * 0.30, 0.28, 1.0);
    vec2 reflectionOffset = vec2(worldDir.x * 0.014, WET_TERRAIN_REFLECTION_OFFSET + grazing * 0.026) * (1.0 - roughness * 0.28);
    vec2 reflectionUv = clamp(uv + reflectionOffset, vec2(0.001), vec2(0.999));
    float edgeFade = getWetScreenEdgeFade(reflectionUv);

    vec3 roughReflection = sampleRainPuddleReflection(sceneTexture, uv, reflectionOffset, roughness);
    float reflectionLuma = getLuminance(roughReflection);
    float reflectionMask = smoothstep(0.12, 0.86, reflectionLuma) * (1.0 - smoothstep(1.15, 1.75, reflectionLuma)) * edgeFade;
    vec3 matchedReflection = mix(roughReflection * vec3(0.72, 0.86, 1.04), skyReflectionColor, 0.30 + grazing * 0.22 + roughness * 0.18);

    float reflectionAmount = wetMask * puddleMask * reflectionMask * (0.30 + grazing * 0.70) * WET_TERRAIN_REFLECTION_STRENGTH;
    color = mix(color, matchedReflection, reflectionAmount);
    color = mix(color, color * vec3(0.82, 0.90, 1.02), wetMask * floorOnly * (0.08 + puddleMask * 0.10));
    color += mix(WET_COOL_HIGHLIGHT, skyReflectionColor, 0.52) * wetMask * puddleMask * (0.018 + streak * grazing * 0.030);

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
    color += wetTint * wetMask * highlightMask * (0.045 + streak * 0.030);

    return color;
}

vec3 sampleWaterPlanarFallback(sampler2D sceneTexture, vec2 uv, vec3 worldDir, float roughness, float flow) {
    vec2 mirroredUv = vec2(uv.x + worldDir.x * 0.018, 1.0 - uv.y + 0.075 + worldDir.y * 0.035);
    mirroredUv += vec2(flow - 0.5, 0.5 - flow) * 0.010;
    mirroredUv = clamp(mirroredUv, vec2(0.001), vec2(0.999));

    vec2 blur = vec2(0.0065, 0.0035) * roughness;
    vec3 reflection = texture2D(sceneTexture, mirroredUv).rgb * 0.36;
    reflection += texture2D(sceneTexture, clamp(mirroredUv + blur, vec2(0.001), vec2(0.999))).rgb * 0.16;
    reflection += texture2D(sceneTexture, clamp(mirroredUv - blur, vec2(0.001), vec2(0.999))).rgb * 0.16;
    reflection += texture2D(sceneTexture, clamp(mirroredUv + blur.yx, vec2(0.001), vec2(0.999))).rgb * 0.16;
    reflection += texture2D(sceneTexture, clamp(mirroredUv - blur.yx, vec2(0.001), vec2(0.999))).rgb * 0.16;
    return reflection;
}

vec3 applyWaterDepthAbsorption(vec3 color, vec3 waterTint, float viewDistance, float verticalWater, float flow, float mask) {
    float horizontalWater = 1.0 - verticalWater;
    float depthAmount = smoothstep(3.0, WATER_ABSORPTION_DISTANCE, viewDistance) * horizontalWater;
    float flowFoam = smoothstep(0.62, 1.0, flow) * verticalWater;
    vec3 shallowTint = vec3(0.50, 0.72, 0.92);
    vec3 deepTint = mix(vec3(0.035, 0.090, 0.160), waterTint, 0.35);

    color = mix(color, color * shallowTint, mask * horizontalWater * 0.12);
    color = mix(color, color * deepTint, mask * depthAmount * 0.42);
    color += waterTint * mask * flowFoam * 0.020;
    return color;
}

vec3 applyWaterSurface(
    vec3 color,
    sampler2D sceneTexture,
    vec2 uv,
    float sceneMask,
    float waterMask,
    vec3 worldNormal,
    vec3 worldDir,
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
    vec3 viewToCamera = normalize(-worldDir);
    float fresnel = pow(1.0 - clamp(abs(dot(waterNormal, viewToCamera)), 0.0, 1.0), 3.0);
    float horizontalWater = 1.0 - verticalWater;
    float roughness = clamp(0.34 + rainStrength * 0.22 + waterfallMask * 0.38 + (1.0 - horizontalWater) * 0.18, 0.25, 1.0);
    vec3 softReflection = mix(skyReflectionColor, waterTint, 0.32 + roughness * 0.24);
    vec3 roughReflection = mix(skyReflectionColor, waterTint, roughness * 0.28 + flow * 0.06);
    vec3 planarFallback = sampleWaterPlanarFallback(sceneTexture, uv, worldDir, roughness, flow);
    float reflectionBrightness = smoothstep(0.08, 0.72, getLuminance(skyReflectionColor));
    float planarLuma = smoothstep(0.10, 0.90, getLuminance(planarFallback));

    color = mix(color, color * vec3(0.86, 0.95, 1.06), mask * 0.18 * horizontalWater);
    color = applyWaterDepthAbsorption(color, waterTint, viewDistance, verticalWater, flow, mask);
    color = mix(color, mix(color * deepWaterTint, color * vec3(0.55, 0.72, 0.95), 0.38 + flow * 0.18), mask * waterfallMask * 0.34);
    vec3 stableReflection = mix(roughReflection, planarFallback * vec3(0.58, 0.76, 0.96), planarLuma * WATER_PLANAR_FALLBACK_STRENGTH * horizontalWater);
    vec3 skyMatchedReflection = mix(stableReflection, skyReflectionColor, fresnel * 0.42 + waterfallMask * 0.24);
    float reflectionAmount = mask * intensity * reflectionBrightness * mix(0.035 + fresnel * 0.105, 0.012, waterfallMask) * horizontalWater;
    color = mix(color, skyMatchedReflection, reflectionAmount);
    color += softReflection * mask * intensity * rainBoost * (0.018 + ripple * 0.010 + fresnel * 0.032) * horizontalWater;
    color += waterTint * mask * waterfallMask * (0.010 + flow * 0.012);

    return color;
}
