#version 120

varying vec2 texCoord;

uniform sampler2D colortex0; // scene color
uniform sampler2D colortex2; // wet mask
uniform float viewWidth;
uniform float viewHeight;

/* DRAWBUFFERS:012 */

#define BLOOM_THRESHOLD 0.8 // Bloom threshold [0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.4 1.6]
const float BLOOM_KNEE      = 0.2;
const float BLOOM_SPREAD    = 4.0; // texel multiplier
const float BLOOM_CLAMP     = 8.0;

float gaussianWeight(int offset) {
    if (offset == 0) return 0.4026;
    if (offset == -1 || offset == 1) return 0.2442;
    return 0.0545;
}

vec3 brightPass(vec2 uv) {
    vec3 color = texture2D(colortex0, uv).rgb;
    float brightness = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float contribution = smoothstep(BLOOM_THRESHOLD, BLOOM_THRESHOLD + BLOOM_KNEE, brightness);
    return color * contribution;
}

vec3 blurBloom(vec2 uv) {
    vec2 texel = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    vec3 result = vec3(0.0);

    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 offset = vec2(float(x), float(y)) * texel * BLOOM_SPREAD;
            float weight = gaussianWeight(x) * gaussianWeight(y);

            result += brightPass(uv + offset) * weight;
        }
    }

    return min(result, vec3(BLOOM_CLAMP));
}

void main() {
    gl_FragData[0] = texture2D(colortex0, texCoord); // pass scene color through
    gl_FragData[1] = vec4(blurBloom(texCoord), 1.0);  // blurred bloom buffer
    gl_FragData[2] = texture2D(colortex2, texCoord); // pass wet mask through
}
