// Depth-based fog utilities

// Returns view-space distance in blocks
float linearizeDepth(float depth, float near, float far) {
    float ndc = depth * 2.0 - 1.0;
    return (2.0 * near * far) / (far + near - ndc * (far - near));
}

// Exponential-squared fog factor, scaled to the current render distance (far)
// so the fog band always sits near the edge of the player's view distance
// instead of at a fixed block distance.
float getFogFactor(float dist, float far, float fogStartRatio, float falloff) {
    float fogStart = far * clamp(fogStartRatio, 0.0, 1.0);
    float fogRange = max(far - fogStart, 1.0);
    float t = clamp((dist - fogStart) / fogRange, 0.0, 1.0);
    return 1.0 - exp2(-falloff * t * t);
}

// Darkens the fog color to match the ambient brightness of the scene behind it,
// so fog fades to dark in dim areas (e.g. caves) instead of to a bright sky tint.
vec3 getAmbientFogColor(vec3 fogColor, vec3 sceneColor, float ambientPull) {
    float sceneLuma = dot(sceneColor, vec3(0.2126, 0.7152, 0.0722));
    float fogLuma = max(dot(fogColor, vec3(0.2126, 0.7152, 0.0722)), 1e-4);
    float ambient = clamp(sceneLuma / fogLuma, 0.0, 1.0);
    return fogColor * mix(1.0, ambient, clamp(ambientPull, 0.0, 1.0));
}

vec3 applyFog(vec3 color, vec3 fogColor, float fogFactor) {
    return mix(color, fogColor, clamp(fogFactor, 0.0, 1.0));
}
