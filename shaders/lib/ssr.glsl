// Low-cost water-only screen-space reflection utilities

const int SSR_STEPS = 16;
const int SSR_BINARY_STEPS = 4;
const float SSR_STEP_SIZE = 0.55;
const float SSR_THICKNESS = 0.35;
const float SSR_MAX_DISTANCE = 48.0;
const float SSR_ROUGH_BLUR_RADIUS = 0.0045;
const float SSR_SKY_FALLBACK_STRENGTH = 0.18;

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

float getSSRDepthDelta(vec3 rayPos, vec2 hitUv, sampler2D depthTexture, mat4 projectionInverse) {
    float sceneDepth = texture2D(depthTexture, hitUv).r;
    if (sceneDepth >= 1.0) return -9999.0;

    vec3 sceneViewPos = reconstructSSRViewPosition(hitUv, sceneDepth, projectionInverse);
    return rayPos.z - sceneViewPos.z;
}

vec3 refineSSRHit(
    vec3 previousRayPos,
    vec3 currentRayPos,
    mat4 projection,
    sampler2D depthTexture,
    mat4 projectionInverse
) {
    vec3 startPos = previousRayPos;
    vec3 endPos = currentRayPos;

    for (int i = 0; i < SSR_BINARY_STEPS; i++) {
        vec3 midPos = mix(startPos, endPos, 0.5);
        vec2 midUv = projectViewToScreen(midPos, projection);
        if (midUv.x < 0.0 || midUv.x > 1.0 || midUv.y < 0.0 || midUv.y > 1.0) {
            endPos = midPos;
            continue;
        }

        float depthDelta = getSSRDepthDelta(midPos, midUv, depthTexture, projectionInverse);
        if (depthDelta > 0.0) {
            endPos = midPos;
        } else {
            startPos = midPos;
        }
    }

    return endPos;
}

vec3 sampleSSRReflectionBlur(sampler2D sceneTexture, vec2 hitUv, float roughness) {
    vec2 radius = vec2(SSR_ROUGH_BLUR_RADIUS * roughness);
    vec3 color = texture2D(sceneTexture, hitUv).rgb * 0.42;
    color += texture2D(sceneTexture, clamp(hitUv + vec2( radius.x, 0.0), vec2(0.001), vec2(0.999))).rgb * 0.145;
    color += texture2D(sceneTexture, clamp(hitUv - vec2( radius.x, 0.0), vec2(0.001), vec2(0.999))).rgb * 0.145;
    color += texture2D(sceneTexture, clamp(hitUv + vec2(0.0,  radius.y), vec2(0.001), vec2(0.999))).rgb * 0.145;
    color += texture2D(sceneTexture, clamp(hitUv - vec2(0.0,  radius.y), vec2(0.001), vec2(0.999))).rgb * 0.145;
    return color;
}

vec3 applyWaterSSR(
    vec3 color,
    sampler2D sceneTexture,
    sampler2D depthTexture,
    vec2 uv,
    vec3 viewPos,
    float waterMask,
    vec3 worldNormal,
    float viewDistance,
    vec3 skyReflectionColor,
    float rainStrength,
    float frameTimeCounter,
    mat4 projection,
    mat4 projectionInverse,
    float intensity
) {
    float mask = clamp(waterMask, 0.0, 1.0);
    if (mask <= 0.001) return color;

    float verticalWater = smoothstep(0.30, 0.86, 1.0 - abs(normalize(worldNormal).y));
    float nearWater = 1.0 - smoothstep(6.0, 24.0, viewDistance);
    float waterfallMask = verticalWater * nearWater;

    vec3 viewDir = normalize(-viewPos);
    vec3 normal = getSSRWaterNormal(uv, frameTimeCounter);
    vec3 rayDir = reflect(viewDir, normal);
    float fresnel = pow(1.0 - clamp(dot(viewDir, normal), 0.0, 1.0), 2.0);
    float roughness = clamp(0.48 + rainStrength * 0.36 + length(normal.xy) * 1.5 + waterfallMask * 0.32, 0.35, 1.0);

    if (rayDir.z > -0.02) {
        float fallbackAmount = mask * fresnel * intensity * SSR_SKY_FALLBACK_STRENGTH * (1.0 - waterfallMask * 0.85);
        return mix(color, skyReflectionColor, fallbackAmount);
    }

    vec3 rayPos = viewPos;
    vec3 previousRayPos = viewPos;
    vec3 hitColor = vec3(0.0);
    float hitFade = 0.0;

    for (int i = 0; i < SSR_STEPS; i++) {
        previousRayPos = rayPos;
        rayPos += rayDir * SSR_STEP_SIZE;

        if (length(rayPos - viewPos) > SSR_MAX_DISTANCE) break;

        vec2 hitUv = projectViewToScreen(rayPos, projection);
        if (hitUv.x < 0.0 || hitUv.x > 1.0 || hitUv.y < 0.0 || hitUv.y > 1.0) break;

        float sceneDepth = texture2D(depthTexture, hitUv).r;
        if (sceneDepth >= 1.0) continue;

        vec3 sceneViewPos = reconstructSSRViewPosition(hitUv, sceneDepth, projectionInverse);
        float depthDelta = rayPos.z - sceneViewPos.z;

        if (depthDelta > -SSR_THICKNESS && depthDelta < SSR_THICKNESS) {
            vec3 refinedRayPos = refineSSRHit(previousRayPos, rayPos, projection, depthTexture, projectionInverse);
            vec2 refinedUv = projectViewToScreen(refinedRayPos, projection);
            refinedUv = clamp(refinedUv, vec2(0.001), vec2(0.999));

            hitColor = sampleSSRReflectionBlur(sceneTexture, refinedUv, roughness);
            float edgeFade = getScreenEdgeFade(refinedUv);
            float distanceFade = 1.0 - clamp(length(refinedRayPos - viewPos) / SSR_MAX_DISTANCE, 0.0, 1.0);
            float depthConfidence = 1.0 - smoothstep(SSR_THICKNESS * 0.35, SSR_THICKNESS, abs(depthDelta));
            hitFade = edgeFade * distanceFade;
            hitFade *= depthConfidence;
            break;
        }
    }

    float reflectionAmount = mask * hitFade * fresnel * intensity * 0.45 * (1.0 - waterfallMask * 0.82);
    float fallbackAmount = mask * (1.0 - hitFade) * fresnel * intensity * SSR_SKY_FALLBACK_STRENGTH * (1.0 - waterfallMask * 0.85);
    vec3 reflectionColor = mix(skyReflectionColor, hitColor * vec3(0.64, 0.78, 0.96), hitFade);
    color = mix(color, skyReflectionColor, fallbackAmount);
    return mix(color, reflectionColor, reflectionAmount);
}
