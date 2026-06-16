#version 120

attribute vec4 mc_Entity;

varying vec2 texCoord;
varying vec2 lmCoord;
varying vec4 glColor;
varying vec3 viewNormal;
varying float isWater;

const float WATER_BLOCK_ID = 11001.0;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glColor = gl_Color;
    viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    isWater = float(abs(mc_Entity.x - WATER_BLOCK_ID) < 0.5);
}