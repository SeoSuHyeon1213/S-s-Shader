# S-Shader

```
I'm making minecraft shader for Iris.
I'm using claude-code and codex (actually, it's almost vibe coding)
아이리스용 쉐이더 제작 중.
클로드 코드와 코덱스를 사용하여 제작 사실상 바이브 코딩


S-s-Shader is a Minecraft shader pack for Iris, focused on mood-heavy post processing rather than realistic rendering.

S-s-Shader는 사실적인 렌더링보다는 분위기 중심의 후처리에 집중한 Iris용 마인크래프트 쉐이더팩입니다.

The current goal is a soft atmospheric style built around color grading, vignette, bloom, fog, shadow tinting, torch/lava glow, and rainy wet-surface highlights.

현재 목표는 색보정, 비네트, 블룸, 안개, 그림자 색감, 횃불/용암 발광, 비 오는 날 젖은 표면 하이라이트를 중심으로 한 부드러운 분위기형 스타일입니다.
```

## Features

- Color grading with exposure, contrast, saturation, warm tint, ACES tonemapping, and pastel tone shaping
- 노출, 대비, 채도, 따뜻한 틴트, ACES 톤매핑, 파스텔 톤 보정을 포함한 색보정
- Bloom extraction and blur using a separate bloom buffer
- 별도 블룸 버퍼를 사용한 블룸 추출 및 블러
- Depth-based fog with rain-aware distance adjustment
- 비 오는 날 거리를 반영하는 깊이 기반 안개
- Vignette for softer screen edges
- 화면 가장자리를 부드럽게 어둡게 만드는 비네트
- Mood lighting based on sun, moon, torch, lava, and rain color palettes
- 태양, 달, 횃불, 용암, 비 색상 팔레트 기반의 분위기 조명
- Held torch lighting with distance falloff, soft edge glow, and subtle flicker
- 거리 감쇠, 부드러운 외곽광, 약한 깜빡임을 포함한 손에 든 횃불 조명
- Lava glow using a terrain lava mask
- 지형 용암 마스크를 이용한 용암 발광
- Rainy wet-surface highlight using terrain wet/wall masks
- 지형 wet/wall 마스크를 이용한 비 오는 날 젖은 표면 하이라이트
- Basic shadow map sampling with PCF
- PCF 기반의 기본 shadow map 샘플링


## Shadow / Normal Buffer Status

- `SHADOW_MODE = 1` enables the PCSS path by default.
- `colortex3` stores encoded world normals for terrain and water.
- Final lighting uses the normal buffer for `NdotL` direct diffuse, back-face form shadow, and shadow-map-based cast shadow blending.
- Contact shadows are strengthened for closer object grounding.
- Remaining shadow work: detailed foliage/water/glass/emissive caster rules, cascade or distance-split stability, and translucent/colored shadows.
## Main Color Palette

- Sun: `#F1FEC6`
- 태양: `#F1FEC6`
- Moon: `#BFD8FF`
- 달: `#BFD8FF`
- Torch: `#F5853F`
- 횃불: `#F5853F`
- Lava: `#FF3A20`
- 용암: `#FF3A20`
- Rain: `#3423A6`
- 비: `#3423A6`

## Shader Options

Options are grouped under the `MOOD` screen in Iris:

옵션은 Iris의 `MOOD` 화면 아래에 묶여 있습니다.

- `EXPOSURE`
- `CONTRAST`
- `SATURATION`
- `LIGHTING_STRENGTH`
- `DAY_LIGHT_STRENGTH`
- `NIGHT_LIGHT_STRENGTH`
- `SUNSET_GLOW_STRENGTH`
- `TORCH_LIGHT_INTENSITY`
- `RAIN_REFLECTION_INTENSITY`
- `BLOOM_INTENSITY`
- `BLOOM_THRESHOLD`
- `FOG_DENSITY`
- `FOG_START`
- `VIGNETTE_OUTER`

## Status

This shader is still in development. Core post-processing, sky/fog unification, wet surfaces, PCSS shadows, contact shadows, and normal-buffer-based terrain form lighting are implemented. In-game testing and visual tuning are still needed across daytime, nighttime, caves, rain, Nether, and End environments.

이 쉐이더는 아직 개발 중입니다. 핵심 후처리 기능은 구현되어 있지만, 낮, 밤, 동굴, 비, 네더, 엔드 환경에서의 인게임 테스트와 색감 튜닝이 아직 필요합니다.

## License
```
MIT License. See `LICENSE` for details.

MIT License를 사용합니다. 자세한 내용은 `LICENSE` 파일을 참고하세요.
```