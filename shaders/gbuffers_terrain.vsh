#version 120

attribute vec4 mc_Entity;

uniform mat4 gbufferModelViewInverse;

varying vec2 texCoord;
varying vec2 lmCoord;
varying vec4 glColor;
varying float isLava;
varying float wetMaskBase;
varying float wallMaskBase;

const float LAVA_BLOCK_ID = 11000.0;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glColor = gl_Color;
    isLava = float(abs(mc_Entity.x - LAVA_BLOCK_ID) < 0.5);

    vec3 viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    vec3 worldNormal = normalize((gbufferModelViewInverse * vec4(viewNormal, 0.0)).xyz);
    float nonLava = 1.0 - isLava;

    wetMaskBase = smoothstep(0.50, 0.92, worldNormal.y) * nonLava;
    wallMaskBase = smoothstep(0.35, 0.85, 1.0 - abs(worldNormal.y)) * nonLava;
}
