#version 120

attribute vec4 mc_Entity;

varying vec2 texCoord;
varying vec4 vertexColor;
varying float shadowCasterMask;
varying float shadowCasterOpacity;

const float LAVA_BLOCK_ID = 11000.0;
const float WATER_BLOCK_ID = 11001.0;
const float WET_FOLIAGE_ID = 11103.0;
const float WET_GLASS_ID = 11104.0;
const float WET_CROP_ID = 11105.0;

float isBlockMaterial(float blockId, float materialId) {
    return float(abs(blockId - materialId) < 0.5);
}

float getShadowCasterOpacity(float blockId) {
    float opacity = 1.0;
    opacity = mix(opacity, 0.58, isBlockMaterial(blockId, WET_FOLIAGE_ID));
    opacity = mix(opacity, 0.30, isBlockMaterial(blockId, WET_GLASS_ID));
    opacity = mix(opacity, 0.44, isBlockMaterial(blockId, WET_CROP_ID));
    return opacity;
}

void main() {
    gl_Position = ftransform();
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vertexColor = gl_Color;

    float blockId = mc_Entity.x;
    float skipWater = isBlockMaterial(blockId, WATER_BLOCK_ID);
    float skipLava = isBlockMaterial(blockId, LAVA_BLOCK_ID);
    shadowCasterOpacity = getShadowCasterOpacity(blockId);
    shadowCasterMask = 1.0 - clamp(max(skipWater, skipLava), 0.0, 1.0);
}
