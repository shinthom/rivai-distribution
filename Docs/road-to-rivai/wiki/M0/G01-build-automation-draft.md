---
title: G01 — Build Automation Draft
type: task
status: active
---

# G01. Build Automation Draft

## 목적

지금까지 [[A01-manifest-and-build-storage|A01]]·[[B02-patch-notes-and-known-issues|B02]]·[[D01-launcher-v0|D01]]에서 손으로 진행한 빌드·해시·업로드·manifest·패치노트·재배포 단계를 **반복 가능한 단일 흐름**으로 묶는다. 이 Task가 끝나면 [[M0]]의 M0.5 Build Automation 세부 마일스톤을 만족하고, D01에서 보류한 **Windows 런처 빌드**가 GitHub Actions로 해결된다.

## 학습 목표

이 Task를 마치면 다음을 본인 말로 설명할 수 있어야 한다.

- "수동 절차의 누적"이 왜 자동화의 트리거가 되는가 (실수 비용 vs 자동화 비용)
- **로컬 스크립트**와 **CI 워크플로**의 책임 분담 기준
- **idempotency(멱등성)**가 release 스크립트 설계에 미치는 영향
- 시크릿(API 토큰)을 코드·로그에서 누설하지 않는 표준 패턴
- 새 빌드 배포의 단계 중 어디까지가 자동화 대상이고 어디부터가 사람 판단인가

## 배경 — 누적된 수동 단계의 무게

현재 새 빌드를 배포하려면 다음을 손으로 수행해야 한다.

```
1. UE 클라이언트/서버 빌드 (RunUAT.bat BuildCookRun) — Windows·Mac 각각
2. 산출물 폴더를 zip으로 압축 (Mac은 ditto, Win은 일반 zip)
3. sha256·sizeBytes 계산
4. R2에 zip 업로드 (wrangler r2 object put)
5. manifest/dev.json 새 값으로 작성 (downloadUrl, sha256, sizeBytes, latestVersion, buildId, releasedAt)
6. manifest를 Cache-Control 헤더와 함께 R2에 재업로드
7. patch-notes/<version>/index.html 작성
8. patch-notes/index.html에 새 빌드 행 추가
9. patch-notes/latest/index.html redirect 대상 갱신
10. (필요 시) known-issues/index.html 갱신
11. portal 재배포 (wrangler pages deploy)
```

총 11단계. 하나라도 빠뜨리면 "manifest는 0.0.2를 가리키는데 zip은 없다", "portal은 0.0.1로 보이는데 manifest는 0.0.2다" 같은 불일치가 생긴다. 사람의 손은 신뢰할 수 없다 — 자동화는 그 불일치 가능성을 0으로 만든다.

## 핵심 개념

### 1) 자동화의 트리거 — "n번째 수동의 비용"

자동화는 공짜가 아니다. 설계·작성·디버깅·유지보수 비용이 든다. **"자동화에 드는 비용 < n번 반복할 때의 누적 비용 + 실수 비용"** 일 때만 정당화된다.

- 1~2번: 손으로 하는 게 빠름.
- 3~5번: 체크리스트 + 손이 좋음.
- 6번 이상, 또는 1번이라도 실수가 치명적: 스크립트화.

지금 우리는 "1번도 했는데 11단계 + 실수 시 사용자가 깨진 manifest를 받는 상황"이라 자동화 ROI가 명확하다.

### 2) 로컬 스크립트 vs CI 워크플로

| | 로컬 스크립트 | CI (GitHub Actions) |
|---|---|---|
| 트리거 | 사람이 명령 입력 | git push, PR, tag, schedule |
| 환경 | 개발자 머신 | 깨끗한 가상 머신 |
| 의존성 | 개발자가 미리 설치 | 매 실행마다 셋업 |
| 비용 | 개발 시간 | runner 시간 (퍼블릭 repo는 무료) |
| 신뢰성 | "내 머신에서는 됨" 함정 | 재현 가능한 환경 |
| 비밀정보 | 로컬 환경변수 | GitHub Secrets |

**경계 그리는 원칙**: "**환경이 무거우면 로컬, 가벼우면 CI**"

- **UE 빌드**: 환경이 무겁다 (UE 설치, 라이센스, 80GB 디스크). **로컬**.
- **런처 빌드**: 환경이 가볍다 (Rust + Node + ditto/codesign). **CI** (특히 Windows runner가 결정적).
- **R2 업로드, manifest 갱신, portal 재배포**: 가볍다. **둘 다 가능**. 로컬 스크립트가 호출하고, CI도 같은 스크립트를 호출하면 일관성이 생긴다.

### 3) Idempotency (멱등성)

같은 입력으로 release 스크립트를 두 번 돌려도 결과가 같아야 한다.

- ❌ 나쁜 설계: 같은 버전을 두 번째 실행하면 manifest의 `buildId`가 자동 증가 → 두 번째 실행이 첫 번째와 다른 결과.
- ✅ 좋은 설계: `release 0.0.2-dev 2026.05.18.003` 처럼 **버전·빌드ID를 인자로 받음** → 같은 인자로 두 번 돌리면 두 번째는 "이미 존재"라며 안전 종료(또는 동일 결과를 그대로 다시 만듦).

멱등성이 있으면 실패한 release를 두려움 없이 재실행할 수 있다.

### 4) Dry-run

```
./release.sh 0.0.2-dev --dry-run
```

실제 R2/manifest/portal에 손대지 않고, "이런 명령이 실행될 것"을 출력만 한다. 처음 자동화를 도입할 때 신뢰를 쌓는 핵심 도구. 우리 스크립트의 모든 destructive 명령은 `--dry-run`을 지원한다.

### 5) 시크릿 관리

- 코드·git·로그에 절대 들어가면 안 되는 값: `CLOUDFLARE_API_TOKEN`.
- 로컬: `~/.zshrc`의 환경변수 또는 1Password CLI 같은 vault.
- CI: GitHub Secrets. workflow에서 `${{ secrets.CLOUDFLARE_API_TOKEN }}`으로만 노출, 로그에는 마스킹.
- 권한 최소화: R2 edit + Pages edit만. workers/d1 등 다른 권한은 빼기.
- 정기 rotation (90일 단위 권장).

## 구현 선택지

### 분담 결정

| 작업 | 위치 | 이유 |
|---|---|---|
| UE 클라이언트/서버 빌드 | 로컬 | 환경 무거움. CI 도입은 M1 이후 검토 |
| 게임 zip → R2 → manifest 갱신 → portal 재배포 | 로컬 스크립트 | UE 빌드 직후 같은 머신에서 즉시 실행 |
| 런처 빌드 (macOS) | 로컬 또는 CI | 어느 쪽이든 OK. CI가 깨끗 |
| 런처 빌드 (Windows) | **CI 필수** | Mac에서 못 만듦 |
| 런처 manifest 갱신 | CI | 빌드 산출물 자리에 바로 |

### 스크립트 언어

| 옵션 | 장점 | 약점 |
|---|---|---|
| **Bash** | 의존성 0, macOS 기본 내장, CI도 그대로 동작 | 복잡한 로직은 가독성 ↓ |
| Node.js | npm 생태계, JSON 다루기 편함 | 의존성 ↑ |
| Python | 잘 알려진 표준 | macOS 기본 python3 외 별도 셋업 가능성 |

**결정: Bash**. release 스크립트의 책임은 "이미 검증된 명령들을 정해진 순서로 실행"이지 복잡한 로직이 아니다. 명령 호출 + 변수 치환 + 종료 코드 체크 정도라 Bash가 가장 직접적.

### CI 플랫폼

**GitHub Actions 확정**. 이유: Cloudflare 공식 action 풍부, Windows/macOS runner 무료(퍼블릭 repo) 또는 월 2000분 무료(프라이빗), Secrets·OIDC 등 기본기 충실.

## 디렉토리·산출물 구조

```
Distribution/
├─ scripts/
│  ├─ lib/
│  │  ├─ common.sh             # 공통 헬퍼 (로그, 에러, 경로)
│  │  └─ r2.sh                 # wrangler 래퍼 (업로드, manifest 갱신)
│  ├─ release-game.sh          # 게임 빌드 배포 (로컬)
│  ├─ release-launcher.sh      # 런처 zip → R2 → launcher manifest 갱신
│  └─ render-patch-notes.sh    # 패치노트 HTML 생성 (템플릿 + 변수 치환)
└─ templates/
   └─ patch-notes.html         # 패치노트 템플릿

(repo root) .github/workflows/
└─ launcher-release.yml         # Windows + macOS 런처 빌드 → 산출물 업로드
```

## 스크립트 인터페이스

### `release-game.sh`

```
./release-game.sh \
  --version 0.0.2-dev \
  --build-id 2026.05.18.003 \
  --client-win64 path/to/client_win64.zip \
  --client-mac path/to/client_mac.zip \
  [--server-win64 path/to/server_win64.zip] \
  [--dry-run]
```

내부 단계 (모두 dry-run 지원):
1. 입력 zip의 sha256·sizeBytes 계산
2. R2에 zip 업로드 (Content-Type: application/zip)
3. manifest/dev.json 새 값으로 생성
4. R2에 manifest 업로드 (Cache-Control: max-age=60)
5. 패치노트 HTML 생성 (`render-patch-notes.sh` 호출)
6. `patch-notes/index.html` 빌드 행 추가
7. `patch-notes/latest/` redirect 갱신
8. portal 재배포 (`wrangler pages deploy`)

### `release-launcher.sh`

```
./release-launcher.sh \
  --version 0.0.2 \
  --build-id 2026.05.18.001 \
  --mac path/to/Rivai\ Launcher.app \
  [--win path/to/Rivai\ Launcher.exe] \
  [--dry-run]
```

CI에서도 같은 스크립트를 호출하므로 로컬·CI 결과가 일관된다.

### `render-patch-notes.sh`

```
./render-patch-notes.sh \
  --version 0.0.2-dev \
  --build-id 2026.05.18.003 \
  --released-at 2026-05-18 \
  --changes-file path/to/changes.md \
  --output portal/patch-notes/0.0.2/index.html
```

템플릿 변수 치환만. M0 단계는 변경 사항을 마크다운으로 받지만 자동 마크다운→HTML 변환은 도입하지 않는다 (의존성 추가 회피). 변경 사항은 그대로 `<pre>` 또는 `<ul>` 안에 넣고, 더 풍부한 렌더링이 필요해지면 별도 마일스톤.

## GitHub Actions 워크플로

`launcher-release.yml` 개요:

```yaml
on:
  workflow_dispatch:           # 수동 트리거 (버전·빌드ID 입력)
  push:
    tags: ['launcher-v*']      # 태그 푸시 시 자동 트리거

jobs:
  build-mac:
    runs-on: macos-latest      # arm64 native
    steps:
      - checkout
      - rust toolchain
      - node 20
      - npm install
      - cargo tauri build
      - ditto으로 .app → zip
      - artifact upload

  build-windows:
    runs-on: windows-latest
    steps:
      - checkout
      - rust toolchain
      - node 20
      - npm install
      - cargo tauri build
      - powershell Compress-Archive
      - artifact upload

  publish:
    needs: [build-mac, build-windows]
    runs-on: ubuntu-latest
    steps:
      - download artifacts
      - install wrangler
      - ./scripts/release-launcher.sh --mac ... --win ...
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

학습 포인트:

- **matrix build 대신 명시 job 분리**: 플랫폼별 단계가 충분히 달라 매트릭스 표현이 어색. 두 job으로 명시.
- **artifacts**: 빌드 job이 산출물을 업로드하고 publish job이 다운로드. 같은 워크플로 안에서도 job 간 파일 전달은 명시적이어야 함.
- **publish 분리**: `needs:`로 의존성 박음. 빌드 중 한쪽이 실패하면 publish 안 됨 (멱등 안전).
- **OIDC vs Secret**: Cloudflare는 OIDC 미지원이라 API Token 시크릿 사용. AWS·GCP는 OIDC로 단기 토큰 발급 가능 (참고용).

## 구현 절차

### Step 1. `scripts/lib/common.sh` — 공통 헬퍼

`die`, `log`, `is_dry_run`, `require_command`, `compute_sha256`, `human_bytes` 정도.

### Step 2. `scripts/lib/r2.sh` — wrangler 래퍼

R2 업로드, manifest 다운로드/갱신/업로드, Cache-Control 일관 적용. 모든 명령에 `--dry-run` 지원.

### Step 3. `templates/patch-notes.html` + `render-patch-notes.sh`

B02에서 직접 작성한 0.0.1 페이지의 골격을 템플릿으로 추출. `{{VERSION}}`, `{{BUILD_ID}}`, `{{RELEASED_AT}}`, `{{CHANGES_HTML}}` 같은 변수.

### Step 4. `release-game.sh`

위 헬퍼 스크립트를 조합. 게임 zip 두 개를 받아 R2 → manifest → 패치노트 → portal까지 한 흐름.

### Step 5. `release-launcher.sh`

Tauri 빌드 산출물을 받아 launcher manifest 갱신. macOS는 ditto, Windows는 zip.

### Step 6. `.github/workflows/launcher-release.yml`

Windows + macOS 런처 빌드 + publish. 시크릿은 GitHub UI에서 미리 등록.

### Step 7. 시크릿 등록

GitHub repository → Settings → Secrets and variables → Actions:

- `CLOUDFLARE_API_TOKEN`: R2 Edit + Pages Edit 권한 토큰
- `CLOUDFLARE_ACCOUNT_ID`: `ba6bc765239901978f54013f4d15df47`

### Step 8. dry-run 검증

모든 스크립트를 `--dry-run`으로 한 번씩 돌려 "실행될 명령"을 출력만 확인. 출력이 의도와 같으면 실제 실행.

### Step 9. 실 release 1회

`release-game.sh`로 0.0.2-dev 더미 빌드 한 번 배포. portal과 런처에서 새 버전이 자동 감지되는지 확인.

### Step 10. CI 워크플로 1회

GitHub Actions에서 `workflow_dispatch`로 런처 0.0.2 빌드. Windows zip이 R2에 올라가고 launcher manifest에 `launcher.win64`가 채워지는지 확인. portal의 Windows 런처 카드가 활성으로 전환되는지 확인.

## 검증 기준

- [ ] `release-game.sh`가 11단계를 한 명령으로 수행한다.
- [ ] 같은 인자로 두 번 실행해도 같은 manifest·같은 산출물이 나온다 (멱등).
- [ ] `--dry-run` 모드에서는 R2·portal에 변화가 없다.
- [ ] 패치노트 HTML이 템플릿에서 자동 생성된다.
- [ ] `patch-notes/index.html`에 새 빌드 행이, `patch-notes/latest/`에 redirect가 자동 갱신된다.
- [ ] GitHub Actions로 Windows + macOS 런처가 빌드되고 R2에 업로드된다.
- [ ] portal의 Windows 런처 카드가 "Coming soon"에서 실제 다운로드 버튼으로 자동 전환된다.
- [ ] 시크릿이 git·로그·아티팩트 어디에도 노출되지 않는다.

## 학습 체크포인트

다음을 본인 말로 설명할 수 있으면 다음 단계로 넘어가도 좋다.

- [ ] "1번 자동화 vs n번 수동"의 ROI 계산 기준
- [ ] 로컬과 CI의 분담을 환경 무거움/가벼움 축으로 가르는 이유
- [ ] 멱등성이 "재실행 두려움"을 어떻게 없애는가
- [ ] `--dry-run`이 자동화 도입기에 핵심 안전장치인 이유
- [ ] 시크릿이 절대 들어가면 안 되는 위치 3곳 (코드·git history·CI 로그)
- [ ] GitHub Actions의 `artifacts`가 job 간 파일 전달의 명시적 방식인 이유

## 산출물

| 산출물 | 설명 |
|---|---|
| `Distribution/scripts/release-game.sh` | 게임 빌드 1-command 배포 |
| `Distribution/scripts/release-launcher.sh` | 런처 zip → R2 → manifest 갱신 |
| `Distribution/scripts/render-patch-notes.sh` | 패치노트 HTML 자동 생성 |
| `Distribution/scripts/lib/*.sh` | 공통 헬퍼 (logging, sha256, r2 래퍼) |
| `Distribution/templates/patch-notes.html` | 패치노트 템플릿 |
| `.github/workflows/launcher-release.yml` | 런처 멀티 플랫폼 빌드 CI |
| GitHub Secrets 등록 | `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` |
| 새 빌드 배포 가이드 (B02 운영 규칙 갱신) | 자동화 도입 후의 단순화된 절차 |

## 관련 문서

- [[M0]]
- [[A01-manifest-and-build-storage|A01 — Manifest and Build Storage]]
- [[B01-homepage-v0|B01 — Homepage v0]]
- [[B02-patch-notes-and-known-issues|B02 — Patch Notes and Known Issues]]
- [[D01-launcher-v0|D01 — Launcher v0]]
- [[H01-end-to-end-validation|H01 — End-to-End Validation]]
