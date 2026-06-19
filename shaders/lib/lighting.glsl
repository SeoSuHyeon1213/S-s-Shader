// Mood lighting utilities

const vec3 SUN_LIGHT_COLOR    = vec3(0.945, 0.996, 0.776); // #F1FEC6 - midday sunlight
const vec3 SUN_HORIZON_COLOR  = vec3(1.000, 0.557, 0.282); // warm sunrise/sunset glow
const vec3 MOON_LIGHT_COLOR   = vec3(0.749, 0.847, 1.000); // cool blue moonlight, tuned for night readability
const vec3 TORCH_LIGHT_COLOR  = vec3(1.000, 0.520, 0.230); // warm installed-torch match
const vec3 TORCH_EDGE_COLOR   = vec3(1.000, 0.610, 0.300); // warm falloff, less milky than pale yellow
const vec3 LAVA_LIGHT_COLOR   = vec3(1.000, 0.227, 0.125); // #FF3A20
const vec3 LAVA_EDGE_COLOR    = vec3(1.000, 0.478, 0.239); // softer lava spill
const vec3 RAIN_ACCENT_COLOR  = vec3(0.204, 0.137, 0.651); // #3423A6
const vec3 RAIN_AMBIENT_COLOR = vec3(0.340, 0.360, 0.530); // desaturated rainy ambient tint

const float SUN_HORIZON_GLOW = 0.35; // base highlight warmth during sunrise/sunset
const float NIGHT_READABILITY_LIFT = 0.035; // subtle blue lift on dark areas at night

const float HELD_LIGHT_RANGE_BOOST = 1.25;
const float HELD_LIGHT_BRIGHTNESS = 0.32;
const float HELD_LIGHT_AMBIENT = 0.018;
const float HELD_LIGHT_DAY_OUTDOOR_MIN = 0.28;
const float HELD_LIGHT_FLICKER_AMOUNT = 0.035;

float getLuminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float getDayMask(int worldTime) {
    float time = mod(float(worldTime), 24000.0);
    float sunrise = smoothstep(0.0, 3000.0, time);
    float sunset = 1.0 - smoothstep(12000.0, 13500.0, time);
    return sunrise * sunset;
}

float getNightMask(int worldTime) {
    return 1.0 - getDayMask(worldTime);
}

// 0 at full day/night, peaks at 1.0 mid-transition (sunrise/sunset)
float getSunHorizonFactor(float dayMask) {
    return 4.0 * dayMask * (1.0 - dayMask);
}

// Shifts sunlight from midday warm-white toward a warm orange glow at sunrise/sunset
vec3 getSunColor(float dayMask) {
    return mix(SUN_LIGHT_COLOR, SUN_HORIZON_COLOR, getSunHorizonFactor(dayMask));
}

// Full strength at midday, with an extra glow during the sunrise/sunset transition
float getSunIntensity(float dayMask, float sunsetGlowStrength) {
    return dayMask * (1.0 + getSunHorizonFactor(dayMask) * SUN_HORIZON_GLOW * sunsetGlowStrength);
}

float getHeldLightLevel(int heldBlockLightValue, int heldBlockLightValue2) {
    return max(float(heldBlockLightValue), float(heldBlockLightValue2));
}

float getHandLightStrength(int heldBlockLightValue, int heldBlockLightValue2) {
    return clamp(getHeldLightLevel(heldBlockLightValue, heldBlockLightValue2) / 15.0, 0.0, 1.0);
}

float getHeldLightDistanceFalloff(vec3 viewPos, int heldBlockLightValue, int heldBlockLightValue2) {
    float lightLevel = getHeldLightLevel(heldBlockLightValue, heldBlockLightValue2);
    float range = max(lightLevel * HELD_LIGHT_RANGE_BOOST, 1.0);
    vec3 handLightPos = vec3(0.35, -0.30, -0.20);
    float lightDistance = length(viewPos - handLightPos);
    float t = clamp(1.0 - lightDistance / range, 0.0, 1.0);
    float smoothFalloff = t * t * (3.0 - 2.0 * t);

    vec3 viewDir = normalize(viewPos + vec3(0.0, 0.0, -0.0001));
    float forwardMask = smoothstep(0.05, 0.85, -viewDir.z);
    float centerMask = 1.0 - smoothstep(0.12, 1.20, length(viewDir.xy));

    return smoothFalloff * mix(0.55, 1.0, forwardMask * centerMask);
}

float getHeldLightEnvironmentFactor(vec3 color, float dayMask) {
    float luma = getLuminance(color);
    float darkInteriorBoost = mix(1.02, 1.18, 1.0 - smoothstep(0.12, 0.55, luma));
    float brightDayOutdoorMask = dayMask * smoothstep(0.55, 0.95, luma);
    return darkInteriorBoost * mix(1.0, HELD_LIGHT_DAY_OUTDOOR_MIN, brightDayOutdoorMask);
}

float getTorchFlicker(float frameTimeCounter, float handLightStrength) {
    float slowWave = sin(frameTimeCounter * 9.7);
    float fastWave = sin(frameTimeCounter * 21.3 + 1.7);
    float flicker = (slowWave * 0.65 + fastWave * 0.35) * HELD_LIGHT_FLICKER_AMOUNT;
    return 1.0 + flicker * handLightStrength;
}

vec3 applyHeldTorchLight(vec3 color, float heldLightMask, float strength, float torchIntensity, float flicker) {
    float luma = getLuminance(color);
    float surfaceProtection = 1.0 - smoothstep(0.58, 0.98, luma);
    float coreMask = heldLightMask * heldLightMask;
    float edgeMask = heldLightMask * (1.0 - coreMask);
    vec3 torchTint = mix(TORCH_EDGE_COLOR, TORCH_LIGHT_COLOR, 0.72 + coreMask * 0.28);
    vec3 warmLift = mix(vec3(1.0), torchTint, 0.58);

    color = mix(color, color * warmLift, edgeMask * strength * torchIntensity * 0.24);
    color += torchTint * coreMask * strength * torchIntensity * flicker *
             (HELD_LIGHT_AMBIENT + HELD_LIGHT_BRIGHTNESS * surfaceProtection);
    color = mix(color, color * vec3(1.035, 0.985, 0.930), heldLightMask * strength * torchIntensity * 0.10);

    return color;
}


vec3 getDirectionalLightVector(int worldTime) {
    float phase = mod(float(worldTime), 24000.0) / 24000.0;
    float angle = (phase - 0.25) * 6.2831853;
    vec3 sunDir = normalize(vec3(-sin(angle), max(cos(angle), 0.08), 0.28));
    vec3 moonDir = normalize(vec3(sin(angle), max(-cos(angle), 0.08), -0.22));
    return normalize(mix(moonDir, sunDir, skyDayMask(worldTime)));
}

vec3 getApproxTerrainNormal(vec3 worldDir, float floorMask, float wallMask) {
    vec3 floorNormal = vec3(0.0, 1.0, 0.0);
    vec3 wallNormal = normalize(vec3(-worldDir.x, 0.22, -worldDir.z));
    float wallBlend = clamp(wallMask / max(floorMask + wallMask, 0.001), 0.0, 1.0);
    return normalize(mix(floorNormal, wallNormal, wallBlend));
}

vec3 applyTerrainFormLighting(
    vec3 color,
    vec3 worldDir,
    float sceneMask,
    float floorMask,
    float wallMask,
    float shadowVisibility,
    vec3 worldNormal,
    float normalMask,
    int worldTime,
    float rainStrength
) {
    float materialMask = max(max(floorMask, wallMask), normalMask);
    float terrainMask = clamp(materialMask * sceneMask, 0.0, 1.0);
    if (terrainMask <= 0.001) return color;

    vec3 fallbackNormal = getApproxTerrainNormal(worldDir, floorMask, wallMask);
    vec3 normal = normalize(mix(fallbackNormal, worldNormal, clamp(normalMask, 0.0, 1.0)));
    vec3 lightDir = getDirectionalLightVector(worldTime);
    float dayMask = skyDayMask(worldTime);
    float twilight = skyTwilightMask(worldTime);
    float rain = clamp(rainStrength, 0.0, 1.0);
    float visibility = clamp(shadowVisibility, 0.0, 1.0);

    float noL = clamp(dot(normal, lightDir), 0.0, 1.0);
    float diffuse = noL * noL * (3.0 - 2.0 * noL);
    float backFace = pow(1.0 - noL, 1.35);
    float shadowMask = 1.0 - visibility;
    float normalConfidence = clamp(normalMask, 0.0, 1.0);

    vec3 directLight = mix(MOON_LIGHT_COLOR * 0.34, SUN_LIGHT_COLOR, dayMask);
    directLight = mix(directLight, SUN_HORIZON_COLOR, twilight * 0.24);
    vec3 skyShade = getSkyShadowTint(worldDir, worldTime, rainStrength);
    vec3 normalShade = mix(vec3(0.52, 0.59, 0.74), skyShade, 0.50);

    float diffuseAmount = diffuse * visibility * terrainMask * normalConfidence * mix(0.045, 0.125, dayMask) * (1.0 - rain * 0.35);
    float formShadow = backFace * terrainMask * normalConfidence * mix(0.095, 0.130, dayMask);
    float castShadow = shadowMask * terrainMask * normalConfidence * mix(0.130, 0.160, dayMask);
    float combinedShadow = clamp(formShadow + castShadow + formShadow * castShadow * 0.8, 0.0, 0.52);

    color = mix(color, color * normalShade, combinedShadow);
    color += directLight * diffuseAmount;
    return color;
}
vec3 applyMoodLighting(
    vec3 color,
    vec3 viewPos,
    float sceneMask,
    float strength,
    float rainStrength,
    int worldTime,
    int heldBlockLightValue,
    int heldBlockLightValue2,
    float shadowVisibility,
    float lavaMask,
    float frameTimeCounter,
    float torchIntensity,
    float dayLightStrength,
    float nightLightStrength,
    float sunsetGlowStrength
) {
    float luma = getLuminance(color);
    float shadowMask = 1.0 - smoothstep(0.12, 0.55, luma);
    float castShadowMask = (1.0 - clamp(shadowVisibility, 0.0, 1.0)) * sceneMask;
    float ambientShadowMask = shadowMask * (1.0 - castShadowMask * 0.62);
    float highlightMask = smoothstep(0.55, 1.25, luma);
    float rain = clamp(rainStrength, 0.0, 1.0);
    float dayMask = getDayMask(worldTime);
    float nightMask = getNightMask(worldTime);
    vec3 sunColor = getSunColor(dayMask) * dayLightStrength;
    vec3 moonColor = MOON_LIGHT_COLOR * nightLightStrength;
    float sunIntensity = getSunIntensity(dayMask, sunsetGlowStrength) * dayLightStrength;
    float sunGlow = getSunHorizonFactor(dayMask);
    float handLightStrength = getHandLightStrength(heldBlockLightValue, heldBlockLightValue2);
    float heldLightBase = handLightStrength
        * getHeldLightDistanceFalloff(viewPos, heldBlockLightValue, heldBlockLightValue2)
        * sceneMask;
    float heldLightMask = clamp(heldLightBase * getHeldLightEnvironmentFactor(color, dayMask), 0.0, 1.0);
    float torchFlicker = getTorchFlicker(frameTimeCounter, handLightStrength);
    float weatherDampen = 1.0 - rain * 0.35;

    vec3 skyTint = mix(moonColor, sunColor, dayMask);
    vec3 shadowTint = mix(vec3(0.86, 0.92, 1.06), skyTint, 0.35 + nightMask * 0.25);
    vec3 highlightTint = mix(moonColor, sunColor, sunIntensity * 0.85 + 0.15);
    vec3 rainReflectTint = mix(vec3(0.85, 0.90, 1.0), RAIN_ACCENT_COLOR, 0.18);
    vec3 lavaSpill = mix(LAVA_EDGE_COLOR, LAVA_LIGHT_COLOR, 0.45);

    color = mix(color, color * shadowTint, ambientShadowMask * strength * 0.28);
    color = mix(color, color * highlightTint, highlightMask * strength * (0.25 + sunGlow * 0.15 * sunsetGlowStrength) * weatherDampen * (1.0 - castShadowMask * 0.42));
    color = applyHeldTorchLight(color, heldLightMask, strength, torchIntensity, torchFlicker);
    color = mix(color, color * lavaSpill + LAVA_LIGHT_COLOR * 0.14, lavaMask * strength * 0.45);
    color += highlightMask * rain * strength * rainReflectTint * 0.06;
    color = mix(color, color * RAIN_AMBIENT_COLOR, rain * strength * 0.07);
    color = mix(color, vec3(getLuminance(color)), rain * strength * 0.10);

    // Night readability: lift dark areas with a touch of cool moonlight
    color += moonColor * ambientShadowMask * nightMask * strength * NIGHT_READABILITY_LIFT;

    return color;
}
