# Changelog

All notable changes to this shader pack will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## Goals / 목표사항

- Iris 기반 마인크래프트 분위기형 쉐이더팩 제작
- 색보정, 비네트, 블룸, 안개를 중심으로 부드러운 파스텔 톤 구현
- 태양, 달, 횃불, 용암, 비 색상 팔레트를 중심으로 장면 분위기 통일
- 비 오는 날 wet floor/wall mask 기반 젖은 표면 하이라이트 구현
- 용암과 물은 block/material mask로 분리해 전용 발광/하이라이트 적용
- 인게임 Iris 컴파일 검증 및 낮, 밤, 동굴, 비, 네더, 엔드 환경별 튜닝

## [Unreleased]

### Added

- `README.md`
  - 프로젝트 설명, 기능 목록, 색상 팔레트, 옵션 목록 추가
  - 영어 원문 아래에 한국어 번역 추가
- `LICENSE`
  - MIT License 초안 추가
- `shaders/final.vsh`, `shaders/final.fsh`
  - 최종 출력 패스 추가
  - 블룸 합성, 그림자, 분위기 조명, wet highlight, 안개, 색보정, 비네트, dithering 적용
- `shaders/composite.vsh`, `shaders/composite.fsh`
  - 블룸 추출/블러 패스 추가
  - `colortex2` material mask pass-through 추가
- `shaders/gbuffers_terrain.vsh`, `shaders/gbuffers_terrain.fsh`
  - terrain 렌더링 패스 추가
  - texture, vertex color, lightmap 기반 기본 terrain 셰이딩
  - world normal 기반 wet floor/wall mask 기록
  - lava material mask 기록
- `shaders/gbuffers_water.vsh`, `shaders/gbuffers_water.fsh`
  - 물 전용 gbuffers 패스 추가
  - water mask 기록 및 물 전용 푸른 틴트, wave normal, Fresnel, ripple, sky/specular 하이라이트 적용
- `shaders/shadow.vsh`, `shaders/shadow.fsh`
  - shadow map 생성을 위한 기본 그림자 패스 추가
- `shaders/block.properties`
  - `minecraft:lava`에 커스텀 block ID `block.11000` 할당
  - `minecraft:water`에 커스텀 block ID `block.11001` 할당
- `shaders/lib/color.glsl`
  - 노출, 대비, 채도, 색온도, ACES 톤매핑, 파스텔 톤, dithering 유틸리티 추가
- `shaders/lib/fog.glsl`
  - 깊이 선형화, 렌더 거리 기반 안개, 주변 밝기 기반 안개색 보정 추가
- `shaders/lib/lighting.glsl`
  - 태양, 달, 횃불, 용암, 비 색상 팔레트 기반 분위기 조명 추가
  - 손에 든 횃불 조명 거리 감쇠, flicker, surface protection 추가
  - 용암 material mask 기반 발광 보정 추가
- `shaders/lib/wet.glsl`
  - 비 오는 날 global wet highlight 추가
  - terrain wet/wall mask 기반 fake wet reflection 추가
- `shaders/lib/ssr.glsl`
  - 물 마스크(`colortex2.a`)에만 제한된 저비용 screen-space raymarching SSR 기본 경로 추가
  - 16 step 이하의 짧은 raymarch, edge fade, distance fade, Fresnel 기반 합성 적용
- `shaders/lib/shadows.glsl`
  - shadow map 샘플링, 3x3 PCF, 거리 fade, 파스텔 그림자 tint 추가

### Changed

- `colortex2` material mask 구조를 `R = wet floor`, `G = wall`, `B = lava`, `A = water`로 확장
- lava mask를 `colortex0.a`에서 `colortex2.b`로 이동
- water mask를 `colortex2.a`에 기록하도록 추가
- `colortex0Format = RGBA8`, `colortex1Format = RGBA16F`, `colortex2Format = RGBA8` 설정
- `composite.fsh`를 `DRAWBUFFERS:012`로 변경해 scene color, bloom buffer, material mask를 함께 전달
- 안개를 렌더 거리(`far`) 비율 기반으로 조정하고, 비 오는 날 안개 시작 지점을 앞당기도록 변경
- 하늘/먼 평면 픽셀에도 수평선 기준 약한 sky horizon fog 적용
- 최종 출력 직전 dithering 적용으로 하늘 그라데이션 banding 완화
- 기본 대비, 채도, 블룸 강도를 낮추고 파스텔 톤 보정 추가
- 태양광은 낮/일출/일몰에 따라 색과 강도가 변하도록 조정
- 달빛은 밤 가독성을 위해 차가운 청색광 중심으로 조정
- 횃불 색상은 `#F5853F` 기준으로 재정렬하고 손전등/횃불 느낌을 개선
- 비 오는 날 wet reflection은 바닥/상면에 강하게, 벽면에는 약하게 적용되도록 변경
- 물 표면에 wave normal 기반 Fresnel/specular 하이라이트와 화면색 기반 rough reflection blur 적용
- final 패스에서 water mask 픽셀에만 `applyWaterSSR`을 적용하고, hit 실패 시 기존 fake water reflection이 유지되도록 변경

### Fixed

- 일부 지형/오브젝트가 투명하게 빠져 보일 수 있던 문제 수정
- opaque terrain의 scene alpha가 material mask로 오염되던 구조 제거
- lava/emissive block mask를 별도 material mask 버퍼(`colortex2.b`)에서 관리하도록 수정

## Shader Options

Options are grouped under the `MOOD` screen in Iris.

- `EXPOSURE`
- `CONTRAST`
- `SATURATION`
- `LIGHTING_STRENGTH`
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

## Planned / Not Implemented

- 인게임 Iris 컴파일 로그 확인
- 낮, 밤, 동굴, 비, 네더, 엔드 환경별 색감 튜닝
- normal 기반 wet specular BRDF 추가
- 물 전용 SSR에 binary search, roughness blur, sky fallback 품질 개선
- 안개 색을 바이옴/시간/날씨에 따라 다르게 적용
- 동굴 내부 가독성을 위한 어두운 영역 보정 추가
- 옵션 설명과 추천 프리셋 정리
- 쉐이더팩 압축 구조 검증

## Water SSR Roadmap

- 물 마스크(`colortex2.a`)가 있는 픽셀에만 SSR 적용 완료
- final 패스에서 depth 기반 view-space position 복원값 재사용
- 화면 공간 water wave normal을 재계산해 반사 방향 생성
- `depthtex0`를 16 step 이하로 짧게 raymarch
- hit 지점의 `colortex0` 색을 반사색으로 샘플링
- 화면 가장자리, 거리, water mask 기반 fade 적용
- hit 실패 시 기존 fake water reflection 유지
- 추후 binary search, roughness blur, sky fallback 품질 개선
