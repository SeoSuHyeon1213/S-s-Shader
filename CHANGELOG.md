# Changelog

All notable changes to this shader pack will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).
## 2026-06-20 - Held Torch Color Match

### Changed

- 들고 있는 횃불 조명이 뿌옇고 흰색으로 뜨는 현상을 줄이기 위해 `TORCH_LIGHT_COLOR`, `TORCH_EDGE_COLOR`를 설치 횃불에 가까운 따뜻한 주황 계열로 재조정.
- held torch의 edge lighting이 전체 색을 흰색으로 들어 올리지 않도록 `vec3(1.0) + tint` 방식 대신 따뜻한 곱셈 tint 중심으로 변경.
- `HELD_LIGHT_AMBIENT`, `HELD_LIGHT_BRIGHTNESS`, 어두운 실내 boost를 낮춰 횃불을 들었을 때 안개처럼 번지는 밝기를 줄임.
- 밝은 표면에서 held torch가 과하게 탈색되지 않도록 surface protection 범위를 조정.

### Notes

- 목표는 설치된 횃불 lightmap과 비슷한 따뜻한 주황빛을 유지하면서, 들고 있는 횃불의 흰색 haze를 줄이는 것.
- 실제 게임에서는 밤 숲, 동굴 벽, 밝은 돌/눈 블록 근처에서 설치 횃불과 들고 있는 횃불 색을 비교해야 함.
## 2026-06-19 - Waterfall Reflection Stabilization

### Changed

- 가까운 수직 물/폭포에서 screen-space reflection과 sky fallback 반사가 하얀 반점처럼 튀는 현상을 줄이기 위해 `worldNormal`과 view distance 기반 `waterfallMask`를 추가.
- `applyWaterSurface()`가 수직/근거리 물에서는 반사량을 줄이고, 깊은 물 흡수색과 부드러운 흐름 음영을 더하도록 변경.
- `applyWaterSSR()`가 가까운 폭포형 물에서는 SSR hit reflection과 sky fallback reflection을 크게 감쇠하도록 변경.
- `gbuffers_water.fsh`의 wave normal 강도와 specular/sky reflection 출력을 낮춰 가까운 물기둥의 반짝임이 점처럼 튀지 않게 조정.

### Notes

- 평평한 호수/바다 표면의 반사는 유지하면서, 카메라에 가까운 수직 물은 사실적인 어두운 투과/흡수 느낌에 더 가깝게 조정함.
- 실제 게임에서는 폭포 가까이, 동굴 물줄기, 넓은 수면을 각각 확인해 SSR 약화가 과하지 않은지 봐야 함.
## 2026-06-19 - Held Item Opaque Pass

### Added

- `gbuffers_hand.vsh/fsh` 추가.
- `gbuffers_hand_water.vsh/fsh` 추가.
- `gbuffers_entities.vsh/fsh` 추가.

### Fixed

- 손에 든 아이템이 일부 투과되어 보일 수 있는 문제를 줄이기 위해 hand/entity 전용 패스에서 `colortex0.a`를 항상 `1.0`으로 출력.
- hand/entity 패스에서 `colortex2` material mask를 `vec4(0.0)`으로 초기화해 이전 terrain/water mask가 섞이지 않도록 처리.
- hand/entity 패스에서도 normal buffer(`colortex3`)를 기록해 final 단계의 normal 기반 shading이 안정적으로 동작하도록 정리.

### Notes

- 이 변경은 아이템 자체 투명 텍스처의 cutout은 유지하면서, 렌더 패스 전체가 반투명 표면처럼 합성되는 문제를 막는 목적입니다.
## 2026-06-19 - Normal Shading and Shadow-Aware Fog

### Changed

- normal buffer 기반 `NdotL` diffuse와 form shadow 강도를 높여 블록 면 방향에 따른 입체감을 강화.
- shadow map으로 가려진 픽셀에서는 mood lighting의 shadow lift와 highlight 적용량을 줄이도록 `applyMoodLighting()`에 `shadowVisibility`를 전달.
- fog 단계에서 shadow map 마스크를 사용해 그림자 영역의 fog factor를 낮추고, fog color가 장면의 어두운 밝기를 더 따라가도록 `shadowAwareFogPull`을 추가.
- normal 기반 form/cast shadow의 최대 합성치를 `0.42`에서 `0.52`로 높여 지형과 나무 밑 그림자 대비를 강화.

### Notes

- 이번 변경은 그림자를 더 진하게 만드는 것뿐 아니라, 후처리 fog/ambient가 그림자를 다시 밝게 덮는 문제를 줄이는 데 초점을 둠.
- 실제 게임에서는 낮 지형 경사면, 밤 숲, 횃불 주변에서 그림자 대비와 fog 밝기 과보정 여부를 확인해야 함.

## Goals / 목표사항

- Iris/NeOculus 기반 Minecraft 분위기형 shaderpack 제작.
- 하늘, 구름, 안개, 지형 fog, 물 반사를 `lib/sky.glsl`의 공통 sky color 체계로 통합해 낮/밤 전환과 수평선 층 분리를 완화.
- 파스텔 톤을 유지하면서 색감, 채도, 노출, 대비를 게임 플레이에 맞게 조정.
- 들고 있는 횃불과 설치된 횃불의 색과 체감 밝기를 비슷하게 맞추고, 실내/동굴에서는 강하게 낮 야외에서는 약하게 보정.
- shadow map 기반 그림자, Poisson PCF, PCSS, contact shadow를 단계적으로 강화해 바닐라보다 뚜렷한 입체감 구현.
- 현재 그림자 구현률 65-72% 수준에서 normal buffer 기반 조명 고도화, 세부 caster rule, cascade/distance split 그림자 안정화를 다음 목표로 진행.
- 물 전용 `gbuffers_water`와 water mask 기반 SSR을 확장해 sky reflection, Fresnel, ripple, rough reflection을 자연스럽게 개선.
- 비 오는 날 wet floor/wall mask 기반 젖은 표면 하이라이트와 rain exposure 반응 강화.
- lava, water, wet floor, wall 등 material mask 구조를 유지해 블록/재질별 효과를 분리.
- bloom, fog, vignette, dithering, tone mapping을 통합해 밴딩과 과노출을 줄이고 부드러운 화면 분위기 유지.
- NeOculus/Embeddium 환경에서 shaderpack zip 구조와 GLSL 호환성을 계속 검증.
- 추후 개선 목표: cascade shadow map, translucent/colored shadow, material/caster rule, water SSR binary search, roughness blur, sky fallback, normal 기반 wet specular BRDF.
- 그림자 관하여 다음과 같은 항목을 중요시 할 예정
foliage/glass/emissive caster rule 세분화
PCSS sample option 확장
cascade/distance split 안정화

## In-Game Tuning Checklist

- 낮 평원에서 기본 노출, 채도, 대비 확인
- 일몰에서 수평선 glow와 구름 tint 확인
- 밤 평원에서 달빛 가독성 확인
- 동굴에서 횃불 조명 거리와 색 번짐 확인
- 비 오는 날 wet reflection과 fog 강도 확인
- 물가에서 water SSR, sky reflection, rough reflection 확인
- 네더에서 용암 발광 과포화 확인



### Added

- `README.md`
  - 프로젝트 설명, 기능 목록, 색상 팔레트, 옵션 목록 추가
  - 영어 원문 아래에 한국어 번역 추가
- `LICENSE`
  - MIT License 초안 추가
- `shaders/final.vsh`, `shaders/final.fsh`
  - 최종 출력 패스 추가
  - 블룸 합성, 그림자, 분위기 조명, wet highlight, 물 SSR, 안개, 색보정, 비네트, dithering 적용
- `shaders/composite.vsh`, `shaders/composite.fsh`
  - 블룸 추출/블러 패스 추가
  - scene color, bloom buffer, material mask pass-through 구성
- `shaders/gbuffers_terrain.vsh`, `shaders/gbuffers_terrain.fsh`
  - terrain 렌더링 패스 추가
  - texture, vertex color, lightmap 기반 기본 terrain 셰이딩
  - world normal 기반 wet floor/wall mask 기록
  - lava material mask 기록
- `shaders/gbuffers_water.vsh`, `shaders/gbuffers_water.fsh`
  - 물 전용 gbuffers 패스 추가
  - water mask 기록 및 물 전용 푸른 틴트, Fresnel, ripple 하이라이트 적용
- `shaders/gbuffers_skybasic.vsh`, `shaders/gbuffers_skybasic.fsh`
  - 기본 하늘 전용 gbuffers 패스 추가
  - sky geometry의 view direction을 world direction으로 변환해 공통 sky color 적용
- `shaders/gbuffers_clouds.vsh`, `shaders/gbuffers_clouds.fsh`
  - 구름 전용 gbuffers 패스 추가
  - 바닐라 구름 텍스처/알파는 유지하고 RGB 색상을 공통 sky color 체계로 보정
  - alpha 주변 샘플 기반 fake thickness, self-shadow, edge light를 추가해 구름 두께감 보정
- `shaders/gbuffers_skytextured.vsh`, `shaders/gbuffers_skytextured.fsh`
  - 태양/달/별 등 sky textured 요소 전용 gbuffers 패스 추가
  - 텍스처 알파와 밝기는 유지하되 RGB를 `lib/sky.glsl`의 공통 sky color 체계로 tint
- `shaders/shadow.vsh`, `shaders/shadow.fsh`
  - shadow map 생성을 위한 기본 그림자 패스 추가
- `shaders/block.properties`
  - `minecraft:lava`에 커스텀 block ID `block.11000` 할당
  - `minecraft:water`에 커스텀 block ID `block.11001` 할당
- `shaders/lib/color.glsl`
  - 노출, 대비, 채도, 색온도, ACES 톤매핑, 파스텔 톤, dithering 유틸리티 추가
- `shaders/lib/fog.glsl`
  - 깊이 선형화, 렌더 거리 기반 안개, 주변 밝기 기반 안개색 보정 추가
- `shaders/lib/sky.glsl`
  - `getSkyColor(worldDir, worldTime, rainStrength)` 중심의 공통 하늘색 유틸리티 추가
  - 낮/밤/일출·일몰/비 상태별 zenith/horizon 색 보간 추가
  - 화면 y좌표 대신 world direction 기반 horizon mask 사용
- `shaders/lib/lighting.glsl`
  - 태양, 달, 횃불, 용암, 비 색상 팔레트 기반 분위기 조명 추가
  - 손에 든 횃불 조명 거리 감쇠, flicker, surface protection 추가
  - 용암 material mask 기반 발광 보정 추가
  - 달빛 색상을 `#BFD8FF` 기준으로 통일
  - 용암 `#FF3A20`과 비 `#3423A6`는 core/accent 색상으로만 사용하고, 주변광은 완화된 edge/ambient 색상으로 분리
- `shaders/lib/wet.glsl`
  - 비 오는 날 global wet highlight 추가
  - terrain wet/wall mask 기반 fake wet reflection 추가
  - water mask 기반 물 표면 하이라이트 추가
- `shaders/lib/ssr.glsl`
  - 물 마스크(`colortex2.a`)에만 제한된 저비용 screen-space raymarching SSR 기본 경로 추가
  - 16 step 이하의 짧은 raymarch, edge fade, distance fade, Fresnel 기반 합성 적용
- `shaders/lib/shadows.glsl`
  - shadow map 샘플링, PCF, 거리 fade, 파스텔 그림자 tint 추가

### Changed
- `shaders/gbuffers_terrain.*`, `shaders/gbuffers_water.fsh`, `shaders/composite.fsh`, `shaders/final.fsh`, `shaders/lib/lighting.glsl`, `shaders/shaders.properties`
  - `colortex3` 기반 normal buffer 추가
  - terrain pass는 world normal을, water pass는 wave-adjusted world normal을 `colortex3.rgb`에 인코딩하고 `a`에 normal 유효 마스크를 기록
  - composite pass가 normal buffer를 final pass까지 전달하도록 `DRAWBUFFERS:0123`으로 확장
  - `applyTerrainFormLighting()`이 wet floor/wall 근사 normal 대신 normal buffer를 우선 사용하도록 변경
- `shaders/lib/shadows.glsl`, `shaders/final.fsh`, `shaders/lib/lighting.glsl`, `shaders/shadow.vsh`, `shaders/shadow.fsh`
  - 추천 구현 순서 1-5단계 적용: PCSS 기본 활성화, 그림자 대비 강화, contact shadow 강화, terrain form shading 추가, shadow caster alpha/material rule 추가
  - `SHADOW_MODE` 기본값을 `1`로 변경하고 `SHADOW_DARKNESS`를 `0.54`로 올려 바닐라보다 더 분명한 그림자 대비를 목표로 조정
  - `CONTACT_SHADOW_INTENSITY` 기본값을 `0.4`로 올려 가까운 오브젝트 접지감을 강화
  - wet floor/wall mask를 활용한 가벼운 normal 근사 diffuse shading을 추가해 지형 면 방향에 따른 입체감을 보강
  - shadow pass에서 alpha cutout을 처리하고 water/lava/glass 계열은 solid shadow caster에서 제외
- `shaders/lib/sky.glsl`, `shaders/gbuffers_clouds.fsh`, `shaders/gbuffers_water.fsh`
  - 하늘, 구름, 안개, 물 반사 색을 `lib/sky.glsl`의 공통 sky color 체계로 더 강하게 통합
  - `getSkyUnifiedColor()`, `getSkyCloudColor()`, `getSkyWaterTint()`를 추가해 낮/밤 전환과 수평선 근처 색 분리를 완화
  - 구름 pass의 개별 색 계산을 공통 sky 함수로 이동하고, 물 tint도 시간/날씨/수평선 기반 sky reflection에 맞춰 보정
- `shaders/lib/lighting.glsl`, `shaders/final.fsh`
  - 들고 있는 횃불 조명이 설치된 기본 횃불과 더 비슷한 체감 밝기를 갖도록 조정
  - `TORCH_LIGHT_INTENSITY` 기본값을 `0.85`에서 `1.0`으로 올리고, 손 횃불의 core/edge 밝기와 어두운 실내 보정을 강화
  - 낮 야외에서는 과하게 튀지 않도록 환경 보정은 유지하되 최소 밝기를 소폭 상향
- `shaders/lib/shadows.glsl`
  - PCSS penumbra radius clamp를 더 강하게 조정
  - `PCSS_LIGHT_SIZE`를 `28.0`에서 `20.0`으로 낮추고, radius 범위를 `0.85` - `2.0`으로 제한해 그림자 번짐을 줄임
- `shaders/lib/shadows.glsl`
  - PCSS 최종 shadow filter를 `PCSS_FILTER_SAMPLES = 8`로 명시
  - blocker search와 기본 Poisson PCF 샘플 수도 각각 `PCSS_BLOCKER_SAMPLES`, `SHADOW_PCF_SAMPLES`로 분리해 튜닝 지점을 정리
- `shaders/lib/shadows.glsl`
  - `SHADOW_MODE = 1` PCSS 경로에 8-sample blocker search를 추가
  - `findAverageBlockerDepth()`로 평균 blocker depth를 계산하고, receiver/blocker depth 차이에 따라 penumbra radius를 산출
  - blocker가 없을 때는 visibility `1.0`을 반환해 불필요한 그림자 번짐을 방지
  - 최종 필터링은 기존 8-sample Poisson PCF를 재사용해 성능 부담을 낮춤

- 하늘/안개/구름 색 체계를 `lib/sky.glsl` 중심으로 통합
  - `gbuffers_skybasic`이 `getSkyBaseColor(worldDir, ...)`로 기본 하늘색 출력
  - `gbuffers_clouds`가 `getSkyColor(worldDir, ...)` 기반으로 구름 RGB 보정
  - `gbuffers_skytextured`가 태양/달/별 텍스처 RGB를 `getSkyColor(worldDir, ...)` 기반으로 보정
  - 구름 고유 팔레트 비중을 낮추고, 수평선/밤/비 상황에서 `skyColor` 블렌딩 비중을 높여 하늘과 구름 경계 분리 완화
  - 구름 alpha 밀도를 주변 샘플로 추정해 두꺼운 영역은 살짝 어둡게, 가장자리는 sky color로 밝게 보정
  - 비/밤 수평선에서 `getSkyColor()`의 horizon contrast를 낮추고 desaturation을 적용해 sky/fog/cloud 색 평균화 강화
  - final 톤매핑/파스텔 처리 이후에도 sky/cloud/fog 색이 튀지 않도록 `getSkyColor()`에 공통 pre-grade desaturation/soften 보정 추가
  - `final.fsh`의 지형 fog 색을 `fogColor` uniform 대신 `getSkyFogColor(worldDir, ...)` 기반으로 변경
  - 지형 fog factor에 `skyHorizonMask(worldDir)` 기반 horizon fog bias를 약하게 섞어 먼 지형이 하늘 수평선 색으로 더 자연스럽게 들어가도록 조정
  - `final.fsh`에서 `depth >= 1.0` 하늘 픽셀에 적용하던 sky fog 덧칠 제거
- `colortex2` material mask 구조를 `R = wet floor`, `G = wall`, `B = lava`, `A = water`로 확장
- lava mask를 `colortex0.a`에서 `colortex2.b`로 이동
- water mask를 `colortex2.a`에 기록하도록 추가
- `colortex0Format = RGBA8`, `colortex1Format = RGBA16F`, `colortex2Format = RGBA8` 설정
- `composite.fsh`를 `DRAWBUFFERS:012`로 변경해 scene color, bloom buffer, material mask를 함께 전달
- 안개를 렌더 거리(`far`) 비율 기반으로 조정하고, 비 오는 날 안개 시작 지점을 앞당기도록 변경
- 최종 출력 직전 dithering 적용으로 하늘 그라데이션 banding 완화
- 기본 대비, 채도, 블룸 강도를 낮추고 파스텔 톤 보정 추가
- 태양광은 낮/일출/일몰에 따라 색과 강도가 변하도록 조정
- 달빛은 밤 가독성을 위해 차가운 청색광 중심으로 조정
- 횃불 색상은 `#F5853F` 기준으로 재정렬하고 손전등/횃불 느낌을 개선
- 시간대별 기본 옵션 `DAY_LIGHT_STRENGTH`, `NIGHT_LIGHT_STRENGTH`, `SUNSET_GLOW_STRENGTH` 추가
- 용암과 비 색상이 전체 화면을 과하게 물들이지 않도록 core/accent와 ambient tint를 분리
- 비 오는 날 wet reflection은 바닥/상면에 강하게, 벽면에는 약하게 적용되도록 변경
- 물 표면에 Fresnel/specular 하이라이트와 화면색 기반 rough reflection blur 적용
- 물 반사색을 `lib/sky.glsl`의 `getSkyColor()`와 연동해 하늘/fog/구름/물 반사 색상 분리 완화
- 물 반사 전용 `getSkyWaterReflectionColor()`를 추가해 sky color를 수평선 방향으로 가중 보정
- final 패스에서 water mask 픽셀에만 `applyWaterSSR`을 적용하고, hit 실패 시 기존 fake water reflection이 유지되도록 변경

### Fixed

- 일부 지형/오브젝트가 투명하게 빠져 보일 수 있던 문제 수정
- opaque terrain의 scene alpha가 material mask로 오염되던 구조 제거
- lava/emissive block mask를 별도 material mask 버퍼(`colortex2.b`)에서 관리하도록 수정
- 밤하늘 및 낮 수평선에서 final sky fog가 하늘을 다시 덧칠하며 층처럼 갈라지던 구조 완화
- 그림자 acne/깜빡임 완화를 위해 slope bias, distance bias, edge fade, distance fade, weather/night fade 적용

## Shader Options

Options are grouped under the `MOOD` screen in Iris.

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

## Current Buffer Layout

- `colortex0`: scene color
- `colortex1`: bloom buffer
- `colortex2.r`: wet floor mask
- `colortex2.g`: wall mask
- `colortex2.b`: lava mask
- `colortex2.a`: water mask
- `colortex3`: encoded world normal, alpha = valid normal mask

## Current Sky/Fog Layout

- `gbuffers_skybasic`: 기본 하늘색을 `lib/sky.glsl`의 `getSkyBaseColor()`로 출력
- `gbuffers_clouds`: 구름 색을 `lib/sky.glsl`의 `getSkyColor()` 기반으로 보정
- `gbuffers_skytextured`: 태양/달/별 텍스처를 `lib/sky.glsl`의 `getSkyColor()` 기반으로 tint
- `final.fsh`: 지형/오브젝트(`depth < 1.0`)에만 fog 적용
- `final.fsh`: 하늘 픽셀(`depth >= 1.0`)에는 별도 sky fog 덧칠 없음


## Current Shadow Implementation Status

- 현재 그림자 구현률 추정: 약 65-72%.
- 현재 상태: PCSS가 기본 활성화되었고, shadow/contact shadow 강도가 올라가 바닐라보다 더 분명한 그림자 대비를 목표로 조정된 상태입니다.
- 구현된 부분:
  - `shadowtex0`, `shadowModelView`, `shadowProjection` 기반 shadow map 샘플링.
  - `shadowMapResolution = 2048`, `shadowDistance = 96.0` 설정.
  - `SHADOW_MODE = 0` 선택 경로의 8-sample Poisson PCF.
  - `SHADOW_MODE = 1` 기본 경로의 8-sample blocker search + 8-sample filter PCSS.
  - `SHADOW_DARKNESS = 0.54` 기반 강화된 shadow tint.
  - `CONTACT_SHADOW_INTENSITY = 0.4` 기반 강화된 screen-space contact shadow.
  - wet floor/wall mask를 활용한 terrain form lighting 근사 diffuse shading.
  - shadow pass alpha cutout 처리 및 water/lava/glass 계열 solid shadow caster 제외.
  - 거리 fade, shadow map edge fade, 날씨 fade, 낮/밤 fade, sky color 기반 shadow tint.
  - 비 오는 날 wet surface 반응을 위한 shadow 기반 rain exposure 보조 함수.
- 현재 한계:
  - terrain form lighting은 `colortex3` normal buffer를 우선 사용하며, normal이 없는 픽셀에서는 wet floor/wall mask 기반 근사를 fallback으로 사용합니다.
  - screen-space contact shadow는 화면 밖/가려진 정보는 처리하지 못합니다.
  - `shadow.vsh` / `shadow.fsh`의 material rule은 1차 caster 제외 수준이며 foliage 세부 투과/색 그림자는 아직 없습니다.
  - cascade shadow map, translucent/colored shadow, material별 shadow tint, directional BRDF 조명 반응은 아직 없습니다.
- 다음 그림자 개선 우선순위:
  - normal buffer 기반 diffuse shading을 바탕으로 foliage/water/glass/emissive 세부 caster rule을 계속 개선.
  - foliage/water/glass/emissive 세부 caster rule 추가.
  - cascade shadow map 또는 distance split 기반 원거리 그림자 안정화.
  - translucent/colored shadow와 material별 shadow tint 추가.
## Water SSR Roadmap

- 물 마스크(`colortex2.a`)가 있는 픽셀에만 SSR 적용 완료
- final 패스에서 depth 기반 view-space position 복원값 재사용
- 화면 공간 water wave normal을 재계산해 반사 방향 생성
- `depthtex0`를 16 step 이하로 짧게 raymarch
- hit 지점의 `colortex0` 색을 반사색으로 샘플링
- 화면 가장자리, 거리, water mask 기반 fade 적용
- hit 실패 시 기존 fake water reflection 유지
- 추후 binary search, roughness blur, sky fallback 품질 개선

## Planned / Not Implemented

- 인게임 Iris 컴파일 로그 확인
- 낮, 밤, 동굴, 비, 네더, 엔드 환경별 색감 튜닝
- normal 기반 wet specular BRDF 추가
- 물 전용 SSR에 binary search, roughness blur, sky fallback 품질 개선
- 안개 색을 바이옴/차원/날씨에 따라 다르게 적용
- 동굴 내부 가독성을 위한 어두운 영역 보정 추가
- 옵션 설명과 추천 프리셋 정리
- 쉐이더팩 압축 구조 검증
