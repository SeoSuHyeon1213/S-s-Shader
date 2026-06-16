#version 120

varying vec2 texCoord;

uniform sampler2D colortex0; // composited scene color
uniform sampler2D colortex1; // blurred bloom buffer (from composite)
uniform sampler2D colortex2; // terrain wet/wall/lava/water masks
uniform sampler2D depthtex0; // scene depth
uniform sampler2D shadowtex0; // sun/moon shadow map

uniform float near;
uniform float far;
uniform vec3 fogColor;
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
#include "/lib/shadows.glsl"
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
const float FOG_AMBIENT_PULL = 0.25; // Keep fog stable while still dimming slightly in dark scenes
const float SKY_HORIZON_FOG_DAY = 0.22; // Daytime sky/horizon fog strength
const float SKY_HORIZON_FOG_NIGHT = 0.035; // Keep night sky from splitting into visible bands
const float SKY_HORIZON_FOG_RAIN = 0.12; // Extra horizon haze during rain

// ---- Bloom ----
#define BLOOM_INTENSITY 0.16 // Bloom strength [0.0 0.05 0.1 0.15 0.16 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.6 0.7 0.8 0.9 1.0]

// ---- Lighting ----
#define LIGHTING_STRENGTH 0.5 // Mood lighting strength [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define TORCH_LIGHT_INTENSITY 0.85 // Held torch intensity [0.0 0.25 0.5 0.65 0.75 0.85 1.0 1.15 1.3 1.5]

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

void main() {
    vec4 sceneSample = texture2D(colortex0, texCoord);
    vec3 color = sceneSample.rgb;
    vec4 terrainSurfaceMasks = texture2D(colortex2, texCoord);
    float terrainWetMask = terrainSurfaceMasks.r;
    float terrainWallMask = terrainSurfaceMasks.g;
    float lavaMask = terrainSurfaceMasks.b; // written by gbuffers_terrain via block.properties
    float waterMask = terrainSurfaceMasks.a; // written by gbuffers_water

    // Bloom (blurred bright-pass from composite)
    color += texture2D(colortex1, texCoord).rgb * BLOOM_INTENSITY;

    // Depth (used by both mood lighting and fog)
    float depth = texture2D(depthtex0, texCoord).r;
    float dist = linearizeDepth(depth, near, far);
    vec3 viewPos = getViewPosition(texCoord, depth);
    vec3 worldPos = getWorldPosition(viewPos);
    float sceneMask = 1.0 - step(1.0, depth);
    float shadowVisibility = getShadowVisibility(worldPos, dist, far, sceneMask, worldTime, rainStrength);
    color = applyShadow(color, shadowVisibility, sceneMask);

    // Mood lighting
    color = applyMoodLighting(color, viewPos, sceneMask, LIGHTING_STRENGTH, rainStrength, worldTime, heldBlockLightValue, heldBlockLightValue2, lavaMask, frameTimeCounter, TORCH_LIGHT_INTENSITY);

    // Rain-wide wet highlight, then surface-biased fake reflection
    color = applyGlobalWetHighlight(color, sceneMask, rainStrength, RAIN_REFLECTION_INTENSITY);
    color = applyFakeWetReflection(color, texCoord, depth, sceneMask, terrainWetMask, terrainWallMask, rainStrength, frameTimeCounter, RAIN_REFLECTION_INTENSITY);
    color = applyWaterSurface(color, colortex0, texCoord, sceneMask, waterMask, rainStrength, frameTimeCounter, RAIN_REFLECTION_INTENSITY);
    color = applyWaterSSR(color, colortex0, depthtex0, texCoord, viewPos, waterMask, frameTimeCounter, gbufferProjection, gbufferProjectionInverse, RAIN_REFLECTION_INTENSITY);

    // Fog
    float fogStartRatio = FOG_START * (1.0 - rainStrength * RAIN_FOG_PULL);
    if (depth < 1.0) {
        float fogFactor = getFogFactor(dist, far, fogStartRatio, FOG_DENSITY);
        vec3 ambientFogColor = getAmbientFogColor(fogColor, color, FOG_AMBIENT_PULL);
        color = applyFog(color, ambientFogColor, fogFactor);
    } else {
        float dayMask = getDayMask(worldTime);
        float nightMask = 1.0 - dayMask;
        float horizonMask = pow(1.0 - smoothstep(0.02, 0.74, texCoord.y), 1.65);
        float skyFogStrength = mix(SKY_HORIZON_FOG_NIGHT, SKY_HORIZON_FOG_DAY, dayMask) + rainStrength * SKY_HORIZON_FOG_RAIN;
        vec3 skyFogColor = mix(color, fogColor, 0.25 + dayMask * 0.55 + rainStrength * 0.20);
        color = applyFog(color, skyFogColor, horizonMask * skyFogStrength * (1.0 - nightMask * 0.35));
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
