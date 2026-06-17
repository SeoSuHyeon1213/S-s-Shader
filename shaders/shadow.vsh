#version 120

attribute vec4 mc_Entity;

varying vec2 texCoord;
varying vec4 vertexColor;
varying float shadowCasterMask;

const float LAVA_BLOCK_ID = 11000.0;
const float WATER_BLOCK_ID = 11001.0;
const float WET_GLASS_ID = 11104.0;

float isBlockMaterial(float blockId, float materialId) {
    return float(abs(blockId - materialId) < 0.5);
}

void main() {
    gl_Position = ftransform();
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vertexColor = gl_Color;

    float blockId = mc_Entity.x;
    float skipWater = isBlockMaterial(blockId, WATER_BLOCK_ID);
    float skipLava = isBlockMaterial(blockId, LAVA_BLOCK_ID);
    float skipGlass = isBlockMaterial(blockId, WET_GLASS_ID);
    shadowCasterMask = 1.0 - clamp(max(max(skipWater, skipLava), skipGlass), 0.0, 1.0);
}