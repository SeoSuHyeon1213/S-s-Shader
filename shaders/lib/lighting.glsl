// Mood lighting utilities

const vec3 SUN_LIGHT_COLOR    = vec3(0.945, 0.996, 0.776); // #F1FEC6 - midday sunlight
const vec3 SUN_HORIZON_COLOR  = vec3(1.000, 0.557, 0.282); // warm sunrise/sunset glow
const vec3 MOON_LIGHT_COLOR   = vec3(0.749, 0.847, 1.000); // cool blue moonlight, tuned for night readability
const vec3 TORCH_LIGHT_COLOR  = vec3(0.961, 0.522, 0.247); // #F5853F
const vec3 TORCH_EDGE_COLOR   = vec3(1.000, 0.720, 0.420); // softer warm edge for held-light falloff
const vec3 LAVA_LIGHT_COLOR   = vec3(1.000, 0.227, 0.125); // #FF3A20
const vec3 RAIN_MOOD_COLOR    = vec3(0.204, 0.137, 0.651); // #3423A6

const float SUN_HORIZON_GLOW = 0.35; // extra highlight warmth during sunrise/sunset
const float NIGHT_READABILITY_LIFT = 0.10; // subtle blue lift on dark areas at night

const float HELD_LIGHT_RANGE_BOOST = 1.15;
const float HELD_LIGHT_BRIGHTNESS = 0.20;
const float HELD_LIGHT_AMBIENT = 0.012;
const float HELD_LIGHT_DAY_OUTDOOR_MIN = 0.20;
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
float getSunIntensity(float dayMask) {
    return dayMask * (1.0 + getSunHorizonFactor(dayMask) * SUN_HORIZON_GLOW);
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
    float darkInteriorBoost = mix(1.0, 1.12, 1.0 - smoothstep(0.12, 0.55, luma));
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
    float surfaceProtection = 1.0 - smoothstep(0.72, 1.15, luma);
    float coreMask = heldLightMask * heldLightMask;
    float edgeMask = heldLightMask * (1.0 - coreMask);
    vec3 torchTint = mix(TORCH_EDGE_COLOR, TORCH_LIGHT_COLOR, 0.65 + coreMask * 0.35);

    color = mix(color, color * (vec3(1.0) + torchTint * 0.10), edgeMask * strength * torchIntensity * 0.22);
    color += torchTint * coreMask * strength * torchIntensity * flicker *
             (HELD_LIGHT_AMBIENT + HELD_LIGHT_BRIGHTNESS * surfaceProtection);

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
    float lavaMask,
    float frameTimeCounter,
    float torchIntensity
) {
    float luma = getLuminance(color);
    float shadowMask = 1.0 - smoothstep(0.12, 0.55, luma);
    float highlightMask = smoothstep(0.55, 1.25, luma);
    float rain = clamp(rainStrength, 0.0, 1.0);
    float dayMask = getDayMask(worldTime);
    float nightMask = getNightMask(worldTime);
    vec3 sunColor = getSunColor(dayMask);
    float sunIntensity = getSunIntensity(dayMask);
    float sunGlow = getSunHorizonFactor(dayMask);
    float handLightStrength = getHandLightStrength(heldBlockLightValue, heldBlockLightValue2);
    float heldLightBase = handLightStrength
        * getHeldLightDistanceFalloff(viewPos, heldBlockLightValue, heldBlockLightValue2)
        * sceneMask;
    float heldLightMask = clamp(heldLightBase * getHeldLightEnvironmentFactor(color, dayMask), 0.0, 1.0);
    float torchFlicker = getTorchFlicker(frameTimeCounter, handLightStrength);
    float weatherDampen = 1.0 - rain * 0.35;

    vec3 skyTint = mix(MOON_LIGHT_COLOR, sunColor, dayMask);
    vec3 shadowTint = mix(vec3(0.86, 0.92, 1.06), skyTint, 0.35 + nightMask * 0.25);
    vec3 highlightTint = mix(MOON_LIGHT_COLOR, sunColor, sunIntensity * 0.85 + 0.15);
    vec3 rainReflectTint = mix(vec3(0.85, 0.90, 1.0), RAIN_MOOD_COLOR, 0.25);

    color = mix(color, color * shadowTint, shadowMask * strength * 0.35);
    color = mix(color, color * highlightTint, highlightMask * strength * (0.25 + sunGlow * 0.15) * weatherDampen);
    color = applyHeldTorchLight(color, heldLightMask, strength, torchIntensity, torchFlicker);
    color = mix(color, color * LAVA_LIGHT_COLOR + LAVA_LIGHT_COLOR * 0.18, lavaMask * strength * 0.55);
    color += highlightMask * rain * strength * rainReflectTint * 0.08;
    color = mix(color, color * RAIN_MOOD_COLOR, rain * strength * 0.12);
    color = mix(color, vec3(getLuminance(color)), rain * strength * 0.10);

    // Night readability: lift dark areas with a touch of cool moonlight
    color += MOON_LIGHT_COLOR * shadowMask * nightMask * strength * NIGHT_READABILITY_LIFT;

    return color;
}
