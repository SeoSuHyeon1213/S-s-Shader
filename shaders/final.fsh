#version 120

varying vec2 texCoord;

uniform sampler2D colortex0; // composited scene color
uniform sampler2D colortex1; // blurred bloom buffer (from composite)
uniform sampler2D colortex2; // terrain wet/wall/lava/water masks
uniform sampler2D colortex3; // encoded world normals
uniform sampler2D depthtex0; // scene depth
uniform sampler2D shadowtex0; // sun/moon shadow map

uniform float near;
uniform float far;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform int worldTime;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

#include "/lib/color.glsl"
#include "/lib/fog.glsl"
#include "/lib/sky.glsl"
#include "/lib/shadows.glsl"
#include "/lib/contact_shadows.glsl"
#include "/lib/lighting.glsl"
#include "/lib/wet.glsl"
#include "/lib/ssr.glsl"

// ---- Color Grading ----
#define EXPOSURE 0.05 // Exposure (EV stops) [-2.0 -1.75 -1.5 -1.25 -1.0 -0.75 -0.5 -0.25 0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]
#define CONTRAST 0.88 // Contrast [0.75 0.8 0.85 0.88 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.25 1.3 1.4]
#define SATURATION 0.936 // Saturation [0.5 0.6 0.7 0.72 0.8 0.9 0.936 1.0 1.1 1.2 1.3 1.4 1.5]
const vec3  COLOR_TINT = vec3(1.03, 1.015, 0.99); // soft pastel warmth

// ---- Vignette ----
const float VIGNETTE_INNER = 0.4;
#define VIGNETTE_OUTER 1.1 // Vignette size, smaller = stronger [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
const float VIGNETTE_MIN   = 0.6; // never fully black at the edges

// ---- Fog ----
#define FOG_START 0.6 // Fog start, as a fraction of render distance [0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define FOG_DENSITY 3.0 // Fog falloff sharpness near the render distance edge [1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 10.0 12.0]
const float RAIN_FOG_PULL = 0.3; // How much rain pulls the fog start closer (fraction of FOG_START)
const float FOG_AMBIENT_PULL = 0.55; // Let night fog follow the darkened scene more closely
const float HORIZON_FOG_PULL = 0.10; // Blends distant terrain into the shared sky horizon curve

// ---- Bloom ----
#define BLOOM_INTENSITY 0.16 // Bloom strength [0.0 0.05 0.1 0.15 0.16 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.6 0.7 0.8 0.9 1.0]

// ---- Contact Shadows ----
#define CONTACT_SHADOW_INTENSITY 0.65 // Near-field screen-space contact shadow strength [0.0 0.08 0.16 0.24 0.32 0.4 0.5 0.65 0.8]

// ---- Lighting ----
#define LIGHTING_STRENGTH 0.5 // Mood lighting strength [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define TORCH_LIGHT_INTENSITY 1.0 // Held torch intensity [0.0 0.25 0.5 0.65 0.75 0.85 1.0 1.15 1.3 1.5]
#define DAY_LIGHT_STRENGTH 1.0 // Daylight strength [0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4]
#define NIGHT_LIGHT_STRENGTH 1.0 // Moonlight/night readability strength [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3]
#define SUNSET_GLOW_STRENGTH 1.0 // Sunrise/sunset warm glow strength [0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0]

// ---- Rain / Wet Surfaces ----
#define RAIN_REFLECTION_INTENSITY 0.45 // Fake wet reflection intensity [0.0 0.15 0.3 0.45 0.6 0.75 0.9 1.0]

vec3 getViewPosition(vec2 uv, float depth) {
    vec4 clipPos = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = gbufferProjectionInverse * clipPos;
    return viewPos.xyz / viewPos.w;
}

vec3 getWorldPosition(vec3 viewPos) {
    return (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
}

vec3 getWorldDirection(vec3 viewPos) {
    return normalize((gbufferModelViewInverse * vec4(normalize(viewPos), 0.0)).xyz);
}
void main() {
    vec4 sceneSample = texture2D(colortex0, texCoord);
    vec3 color = sceneSample.rgb;
    vec4 terrainSurfaceMasks = texture2D(colortex2, texCoord);
    vec4 normalSample = texture2D(colortex3, texCoord);
    float terrainWetMask = terrainSurfaceMasks.r;
    float terrainWallMask = terrainSurfaceMasks.g;
    float lavaMask = terrainSurfaceMasks.b; // written by gbuffers_terrain via block.properties
    float waterMask = terrainSurfaceMasks.a; // written by gbuffers_water
    vec3 worldNormal = normalize(normalSample.rgb * 2.0 - 1.0);
    float normalMask = normalSample.a * sceneSample.a;

    // Bloom (blurred bright-pass from composite)
    color += texture2D(colortex1, texCoord).rgb * BLOOM_INTENSITY;

    // Depth (used by both mood lighting and fog)
    float depth = texture2D(depthtex0, texCoord).r;
    float dist = linearizeDepth(depth, near, far);
    vec3 viewPos = getViewPosition(texCoord, depth);
    vec3 worldPos = getWorldPosition(viewPos);
    vec3 worldDir = getWorldDirection(viewPos);
    vec3 skyReflectionColor = getSkyWaterReflectionColor(worldDir, worldTime, rainStrength);
    float sceneMask = 1.0 - step(1.0, depth);
    float shadowVisibility = getShadowVisibility(worldPos, dist, far, sceneMask, worldTime, rainStrength);
    float rainExposure = getRainExposure(worldPos, dist, far, sceneMask);
    float surfaceRainStrength = rainStrength * rainExposure;
    color = applyShadow(color, shadowVisibility, sceneMask, worldDir, worldTime, rainStrength);
    color = applyContactShadow(color, depthtex0, texCoord, depth, viewPos, sceneMask, gbufferProjectionInverse, dist, worldDir, worldTime, rainStrength, CONTACT_SHADOW_INTENSITY);
    color = applyTerrainFormLighting(color, worldDir, sceneMask, terrainWetMask, terrainWallMask, shadowVisibility, worldNormal, normalMask, worldTime, rainStrength);

    // Mood lighting
    color = applyMoodLighting(color, viewPos, sceneMask, LIGHTING_STRENGTH, rainStrength, worldTime, heldBlockLightValue, heldBlockLightValue2, lavaMask, frameTimeCounter, TORCH_LIGHT_INTENSITY, DAY_LIGHT_STRENGTH, NIGHT_LIGHT_STRENGTH, SUNSET_GLOW_STRENGTH);

    // Rain-wide wet highlight, then surface-biased fake reflection
    color = applyGlobalWetHighlight(color, sceneMask, surfaceRainStrength, RAIN_REFLECTION_INTENSITY);
    color = applyFakeWetReflection(color, texCoord, depth, sceneMask, terrainWetMask, terrainWallMask, surfaceRainStrength, frameTimeCounter, RAIN_REFLECTION_INTENSITY);
    color = applyWetTerrainScreenReflection(color, colortex0, texCoord, worldDir, depth, sceneMask, terrainWetMask, terrainWallMask, skyReflectionColor, surfaceRainStrength, frameTimeCounter, RAIN_REFLECTION_INTENSITY);
    color = applyWetWallRunoff(color, texCoord, worldDir, depth, sceneMask, terrainWallMask, surfaceRainStrength, frameTimeCounter, RAIN_REFLECTION_INTENSITY);
    color = applyWetSpecularBRDF(color, worldDir, depth, sceneMask, terrainWetMask, terrainWallMask, surfaceRainStrength, worldTime, RAIN_REFLECTION_INTENSITY);
    color = applyWaterSurface(color, colortex0, texCoord, sceneMask, waterMask, skyReflectionColor, surfaceRainStrength, frameTimeCounter, RAIN_REFLECTION_INTENSITY);
    color = applyWaterSSR(color, colortex0, depthtex0, texCoord, viewPos, waterMask, skyReflectionColor, surfaceRainStrength, frameTimeCounter, gbufferProjection, gbufferProjectionInverse, RAIN_REFLECTION_INTENSITY);

    // Fog
    float fogStartRatio = FOG_START * (1.0 - rainStrength * RAIN_FOG_PULL);
    if (depth < 1.0) {
        float fogFactor = getFogFactor(dist, far, fogStartRatio, FOG_DENSITY);
        float horizonFog = skyHorizonMask(worldDir) * smoothstep(far * 0.35, far, dist);
        float twilightFogSoftening = mix(1.0, 0.58, skyTwilightMask(worldTime));
        fogFactor = clamp(fogFactor + horizonFog * HORIZON_FOG_PULL * twilightFogSoftening * (1.0 + rainStrength * 0.45), 0.0, 1.0);
        fogFactor *= mix(0.68, 1.0, skyDayMask(worldTime));
        vec3 skyFogColor = getSkyFogColor(worldDir, color, worldTime, rainStrength);
        vec3 ambientFogColor = getAmbientFogColor(skyFogColor, color, FOG_AMBIENT_PULL);
        color = applyFog(color, ambientFogColor, fogFactor);
    }

    // Color grading
    color = adjustExposure(color, EXPOSURE);
    color = colorBalance(color, COLOR_TINT);
    color = adjustContrast(color, CONTRAST);
    color = adjustSaturation(color, SATURATION);
    color = tonemapACES(color);
    color = applyPastelTone(color);

    // Vignette
    float vig = vignette(texCoord, VIGNETTE_INNER, VIGNETTE_OUTER);
    color *= mix(VIGNETTE_MIN, 1.0, vig);

    color = applyDither(color, gl_FragCoord.xy);
    gl_FragColor = vec4(color, 1.0);
}
