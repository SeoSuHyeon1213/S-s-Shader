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

    // Keep the scene color buffer opaque. Some Iris/composite paths can treat
    // colortex0 alpha as real transparency, so material masks live in colortex2.
    gl_FragData[0] = vec4(albedo.rgb, 1.0);

    // colortex2 carries terrain material masks:
    // R = upward wettable floor, G = vertical wall, B = lava/emissive block.
    gl_FragData[1] = vec4(wetMaskBase, wallMaskBase, isLava, 1.0);
}
