#version 120

uniform sampler2D texture;

varying vec2 texCoord;
varying vec4 vertexColor;
varying float shadowCasterMask;

void main() {
    if (shadowCasterMask < 0.5) discard;

    vec4 albedo = texture2D(texture, texCoord) * vertexColor;
    if (albedo.a < 0.10) discard;
}