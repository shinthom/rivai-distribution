---
title: C01 — Manual Distribution
type: task
status: active
---

# C01. Manual Distribution

## 목적

런처가 완성되기 전에도, 그리고 런처를 못 받거나 안 쓰는 상황에서도, 팀원이 홈페이지 링크 하나만으로 클라이언트 zip을 받아 실행하고 피드백을 남길 수 있게 한다. 이 Task가 끝나면 [[M0]]의 **M0.1 Manual Distribution** 세부 마일스톤을 만족한다.

## 학습 목표

이 Task를 마치면 다음을 본인 말로 설명할 수 있어야 한다.

- "팀원이 새 PC에서"라는 시나리오가 실제로 검증하는 것은 무엇인가 (clean slate가 잡아내는 것)
- 같은 manifest를 자동(런처)과 수동(사람) 두 경로가 동시에 소비할 때 어떤 일관성이 필요한가
- 다운로드~첫 실행 사이의 마찰점(friction)이 어디에 숨어 있는가 (OS 보안 경고, 압축 도구 차이, 권한, 경로)
- M0.1에서 "게임 내 Build Version"이 더미 빌드와 진짜 빌드에서 어떻게 다르게 검증되는가
- 사람 절차(가이드)와 자동화(런처)가 같은 사이클을 다루는데 왜 둘 다 필요한가

## 배경 — 왜 수동 경로가 끝까지 살아있어야 하는가

런처(D01)가 동작하는 상황에서도 수동 zip 경로는 다음 이유로 끝까지 유지된다.

- 런처가 깨지거나 OS 정책으로 막혔을 때의 **폴백(fallback)**
- 외부 검수자(보안·QA 등)에게 빌드를 직접 전달해야 할 때
- CI/디버깅에서 특정 버전을 강제로 받아야 할 때
- 신뢰의 단순성 — 무엇이 들어있는지 사용자가 직접 확인할 수 있어야 할 때

즉 수동 경로는 단순 "초기 임시 수단"이 아니라 **자동 경로의 안전망**이다. 따라서 사라지지 않게 사람 절차로 박아둔다.

## 핵심 개념

### 1) "새 PC에서"의 진짜 의미

이건 단순히 "다른 컴퓨터에서 돌려본다"가 아니라 **clean slate 가정**이다.

- 개발 도구 없음 (Unreal Editor·Visual Studio·Xcode 모두 미설치)
- 환경 변수 없음, 추가 DLL 없음
- 다운로드 폴더에 받은 zip 하나만 있음
- 사용자는 운영체제 기본 도구(Finder, 압축 해제 기본 기능, 더블클릭 실행)만 사용

이 가정이 잡아내는 함정 — 개발자 머신에서는 "있는 줄 몰랐던 의존성"이 새 PC에서 missing DLL/dyld 에러로 폭발. M0.1은 이 함정의 존재 여부를 사람 절차로 검증한다.

### 2) 동일 manifest, 두 소비자

런처(D01)와 portal 다운로드 카드(B01)는 같은 manifest의 `client.win64.downloadUrl`을 가리키고, 결국 같은 zip을 받는다. 그러므로:

- 수동 다운로드한 zip의 sha256은 manifest의 sha256과 정확히 일치해야 한다 (런처가 검증하는 것과 동일).
- 사람이 받았을 때도 sha256을 검증할 수 있는 방법이 안내되어 있어야 한다 — 의무는 아니지만 "할 수 있는 사람은 한다".
- portal에 표시되는 Version·Build ID는 zip 안의 `Version.txt`와 일치해야 한다.

이 세 정합성이 만족되면 사람이 받은 zip은 런처가 받은 zip과 동일하다는 신뢰가 생긴다.

### 3) 다운로드~첫 실행의 마찰점

| 마찰점 | OS | 처리 |
|---|---|---|
| Gatekeeper "손상됨" | macOS 15+ | `xattr -dr com.apple.quarantine` 안내 (이미 [[B02-patch-notes-and-known-issues|Known Issues]]에 박힘) |
| SmartScreen "보호됨" | Windows | "추가 정보 → 실행" 안내 |
| 압축 해제 도구 차이 | Mac | `Rivai.app`은 Finder 또는 `ditto -x -k`. WinRAR/7-Zip로 풀면 깨질 수 있음 |
| 실행 권한 | macOS | ditto는 보존. 잘못된 도구로 풀면 `chmod +x` 안내 |
| 게임 작업 디렉토리 | 양쪽 | UE 빌드는 상대 경로로 콘텐츠를 찾으므로 zip을 풀고 **나오는 폴더 그대로** 실행 |

가이드 문서는 이 5가지를 모두 다룬다. 가짓수는 적지만 빠짐없이 적혀 있어야 사용자가 끝까지 도달한다.

### 4) Build Version 확인 — M0.1의 임시 방편

M0.1 단계에서 "게임 내 Build Version 확인"의 정식 형태는 게임 화면 어딘가에 텍스트로 표시되는 것이다. 그러나 현재 빌드는 더미라 그 표시가 없다.

대체 방안: **zip 안 `Version.txt`**. 이미 [[A01-manifest-and-build-storage|A01]]에서 더미 빌드에 포함했다.

```
Version.txt:
  0.0.2-dev
  2026.05.18.001
```

가이드에서는 "압축 해제 후 `Version.txt`를 열면 Version과 Build ID가 두 줄로 보임. 피드백 폼 작성 시 그대로 복사"로 안내한다. 실제 UE 빌드(M1 이후)가 들어오면 게임 내 표시로 자연 승격된다 — `Version.txt`는 그대로 두어 호환을 유지한다.

### 5) 사람 절차와 자동화의 공존

런처가 모든 걸 자동화해도 사람 절차(가이드)는 사라지지 않는다. 다만 가이드는 **자동화가 못 하는 부분**에 집중한다.

- 자동화 못 함: OS 보안 경고 우회, 첫 실행 권한 부여, "왜 이게 안 되지" 트러블슈팅
- 자동화 잘 함: 다운로드, 무결성 검증, 압축 해제, 실행, 업데이트 알림

따라서 가이드 문서는 트러블슈팅 중심으로 작성한다. "잘 되면 안 봐도 되고, 안 될 때 봐서 풀리는" 문서.

## 구현 선택지

### 가이드 호스팅 위치

| 옵션 | 장점 | 약점 |
|---|---|---|
| **portal 내부 `/install-guide/`** | 같은 도메인·디자인, manifest 링크와 일관, 한 곳에서 deploy | portal 변경 사이클에 묶임 |
| 외부 노션·블로그 | 비개발자가 편집 쉬움 | 도메인 분리, 동기화 부담 |
| zip 안의 README | 사용자가 zip 풀자마자 봄 | 갱신하려면 zip 재빌드 |

**결정: portal 내부 + zip 안에 짧은 README 동봉**. portal 가이드가 정식 문서, zip의 README는 "이 폴더에서 무엇을 해야 하는가" 한 페이지 압축본 + portal 가이드 링크.

### Build Version 확인 방식

**결정: M0.1은 `Version.txt`, M1 이후 게임 내 HUD로 자연 승격**. release-game.sh가 zip 빌드 단계에서 `Version.txt`를 자동으로 박아 넣게 한다 (지금은 더미 빌드의 일부지만, 실제 빌드에서도 같은 규약 유지).

### 새 PC 시뮬레이션 방법

| 옵션 | 비용 | 정확도 |
|---|---|---|
| **macOS의 다른 사용자 계정** | 0 (기존 머신에 계정 추가) | 양호 (홈 디렉토리·환경변수 분리) |
| 가상머신 (UTM, Parallels) | 디스크 + 시간 | 높음 |
| 실제 다른 PC | 가장 정확 | 가장 비싸 |
| `~/Downloads/sandbox/` 빈 폴더 | 0 | 낮음 (개발 환경 그대로) |

**결정: macOS는 다른 사용자 계정**, **Windows는 동료의 실제 PC**(런처 동작 확인 시점에 같이 검증). 가상머신은 H01에서 정식 검증 시 도입 검토.

## 디렉토리 구조

```
Distribution/portal/
└─ install-guide/
   └─ index.html              # 정식 설치·실행 가이드 (트러블슈팅 중심)

Distribution/templates/
└─ zip-readme.txt             # zip에 동봉할 짧은 README 템플릿

Distribution/scripts/
└─ release-game.sh            # zip 빌드 시 Version.txt + README를 자동 동봉 (확장)
```

manifest 추가 필드:

```json
"installGuideUrl": "https://rivai-portal.pages.dev/install-guide/"
```

portal 홈의 "설치 가이드" 링크가 이 URL을 가리키게 한다 (B01의 placeholder를 교체).

## 가이드 페이지 구성

```
설치 & 실행 가이드 (rivai-portal.pages.dev/install-guide/)
─────────────────────────────────────────────────────────
1. 다운로드 — 어디서 받는가
   · 권장: 런처 (D01) — 자동 검증·자동 업데이트
   · 수동: portal 첫 화면의 OS별 Download 버튼

2. 압축 해제
   · macOS: 더블클릭 (자동) 또는 터미널 `ditto -x -k 파일.zip 출력디렉토리`
   · Windows: 우클릭 → "모두 압축 풀기"

3. 첫 실행 — OS 보안 경고 처리
   · macOS 14 이하: 우클릭 → "열기"
   · macOS 15/26 이상: 터미널 `xattr -dr com.apple.quarantine 경로/Rivai.app`
   · Windows SmartScreen: "추가 정보" → "실행"

4. Build Version 확인
   · 압축 해제된 폴더의 `Version.txt`를 텍스트 편집기로 열면 두 줄
   · 첫 줄: latestVersion (예: 0.0.2-dev)
   · 둘째 줄: buildId (예: 2026.05.18.001)

5. 무결성 검증 (선택)
   · macOS: `shasum -a 256 받은파일.zip`
   · Windows PowerShell: `Get-FileHash -Algorithm SHA256 받은파일.zip`
   · 출력값이 manifest의 sha256과 동일하면 OK
   · manifest는 https://pub-<hash>.r2.dev/manifest/dev.json 에서 직접 확인 가능

6. 피드백 — 무엇을 적어야 하는가
   · Build Version, Build ID (Version.txt에서 복사)
   · 사용한 OS·아키텍처
   · 재현 절차, 기대/실제 결과
   · (F01 완료 후 폼 링크로 직접 이동)

7. 문제가 안 풀릴 때
   · Known Issues 페이지 확인
   · 피드백 폼에 로그 파일 첨부
```

## zip 안 README 템플릿

```
Rivai dev build {{VERSION}}  (Build {{BUILD_ID}})
─────────────────────────────────────────────────

이 폴더에서 다음을 실행하세요:
  Windows: Rivai.exe
  macOS:   Rivai.app  (우클릭 → 열기)

처음 실행 시 OS가 보안 경고를 띄울 수 있습니다.
처리 방법: https://rivai-portal.pages.dev/install-guide/

Version 정보는 같은 폴더의 Version.txt에 있습니다.
피드백: https://rivai-portal.pages.dev/feedback
Known Issues: https://rivai-portal.pages.dev/known-issues/
```

## 구현 절차

### Step 1. `install-guide/index.html` 작성

위 구성에 맞춰 portal 스타일과 일관된 HTML. 트러블슈팅 중심.

### Step 2. zip-readme 템플릿 + release-game.sh 확장

`Distribution/templates/zip-readme.txt`를 만들고, release-game.sh가 더미 zip을 생성할 때(또는 zip을 받아 처리할 때) 풀어서 README와 Version.txt를 끼워 넣는 단계 추가. M0.1 단계에서는 우리 더미 zip 두 개에 직접 README/Version.txt를 추가하고 재생성·재업로드.

### Step 3. manifest에 `installGuideUrl` 추가

release-game.sh가 manifest 작성 시 `installGuideUrl` 필드를 자동 포함하도록 확장. portal의 "Install Guide" 링크와 zip README의 링크가 같은 URL을 가리킨다.

### Step 4. portal의 "Install Guide" 링크 교체

B01의 placeholder를 manifest의 `installGuideUrl`로 자동 채우게 app.js 확장.

### Step 5. 새 PC 시뮬레이션

- **macOS**: 시스템 설정 → 사용자 및 그룹 → 새 계정 생성 → 로그인 → portal URL만 받은 상태에서 1~5단계 수행
- **Windows**: 동료에게 portal URL만 전달 → 같은 시나리오 수행

각 단계에서 "막힌 곳"을 메모. 가이드에 없는 마찰점이 발견되면 가이드 보강.

### Step 6. 결과 기록

`Distribution/portal/install-guide/index.html` 아래 작은 섹션으로 "검증 이력" 또는 별도 메모로 남김 (어떤 OS 버전·어떤 절차에서 통과했는지).

## 검증 기준

- [ ] portal 홈의 "Install Guide" 링크가 manifest의 `installGuideUrl`을 가리킨다.
- [ ] `install-guide/` 페이지가 200으로 응답하고 7개 섹션을 모두 포함한다.
- [ ] portal에서 받은 클라이언트 zip 안에 README.txt와 Version.txt가 들어있다.
- [ ] README.txt와 Version.txt가 manifest의 latestVersion·buildId와 일치한다.
- [ ] 받은 zip의 sha256이 manifest 값과 일치한다 (자동 / 사람 동시 통과).
- [ ] 새 PC(또는 새 macOS 사용자 계정)에서 portal URL만으로 다운로드 → 압축 해제 → 첫 실행까지 도달한다.
- [ ] 위 사이클 중 발생한 OS 보안 경고가 모두 가이드에서 해결 가능했다 (가이드 보강이 필요했다면 패치노트에 명시).

## 학습 체크포인트

다음을 본인 말로 설명할 수 있으면 다음 단계로 넘어가도 좋다.

- [ ] "새 PC에서"가 단순한 환경 차이 검증이 아니라 clean slate 가정의 implicit 검증인 이유
- [ ] 런처가 있는데도 수동 경로를 끝까지 유지해야 하는 4가지 시나리오
- [ ] Build Version 확인을 `Version.txt`로 시작해서 게임 내 HUD로 승격하는 점진적 설계
- [ ] 가이드 문서가 자동화와 중복되지 않으려면 어디에 집중해야 하는가 (트러블슈팅)
- [ ] M0.1 검증이 성공이라는 게 어떤 상태를 의미하는가

## 산출물

| 산출물 | 설명 |
|---|---|
| `Distribution/portal/install-guide/index.html` | 정식 설치·실행 가이드 |
| `Distribution/templates/zip-readme.txt` | zip 동봉 README 템플릿 |
| 갱신된 `release-game.sh` | 더미 zip에 Version.txt + README 자동 동봉, manifest에 `installGuideUrl` 추가 |
| 갱신된 `manifest/dev.json` | `installGuideUrl` 필드 포함 |
| 갱신된 portal app.js | "Install Guide" 링크가 manifest 값을 가리킴 |
| 시뮬레이션 결과 메모 | 새 사용자 계정·새 PC에서 사이클 통과 기록 |

## 관련 문서

- [[M0]]
- [[A01-manifest-and-build-storage|A01 — Manifest and Build Storage]]
- [[B01-homepage-v0|B01 — Homepage v0]]
- [[B02-patch-notes-and-known-issues|B02 — Patch Notes and Known Issues]]
- [[D01-launcher-v0|D01 — Launcher v0]]
- [[F01-feedback-and-log-loop|F01 — Feedback and Log Loop]]
- [[G01-build-automation-draft|G01 — Build Automation Draft]]
- [[H01-end-to-end-validation|H01 — End-to-End Validation]]
