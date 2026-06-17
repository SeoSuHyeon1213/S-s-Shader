#version 120

uniform sampler2D texture;
uniform float rainStrength;
uniform int worldTime;
uniform mat4 gbufferModelViewInverse;

varying vec2 texCoord;
varying vec4 vertexColor;
varying vec3 viewDir;

#include "/lib/sky.glsl"

/* DRAWBUFFERS:0 */

void main() {
    vec4 texSample = texture2D(texture, texCoord) * vertexColor;
    if (texSample.a < 0.01) discard;

    vec3 worldDir = normalize((gbufferModelViewInverse * vec4(normalize(viewDir), 0.0)).xyz);
    vec3 skyColor = getSkyColor(worldDir, worldTime, rainStrength);
    float dayMask = skyDayMask(worldTime);
    float nightMask = 1.0 - dayMask;
    float horizon = skyHorizonMask(worldDir);
    float twilight = skyTwilightMask(worldTime);
    float luma = dot(texSample.rgb, vec3(0.2126, 0.7152, 0.0722));

    float tintAmount = clamp(0.26 + horizon * 0.14 + twilight * 0.10 + rainStrength * 0.24, 0.0, 0.68);
    tintAmount *= mix(1.12, 0.82, luma);

    vec3 skyTinted = mix(texSample.rgb, texSample.rgb * skyColor * 1.35, tintAmount);
    skyTinted += skyColor * nightMask * smoothstep(0.18, 0.85, luma) * 0.04;

    gl_FragData[0] = vec4(skyTinted, texSample.a);
}
