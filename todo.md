# todo

## Xcode 프로젝트화
- [x] 소스를 `SoundLab/` 폴더로 정리
- [x] XcodeGen `project.yml` 작성 (iOS 17, 마이크 권한 Info.plist)
- [x] `SoundLab.xcodeproj` 생성
- [x] 시뮬레이터 빌드 & 컴파일 에러 수정
- [x] 시뮬레이터 실행 확인

## 신스 랩 개편 — 목표 소리 시각화 + 직관적 UX
- [x] 엔진: 목표/내 소리 보이스 분리, 탭·홀드 통합 패드, A/B 연속 재생
- [x] 슬라이더를 지각 스케일(로그)로 — 피치·컷오프·시간
- [x] 오프라인 렌더 → 파형 윤곽 + 스펙트로그램 (`Audio/SoundAnalysis.swift`)
- [x] 소리 그림 카드: 목표 vs 내 소리 레인, 재생 헤드, 특징 비교표
- [x] 모듈 카드(소스→필터→앰프) + 드래그 가능한 피치/필터/ADSR 그래프
- [x] 집중 모드 진행도(n/12)
- [x] 빌드 (Xcode 27)
- [ ] 시뮬레이터에서 화면 확인 및 조정

## 앱 아이콘 & 공개
- [x] 앱 아이콘 생성 (`scripts/make_icon.py` → `Assets.xcassets/AppIcon`)
- [x] 에셋 카탈로그 프로젝트 반영 & 빌드 확인
- [x] 레포 퍼블릭 확인 (이미 PUBLIC)
- [x] 커밋 & 푸시
