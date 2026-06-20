#version 120

uniform sampler2D texture;

varying vec2 texCoord;
varying vec4 vertexColor;
varying float shadowCasterMask;
varying float shadowCasterOpacity;

float shadowDither(vec2 uv) {
    vec2 cell = floor(uv * 256.0);
    return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
    if (shadowCasterMask < 0.5) discard;

    vec4 albedo = texture2D(texture, texCoord) * vertexColor;
    if (albedo.a < 0.10) discard;

    float effectiveOpacity = clamp(albedo.a * shadowCasterOpacity, 0.0, 1.0);
    if (effectiveOpacity < 0.995 && shadowDither(texCoord) > effectiveOpacity) discard;
}
