---
title: A01 — Manifest and Build Storage
type: task
status: active
---

# A01. Manifest and Build Storage

## 목적

런처와 홈페이지가 같은 빌드 정보를 읽을 수 있도록 `manifest.json`과 빌드 저장소 구조를 확정한다. 이 Task가 끝나면 [[M0]]의 `manifest.json`, 빌드 저장소, 버전·URL·sha256·서버 주소 관리 범위를 만족하며, 이후 B01/B02/C01/D01/E01 Task의 공통 계약이 된다.

## 학습 목표

이 Task를 마치면 다음을 본인 말로 설명할 수 있어야 한다.

- 빌드 배포에서 manifest가 하는 역할과 없을 때 생기는 문제
- sha256으로 다운로드 무결성을 검증하는 이유와 절차
- 정적 사이트와 객체 스토리지를 분리해 호스팅하는 이유
- 새 빌드 배포 시 zip → 해시 → manifest 갱신을 어떤 순서로 해야 안전한가

## 배경 — 왜 manifest를 가장 먼저 만드는가

런처(D01), 홈페이지(B01), 수동 배포(C01), 빌드 자동화(G01)는 모두 "현재 배포된 빌드가 무엇인지"를 알아야 한다.

manifest가 없으면 각 곳이 버전을 하드코딩하거나 별도 설정 파일을 두게 되고, 새 빌드를 낼 때마다 모든 곳을 따로 갱신해야 한다. 한 곳이라도 빠지면 런처는 옛 zip을 받는데 홈페이지는 새 버전을 표시하는 식의 불일치가 생긴다.

manifest는 그래서 **Single Source of Truth(단일 진실 공급원)** 역할을 한다. 모든 구성요소가 같은 manifest URL을 읽으면 새 빌드 배포는 결국 "zip 업로드 + manifest 갱신" 두 단계로 정리된다.

## 핵심 개념

### 1) Manifest 파일의 패턴

소프트웨어 배포에서 manifest는 흔한 패턴이다.

| 사례 | manifest 역할 |
|---|---|
| 웹 PWA | `manifest.json` (앱 이름, 아이콘, 시작 URL) |
| Node.js | `package.json` (이름, 버전, 의존성) |
| Android | `AndroidManifest.xml` (권한, 컴포넌트) |
| 게임 런처(우리) | 최신 버전, 다운로드 URL, 해시, 서버 주소 |

공통점은 시스템 외부가 "이게 무엇인지" 알 수 있도록 메타데이터를 한 파일에 담는다는 것이다.

### 2) 무결성 검증 (sha256)

zip 파일은 다운로드 중 네트워크 손상, 부분 다운로드, 또는 중간 변조로 깨질 수 있다. 무결성 검증이 없으면 런처는 깨진 zip을 풀고 실행하다 의문스러운 에러로 죽는다.

해법은 **암호학적 해시(cryptographic hash)** 다. zip 전체에 sha256을 적용하면 256비트 길이의 지문이 나오고, 입력이 한 바이트만 바뀌어도 지문은 완전히 달라진다.

- 배포 시: 서버 측에서 zip의 sha256을 계산해 manifest에 적는다.
- 다운로드 시: 런처가 zip을 받은 뒤 직접 sha256을 계산해 manifest 값과 비교한다.
- 다르면 zip을 폐기하고 다시 받는다.

> md5와 sha1은 충돌 공격이 알려져 있어 무결성·보안 용도로는 권장하지 않는다. sha256이 현재 사실상 표준이다. 다만 sha256만으로는 "변조됐는지"를 막을 수는 없다 — 공격자가 zip을 바꿔치기하면 manifest의 sha256도 같이 바꿀 수 있기 때문이다. 그건 HTTPS와 서명(signature)으로 별도로 해결한다. M0 단계에서는 HTTPS + sha256으로 충분하다.

### 3) 정적 사이트와 객체 스토리지의 분리

|  | 정적 사이트 (홈페이지·manifest) | 객체 스토리지 (빌드 zip) |
|---|---|---|
| 크기 | 작음 (수 KB~수 MB) | 큼 (수백 MB~수 GB) |
| 갱신 빈도 | 자주 | 빌드마다 |
| 트래픽 패턴 | 가벼움, CDN 캐시 친화적 | 대용량 단발 다운로드 |
| 적합한 서비스 | Cloudflare Pages, GitHub Pages, Netlify | Cloudflare R2, AWS S3, GitHub Releases |

분리하는 이유: 정적 사이트 호스팅은 작은 파일에 최적화되어 있고, 큰 zip을 같이 두면 비용 또는 제한(예: GitHub Pages 1GB)에 걸리기 쉽다. 또한 zip이 바뀌어도 사이트는 바뀌지 않으므로 책임 분리가 명확해진다.

## 구현 선택지

### 호스팅 옵션 비교

| 옵션 | 정적 사이트 | 빌드 zip 저장 | 장점 | 약점 |
|---|---|---|---|---|
| A) GitHub 통합 | GitHub Pages | GitHub Releases | 인프라 통일, Git 워크플로만으로 충분, 무료 | Release asset 2GB 제한, 다운로드 속도 들쭉날쭉, 비공개 빌드 어려움 |
| B) Cloudflare 통합 | Cloudflare Pages | Cloudflare R2 | egress(외부 전송) 무료, S3 호환 API, 빌드가 커져도 비용 안전 | R2/Pages 신규 학습 필요, 별도 계정 필요 |
| C) 자체 서버 + nginx | 직접 운영 | 직접 운영 | 완전 통제 | 운영 부담 큼, M0 단계엔 부적합 |

### 결정: **옵션 B (Cloudflare Pages + R2)**

채택 이유:

1. **확장성**: R2는 egress 무료. 빌드가 커지고 테스터가 늘어도 비용이 폭발하지 않는다.
2. **표준 학습**: R2는 S3 호환 API라 한 번 배우면 AWS S3, Backblaze B2 등 다른 객체 스토리지로 그대로 이식 가능.
3. **역할 분리**: 정적 호스팅과 객체 스토리지가 별개 서비스라 책임 경계가 명확해진다.
4. **확장 여지**: 비공개 빌드를 위해 사인된 URL(presigned URL)이나 Cloudflare Workers로 접근 제어를 얹기 쉽다.

### 도메인 정책

M0 단계에서는 **R2 public bucket URL을 그대로 사용**한다. 형태는 `https://pub-<hash>.r2.dev/<key>` 또는 R2가 자동 발급하는 `*.r2.cloudflarestorage.com` 계열.

커스텀 도메인(`dist.rivai.example` 등) 연결은 보류한다. M0의 학습 우선순위는 manifest 계약과 무결성 검증이고, 도메인은 추후 별도로 붙여도 manifest의 `downloadUrl` 값만 교체하면 되므로 클라이언트 영향이 작다.

## 디렉토리·URL 구조

R2 버킷 안에서는 다음 구조를 사용한다.

```
rivai-dist/                                       # R2 bucket
├─ manifest/
│  └─ dev.json                                    # channel별 manifest (단일 SSOT)
├─ builds/
│  └─ dev/
│     ├─ client/
│     │  ├─ win64/
│     │  │  └─ rivai_client_0.0.1_dev_win64.zip
│     │  └─ mac/
│     │     └─ rivai_client_0.0.1_dev_mac.zip
│     └─ server/
│        └─ win64/
│           └─ rivai_server_0.0.1_dev_win64.zip   # 서버는 우선 win64만
└─ patch-notes/
   └─ dev/
      └─ 0.0.1.md
```

원칙:

- **channel**(dev/qa/live)로 최상위 분리 → 추후 채널별 manifest URL을 다르게 줄 수 있다.
- **version**은 파일명에 포함해 같은 폴더에 누적 → 과거 빌드도 그대로 남고, 롤백이 가능해진다.
- **client/server**를 분리 → 서버 zip은 외부에 노출하지 않을 수도 있다.
- **platform**(win64/mac)을 폴더와 파일명에 둘 다 포함 → 파일명만 봐도 어느 플랫폼인지 식별, 폴더 단위로 일괄 권한 정책을 걸 수도 있다.
- **manifest는 한 채널당 한 파일**로 유지 → Windows와 Mac 빌드를 같은 manifest에서 함께 가리킨다. 플랫폼마다 manifest를 분리하면 갱신 시 동기화 부담이 생겨 SSOT 원칙이 깨진다.

## manifest.json 스키마

```json
{
  "project": "Rivai",
  "channel": "dev",
  "latestVersion": "0.0.1-dev",
  "buildId": "2026.05.17.001",
  "releasedAt": "2026-05-17T10:00:00+09:00",
  "client": {
    "win64": {
      "downloadUrl": "https://pub-<r2-bucket-hash>.r2.dev/builds/dev/client/win64/rivai_client_0.0.1_dev_win64.zip",
      "sha256": "PUT_SHA256_HASH_HERE",
      "sizeBytes": 1500000000,
      "executable": "Rivai.exe"
    },
    "mac": {
      "downloadUrl": "https://pub-<r2-bucket-hash>.r2.dev/builds/dev/client/mac/rivai_client_0.0.1_dev_mac.zip",
      "sha256": "PUT_SHA256_HASH_HERE",
      "sizeBytes": 1600000000,
      "executable": "Rivai.app"
    }
  },
  "server": {
    "name": "Test Server 01",
    "host": "test.rivai.example",
    "port": 7777
  },
  "patchNotesUrl": "https://rivai.example/patch-notes/0.0.1",
  "feedbackUrl": "https://rivai.example/feedback",
  "knownIssuesUrl": "https://rivai.example/known-issues"
}
```

### 필드 설명 (왜 이 필드가 필요한가)

| 필드 | 이유 |
|---|---|
| `project` | 한 manifest URL이 다른 프로젝트로 오인되지 않도록 자기 식별 |
| `channel` | dev/qa/live 분리. 런처가 어느 채널에 붙어있는지 자기 확인 |
| `latestVersion` | 런처가 "내 설치 버전 vs 최신"을 비교하는 기준 (semver 권장) |
| `buildId` | 같은 버전 안에서도 빌드를 구분 (CI에서 단조 증가) |
| `releasedAt` | 테스터·개발자가 "언제 배포된 빌드인지" 한눈에 확인 |
| `client.<platform>` | 플랫폼별 빌드 메타데이터. 키는 `win64`, `mac`. 런처가 자신의 OS를 보고 해당 객체를 선택 |
| `client.<platform>.downloadUrl` | 런처가 받을 zip의 절대 URL |
| `client.<platform>.sha256` | 무결성 검증 |
| `client.<platform>.sizeBytes` | 런처가 진행률 표시·디스크 사전 검사에 사용 |
| `client.<platform>.executable` | 압축 해제 후 어느 실행파일/번들을 실행할지 (Win: `Rivai.exe`, Mac: `Rivai.app`) |
| `server` | 테스트 서버 접속 정보. 런처가 게임 실행 시 인자로 넘김 |
| `patchNotesUrl` / `feedbackUrl` / `knownIssuesUrl` | 런처 UI 버튼이 직접 사용 |

> 플랫폼 분기 설계 메모: 플랫폼별로 manifest를 분리하지 않고 `client` 안에 객체로 둔 이유는 (1) 새 빌드 배포 시 한 번의 PUT으로 두 플랫폼이 동시에 갱신되어 SSOT가 유지되고, (2) 한쪽 플랫폼 빌드가 빠진 빌드도 키 누락으로 명시적으로 표현할 수 있기 때문이다. 런처는 "내 플랫폼 키가 있나" 확인 후 없으면 "이 빌드는 내 OS 미지원"으로 처리한다.

### Mac zip 압축에 대한 주의 (학습 포인트)

`Rivai.app`은 단일 파일이 아니라 디렉토리(번들)다. macOS 파일에는 일반 zip이 보존하지 못하는 메타데이터(실행 권한, 확장 속성, 심볼릭 링크 등)가 들어있어, Windows에서 만든 zip으로 Mac 앱을 압축하면 풀었을 때 실행이 깨질 수 있다. **Mac 빌드는 Mac에서 압축**하고 가능하면 `ditto`를 쓴다.

```bash
ditto -c -k --sequesterRsrc --keepParent Rivai.app rivai_client_0.0.1_dev_mac.zip
```

또한 사인되지 않은 Mac 앱은 첫 실행 시 Gatekeeper가 막는다. M0에서는 테스터 가이드(B01·F01)에서 "우클릭 → 열기"로 우회한다고 안내하고, 정식 코드 사인·공증(notarization)은 후속 마일스톤에서 다룬다.

## 구현 절차

전제: 옵션 B(Cloudflare R2 + Pages) 채택. 첫 zip은 더미로 파이프라인을 먼저 검증하고, 실제 UE5 BuildCookRun 산출물은 G01에서 연결한다. 타겟 플랫폼은 Windows + Mac.

### Step 1. Cloudflare 계정 만들기

- `https://dash.cloudflare.com/sign-up` 에서 계정 생성. 카드 등록은 R2 무료 한도(월 10GB 저장 + Class A/B 요청) 안에서는 필요 없지만, R2 활성화 시 결제 정보 등록은 요구된다 (한도 초과 전엔 과금 안 됨).
- 이메일 인증 완료.

### Step 2. R2 활성화

- 대시보드 좌측 **R2 Object Storage** → **Enable R2**.
- 결제 정보 등록 (한도 안에서는 청구 0원).
- 학습 포인트: 객체 스토리지가 다른 클라우드 서비스와 별도 활성화 단계를 요구하는 이유는 비용·운영 모델이 다르기 때문이다. 한 번 활성화한 후 추가 버킷은 자유롭게 만들 수 있다.

### Step 3. R2 버킷 생성

- 버킷명: `rivai-dist`.
- Location: Automatic (가까운 region이 자동 선택됨).
- **Public access**를 활성화. 첫 단계에서는 모든 객체가 익명 read 가능해야 한다.
- 학습 포인트: 객체 스토리지의 권한 모델은 일반 파일시스템과 다르다. 익명 read는 ACL 또는 정책으로 **명시적으로** 허용해야 한다. 기본값은 비공개다.

### Step 4. wrangler CLI 설치 + 로그인

- Node.js 20+ 가 있는지 확인: `node --version`
- 전역 설치: `npm i -g wrangler`
- 로그인: `wrangler login` — 브라우저가 열리고 Cloudflare 계정에 권한을 부여하면 로컬에 토큰이 저장된다.
- 확인: `wrangler whoami`
- 학습 포인트: CLI는 내부적으로 Cloudflare API에 HTTPS 요청을 보내고, `wrangler login`은 OAuth 같은 방식으로 API 토큰을 발급받아 로컬에 저장한다. 자동화(CI)에서는 토큰을 환경변수로 주입한다.

### Step 5. R2 public URL 확보

- 대시보드의 버킷 페이지에서 **Public Bucket URL** 확인 → `https://pub-<hash>.r2.dev` 형태.
- 이 URL을 manifest `downloadUrl` 의 베이스로 사용한다. (커스텀 도메인은 M0 이후로 보류.)

### Step 6. 더미 클라이언트 zip 두 개 만들기 (Windows + Mac)

목적: 파이프라인이 동작하는지 검증. 실제 게임 바이너리는 아직 필요 없다.

Windows 더미 (어디서 만들든 무방, 결정론적):

```
rivai_client_0.0.1_dev_win64/
├─ Rivai.exe                  # 더미 (텍스트 파일. 내용: "dummy")
└─ Version.txt                # "0.0.1-dev\n2026.05.17.001"
```

→ 일반 zip으로 압축: `rivai_client_0.0.1_dev_win64.zip`

Mac 더미 (Mac에서 만들어야 함):

```
Rivai.app/
└─ Contents/
   ├─ MacOS/Rivai             # 더미 (텍스트)
   └─ Info.plist              # 최소 plist
Version.txt
```

→ `ditto`로 압축: `ditto -c -k --sequesterRsrc --keepParent rivai_client_0.0.1_dev_mac/ rivai_client_0.0.1_dev_mac.zip`

학습 포인트: 더미라도 디렉토리 구조와 파일명 규칙은 실제 빌드와 동일하게 맞춘다. G01에서 실제 빌드로 교체할 때 파이프라인의 다른 부분이 깨지지 않는다.

### Step 7. sha256과 sizeBytes 계산

- Windows PowerShell: `Get-FileHash -Algorithm SHA256 .\rivai_client_0.0.1_dev_win64.zip`
- macOS: `shasum -a 256 rivai_client_0.0.1_dev_mac.zip`
- 크기: macOS `stat -f%z file.zip` / Windows `(Get-Item file.zip).Length`
- 두 값을 메모해둔다 — manifest에 들어간다.
- 학습 포인트: 해시 계산은 결정론적이라 같은 입력은 어느 OS·어느 시점에 계산해도 같은 결과가 나온다. 그래서 "서버가 적은 값" vs "런처가 직접 계산한 값"을 단순 비교하면 된다.

### Step 8. zip을 R2에 업로드

```bash
wrangler r2 object put rivai-dist/builds/dev/client/win64/rivai_client_0.0.1_dev_win64.zip \
  --file=./rivai_client_0.0.1_dev_win64.zip

wrangler r2 object put rivai-dist/builds/dev/client/mac/rivai_client_0.0.1_dev_mac.zip \
  --file=./rivai_client_0.0.1_dev_mac.zip
```

학습 포인트: 객체 스토리지는 "키(key) = 경로 문자열"인 평면 키-값 구조다. 디렉토리는 시각적 표현일 뿐, 실제로는 슬래시가 포함된 긴 키 이름이다.

### Step 9. manifest.json 작성 후 업로드

- 위의 스키마 예시를 기반으로 `dev.json` 생성. `downloadUrl`, `sha256`, `sizeBytes`를 Step 7/8의 실제 값으로 채운다.
- Content-Type 명시:
  ```bash
  wrangler r2 object put rivai-dist/manifest/dev.json \
    --file=./dev.json \
    --content-type=application/json
  ```
- 학습 포인트: 브라우저·런처가 응답을 어떻게 해석할지는 `Content-Type` 헤더에 의존한다. 객체 스토리지는 이 헤더를 객체 메타데이터로 저장해 응답 시 그대로 돌려준다.

### Step 10. 다운로드 검증 (수동, 두 플랫폼 모두)

- manifest URL에 curl: `curl -fsSL https://pub-<hash>.r2.dev/manifest/dev.json | jq .`
- 응답에서 `client.win64.downloadUrl`, `client.mac.downloadUrl`을 각각 받아 zip 다운로드.
- 받은 zip의 sha256을 계산해 manifest 값과 비교.
- 일치하면 ✅ 파이프라인 성립. 다르면 zip 업로드 직후 manifest의 해시 갱신을 잊었을 가능성이 가장 크다.

## 배포 순서와 안전 규칙

manifest 갱신은 항상 zip 업로드 **이후**에 한다.

```
잘못된 순서                     안전한 순서
1. manifest 먼저 갱신     →    1. 새 zip 업로드 (기존 zip은 그대로)
2. zip 업로드                  2. zip이 다운로드 가능한지 확인
                               3. sha256·sizeBytes 계산
                               4. manifest 갱신 (한 번의 PUT으로)
```

이유: manifest를 먼저 바꾸면 짧은 시간 동안 런처는 "최신은 0.0.2"라고 보는데 zip은 아직 없어서 404가 난다. zip이 먼저 있어야 manifest가 가리키는 URL이 항상 유효하다.

같은 Version은 두 번 업로드하지 않는다. 내용이 바뀌면 새 Version 또는 새 Build ID. 그래야 sha256과 캐시 동작이 일관된다.

## 검증 기준

- [ ] `manifest.json`이 공개 URL에서 200으로 응답한다.
- [ ] `client.win64.downloadUrl`과 `client.mac.downloadUrl`로 각각 zip 다운로드가 성공한다.
- [ ] 다운로드한 두 zip의 sha256이 manifest의 각 `sha256`과 일치한다.
- [ ] `manifest.json`의 `latestVersion`/`buildId`가 패치노트, 홈페이지, 게임 내 Build Version과 일치한다 (다른 Task 완료 후 교차 검증).
- [ ] 배포 순서 규칙을 따랐을 때 manifest가 가리키는 두 zip이 항상 존재한다.
- [ ] Mac zip을 풀었을 때 `Rivai.app` 번들 구조가 유지된다 (`ditto` 또는 동등 도구 사용 확인).
- [ ] 런처/홈페이지가 manifest를 읽어 최신/설치 버전을 비교할 수 있다 (D01, B01에서 검증).

## 학습 체크포인트

다음을 본인 말로 설명할 수 있으면 다음 단계로 넘어가도 좋다.

- [ ] manifest가 없을 때 새 빌드 배포에서 어떤 불일치가 생기는지
- [ ] sha256이 "무결성"엔 쓰이지만 "인증·변조 방지"엔 부족한 이유 (힌트: 누구나 계산할 수 있다)
- [ ] 정적 사이트와 객체 스토리지를 분리하는 이유
- [ ] manifest 갱신을 zip 업로드 이후에 두는 이유
- [ ] 옵션 A(GitHub 통합)와 옵션 B(Cloudflare)의 trade-off
- [ ] 멀티 플랫폼을 하나의 manifest 안에서 분기로 처리하는 이유 (vs 플랫폼별 manifest 분리)
- [ ] Mac `.app` 번들이 단일 파일이 아니라 디렉토리라는 점과, `ditto`로 압축해야 하는 이유

## 산출물

| 산출물 | 설명 |
|---|---|
| R2 버킷 (또는 동등 객체 스토리지) | 클라이언트/서버 zip과 manifest 저장소 |
| `manifest/dev.json` | dev 채널 최신 빌드 메타데이터 |
| `builds/dev/client/<file>.zip` | 첫 클라이언트 빌드 zip (더미여도 됨) |
| sha256 계산·검증 절차 메모 | OS별 명령과 검증 순서 |
| 배포 안전 규칙 메모 | "zip 먼저, manifest 나중" 원칙 |

## 관련 문서

- [[M0]]
- [[B01-homepage-v0|B01 — Homepage v0]]
- [[C01-manual-distribution|C01 — Manual Distribution]]
- [[D01-launcher-v0|D01 — Launcher v0]]
- [[E01-test-server|E01 — Test Server]]
