# 〈초록의 무덤 (Verdant Tomb)〉 빌드 가이드

Godot 4.6 프로젝트. 하나의 코드베이스로 Android·iOS 양쪽 export.
`export_presets.cfg` 에 Android/iOS 프리셋이 준비되어 있습니다.
번들 ID 기본값 `com.trimage.verdanttomb` (원하는 값으로 변경 가능). Apple Team ID 는 Xcode 서명에서 입력.

## 🍎 iOS 실기기 빠른 시작 (우선 테스트 경로)
1. Godot 4.6 에디터로 `project.godot` 열기 → `Editor > Manage Export Templates` 에서 4.6 템플릿 설치.
2. `Project > Export > iOS` 프리셋에서:
   - `application/bundle_identifier` 확인/변경 (`com.trimage.verdanttomb`).
   - `application/app_store_team_id` 는 비워둬도 됨(Xcode 에서 팀 선택).
3. `Export Project` → `build/ios/` 에 Xcode 프로젝트(`.xcodeproj`) 생성.
4. 생성된 `.xcodeproj` 를 Xcode 로 열기:
   - `Signing & Capabilities` 에서 본인 Apple ID 팀 선택(자동 서명).
   - iPhone 을 USB 로 연결 → 상단 타깃을 실기기로 선택 → ⌘R 빌드·실행.
   - 첫 설치 시 기기 `설정 > 일반 > VPN 및 기기 관리` 에서 개발자 앱 신뢰.
5. 세로 모드 고정, 터치 UI(좌 조이스틱 + 우 세로 버튼 스택)로 바로 플레이 가능.

## 공통
1. Godot 4.6 에디터로 `project.godot` 열기.
2. `Editor > Manage Export Templates` 에서 현재 버전(4.6) 템플릿 설치.

## Android (APK/AAB)
요구: OpenJDK 17, Android SDK(+ build-tools, platform-tools), (선택) Gradle 빌드.
1. `Editor > Editor Settings > Export > Android` 에서 Java SDK / Android SDK 경로 지정.
2. 디버그 키스토어 자동 생성 또는 릴리스 키스토어 등록.
3. `Project > Export > Android` 프리셋 선택:
   - `package/unique_name` 을 실제 패키지명으로 변경(예: `com.yourco.verdanttomb`).
   - AAB 가 필요하면 `gradle_build/use_gradle_build=true`, `export_format=1`.
4. `Export Project` → `build/android/verdant_tomb.apk` 생성.

## iOS (Xcode)
요구: macOS + Xcode, Apple 개발자 계정.
1. `Project > Export > iOS` 프리셋 선택:
   - `application/bundle_identifier` 와 `application/app_store_team_id` 입력.
2. `Export Project` → `build/ios/verdant_tomb.xcodeproj` 생성.
3. 생성된 `.xcodeproj` 를 Xcode 로 열어 서명(Team) 설정 후 실기/시뮬레이터 빌드·아카이브.

## 화면/입력
- 기본 세로(portrait) 모드 720×1280, 캔버스 스트레치(`canvas_items`/`expand`)로 해상도 대응.
- 터치 입력 기준 UI(좌측 가상 조이스틱 + 우측 액션/회피 버튼). 데스크톱은 마우스로 터치 에뮬.

## 에셋 교체(.glb)
- 모델은 `assets/` 에 두고, `data/*.json` 의 각 정의 `model` 필드에 `res://assets/...glb` 경로를 넣으면
  기본 박스 대신 해당 로우폴리 모델로 자동 교체됩니다(비면 박스 폴백). `LowpolyFactory` 가 처리.
- 사운드는 `assets/audio/` 에 넣고 `data/sounds.json` 의 경로와 맞추면 `AudioManager` 가 재생(없으면 무음).
