![platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20MacOS%20%7C%20Linux-brightgreen)
![last-commit](https://img.shields.io/github/last-commit/bingxizhe/JHenTai)
![star](https://img.shields.io/github/stars/bingxizhe/JHenTai)
[![issue](https://img.shields.io/badge/chat-issue-brightgreen)](https://github.com/bingxizhe/JHenTai/issues/new)

# JHenTai (Fork)

[English](README.md) | [简体中文](README_cn.md) | 한국어

이 저장소는 [JHenTai](https://github.com/jiangtian616/JHenTai)의 Fork로, Android, iOS, Windows, MacOS, Linux를 지원하는 E-Hentai 만화 애플리케이션입니다.

이 Fork는 원본 프로젝트에 여러 기능과 최적화를 추가합니다. 모든 변경사항은 비침투적으로 설계되었으며 상위 코드베이스와 호환됩니다.

## Fork 기능 및 최적화

### 1. 시작 성능 최적화

- **지연 갤러리 스캔**: 로컬 갤러리 스캔이 앱 시작을 차단하지 않습니다. 스캔 로직은 `doInitBean()` 대신 `doAfterBeanReady()`를 통해 UI 렌더링 완료 후 실행됩니다.
- **지연 데이터베이스 쿼리**: 대규모 데이터셋 쿼리(예: 이미지 레코드)가 UI 초기화 완료 후 실행되도록 지연되어, 초기 데이터베이스 쿼리 시간을 약 3.9초에서 82ms로 단축했습니다.
- **복원 경쟁 상태 수정**: `restoreTasks()`가 `isRestoring` 가드와 `try-finally`를 사용하여, 다운로드 페이지 진입 시 복원과 설정 페이지에서 수동 복원이 동시에 실행되는 경쟁 상태를 방지합니다.

### 2. 이전 버전 일괄 삭제

- **Union-Find 버전 그룹화**: 이름이 아닌 `oldVersionGalleryUrl` 필드를 사용한 버전 체인으로 그룹화하여, 동일한 이름의 갤러리 오판을 방지합니다.
- **듀얼 사이트 심층 스캔**: 갤러리 버전 스캔 시 원본 사이트(e-hentai.org/exhentai.org)를 최대 5회 재시도하고, 실패 시 반대 사이트로 전환하여 추가 5회 재시도하여 사이트 간 이동된 갤러리의 스캔 성공률을 높입니다.
- **스캔 결과 영속화**: 심층 스캔 결과(재시도 결과 포함)가 통합으로 저장되며, 기존 스캔 이력에 재시도 데이터가 자동 병합됩니다. 24시간 이상 경과한 결과는 자동 폐기됩니다.
- **전역 상태 업데이트**: 삭제 후 `updateGlobalGalleryStatus()`를 호출하여 모든 페이지의 갤러리 상태를 동기화합니다.
- **이전 버전 기본 선택**: 모든 이전 버전이 기본으로 선택되어, 사용자가 그룹을 수동으로 펼치지 않아도 바로 삭제할 수 있습니다.

### 3. 즐겨찾기 일괄 다운로드

- **원클릭 일괄 다운로드**: 특정 그룹의 모든 즐겨찾기를 한 번에 다운로드하며, 중단점 이어받기를 지원합니다.
- **증분 영속화**: 즐겨찾기 목록을 매 페이지가 아닌 5페이지마다 저장하여, 대규모 컬렉션의 O(n²) 직렬화 오버헤드를 감소시킵니다.
- **네트워크 계층 속도 제한**: 큐 작업 간 인위적 지연이 없습니다. 속도 제한은 다운로드 엔진(`EHExecutor`)이 실제 네트워크 요청 디스패치 시 `Rate(maximum, period)`를 통해 처리합니다.
- **재시도 메커니즘**: 실패한 다운로드 작업을 최대 5회 재시도하며, 재시도 간격은 설정 가능합니다.

### 4. WebP/GIF 애니메이션 재생 최적화

- **가시성 기반 애니메이션 제어**: 애니메이션 WebP/GIF 이미지가 뷰포트에 보일 때만 재생됩니다. 화면 밖 이미지는 첫 프레임만 렌더링하여 디코드 비용과 메모리 압력을 줄입니다.
- **애니메이션 필드 간소화**: 3개 애니메이션 제어 필드(`disableGifAnimation`, `playAnimation`, `forcePlay`)를 2개(`disableGifAnimation`, `playAnimation`)로 통합하고, `VisibilityDetector`에만 가시성 추적을 위임합니다.
- **오프스크린 이미지 단일 프레임 디코딩**: 오프스크린 로컬 이미지는 `_SingleFrameExtendedFileImageProvider`를, 오프스크린 온라인 이미지는 `_SingleFrameExtendedNetworkImageProvider`를 사용하여 첫 프레임만 디코딩합니다.

### 5. 안정성 수정

- **setState() after dispose() 수정**: `VisibilityDetector` 콜백에 `if (!mounted) return;` 가드를 추가하여, widget이 폐기된 후 `setState()`가 호출되는 것을 방지합니다.
- **디버그 코드 정리**: `debugPrint` 호출을 프로젝트 통일 `log.trace` 시스템으로 교체했습니다.

## 다운로드 및 설치

안정 버전은 [원본 프로젝트 Releases](https://github.com/jiangtian616/JHenTai/releases)를 참조하세요.

소스에서 빌드:

1. Android 서명을 직접 관리해야 합니다: https://docs.flutter.dev/deployment/android#signing-the-app
2. IDEA 또는 VSCode에서 직접 실행하세요.

## 주요 Dart 종속성

- [get](https://pub.flutter-io.cn/packages/get): 종속성 관리, 상태 관리, l18n, NoSQL
- [dio](https://pub.flutter-io.cn/packages?q=dio): 네트워크
- [extendedImage](https://pub.flutter-io.cn/packages/extended_image): 이미지
- [drift](https://pub.flutter-io.cn/packages/drift): 데이터베이스

## 참조 및 감사

- [JHenTai](https://github.com/jiangtian616/JHenTai) - 원본 프로젝트
- [FEhviewer](https://github.com/honjow/FEhViewer) - 레이아웃 스타일 참조
- [EHPanda](https://github.com/tatsuz0u/EhPanda) - 레이아웃 스타일 참조
- [EhTagTranslation](https://github.com/EhTagTranslation/Database) - 태그 번역
