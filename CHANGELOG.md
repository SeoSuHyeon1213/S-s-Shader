# Changelog

All notable changes to this shader pack will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## 2026-06-20 - Hand Pass Shadow Isolation

### Fixed

- Prevented held hands/items from receiving terrain shadow map visibility, contact shadow, normal form lighting, and global wet highlights.
- Added a final-pass terrain receiver mask based on `colortex2` material channels, so only terrain/water/lava-marked pixels enter terrain shadow and wet-surface paths.
- Stopped `applyTerrainFormLighting()` from treating any valid normal buffer pixel as terrain by itself.

### Notes

- Hand/entity passes still write normals for compatibility, but final terrain shading now requires material masks as well.
- This is likely related to player-movement shadow instability because held hands/items move with the camera while terrain shadow code expected world-stable receivers.

## 2026-06-20 - Terrain-Only PCSS Expression Restore

### Changed

- Reduced `shadowIntervalSize` from `16.0` to `8.0` for a better stability/detail balance.
- Kept `ENABLE_CONTACT_SHADOWS = 0` and hand/entity receiver isolation intact.
- Restored terrain-only PCSS expression by letting blocker-depth penumbra drive the filter radius again.
- Tuned PCSS values to `PCSS_LIGHT_SIZE = 16.0`, `PCSS_MIN_RADIUS = 0.65`, and `PCSS_MAX_RADIUS = 2.8`.
- Increased `SHADOW_DARKNESS` to `0.74` and cooled/darkened shadow tint to reduce the vanilla-like flat look.

### Notes

- If walking remains stable, `shadowIntervalSize = 4.0` is the next detail-oriented test value.

## 2026-06-20 - Player-Movement Shadow Stability

### Changed

- Increased `shadowIntervalSize` from `1.0` to `16.0` so the shadow projection no longer follows every small player movement.
- Changed `ENABLE_CONTACT_SHADOWS` default from `1` to `0` because screen-space contact shadows move with the camera by design.
- Removed view-distance-dependent shadow bias, PCF radius, PCSS search radius, and shadow strength fade from the main shadow map path.
- Added stable PCF/PCSS radius constants so a surface keeps the same shadow filtering while the player moves.
- Changed partial shadow caster dithering from `gl_FragCoord` to texture-coordinate cells to reduce reprojection crawling.
- Fixed contact shadow sampling radius so it no longer scales while the player walks toward or away from geometry.

### Notes

- Shadow map edge fade and weather/time fade still apply, but ordinary player movement should no longer continuously change shadow softness or strength.
- `shadowIntervalSize = 16.0` was used as a maximum-stability diagnostic value; current balanced default is `8.0`.

## 2026-06-20 - Wet Specular BRDF Material Refinement

### Changed

- Reworked wet specular highlights from a simple Phong-style lobe to a GGX-style microfacet BRDF.
- `applyWetSpecularBRDF()` now uses the `colortex3` world normal buffer when available, falling back to the older floor/wall normal estimate only when needed.
- Wet material response values are now interpreted as roughness/F0 hints, so stone/glass-like surfaces stay glossier while foliage/crop-like surfaces remain broad and muted.
- Wall and floor wet masks now influence roughness separately, reducing harsh vertical streak highlights.

### Notes

- Material-specific behavior is inferred from the existing wet response masks because the current buffer layout does not store a dedicated material ID in the final pass.

## 2026-06-20 - Water Reflection and Absorption Refinement

### Changed

- Increased water SSR ray steps and binary refinement steps for more stable hit placement.
- Tightened SSR thickness and added hit confidence based on edge fade, ray distance, and refined depth delta.
- Reworked SSR roughness blur from a 5-tap cross into a softer 9-tap kernel.
- Added a low-cost planar-style fallback reflection for horizontal water using mirrored screen sampling.
- Added view-distance-based water absorption and stronger flow/foam separation for vertical water.

### Notes

- This is still not a true planar reflection pass. A real planar pass would need an additional reflected scene render target or loader-specific reflection buffer.

## 2026-06-20 - Material-Aware Shadow Refinement

### Changed

- Refined shadow caster rules for foliage, crop, and glass material groups instead of treating every non-water/non-lava caster as fully opaque.
- Added stable dithered partial shadow casting for translucent or thin materials in the shadow pass.
- Added distance-split-style far shadow softening to reduce harsh distant shadow bands without adding a full cascade pipeline.
- Made final shadow tint and strength react to wet floor/wall, water, and lava masks.
- Improved normal-based directional lighting with a small BRDF lobe on wet/material-marked terrain.

### Notes

- This is still a single shadow map path, not a true cascaded shadow map implementation.
- Colored/translucent shadows are approximated through partial caster opacity and material-aware final tint because the current buffer layout only stores a single depth shadow map.

## 2026-06-20 - Shadow Movement Stabilization

### Changed

- 플레이어 이동 중 그림자가 계속 변형되어 보이는 현상을 줄이기 위해 `shadowIntervalSize`를 `0.25`에서 안정 우선값 `1.0`으로 되돌림.
- PCF/PCSS 샘플 커널의 per-pixel hash 회전을 제거하고 고정 Poisson kernel을 사용하도록 변경.
- shadow map 재투영 변화와 필터 패턴 crawling이 동시에 보이는 상황을 줄이는 방향으로 조정.

### Notes

- `0.25`는 갱신 단위는 촘촘하지만 카메라 이동 중 shadow shimmer와 변형이 커질 수 있음.
- 현재 안정 우선값은 `1.0`이며, 더 타이트한 움직임이 필요하면 `0.5`를 다시 실험하는 것을 권장.

## 2026-06-20 - Tighter Experimental Shadow Interval

### Changed

- `shadowIntervalSize`를 `0.5`에서 `0.25`로 낮춰 shadow map 갱신 단위를 더 촘촘하게 조정.
- 그림자가 시간 변화나 카메라 이동을 더 빠르게 따라오도록 실험값을 적용.

### Notes

- `0.25`는 더 타이트한 값이지만 환경에 따라 shimmer가 늘 수 있음.
- 그림자가 미세하게 떨리면 `0.5` 또는 안정 우선값 `1.0`으로 되돌리는 것을 권장.

## 2026-06-20 - Documentation Cleanup and Current State Sync

### Changed

- `CHANGELOG.md` 구조를 최근 변경 이력, 현재 구현 상태, 목표, 미구현 항목으로 다시 정리.
- 파일에는 없거나 흩어져 있던 최신 구현 내용을 현재 코드 기준으로 반영.
- 오래된 `MOOD` 옵션 화면 설명을 제거하고, Iris/NeOculus 옵션 화면에 직접 노출되는 현재 구조로 정리.
- 깨진 한글 텍스트가 다시 섞이지 않도록 문서를 UTF-8 한국어 중심으로 재작성.

### Synced From Code

- `shadowIntervalSize = 1.0` 안정 우선 그림자 갱신 간격 설정.
- `ENABLE_CONTACT_SHADOWS`, `ENABLE_NORMAL_FORM_LIGHTING`, `ENABLE_WET_GROUND_LAYER`, `ENABLE_WET_SCREEN_REFLECTIONS`, `ENABLE_WET_SPECULAR`, `ENABLE_WATER_SURFACE` 안정성/디버그 토글.
- `colortex3Format = RGBA16F` normal buffer와 `DRAWBUFFERS:0123` 전달 구조.
- `gbuffers_hand`, `gbuffers_entities`, `gbuffers_hand_water` 전용 패스.
- `gbuffers_skybasic`, `gbuffers_skytextured`, `gbuffers_clouds`, `gbuffers_water` 전용 패스.
- `block.properties`의 lava, water, stone, soil, wood, foliage, glass, crop material 그룹.

## 2026-06-20 - Tighter Shadow Update Interval

### Changed

- `shaders.properties`에 `shadowIntervalSize`를 추가하고, 이후 실험값을 `0.25`로 조정.
- 카메라 이동이나 시간 변화 중 그림자가 큰 단위로 따라오는 느낌을 줄이도록 shadow map 위치 갱신 단위를 더 촘촘하게 설정.

### Notes

- 값이 작을수록 그림자 갱신은 더 타이트해지지만, 환경에 따라 미세한 shadow shimmer가 늘어날 수 있음.
- 떨림이 보이면 `shadowIntervalSize = 0.5` 또는 안정 우선값 `1.0`으로 완화하는 것을 권장.

## 2026-06-20 - NeOculus Stability Debug Options

### Changed

- NeOculus에서 `Unable to resolve shader pack option menu element "MOOD"` 경고가 발생하던 `screen = MOOD` / `screen.MOOD` 구조를 제거.
- 옵션을 최상위 `screen`에 직접 노출하도록 `shaders.properties`를 정리.
- 최근 추가한 고비용 후처리 경로를 기능별 `#if` 토글로 분리해 크래시 원인 분리가 가능하도록 변경.
- CurseForge용 `minecraftshader.zip` 패키징 구조를 검증.

### Added

- `ENABLE_CONTACT_SHADOWS`: 가까운 거리 screen-space contact shadow on/off.
- `ENABLE_NORMAL_FORM_LIGHTING`: normal buffer 기반 지형 입체 조명 on/off.
- `ENABLE_WET_GROUND_LAYER`: 비 오는 날 젖은 바닥 darkening/sheen layer on/off.
- `ENABLE_WET_SCREEN_REFLECTIONS`: 젖은 바닥 screen-space reflection on/off.
- `ENABLE_WET_SPECULAR`: 젖은 표면 BRDF 하이라이트 on/off.
- `ENABLE_WATER_SURFACE`: 물 Fresnel/flow surface shading on/off.

### Notes

- 다른 셰이더에서는 크래시가 없고 이 셰이더에서만 발생한다면 `ENABLE_WET_SCREEN_REFLECTIONS`, `ENABLE_WATER_SURFACE`, `ENABLE_CONTACT_SHADOWS`, `ENABLE_NORMAL_FORM_LIGHTING` 순서로 기능을 끄며 확인하는 것을 권장.

## 2026-06-20 - Wet Ground Material Layer

### Changed

- `applyWetGroundLayer()`를 추가해 비 오는 날 바닥이 단순히 밝게 반사되는 대신 젖은 표면처럼 어둡고 차분하게 보이도록 조정.
- rain, puddle, floor mask를 기준으로 바닥을 먼저 어둡게 누르고, 차가운 물막 tint와 낮은 각도 sheen을 얹도록 변경.
- puddle reflection보다 앞단에서 젖은 재질감을 먼저 형성하도록 순서를 조정.
- grass, dirt, soil 계열은 강한 거울 반사보다 wet darkening과 은은한 광택 위주로 보정.

## 2026-06-20 - Rain Puddle Ground Reflections

### Changed

- `getRainPuddleMask()`와 `sampleRainPuddleReflection()`을 추가.
- 비 오는 날 평평한 바닥에 웅덩이 기반 screen-space reflection을 적용.
- `WET_TERRAIN_REFLECTION_STRENGTH = 0.34`로 상향.
- `RAIN_REFLECTION_INTENSITY = 0.6`으로 조정.
- 수직 벽면에는 반사가 과하게 적용되지 않도록 floor mask와 screen edge fade를 강화.

## 2026-06-20 - Water Reflection Mode Step 1

### Changed

- `WATER_REFLECTION_MODE` 옵션을 추가.
- 기본값 `0`에서는 화면 샘플 기반 SSR 대신 안정적인 sky/Fresnel/roughness/flow 기반 물 표현을 사용.
- `WATER_REFLECTION_MODE = 1`일 때만 약한 water SSR을 추가 적용.
- `applyWaterSurface()`에서 수평 물은 Fresnel 반사를 유지하고, 폭포/수직 물기둥은 absorption + flow shading 위주로 분리.
- `applyWaterSSR()`는 fallback 경로로 남기되, 가까운 수직 물에서는 반사량을 크게 감쇠.

### Notes

- 진짜 planar reflection은 아직 구현되지 않음.
- 추후 별도 reflected scene texture 또는 전용 reflection pass 구조가 필요함.

## 2026-06-20 - Held Torch Color Match

### Changed

- 손에 든 횃불 조명이 뿌옇고 하얗게 뜨는 현상을 줄임.
- `TORCH_LIGHT_COLOR`, `TORCH_EDGE_COLOR`를 설치된 횃불에 가까운 따뜻한 주황 계열로 조정.
- held torch의 ambient, brightness, indoor boost를 낮춰 과노출과 흰색 haze를 완화.
- `heldBlockLightValue`, `heldBlockLightValue2` 기반 손 조명 강도와 거리 감쇠를 유지.

## 2026-06-19 - Waterfall Reflection Stabilization

### Changed

- 가까운 수직 물/폭포에서 하얀 반점처럼 보이던 reflection artifact를 줄이기 위해 `waterfallMask`를 추가.
- `worldNormal`과 view distance를 사용해 수직/근거리 물의 SSR, sky fallback, specular를 감쇠.
- 폭포는 반사보다 깊은 물색, 흡수감, 흐름 표현 중심으로 조정.
- `gbuffers_water.fsh`의 wave normal 강도와 specular/sky reflection 출력을 낮춰 가까운 물기둥의 반짝임을 완화.

## 2026-06-19 - Held Item Opaque Pass

### Added

- `gbuffers_hand.vsh/fsh`.
- `gbuffers_hand_water.vsh/fsh`.
- `gbuffers_entities.vsh/fsh`.

### Fixed

- 손에 든 아이템이 일부 투과되어 보이던 문제를 줄이기 위해 hand/entity pass에서 `colortex0.a = 1.0`을 출력.
- hand/entity pass에서 `colortex2` material mask를 `vec4(0.0)`으로 초기화해 terrain/water mask가 섞이지 않도록 정리.
- hand/entity pass에서도 normal buffer를 기록해 final 단계의 normal 기반 shading이 안정적으로 동작하도록 정리.

## 2026-06-19 - Normal Shading and Shadow-Aware Fog

### Changed

- `colortex3` normal buffer 기반 `NdotL` diffuse와 form shadow를 추가.
- `gbuffers_terrain`, `gbuffers_water`, `gbuffers_hand`, `gbuffers_entities`, `gbuffers_hand_water`가 normal buffer를 기록하도록 정리.
- `composite.fsh`가 `DRAWBUFFERS:0123`으로 scene color, bloom buffer, material mask, normal buffer를 final pass까지 전달.
- shadow map으로 가려진 영역에서 mood lighting lift와 highlight가 과하게 들어가지 않도록 `shadowVisibility`를 전달.
- fog가 그림자 영역을 다시 밝게 덮는 현상을 줄이기 위해 shadow-aware fog 보정을 추가.

## 2026-06-18 - Shadow Contrast and PCSS Work

### Changed

- `SHADOW_MODE = 1` 기본 경로에 PCSS를 활성화.
- 8-sample blocker search와 8-sample filter를 사용하도록 `PCSS_BLOCKER_SAMPLES`, `PCSS_FILTER_SAMPLES`를 명시.
- `PCSS_LIGHT_SIZE = 20.0`, `PCSS_MIN_RADIUS = 0.85`, `PCSS_MAX_RADIUS = 2.0`으로 radius clamp를 강하게 조정.
- `SHADOW_DARKNESS = 0.66`으로 shadow tint 대비를 강화.
- `CONTACT_SHADOW_INTENSITY = 0.65`로 가까운 거리 접지감을 강화.
- `getSkyShadowTint()`를 통해 `getSkyColor()` 기반 shadow tint를 적용.

### Notes

- 현재 그림자는 바닐라보다 대비가 강해졌지만, 유명 셰이더 수준의 cascade shadow, colored shadow, material-specific caster rule은 아직 미구현.

## 2026-06-17 - Sky, Cloud, Fog, and Horizon Unification

### Added

- `lib/sky.glsl`.
- `gbuffers_skybasic.vsh/fsh`.
- `gbuffers_skytextured.vsh/fsh`.
- `gbuffers_clouds.vsh/fsh`.

### Changed

- 하늘, 구름, 안개, 지형 fog, 물 반사 색을 `lib/sky.glsl`의 공통 sky color 체계로 통합.
- `getSkyColor()`, `getSkyUnifiedColor()`, `getSkyCloudColor()`, `getSkyWaterReflectionColor()`, `getSkyWaterTint()`, `getSkyFogColor()`를 중심으로 색 계산을 정리.
- `final.fsh`에서 `depth >= 1.0` 하늘 픽셀에 적용하던 추가 fog 덧칠을 제거 또는 최소화.
- 지형 fog 색을 `fogColor` uniform 대신 `getSkyFogColor(worldDir, ...)` 기반으로 변경.
- 낮에서 밤으로 바뀔 때 수평선과 하늘이 두 층으로 갈라져 보이는 현상을 완화.
- 구름 RGB를 공통 sky color 체계로 보정하면서 바닐라 구름 alpha는 유지.

## 2026-06-16 - Water Pass and Material Mask Expansion

### Added

- `gbuffers_water.vsh/fsh` 물 전용 pass.
- `colortex2.a` water mask.
- 물 전용 Fresnel, ripple, sky reflection tint, flow shading.

### Changed

- `colortex2` material mask 구조를 `R = wet floor`, `G = wall`, `B = lava`, `A = water`로 확장.
- lava mask를 `colortex0.a`에서 `colortex2.b`로 이동.
- `colortex0Format = RGBA8`, `colortex1Format = RGBA16F`, `colortex2Format = RGBA8`, `colortex3Format = RGBA16F` 설정.

## 2026-06-15 - Shadow Stabilization and Caster Rules

### Changed

- shadow map sampling에 slope bias, distance bias, edge fade, weather/night fade를 추가.
- shadow pass에서 alpha cutout을 처리.
- water, lava, glass 계열은 solid shadow caster에서 제외.
- `shadowMapResolution = 2048`, `shadowDistance = 96.0` 설정.

### Fixed

- 일부 오브젝트가 잘못 투명하거나 누락되어 보이는 문제를 줄이기 위해 material mask와 alpha 출력 구조를 정리.

## 2026-06-14 - Initial Shader Structure

### Added

- `README.md`.
- `LICENSE`.
- `shaders/final.vsh`, `shaders/final.fsh`.
- `shaders/composite.vsh`, `shaders/composite.fsh`.
- `shaders/gbuffers_terrain.vsh`, `shaders/gbuffers_terrain.fsh`.
- `shaders/shadow.vsh`, `shaders/shadow.fsh`.
- `shaders/block.properties`.
- `shaders/lib/color.glsl`.
- `shaders/lib/fog.glsl`.
- `shaders/lib/lighting.glsl`.
- `shaders/lib/wet.glsl`.
- `shaders/lib/ssr.glsl`.
- `shaders/lib/shadows.glsl`.

### Implemented

- 색 보정: exposure, contrast, saturation, warm tint, ACES tonemapping, pastel tone, dithering.
- bloom 추출 및 blur.
- 렌더 거리 기반 fog.
- sun, moon, torch, lava, rain palette 기반 mood lighting.
- held torch 조명 거리 감쇠와 flicker.
- lava mask 기반 발광 보정.
- wet floor/wall mask 기반 비 오는 날 wet highlight.
- water mask 기반 초기 SSR 경로.
- shadow map 기반 초기 PCF 그림자.

## Current Goals / 목표사항

- Iris/NeOculus 기반 Minecraft 분위기형 shaderpack 제작.
- 하늘, 구름, 안개, 지형 fog, 물 반사를 `lib/sky.glsl`의 공통 sky color 체계로 통합해 낮/밤 전환과 수평선 층 분리를 완화.
- 파스텔 톤을 유지하면서 색감, 채도, 노출, 대비를 게임 플레이에 맞게 조정.
- 들고 있는 횃불과 설치된 횃불의 색과 체감 밝기를 비슷하게 맞춤.
- 비 오는 날 젖은 바닥, 벽면 물 흐름, 웅덩이 반사를 강화.
- shadow map, Poisson PCF, PCSS, contact shadow, normal buffer 기반 form lighting을 단계적으로 강화.
- material mask 구조를 유지해 lava, water, wet floor, wall, foliage, glass, crop 등 재질별 효과를 분리.
- NeOculus/Embeddium 환경에서 shaderpack zip 구조와 GLSL 호환성을 계속 검증.

## Current Shader Options

- `SHADOW_MODE`
- `WATER_REFLECTION_MODE`
- `ENABLE_CONTACT_SHADOWS`
- `ENABLE_NORMAL_FORM_LIGHTING`
- `ENABLE_WET_GROUND_LAYER`
- `ENABLE_WET_SCREEN_REFLECTIONS`
- `ENABLE_WET_SPECULAR`
- `ENABLE_WATER_SURFACE`
- `EXPOSURE`
- `CONTRAST`
- `SATURATION`
- `LIGHTING_STRENGTH`
- `DAY_LIGHT_STRENGTH`
- `NIGHT_LIGHT_STRENGTH`
- `SUNSET_GLOW_STRENGTH`
- `TORCH_LIGHT_INTENSITY`
- `CONTACT_SHADOW_INTENSITY`
- `RAIN_REFLECTION_INTENSITY`
- `BLOOM_INTENSITY`
- `BLOOM_THRESHOLD`
- `FOG_DENSITY`
- `FOG_START`
- `VIGNETTE_OUTER`

## Current Buffer Layout

- `colortex0`: scene color.
- `colortex1`: bloom buffer.
- `colortex2.r`: wet floor mask.
- `colortex2.g`: wall mask.
- `colortex2.b`: lava mask.
- `colortex2.a`: water mask.
- `colortex3.rgb`: encoded world normal.
- `colortex3.a`: valid normal mask.

## Current Material IDs

- `block.11000`: lava.
- `block.11001`: water.
- `block.11100`: stone-like wet response group.
- `block.11101`: soil/grass/sand/gravel wet response group.
- `block.11102`: wood wet response group.
- `block.11103`: foliage/moss/grass wet response group.
- `block.11104`: glass wet response group.
- `block.11105`: crops/small plants low-reflection group.

## Current Shadow Implementation Status

현재 그림자 구현률 추정: 약 65-72%.

구현된 부분:

- `shadowtex0`, `shadowModelView`, `shadowProjection` 기반 shadow map sampling.
- `shadowMapResolution = 2048`.
- `shadowDistance = 96.0`.
- `shadowIntervalSize = 8.0`.
- `SHADOW_MODE = 0`: 8-sample Poisson PCF.
- `SHADOW_MODE = 1`: 8-sample blocker search + 8-sample filter PCSS.
- `SHADOW_DARKNESS = 0.74` 기반 강화된 shadow tint.
- screen-space contact shadow option (`ENABLE_CONTACT_SHADOWS = 0` by default for movement stability).
- normal buffer 기반 terrain form lighting.
- alpha cutout 처리 및 water/lava/glass 계열 solid shadow caster 제외.
- 거리 fade, shadow map edge fade, 날씨 fade, 낮/밤 fade, sky color 기반 shadow tint.
- 비 오는 날 wet surface 반응을 위한 shadow 기반 rain exposure 보조 함수.

현재 한계:

- screen-space contact shadow는 화면 밖 또는 가려진 geometry 정보를 처리하지 못함.
- foliage 세부 투과 그림자와 colored shadow는 아직 없음.
- cascade shadow map 또는 distance split 기반 원거리 안정화는 아직 없음.
- material별 shadow tint와 directional BRDF 반응은 아직 단순함.

## Water Reflection Roadmap

구현된 부분:

- `colortex2.a` water mask 픽셀에만 물 효과 적용.
- sky/Fresnel/roughness/flow 기반 안정 물 표현.
- 약한 SSR 옵션 경로 유지.
- 폭포/수직 물기둥은 reflection보다 absorption + flow shading 중심으로 분리.

남은 부분:

- 진짜 planar reflection.
- water SSR binary search 품질 개선.
- roughness blur 고도화.
- 물 depth/absorption 추가 개선.

## Planned / Not Implemented

- 인게임 Iris/NeOculus 컴파일 로그 반복 확인.
- 낮, 밤, 동굴, 비, 네더, 엔드 환경별 색감 프리셋 정리.
- 인게임 스크린샷 기반 wet specular roughness/F0 추가 튜닝.
- cascade shadow map 또는 distance split 구현.
- translucent/colored shadow.
- foliage/glass/emissive material caster rule 세분화.
- planar water reflection.
- 옵션 설명과 추천 프리셋 정리.
