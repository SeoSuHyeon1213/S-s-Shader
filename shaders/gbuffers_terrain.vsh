#version 120

attribute vec4 mc_Entity;

uniform mat4 gbufferModelViewInverse;

varying vec2 texCoord;
varying vec2 lmCoord;
varying vec4 glColor;
varying float isLava;
varying float wetMaskBase;
varying float wallMaskBase;
varying vec3 worldNormalOut;

const float LAVA_BLOCK_ID = 11000.0;
const float WET_STONE_ID = 11100.0;
const float WET_SOIL_ID = 11101.0;
const float WET_WOOD_ID = 11102.0;
const float WET_FOLIAGE_ID = 11103.0;
const float WET_GLASS_ID = 11104.0;
const float WET_CROP_ID = 11105.0;

float isBlockMaterial(float blockId, float materialId) {
    return float(abs(blockId - materialId) < 0.5);
}

float getWetFloorResponse(float blockId) {
    float response = 0.62; // fallback for uncategorized terrain
    response = mix(response, 1.00, isBlockMaterial(blockId, WET_STONE_ID));
    response = mix(response, 0.78, isBlockMaterial(blockId, WET_SOIL_ID));
    response = mix(response, 0.42, isBlockMaterial(blockId, WET_WOOD_ID));
    response = mix(response, 0.30, isBlockMaterial(blockId, WET_FOLIAGE_ID));
    response = mix(response, 0.72, isBlockMaterial(blockId, WET_GLASS_ID));
    response = mix(response, 0.16, isBlockMaterial(blockId, WET_CROP_ID));
    return response;
}

float getWetWallResponse(float blockId) {
    float response = 0.44; // fallback for uncategorized terrain
    response = mix(response, 0.72, isBlockMaterial(blockId, WET_STONE_ID));
    response = mix(response, 0.34, isBlockMaterial(blockId, WET_SOIL_ID));
    response = mix(response, 0.38, isBlockMaterial(blockId, WET_WOOD_ID));
    response = mix(response, 0.16, isBlockMaterial(blockId, WET_FOLIAGE_ID));
    response = mix(response, 0.66, isBlockMaterial(blockId, WET_GLASS_ID));
    response = mix(response, 0.08, isBlockMaterial(blockId, WET_CROP_ID));
    return response;
}

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glColor = gl_Color;
    isLava = float(abs(mc_Entity.x - LAVA_BLOCK_ID) < 0.5);

    vec3 viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    vec3 worldNormal = normalize((gbufferModelViewInverse * vec4(viewNormal, 0.0)).xyz);
    worldNormalOut = worldNormal;
    float nonLava = 1.0 - isLava;
    float blockId = mc_Entity.x;
    float floorWetResponse = getWetFloorResponse(blockId);
    float wallWetResponse = getWetWallResponse(blockId);

    wetMaskBase = smoothstep(0.50, 0.92, worldNormal.y) * floorWetResponse * nonLava;
    wallMaskBase = smoothstep(0.35, 0.85, 1.0 - abs(worldNormal.y)) * wallWetResponse * nonLava;
}
