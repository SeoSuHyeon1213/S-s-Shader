// Low-cost water-only screen-space reflection utilities

const int SSR_STEPS = 16;
const float SSR_STEP_SIZE = 0.55;
const float SSR_THICKNESS = 0.35;
const float SSR_MAX_DISTANCE = 48.0;

float getScreenEdgeFade(vec2 uv) {
    vec2 edge = min(uv, 1.0 - uv);
    return smoothstep(0.0, 0.08, min(edge.x, edge.y));
}

vec2 projectViewToScreen(vec3 viewPos, mat4 projection) {
    vec4 clipPos = projection * vec4(viewPos, 1.0);
    vec3 ndc = clipPos.xyz / max(clipPos.w, 0.0001);
    return ndc.xy * 0.5 + 0.5;
}

vec3 reconstructSSRViewPosition(vec2 uv, float depth, mat4 projectionInverse) {
    vec4 clipPos = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 viewPos = projectionInverse * clipPos;
    return viewPos.xyz / viewPos.w;
}

vec3 getSSRWaterNormal(vec2 uv, float time) {
    float waveX = sin((uv.x + time * 0.020) * 54.0 + uv.y * 17.0);
    float waveY = cos((uv.y - time * 0.016) * 49.0 - uv.x * 21.0);
    return normalize(vec3(waveX * 0.10, waveY * 0.10, 1.0));
}

vec3 applyWaterSSR(
    vec3 color,
    sampler2D sceneTexture,
    sampler2D depthTexture,
    vec2 uv,
    vec3 viewPos,
    float waterMask,
    float frameTimeCounter,
    mat4 projection,
    mat4 projectionInverse,
    float intensity
) {
    float mask = clamp(waterMask, 0.0, 1.0);
    if (mask <= 0.001) return color;

    vec3 viewDir = normalize(-viewPos);
    vec3 normal = getSSRWaterNormal(uv, frameTimeCounter);
    vec3 rayDir = reflect(viewDir, normal);

    if (rayDir.z > -0.02) return color;

    vec3 rayPos = viewPos;
    vec3 hitColor = vec3(0.0);
    float hitFade = 0.0;

    for (int i = 0; i < SSR_STEPS; i++) {
        rayPos += rayDir * SSR_STEP_SIZE;

        if (length(rayPos - viewPos) > SSR_MAX_DISTANCE) break;

        vec2 hitUv = projectViewToScreen(rayPos, projection);
        if (hitUv.x < 0.0 || hitUv.x > 1.0 || hitUv.y < 0.0 || hitUv.y > 1.0) break;

        float sceneDepth = texture2D(depthTexture, hitUv).r;
        if (sceneDepth >= 1.0) continue;

        vec3 sceneViewPos = reconstructSSRViewPosition(hitUv, sceneDepth, projectionInverse);
        float depthDelta = rayPos.z - sceneViewPos.z;

        if (depthDelta > -SSR_THICKNESS && depthDelta < SSR_THICKNESS) {
            hitColor = texture2D(sceneTexture, hitUv).rgb;
            float edgeFade = getScreenEdgeFade(hitUv);
            float distanceFade = 1.0 - clamp(length(rayPos - viewPos) / SSR_MAX_DISTANCE, 0.0, 1.0);
            hitFade = edgeFade * distanceFade;
            break;
        }
    }

    float fresnel = pow(1.0 - clamp(dot(viewDir, normal), 0.0, 1.0), 2.0);
    float reflectionAmount = mask * hitFade * fresnel * intensity * 0.45;
    return mix(color, hitColor * vec3(0.72, 0.86, 1.08), reflectionAmount);
}
