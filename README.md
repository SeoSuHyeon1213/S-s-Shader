# S-Shader

S-Shader는 Iris/NeOculus 환경을 목표로 제작 중인 Minecraft 셰이더팩입니다. 사실적인 렌더링을 완전히 재현하기보다는, 부드러운 색감, 안개, 하늘 색 통합, 젖은 표면, 횃불 조명, 그림자 대비를 통해 분위기 있는 화면을 만드는 것을 목표로 합니다.

현재 개발은 Codex와 Claude Code를 함께 사용해 빠르게 실험하고 있으며, 실제 게임 플레이 스크린샷을 기준으로 색감과 효과를 계속 조정하고 있습니다.

## 주요 기능

- 노출, 대비, 채도, 따뜻한 색 보정, ACES 톤 매핑, 파스텔 톤 기반 색 보정
- 별도 bloom buffer를 사용한 bloom 추출 및 blur
- `lib/sky.glsl` 기반의 하늘, 구름, 안개, 지형 fog, 물 반사 색 체계 통합
- 낮/밤 전환과 수평선 부근의 색 층 분리 완화
- 비 오는 날 젖은 바닥, 벽면 물 흐름, 웅덩이 반사, wet specular 표현
- 물 전용 `gbuffers_water`와 물 mask 기반 Fresnel/flow/rough reflection 표현
- 횃불을 들었을 때 설치된 횃불과 비슷한 따뜻한 주황빛 조명
- lava mask 기반 발광 보정
- shadow map 기반 PCF/PCSS 그림자, shadow tint, contact shadow
- `colortex3` normal buffer 기반 지형 diffuse/form shadow 보정
- hand/entity 전용 pass를 통한 들고 있는 아이템 반투명 문제 완화

## 주요 색상 팔레트

- Sun: `#F1FEC6`
- Moon: `#BFD8FF`
- Torch: `#F5853F`
- Lava: `#FF3A20`
- Rain accent: `#3423A6`

## Shader Options

옵션은 Iris/NeOculus 셰이더 옵션 화면에 직접 노출됩니다.

- `SHADOW_MODE`: `0` = Poisson PCF, `1` = PCSS
- `WATER_REFLECTION_MODE`: `0` = 안정적인 sky/Fresnel 물 반사, `1` = 약한 SSR 추가
- `ENABLE_CONTACT_SHADOWS`: 가까운 거리 screen-space contact shadow on/off
- `ENABLE_NORMAL_FORM_LIGHTING`: normal buffer 기반 지형 입체 조명 on/off
- `ENABLE_WET_GROUND_LAYER`: 비 오는 날 젖은 바닥 darkening/sheen layer on/off
- `ENABLE_WET_SCREEN_REFLECTIONS`: 젖은 바닥 screen-space reflection on/off
- `ENABLE_WET_SPECULAR`: normal buffer와 material response 기반 젖은 표면 BRDF 하이라이트 on/off
- `ENABLE_WATER_SURFACE`: 물 Fresnel/flow surface shading on/off
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

## Buffer Layout

- `colortex0`: scene color
- `colortex1`: bloom buffer
- `colortex2.r`: wet floor mask
- `colortex2.g`: wall mask
- `colortex2.b`: lava mask
- `colortex2.a`: water mask
- `colortex3.rgb`: encoded world normal
- `colortex3.a`: valid normal mask

## Sky / Fog Layout

- `gbuffers_skybasic`: 기본 하늘 색을 `lib/sky.glsl`의 공통 sky color로 출력
- `gbuffers_clouds`: 바닐라 구름 texture alpha를 유지하면서 RGB를 sky color 체계로 보정
- `gbuffers_skytextured`: 해, 달, 별 texture를 sky color 기반으로 tint
- `final.fsh`: 지형 fog를 `fogColor` uniform 대신 `getSkyFogColor()` 기반으로 적용
- `depth >= 1.0` 하늘 영역에는 별도 fog 덧칠을 최소화해 하늘 층 분리를 줄임

## Shadow Status

현재 그림자 구현은 실험 단계입니다.

구현된 부분:

- `shadowtex0`, `shadowModelView`, `shadowProjection` 기반 shadow map sampling
- `SHADOW_MODE = 0`: 8-sample Poisson PCF
- `SHADOW_MODE = 1`: 8-sample blocker search + 8-sample filter PCSS
- `shadowMapResolution = 2048`
- `shadowDistance = 96.0`
- `shadowIntervalSize = 8.0`
- shadow tint와 rain/weather fade
- screen-space contact shadow
- normal buffer 기반 terrain form lighting
- shadow pass의 기본 alpha cutout 및 water/lava caster 제외
- foliage/crop/glass material의 dithered partial caster rule
- material mask 기반 wet/water/lava shadow tint 및 강도 보정
- 플레이어 이동에 따라 변하지 않는 안정 우선 PCF/PCSS radius와 shadow strength
- `ENABLE_CONTACT_SHADOWS = 0` 기본값으로 screen-space 그림자 이동감 최소화
- texture-coordinate 기반 partial caster dither로 shadow reprojection crawling 완화
- terrain-only PCSS penumbra 기반 soft shadow 표현력 복구

남은 작업:

- torch 등 emissive block에 대한 더 정교한 caster rule
- 실제 cascade shadow map 기반 장거리 안정화
- 별도 colored shadow buffer 기반 translucent/colored shadow
- 재질별 shadow tint 세분화
- 더 정확한 directional BRDF 조명 반응

## Water Status

구현된 부분:

- `colortex2.a` water mask 기반 물 표면 효과
- sky/Fresnel/roughness/flow 기반 안정 물 반사
- 수평 물 전용 low-cost planar 스타일 mirrored screen fallback
- `WATER_REFLECTION_MODE = 1`에서 water SSR 추가
- 20-step SSR ray march와 6-step binary refinement
- 9-tap roughness blur 기반 SSR reflection filtering
- view-distance 기반 물 depth/absorption 근사
- 폭포/수직 물기둥의 flow/absorption 중심 표현

남은 작업:

- 별도 reflected scene texture 기반 진짜 planar reflection
- loader별 reflection/depth buffer 지원 여부 확인
- 더 정확한 물 깊이 계산과 underwater absorption
- SSR edge artifact 및 disocclusion 처리 고도화

## Crash / Stability Debug

NeOculus/Embeddium 환경에서 특정 후처리 조합이 GPU/드라이버 쪽 불안정을 만들 수 있어, 최근 기능은 옵션으로 분리했습니다.

크래시가 의심될 때 권장 테스트 순서:

1. `ENABLE_WET_SCREEN_REFLECTIONS = 0`
2. `ENABLE_WATER_SURFACE = 0`
3. `ENABLE_CONTACT_SHADOWS = 0`
4. `ENABLE_NORMAL_FORM_LIGHTING = 0`

## Status

아직 개발 중인 셰이더팩입니다. 핵심 후처리, 하늘/fog 통합, 젖은 표면, 물 표현, PCSS 그림자, contact shadow, normal buffer 기반 지형 조명은 구현되어 있지만 실제 게임 내 낮, 밤, 동굴, 비, 네더, 엔드 환경에서 추가 튜닝이 필요합니다.

## License

MIT License. 자세한 내용은 `LICENSE` 파일을 참고하세요.
