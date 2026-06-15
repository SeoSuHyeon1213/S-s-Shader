#version 120

uniform sampler2D texture;
uniform sampler2D lightmap;

varying vec2 texCoord;
varying vec2 lmCoord;
varying vec4 glColor;
varying float isLava;
varying float wetMaskBase;
varying float wallMaskBase;

/* DRAWBUFFERS:02 */

void main() {
    vec4 albedo = texture2D(texture, texCoord) * glColor;
    if (albedo.a < 0.1) discard;

    albedo.rgb *= texture2D(lightmap, lmCoord).rgb;

    // Alpha is unused for blending in the opaque terrain pass, so it carries
    // the lava mask through to lib/lighting.glsl via colortex0.
    gl_FragData[0] = vec4(albedo.rgb, isLava);

    // colortex2 carries rain-surface masks:
    // R = upward-facing wettable floor/top surface, G = vertical wall surface.
    gl_FragData[1] = vec4(wetMaskBase, wallMaskBase, 0.0, 1.0);
}
