#version 120

uniform mat4 gbufferModelViewInverse;

varying vec2 texCoord;
varying vec2 lmCoord;
varying vec4 glColor;
varying vec3 worldNormalOut;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glColor = gl_Color;

    vec3 viewNormal = normalize(gl_NormalMatrix * gl_Normal);
    worldNormalOut = normalize((gbufferModelViewInverse * vec4(viewNormal, 0.0)).xyz);
}