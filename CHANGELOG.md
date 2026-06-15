# Changelog

All notable changes to this shader pack will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

마인크래프트 iris 기반 쉐이더 제작

색보정, 비네트, 블룸, 안개 중심의 분위기형 쉐이더를 목표로 제작 중

예상 파일 구조
├─ README.md
├─ LICENSE
├─ CHANGELOG.md
└─ shaders/
   ├─ final.vsh
   ├─ final.fsh
   ├─ composite.vsh
   ├─ composite.fsh
   ├─ shadow.vsh
   ├─ shadow.fsh
   ├─ lib/
   │  ├─ color.glsl
   │  ├─ fog.glsl
   │  ├─ lighting.glsl
   │  ├─ wet.glsl
   │  └─ shadows.glsl
   └─ shaders.properties

현재 셰이더에 추천하는 적용 순서
그림자부터
shadow.vsh/fsh 추가
shadow map 기반 태양 그림자
PCF 3x3 또는 5x5
성능/효과 대비 가장 체감 큼

간단한 SSR
물/얼음/젖은 표면부터 제한 적용
전체 블록에 반사 적용하면 마인크래프트 질감이 과하게 번쩍일 수 있음

물 전용 반사
gbuffers_water.fsh 추가
Fresnel, normal wave, sky reflection
유명 셰이더 느낌을 가장 빠르게 낼 수 있음

고급 효과
contact shadow
SSAO
rough reflection blur
colored shadow
SSGI

### Added
- `shaders/final.vsh`, `shaders/final.fsh`: 최종 출력 패스
  - 블룸(`colortex1`) 합성
  - 렌더 거리(`far`) 대비 비율로 시작/감쇠하는 깊이 기반 안개, 주변 밝기에 맞춘 안개 색 보정, 하늘 수평선 보정
  - 색보정 (노출, 색온도 틴트, 대비, 채도, ACES 톤맵)
  - 비네트
- `shaders/composite.vsh`, `shaders/composite.fsh`: 블룸 추출/블러 패스
  - 밝기 임계값 기반 브라이트 패스 추출
  - 5x5 가중치 블러
  - `colortex0`(씬 컬러 패스스루), `colortex1`(블룸 버퍼)에 동시 출력 (`DRAWBUFFERS:01`)
- `shaders/lib/color.glsl`: 색보정 및 비네트 유틸리티 함수
- `shaders/lib/fog.glsl`: 깊이 선형화 및 안개 계산 함수
- `shaders/lib/lighting.glsl`: 화면 색 기반 분위기 조명 보정 함수
- `shaders/lib/wet.glsl`: 비 오는 날 fake wet reflection 유틸리티 함수
- `shaders/shadow.vsh`, `shaders/shadow.fsh`: shadow map 생성을 위한 기본 그림자 패스
- `shaders/lib/shadows.glsl`: shadow map 샘플링, 3x3 PCF, 거리 fade, 그림자 색 보정 유틸리티 함수
- `shaders/shaders.properties`
  - `colortex1Format = RGBA16F` (블룸 버퍼 정밀도 향상)
  - 셰이더 옵션 화면 "MOOD" 카테고리 추가: 노출(`EXPOSURE`), 블룸 강도(`BLOOM_INTENSITY`), 안개 감쇠 강도(`FOG_DENSITY`), 비네트 크기(`VIGNETTE_OUTER`) 슬라이더
  - 추가 튜닝 옵션 연결: 대비(`CONTRAST`), 채도(`SATURATION`), 블룸 임계값(`BLOOM_THRESHOLD`), 안개 시작 지점(`FOG_START`) 슬라이더
  - 조명 강도(`LIGHTING_STRENGTH`) 슬라이더 추가
  - 비 오는 날 반사 강도(`RAIN_REFLECTION_INTENSITY`) 슬라이더 추가
- `shaders/block.properties`
  - `minecraft:lava`에 커스텀 block ID `block.11000` 할당 (용암 블록 식별용)
- `shaders/gbuffers_terrain.vsh`, `shaders/gbuffers_terrain.fsh`: terrain 렌더링 패스
  - texture * vertex color * lightmap 기반 기본 terrain 셰이딩
  - `mc_Entity.x`가 `block.properties`의 용암 ID와 일치하면 `colortex0` 알파 채널에 lava mask(`1.0`) 기록
  - world normal 기반으로 위를 향한 비-용암 지형 표면을 `colortex2.r`에 wet floor mask로 기록
  - world normal 기반으로 수직 지형 표면을 `colortex2.g`에 wall mask로 기록


### Changed
- `shaders/shadow.vsh`, `shaders/shadow.fsh`, `shaders/lib/shadows.glsl`
  - shadow map 생성을 위한 기본 shadow 패스 추가
  - `shadowtex0`, `shadowModelView`, `shadowProjection` 기반의 3x3 PCF 그림자 샘플링 추가
  - 화면 depth에서 view/world position을 복원해 final 패스에서 태양/달 그림자 적용
  - `SHADOW_DARKNESS`, `SHADOW_FADE_START`, `SHADOW_BIAS`, `SHADOW_TEXEL_SIZE` 튜닝값 추가
- `shaders/shaders.properties`
  - `shadowMapResolution = 2048`, `shadowDistance = 96.0` 설정 추가
- `shaders/final.fsh`
  - 하늘/먼 평면 픽셀을 안개에서 완전히 제외하던 처리를 수정해 수평선 근처에 약한 sky horizon fog 적용
  - `FOG_DENSITY` 기본값을 `6.0`에서 `3.0`으로 낮춰 원거리 안개 경계를 부드럽게 조정
  - `FOG_AMBIENT_PULL` 옵션을 추가해 주변 밝기에 따른 안개색 보정을 약하게만 반영
  - 최종 출력 직전에 dithering 적용으로 하늘 그라데이션 banding 완화
- `shaders/lib/fog.glsl`
  - `getAmbientFogColor`가 장면 밝기에 과하게 끌려가지 않도록 `ambientPull` 인자 추가
- `shaders/lib/color.glsl`
  - `hash12`, `applyDither` 유틸리티 추가
- `shaders/final.fsh`
  - `heldBlockLightValue2`, `gbufferProjectionInverse` uniform 추가
  - depth와 projection inverse로 현재 픽셀의 view-space 위치를 복원해 손에 든 광원 계산에 전달
- `shaders/lib/lighting.glsl`
  - `heldBlockLightValue`와 `heldBlockLightValue2` 중 더 강한 값을 사용해 `handLightStrength` 계산
  - 카메라/플레이어 위치를 view-space 광원 원점으로 보고 현재 픽셀 위치와의 거리 기반 감쇠 적용
  - 따뜻한 주황색 additive 발광을 추가하고, 실내/동굴처럼 어두운 장면에서는 강하게, 낮 야외처럼 밝은 장면에서는 약하게 보정
  - `HELD_LIGHT_RANGE_BOOST`, `HELD_LIGHT_BRIGHTNESS`, `HELD_LIGHT_AMBIENT`, `HELD_LIGHT_DAY_OUTDOOR_MIN` 튜닝값 추가
  - 눈/나뭇잎 같은 밝은 표면에서 횃불 발광이 포화되지 않도록 손 광원 마스크를 `0.0~1.0`으로 제한하고 기본 밝기와 범위를 하향 조정
  - 횃불 색상을 부드러운 파스텔 주황으로 낮추고 손 광원 additive 밝기와 틴트 배율 추가 하향
  - 손에 든 횃불 빛의 색상, 범위, 세기를 설치된 횃불 라이트맵과 더 가깝게 맞추도록 범위 boost와 additive 밝기 추가 하향
  - 횃불 색상을 목표 팔레트 `#F5853F` 기준으로 재정렬
  - 손 위치를 기준으로 한 view-space 오프셋, 전방 중심 감쇠, 부드러운 외곽광, 약한 flicker를 추가해 손전등/횃불 느낌 개선
  - 밝은 표면에서 주황빛이 과포화되지 않도록 표면 밝기 기반 보호값 적용
  - `TORCH_LIGHT_INTENSITY` 옵션을 추가해 손에 든 횃불 조명 강도 조절
- `shaders/lib/wet.glsl`, `shaders/final.fsh`, `shaders/shaders.properties`
  - `applyGlobalWetHighlight` 추가
  - `applyFakeWetReflection` 추가
  - `final.fsh`에서 `rainStrength` 기반 전체 wet highlight를 먼저 적용한 뒤, 표면 기반 fake reflection을 추가로 합성
  - `gbuffers_terrain`이 기록한 `colortex2.rg` normal mask를 사용해 바닥/상면은 강하게, 벽면은 약하게 반사가 들어가도록 조정
  - `rainStrength` 기반으로 비 오는 날 지형 픽셀에 차가운 하이라이트와 약한 streak 반사를 더하는 fake wet reflection 적용
  - `RAIN_REFLECTION_INTENSITY` 옵션 추가
- `shaders/composite.fsh`
  - `DRAWBUFFERS:012`로 변경해 `colortex2` wet mask를 final 패스까지 pass-through
- `shaders/shaders.properties`
  - `colortex2Format = RGBA8` 추가, red channel은 wet floor mask, green channel은 wall mask 용도로 사용
- `shaders/final.fsh`, `shaders/lib/color.glsl`
  - 기본 대비와 채도를 낮추고 블룸 강도를 줄여 전체 색감을 파스텔 톤으로 조정
  - `applyPastelTone` 유틸리티를 추가해 톤매핑 이후 밝은 영역을 크림색 기반으로 부드럽게 보정
  - 파스텔 톤을 유지하면서 전체 채도를 기존 `0.72`에서 30% 증가한 `0.936`으로 조정
- `shaders/lib/lighting.glsl`
  - `SUN_HORIZON_COLOR`(`#FF8E48`) 추가, `getSunHorizonFactor`로 일출/일몰 전환 구간(낮/밤 전환 중간)을 감지해 태양광 색상을 `SUN_LIGHT_COLOR` → `SUN_HORIZON_COLOR`로 보간하는 `getSunColor` 추가
  - `getSunIntensity`를 추가해 정오에 최대 강도, 일출/일몰 전환 구간에서는 `SUN_HORIZON_GLOW`만큼 하이라이트에 추가 글로우를 부여
  - `skyTint`/`highlightTint`가 정적 `SUN_LIGHT_COLOR` 대신 시간대 기반 `getSunColor`/`getSunIntensity` 결과를 사용하도록 변경
  - `MOON_LIGHT_COLOR`를 `#DDFFF7`에서 더 차가운 청색광 `#BFD8FF`로 조정
  - `NIGHT_READABILITY_LIFT`를 추가해 밤에는 어두운 영역에 옅은 달빛 색을 더해 가독성 보강
- `shaders/lib/lighting.glsl`, `shaders/final.fsh`, `shaders/shaders.properties`
  - 화면 색상 기반 추정이었던 `getLavaMask` 제거
  - `applyMoodLighting`에 `lavaMask` 파라미터 추가, `gbuffers_terrain`이 기록한 `colortex0.a` 기반 마스크로 용암 블록 발광 보정 적용
  - `final.fsh`에서 `colortex0`의 알파 채널을 읽어 `lavaMask`로 전달
  - `colortex0Format = RGBA8` 명시 (알파 채널을 lava mask 용도로 사용함을 표기)

### Implementation Checklist
- Iris 셰이더 기본 구조 구성
  - `shaders/final.vsh`
  - `shaders/final.fsh`
  - `shaders/composite.vsh`
  - `shaders/composite.fsh`
  - `shaders/shadow.vsh`
  - `shaders/shadow.fsh`
  - `shaders/lib/color.glsl`
  - `shaders/lib/fog.glsl`
  - `shaders/lib/lighting.glsl`
  - `shaders/lib/wet.glsl`
  - `shaders/lib/shadows.glsl`
  - `shaders/shaders.properties`
- 기본 그림자 패스 구현
  - `shadow.vsh`, `shadow.fsh` 추가
  - `shaders.properties`에서 `shadowMapResolution = 2048`, `shadowDistance = 96.0` 설정
  - `final.fsh`에서 `gbufferProjectionInverse`, `gbufferModelViewInverse`로 화면 depth 기반 view/world position 복원
  - `shadowtex0`, `shadowModelView`, `shadowProjection` 기반 shadow space 변환
  - `shaders/lib/shadows.glsl`에서 3x3 PCF 그림자 샘플링, 거리 fade, 파스텔 그림자 tint 적용
- 블룸 패스 구현 완료
  - `composite.fsh`에서 밝기 임계값 기반 브라이트 패스 추출
  - 5x5 Gaussian 가중치 블러 적용
  - `DRAWBUFFERS:01`을 사용해 `colortex0`에는 씬 컬러 패스스루, `colortex1`에는 블룸 버퍼 출력
  - `shaders.properties`에서 `colortex1Format = RGBA16F` 설정
- 최종 합성 패스 구현
  - `final.fsh`에서 원본 컬러와 `colortex1` 블룸 합성
  - `BLOOM_INTENSITY` 옵션으로 블룸 강도 조절
  - `BLOOM_THRESHOLD` 옵션으로 블룸이 시작되는 밝기 조절
- 분위기형 색보정 구현
  - `EXPOSURE` 기반 노출 조정
  - 색온도 틴트
  - `CONTRAST` 기반 대비 조정
  - `SATURATION` 기반 채도 조정
  - ACES 톤매핑
  - 관련 유틸리티 함수는 `shaders/lib/color.glsl`에 분리
- 분위기형 조명 보정 구현
  - `shaders/lib/lighting.glsl` 추가
  - 태양광 색상 기준: 따뜻한 백색광 `#F1FEC6`
  - 달빛 색상 기준: 차가운 청색광 `#DDFFF7`
  - 횃불 색상 기준: 주황색 국소광 `#F5853F`
  - 용암 색상 기준: 붉고 강한 발광 `#FF3A20`
  - 비 오는 날 색상 기준: 우울한 보라빛 톤 `#3423A6`
  - `worldTime`을 기반으로 낮/밤 조명 색을 전환
  - `heldBlockLightValue`를 기반으로 손에 든 광원의 중심부 국소광 보정
  - `depthtex0` 기반 거리에 `getHeldLightRangeFalloff`를 적용해, 광원 레벨만큼의 실제 블록 거리까지만 빛이 도달하도록 처리
  - `frameTimeCounter` 기반의 약한 flicker와 손 위치 오프셋을 적용해 실제 횃불/손전등 느낌 보정
  - `TORCH_LIGHT_INTENSITY` 옵션으로 손에 든 횃불 조명 강도 조절
  - `gbuffers_terrain`이 기록한 lava mask(`colortex0.a`)를 기반으로 용암 블록에 용암 계열 발광 보정 적용
  - `rainStrength`를 반영해 비 오는 환경에서는 전체 대비를 낮추고 차가운 톤을 추가
  - `LIGHTING_STRENGTH` 옵션으로 조명 보정 강도 조절
- 비 오는 날 fake wet reflection 구현
  - `shaders/lib/wet.glsl` 추가
  - `final.fsh`에서 `rainStrength` 기반 전체 wet highlight를 먼저 적용
  - `gbuffers_terrain`에서 world normal 기반으로 바닥/벽을 구분해 `colortex2.rg`에 기록
  - `composite.fsh`에서 `colortex2` wet mask를 final 패스까지 pass-through
  - `rainStrength` 기반으로 젖은 표면 반사 강도 조절
  - 화면 색상 밝기, depth, terrain wet/wall mask를 이용해 하늘/용암을 제외하고 바닥은 강하게, 벽은 약하게 반사 적용
  - `#3423A6` 톤을 중심으로 차가운 하이라이트와 약한 streak 반사 추가
  - `RAIN_REFLECTION_INTENSITY` 옵션으로 반사 강도 조절
- 용암 블록 식별 구현
  - `shaders/block.properties`에서 `minecraft:lava`에 `block.11000` 할당
  - `shaders/gbuffers_terrain.vsh`, `shaders/gbuffers_terrain.fsh` 추가: 기본 terrain 셰이딩(texture * vertex color * lightmap) + `mc_Entity.x` 기반 lava mask를 `colortex0.a`에 기록
  - `shaders/lib/lighting.glsl`의 `applyMoodLighting`이 `lavaMask` 파라미터를 받아 용암 블록 전용 발광 보정 적용
- 비네트 구현
  - 화면 중심 기준 거리로 가장자리 어둡게 처리
  - `VIGNETTE_OUTER` 옵션으로 비네트 크기 조절
  - 필요 시 비네트 강도 옵션 추가 검토
- 깊이 기반 안개 구현
  - `depthtex0` 기반 깊이 선형화
  - 지수 제곱 감쇠 방식 안개 적용
  - 하늘 및 먼 평면 픽셀에 수평선 기준 약한 안개 보정 적용
  - `FOG_START` 옵션으로 안개 시작 지점을 렌더 거리(`far`) 대비 비율로 조절
  - `FOG_DENSITY` 옵션으로 렌더 거리 끝부분의 안개 감쇠 강도 조절
  - `RAIN_FOG_PULL`로 비 오는 환경에서 안개 시작 지점을 앞당김
  - `FOG_AMBIENT_PULL`로 주변 화면 밝기에 따른 안개색 보정 강도 제한
  - `getAmbientFogColor`로 안개 색을 주변 화면 밝기에 맞춰 보정하되, 과한 수평 밴딩을 줄이도록 완화
  - 관련 계산 함수는 `shaders/lib/fog.glsl`에 분리
- 추후 확장 검토
  - 시간대별 햇빛 색, 횃불 색감, 그림자 톤 보정 등을 `shaders/lib/lighting.glsl`에 추가 확장

### Priority
1. `composite` 패스에서 블룸 버퍼 생성 완료
2. `final` 패스에서 안개, 색보정, 블룸, 비네트 합성
3. `shaders.properties`에서 사용자 옵션 연결 완료
4. 실제 게임 내에서 낮, 밤, 실내, 안개 낀 환경 기준으로 색감 튜닝

### Planned / Not Implemented
- 인게임 Iris 컴파일 검증
  - 현재 소스 기준 문법과 연결 구조는 정리되어 있으나, 실제 Minecraft/Iris 환경에서 컴파일 로그 확인 필요
  - 낮, 밤, 비, 동굴, 네더, 엔드 환경별 렌더링 확인 필요
- 광원별 조명 고도화
  - 비 오는 날 `#3423A6`: normal 기반 바닥/벽 구분 fake wet reflection은 구현했으나, specular BRDF와 SSR은 미구현
- 추가 옵션화 후보
  - `BLOOM_KNEE`: 블룸 임계값 주변의 부드러움 조절
  - `BLOOM_SPREAD`: 블룸 번짐 범위 조절
  - `VIGNETTE_MIN`: 화면 가장자리 최소 밝기 조절
  - `COLOR_TINT`: 전체 색온도 직접 조절
  - `FOG_START`, `FOG_DENSITY`의 환경별 프리셋 분리
- 품질 개선 목표
  - 블룸 다중 패스 또는 다운샘플 기반 블러로 성능과 품질 개선
  - 안개 색을 바이옴/시간/날씨에 따라 다르게 적용
  - 동굴 내부 가독성을 위한 어두운 영역 보정 추가
  - normal/wet mask 또는 SSR 기반으로 수면/비 오는 날 하이라이트를 더 자연스럽게 보이도록 반사 계열 후처리 개선
- 배포 준비
  - `README.md` 작성
  - `LICENSE` 추가
  - 옵션 설명과 추천 프리셋 정리
  - 쉐이더팩 압축 구조 검증
