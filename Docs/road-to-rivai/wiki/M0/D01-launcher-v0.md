---
title: D01 — Launcher v0
type: task
status: active
---

# D01. Launcher v0

## 목적

테스터가 zip을 직접 다루지 않고 런처에서 최신 빌드를 다운로드·업데이트·실행할 수 있게 한다. 이 Task가 완료되면 [[M0]]의 M0.2 Launcher v0 세부 마일스톤과 런처 관련 완료 체크리스트를 만족한다.

## 학습 목표

이 Task를 마치면 다음을 본인 말로 설명할 수 있어야 한다.

- 게임 런처가 가지는 4가지 핵심 책임(버전 비교 / 다운로드 / 무결성 검증 / 실행)과 각각이 왜 분리되어야 하는가
- 크로스 플랫폼 데스크톱 앱의 주요 선택지(Tauri / Electron / Avalonia) 비교와 트레이드오프
- 자동 업데이트의 두 패턴 (in-place vs side-by-side 설치)
- 로컬 install state를 어디에 두고 어떻게 manifest와 동기화할 것인가
- 사용자가 받는 "런처 자체"의 무결성·신뢰성을 어떻게 확보하는가 (코드 사인의 의미)

## 배경 — 런처가 풀어주는 문제

[[C01-manual-distribution|C01]]에서 검증한 수동 배포 사이클은 다음 문제를 안고 있다.

1. 테스터가 매번 홈페이지 → zip 다운로드 → 압축 해제 → 실행을 반복해야 한다.
2. sha256 검증은 사실상 안 한다 (테스터에게 명령어 부담을 줄 수 없다).
3. 새 빌드가 나왔는지 테스터가 능동적으로 확인해야 한다.
4. 게임 실행 시 서버 주소·인자를 수동으로 넣어야 한다.

런처는 이 네 가지를 자동화한다. 사용자에게 보이는 건 "Play" 버튼 하나지만, 그 뒤에서 manifest fetch → 버전 비교 → 다운로드 → sha256 검증 → 압축 해제 → 자식 프로세스 실행이 일어난다.

## 핵심 개념

### 1) 런처의 4가지 책임

| 책임 | 입력 | 출력 |
|---|---|---|
| 버전 비교 | manifest(latest) + 로컬 install state | "최신/업데이트 필요/미설치" |
| 다운로드 | manifest의 downloadUrl, sizeBytes | 로컬 zip 파일 + 진행률 |
| 무결성 검증 | 다운로드된 zip, manifest의 sha256 | OK 또는 실패 (실패 시 zip 폐기) |
| 실행 | 설치 폴더 + manifest의 executable + server 정보 | 자식 프로세스 실행 |

각 책임은 독립적으로 실패할 수 있고, 각각의 오류 메시지가 사용자에게 의미 있어야 한다. "왜 안 되는지" 사용자가 알아야 피드백을 줄 수 있다.

### 2) 자동 업데이트의 두 패턴

| 패턴 | 동작 | 장점 | 약점 |
|---|---|---|---|
| In-place | 같은 폴더에 덮어쓰기 | 디스크 최소 | 다운로드 중 실패 시 깨진 설치 상태. 롤백 어려움 |
| **Side-by-side** | 새 버전을 별도 폴더에 설치 후 포인터만 교체 | 원자적 전환, 즉시 롤백 가능 | 디스크 2배 필요 (한시적) |

**결정: side-by-side.** 새 버전이 완전히 설치·검증된 다음에 "현재 버전 포인터"를 교체한다. 이전 버전은 1~2개 정도 유지해 빠른 롤백을 가능하게 한다.

```
~/RivaiLauncher/
├─ launcher.json              # 현재 활성 버전 포인터 (single source of truth)
└─ versions/
   ├─ 0.0.1-dev/
   │  └─ Rivai.exe (또는 Rivai.app)
   └─ 0.0.2-dev/
      └─ Rivai.exe
```

### 3) 런처 자체의 신뢰성

런처는 사용자가 매번 받는 게 아니라 한 번 설치하고 계속 쓴다. 그래서 **런처 자체의 무결성**이 중요하다.

- 런처가 변조되면 모든 후속 검증(zip sha256 등)이 무의미해진다 (악성 런처가 sha256을 가짜로 매번 OK라고 할 수 있음).
- 정식 해법은 **코드 사인 + (Mac) 공증**. Windows Authenticode, Apple Developer Notarization.
- M0 단계에서는 코드 사인 없이 가되, 사용자에게 첫 실행 시 OS 보안 경고를 우회하는 방법을 안내한다. 추후 마일스톤에서 사인 도입.

### 4) 로컬 install state의 SSOT

manifest의 SSOT는 R2에 있지만, 런처는 자기 자신의 SSOT도 가져야 한다.

```
launcher.json (예시)
{
  "channel": "dev",
  "manifestUrl": "https://pub-.../manifest/dev.json",
  "installedVersion": "0.0.1-dev",
  "installedBuildId": "2026.05.17.001",
  "installedAt": "2026-05-17T22:24:26+09:00",
  "installPath": "/Users/.../RivaiLauncher/versions/0.0.1-dev",
  "executable": "Rivai.app",
  "lastChecked": "2026-05-17T22:30:00+09:00"
}
```

이 파일이 손상되면 런처는 "미설치 상태"로 폴백한다. 절대 추정하지 않는다.

## 구현 선택지 — 큰 결정

기존 [[M0]] 초기 결정은 "C# WPF 또는 WinUI"였지만 Mac 동시 지원이 결정되면서 무효가 됐다. Windows + macOS를 한 코드베이스로 가져갈 수 있는 데스크톱 프레임워크 중 학습 가치와 실용성을 함께 가진 3개를 비교한다.

### 옵션 비교

| 옵션 | 언어 | 바이너리 크기 | 학습 곡선 | portal 자산 재활용 | 자동 업데이트 |
|---|---|---|---|---|---|
| **Tauri** | Rust (core) + HTML/CSS/JS (UI) | ~5~15 MB | 중간 (Rust 일부) | 높음 (portal UI 코드 재활용) | 공식 Updater 플러그인 |
| Electron | JS (전체) | ~80~150 MB | 낮음 | 높음 | electron-builder/electron-updater |
| Avalonia | C# / XAML | ~30~60 MB | 중간 (XAML) | 낮음 (UI 새로 작성) | 수동 구현 또는 Squirrel 등 |

### 상세 비교

**Tauri**
- Rust로 native 책임(파일·해시·자식 프로세스·zip 해제)을 안전하게 처리.
- UI는 OS의 native webview(Windows WebView2, macOS WKWebView) 사용 → portal에서 만든 vanilla HTML/CSS/JS 그대로 적용 가능.
- 작은 바이너리 → 첫 런처 다운로드 부담 적음 (Pages에서 호스팅하기도 가벼움).
- 단점: Rust를 일부 작성해야 함. macOS Universal Binary(인텔+ARM) 빌드 약간 신경 써야 함.
- 자료: Tauri 2.x 기준 풍부.

**Electron**
- 학습 곡선이 가장 낮음 (전부 JS).
- portal UI 코드를 거의 그대로 가져와 시작 가능.
- 단점: 런타임이 무거움 (~100MB). 메모리 사용 많음. 런처가 "이게 왜 이렇게 무겁지" 인상을 줄 수 있음.
- 자동 업데이트 도구 풍부 (electron-updater).

**Avalonia**
- C# 생태계 학습. UE는 C++지만 게임 tooling에 C#이 흔히 쓰임.
- WPF/XAML 패턴 학습 — 데스크톱 native 패러다임 경험.
- portal 자산은 재활용 어려움 (UI를 XAML로 새로 짜야 함).
- macOS 데스크톱 성숙도는 Tauri/Electron보다 떨어짐.

### 추천: **Tauri 2.x**

이유:
1. **portal 학습 자산 재활용**: B01에서 작성한 vanilla HTML/CSS/JS 패턴(특히 manifest fetch + DOM 갱신)이 그대로 런처 UI에 들어감.
2. **작은 바이너리**: 런처는 첫 진입 도구. ~10MB와 ~100MB는 사용자 경험에서 큰 차이.
3. **Rust 노출 최소화**: native 책임만 Rust로 — 파일 IO, sha256, zip 해제, 자식 프로세스. 패턴이 정해져 있어 학습 부담이 통제됨.
4. **현대적 표준**: 2024년 이후 새 런처들의 일반적 선택. 자료 신선함.
5. **자동 업데이트 공식 지원**: Tauri Updater Plugin이 manifest 기반 업데이트와 잘 맞음 (단, M0.2 v0에선 수동 업데이트 확인부터).

다른 옵션을 원하시면 그 기준으로 다시 정리하겠습니다. **이 결정이 D01 전체 구현 분량을 좌우하니, 진행 전에 사용자 확정이 필요합니다.**

## UI 흐름

```
[Rivai Launcher]                                              [_  □  X]
─────────────────────────────────────────────────────────────────────
  Latest:   0.0.1-dev  ·  Build 2026.05.17.001
  Installed: 0.0.1-dev (up to date)        |  Server: Test Server 01

  ┌──────────────────────────┐  ┌──────────────────────────┐
  │     Play                 │  │  Download / Update       │
  │     (활성: 설치 완료)    │  │  (활성: 업데이트 있음)   │
  └──────────────────────────┘  └──────────────────────────┘

  [Patch Notes]  [Open Logs]  [Copy Build Info]  [Feedback]

  → 진행 중일 때: 진행률 바 + 현재 단계(다운로드/검증/압축 해제)
  → 에러: 사용자 친화적 메시지 + 재시도 버튼
─────────────────────────────────────────────────────────────────────
```

원칙:
- 첫 화면에서 "지금 무엇을 해야 하는지" 단 하나가 명확히 보여야 한다 (Play 또는 Update).
- 모든 상태(미설치/업데이트 가능/최신)에 한 가지 추천 동작이 있다.
- 에러 메시지는 다음 행동을 알려준다 ("재시도", "로그 열기", "피드백").

## 데이터 모델

### launcher.json (로컬 SSOT)

```json
{
  "channel": "dev",
  "manifestUrl": "https://pub-0ac7d3ef69e344e1bb87f0d1475315cb.r2.dev/manifest/dev.json",
  "installedVersion": "0.0.1-dev",
  "installedBuildId": "2026.05.17.001",
  "installedAt": "2026-05-17T22:24:26+09:00",
  "installPath": "/Users/.../RivaiLauncher/versions/0.0.1-dev",
  "executable": "Rivai.app",
  "lastChecked": "2026-05-17T22:30:00+09:00",
  "lastError": null
}
```

### 디렉토리 구조 (사용자 PC 기준)

```
~/Library/Application Support/RivaiLauncher/   (macOS)
%APPDATA%\RivaiLauncher\                       (Windows)
├─ launcher.json
├─ versions/
│  ├─ 0.0.1-dev/           # 압축 해제된 설치본
│  └─ 0.0.2-dev/
└─ cache/
   └─ downloads/           # 진행 중인 다운로드 임시 위치
```

학습 포인트: OS별 표준 앱 데이터 경로를 따른다. Tauri의 `path::app_data_dir()`가 자동 처리.

## 구현 절차 (Tauri 선택 시)

전제: Tauri 2.x. 자세한 명령은 사용자 확정 후 구현 단계에서 풀어 설명.

### Step 1. 사전 도구 설치
- Rust toolchain (`rustup`)
- Node.js 20+ (Tauri는 frontend dev server에 Node 사용)
- Xcode Command Line Tools (Mac), Visual Studio Build Tools (Windows)

### Step 2. Tauri 프로젝트 scaffold
- `Distribution/launcher/` 디렉토리에 `cargo create-tauri-app`로 생성.
- frontend는 "vanilla" 선택 (portal과 일관).

### Step 3. 프로젝트 구조 정리
```
Distribution/launcher/
├─ src/                  # frontend (HTML/CSS/JS)
├─ src-tauri/            # Rust core
│  ├─ src/main.rs
│  ├─ tauri.conf.json
│  └─ Cargo.toml
└─ package.json          # frontend dev tools
```

### Step 4. Rust 측 command 정의
sha256 계산, manifest fetch, zip 다운로드(스트리밍 + 진행률), 압축 해제, 자식 프로세스 spawn, launcher.json 읽기/쓰기 — 각각 Tauri command로 노출.

### Step 5. Frontend UI 작성
portal의 style.css 일부 재활용. data-slot 패턴으로 DOM 채움. Tauri JS API로 Rust command 호출.

### Step 6. 자동 업데이트 흐름 구현
1. 시작 시 `launcher.json` 읽음 (없으면 미설치 상태)
2. `manifestUrl` fetch → latest와 installed 비교
3. 상태에 따라 Play/Update 버튼 활성화
4. Update 클릭 → 새 버전 다운로드 → sha256 검증 → 새 폴더에 압축 해제 → launcher.json 갱신
5. Play 클릭 → executable spawn (manifest의 server 정보 인자로 전달)

### Step 7. 보조 버튼
- Patch Notes / Feedback → `tauri::shell::open` 으로 외부 URL
- Open Logs → 게임 로그 폴더(UE의 `Saved/Logs/`)를 OS file manager로 open
- Copy Build Info → 클립보드에 Version·Build ID·OS·Ping 등 텍스트 복사

### Step 8. 빌드 및 배포
- `cargo tauri build` → Windows .msi/.exe, macOS .app/.dmg 산출
- R2의 `builds/dev/launcher/{win64,mac}/` 에 업로드
- portal에 런처 다운로드 카드 추가 (홈페이지의 [Get Launcher] 자리)

### Step 9. M0.2 검증
새 PC(또는 깨끗한 사용자 환경)에서:
1. portal → 런처 다운로드
2. 런처 실행 → manifest 자동 fetch → "Update available"
3. Download/Update → 진행률 → 검증 → 설치 완료
4. Play → 게임 실행

## 검증 기준

- [ ] 런처가 manifest를 fetch하고 Latest·Installed 표시 (미설치 상태도 명확히)
- [ ] 첫 다운로드·설치가 성공한다 (Windows + Mac 모두)
- [ ] 다운로드한 zip의 sha256이 manifest 값과 자동으로 비교된다
- [ ] sha256 불일치 시 설치하지 않고 사용자에게 명확한 오류·재시도 옵션을 보여준다
- [ ] Play 버튼이 설치된 executable을 정확한 인자(서버 정보)와 함께 실행한다
- [ ] 보조 버튼(Patch Notes, Open Logs, Copy Build Info, Feedback) 모두 동작
- [ ] launcher.json이 매 설치 후 갱신되며, 다음 실행 시 상태가 유지된다
- [ ] 새 빌드를 R2에 배포하고 런처를 재실행했을 때 "Update available"로 전환된다

## 학습 체크포인트

다음을 본인 말로 설명할 수 있으면 다음 단계로 넘어가도 좋다.

- [ ] 런처의 4가지 책임을 분리해서 다루는 이유 (실패 격리·UX 측면)
- [ ] side-by-side 설치 패턴이 in-place보다 안전한 이유
- [ ] 런처 자체의 무결성(코드 사인)이 zip sha256 검증보다 더 근본적인 이유
- [ ] launcher.json을 SSOT로 두고 "추정하지 않는다"는 원칙의 의미
- [ ] Tauri의 native(Rust) / UI(웹) 분리가 학습·운영 측면에서 주는 이득
- [ ] 자동 업데이트의 "다운로드 완료 후 포인터 교체" 패턴의 원자성

## 산출물

| 산출물 | 설명 |
|---|---|
| `Distribution/launcher/` Tauri 프로젝트 | 런처 소스 (Rust + HTML/CSS/JS) |
| Windows 런처 빌드 (`.msi` 또는 `.exe`) | 테스터 배포용 |
| macOS 런처 빌드 (`.app` 또는 `.dmg`) | 테스터 배포용 |
| 런처 다운로드 카드 (portal) | 홈페이지에서 런처를 받을 진입점 |
| `launcher.json` 스키마 문서 | 로컬 install state의 형식 |
| 런처 사용 가이드 (B02 Known Issues 갱신) | 첫 실행·Gatekeeper 우회·로그 위치 안내 |

## 관련 문서

- [[M0]]
- [[A01-manifest-and-build-storage|A01 — Manifest and Build Storage]]
- [[B01-homepage-v0|B01 — Homepage v0]]
- [[F01-feedback-and-log-loop|F01 — Feedback and Log Loop]]
- [[G01-build-automation-draft|G01 — Build Automation Draft]]
- [[H01-end-to-end-validation|H01 — End-to-End Validation]]
