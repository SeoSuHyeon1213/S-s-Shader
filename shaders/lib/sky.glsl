// Shared sky color utilities
// Used by sky, cloud, fog, shadow tint, wet reflection, and water reflection paths.

const vec3 SKY_DAY_ZENITH      = vec3(0.47, 0.62, 0.78);
const vec3 SKY_DAY_HORIZON     = vec3(0.66, 0.76, 0.86);
const vec3 SKY_NIGHT_ZENITH    = vec3(0.020, 0.026, 0.045);
const vec3 SKY_NIGHT_HORIZON   = vec3(0.075, 0.070, 0.105);
const vec3 SKY_SUNSET_HORIZON  = vec3(0.98, 0.54, 0.31);
const vec3 SKY_RAIN_DESAT      = vec3(0.55, 0.58, 0.64);
const float SKY_PRE_GRADE_DESAT = 0.08;
const float SKY_PRE_GRADE_SOFTEN = 0.06;
const vec3 SKY_CLOUD_DAY_COLOR     = vec3(0.86, 0.87, 0.88);
const vec3 SKY_CLOUD_NIGHT_COLOR   = vec3(0.26, 0.28, 0.36);
const vec3 SKY_CLOUD_RAIN_COLOR    = vec3(0.48, 0.50, 0.55);
const vec3 SKY_CLOUD_SUNSET_COLOR  = vec3(0.94, 0.68, 0.52);
const vec3 SKY_WATER_DAY_TINT      = vec3(0.62, 0.82, 1.00);
const vec3 SKY_WATER_NIGHT_TINT    = vec3(0.38, 0.46, 0.62);
const vec3 SKY_WATER_RAIN_TINT     = vec3(0.48, 0.56, 0.66);

vec3 desaturateSkyColor(vec3 color, float amount) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    return mix(color, vec3(luma), clamp(amount, 0.0, 1.0));
}

vec3 applySkyPreGrade(vec3 color, float horizon, float rain, float nightMask) {
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float desat = SKY_PRE_GRADE_DESAT + horizon * (rain * 0.08 + nightMask * 0.05);
    vec3 graded = desaturateSkyColor(color, desat);
    vec3 softTarget = vec3(luma) * 0.92 + vec3(0.04, 0.045, 0.05);
    return mix(graded, softTarget, SKY_PRE_GRADE_SOFTEN * (0.5 + horizon * 0.5));
}

const float SKY_PI = 3.14159265;

float skySunHeight(int worldTime) {
    float phase = mod(float(worldTime), 24000.0) / 24000.0;
    return cos((phase - 0.25) * 2.0 * SKY_PI);
}

float skyDayMask(int worldTime) {
    float sunHeight = skySunHeight(worldTime);
    return smoothstep(-0.22, 0.34, sunHeight);
}

float skyTwilightMask(int worldTime) {
    float sunHeight = skySunHeight(worldTime);
    float nearHorizon = 1.0 - smoothstep(0.08, 0.52, abs(sunHeight));
    float belowLimit = smoothstep(-0.90, -0.58, sunHeight);
    return clamp(nearHorizon * belowLimit, 0.0, 1.0);
}

float skyTransitionMask(float dayMask) {
    return smoothstep(0.08, 0.52, dayMask) * (1.0 - smoothstep(0.48, 0.92, dayMask));
}

float skyHorizonMask(vec3 worldDir) {
    float up = clamp(worldDir.y * 0.5 + 0.5, 0.0, 1.0);
    float horizon = 1.0 - smoothstep(0.34, 0.98, up);
    return horizon * horizon * (3.0 - 2.0 * horizon);
}

vec3 getSkyColor(vec3 worldDir, int worldTime, float rainStrength) {
    float dayMask = skyDayMask(worldTime);
    float nightMask = 1.0 - dayMask;
    float transition = skyTwilightMask(worldTime);
    float horizon = skyHorizonMask(worldDir);
    float rain = clamp(rainStrength, 0.0, 1.0);
    float calmHorizon = horizon * clamp(rain * 0.55 + nightMask * 0.42 + transition * 0.28, 0.0, 0.86);

    vec3 daySky = mix(SKY_DAY_ZENITH, SKY_DAY_HORIZON, horizon);
    vec3 nightSky = mix(SKY_NIGHT_ZENITH, SKY_NIGHT_HORIZON, horizon);
    vec3 sky = mix(nightSky, daySky, dayMask);
    vec3 averagedSky = mix(
        mix(SKY_NIGHT_ZENITH, SKY_DAY_ZENITH, dayMask),
        mix(SKY_NIGHT_HORIZON, SKY_DAY_HORIZON, dayMask),
        0.50
    );
    sky = mix(sky, averagedSky, calmHorizon);

    vec3 twilightSky = mix(sky, SKY_SUNSET_HORIZON, horizon * transition * 0.26);
    sky = mix(sky, twilightSky, transition * 0.62);

    vec3 rainySky = mix(sky, SKY_RAIN_DESAT, 0.45 + nightMask * 0.20);
    sky = mix(sky, rainySky, rain * 0.72);
    sky = desaturateSkyColor(sky, horizon * (rain * 0.18 + nightMask * 0.10));
    sky = applySkyPreGrade(sky, horizon, rain, nightMask);
    return sky;
}

vec3 getSkyBaseColor(vec3 worldDir, int worldTime, float rainStrength) {
    return getSkyColor(worldDir, worldTime, rainStrength);
}

float skyUnificationMask(vec3 worldDir, int worldTime, float rainStrength) {
    float dayMask = skyDayMask(worldTime);
    float nightMask = 1.0 - dayMask;
    float twilight = skyTwilightMask(worldTime);
    float horizon = skyHorizonMask(worldDir);
    float rain = clamp(rainStrength, 0.0, 1.0);
    return clamp(horizon * (0.18 + twilight * 0.34 + nightMask * 0.24 + rain * 0.32), 0.0, 0.78);
}

vec3 getSkyUnifiedColor(vec3 worldDir, int worldTime, float rainStrength) {
    vec3 horizonDir = normalize(vec3(worldDir.x, mix(worldDir.y, 0.0, 0.82), worldDir.z));
    vec3 viewSky = getSkyColor(worldDir, worldTime, rainStrength);
    vec3 horizonSky = getSkyColor(horizonDir, worldTime, rainStrength);
    return mix(viewSky, horizonSky, skyUnificationMask(worldDir, worldTime, rainStrength));
}

vec3 getSkyCloudColor(
    vec3 worldDir,
    vec3 cloudAlbedo,
    float thickness,
    float selfShadow,
    float edgeLight,
    int worldTime,
    float rainStrength
) {
    float dayMask = skyDayMask(worldTime);
    float nightMask = 1.0 - dayMask;
    float twilight = skyTwilightMask(worldTime);
    float horizon = skyHorizonMask(worldDir);
    float rain = clamp(rainStrength, 0.0, 1.0);
    vec3 skyColor = getSkyUnifiedColor(worldDir, worldTime, rainStrength);

    vec3 cloudTint = mix(SKY_CLOUD_NIGHT_COLOR, SKY_CLOUD_DAY_COLOR, dayMask);
    cloudTint = mix(cloudTint, SKY_CLOUD_SUNSET_COLOR, twilight * horizon * 0.18);
    cloudTint = mix(cloudTint, SKY_CLOUD_RAIN_COLOR, rain * 0.45);

    float cloudLuma = dot(cloudAlbedo, vec3(0.2126, 0.7152, 0.0722));
    vec3 shapedCloud = mix(skyColor, cloudTint, 0.26) * mix(0.82, 1.12, cloudLuma);
    shapedCloud *= mix(1.0 - 0.26 * selfShadow, 1.0, nightMask * 0.35);
    shapedCloud = mix(shapedCloud, shapedCloud * 0.84, thickness * 0.42 * (0.35 + rain * 0.45));
    shapedCloud += skyColor * edgeLight * 0.18 * (0.45 + dayMask * 0.55);

    float skyBlend = clamp(0.48 + horizon * 0.36 + nightMask * 0.16 + rain * 0.20 + twilight * 0.12, 0.0, 0.94);
    return mix(shapedCloud, skyColor, skyBlend);
}

vec3 getSkyWaterReflectionColor(vec3 worldDir, int worldTime, float rainStrength) {
    vec3 horizonDir = normalize(vec3(worldDir.x, mix(worldDir.y, 0.0, 0.72), worldDir.z));
    vec3 viewSky = getSkyUnifiedColor(worldDir, worldTime, rainStrength);
    vec3 horizonSky = getSkyColor(horizonDir, worldTime, rainStrength);
    float horizonWeight = clamp(0.42 + skyHorizonMask(worldDir) * 0.34 + rainStrength * 0.12, 0.0, 0.86);
    return mix(viewSky, horizonSky, horizonWeight);
}

vec3 getSkyWaterTint(vec3 worldDir, int worldTime, float rainStrength) {
    float dayMask = skyDayMask(worldTime);
    float rain = clamp(rainStrength, 0.0, 1.0);
    vec3 skyReflection = getSkyWaterReflectionColor(worldDir, worldTime, rainStrength);
    vec3 baseTint = mix(SKY_WATER_NIGHT_TINT, SKY_WATER_DAY_TINT, dayMask);
    baseTint = mix(baseTint, SKY_WATER_RAIN_TINT, rain * 0.55);
    vec3 skyTint = clamp(skyReflection * 1.12 + vec3(0.06, 0.08, 0.10), vec3(0.32), vec3(1.08));
    return mix(baseTint, skyTint, 0.28 + skyUnificationMask(worldDir, worldTime, rainStrength) * 0.30);
}

vec3 getSkyFogColor(vec3 worldDir, vec3 sceneColor, int worldTime, float rainStrength) {
    vec3 skyColor = getSkyUnifiedColor(worldDir, worldTime, rainStrength);
    float sceneLuma = dot(sceneColor, vec3(0.2126, 0.7152, 0.0722));
    float skyLuma = max(dot(skyColor, vec3(0.2126, 0.7152, 0.0722)), 1e-4);
    float ambientMatch = clamp(sceneLuma / skyLuma, 0.18, 1.08);
    return skyColor * mix(1.0, ambientMatch, 0.46);
}

float getSkyFogAmount(vec3 worldDir, int worldTime, float rainStrength) {
    float dayMask = skyDayMask(worldTime);
    float horizon = skyHorizonMask(worldDir);
    float baseStrength = mix(0.035, 0.18, dayMask);
    return horizon * (baseStrength + clamp(rainStrength, 0.0, 1.0) * 0.12);
}
