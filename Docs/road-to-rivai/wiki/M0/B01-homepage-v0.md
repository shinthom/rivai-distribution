---
title: B01 — Homepage v0
type: task
status: active
---

# B01. Homepage v0

## 목적

팀원이 별도 설명 없이 홈페이지에서 최신 클라이언트 빌드, 런처, 패치노트, 실행 가이드, Known Issues, 피드백 링크를 찾을 수 있게 한다. 이 Task가 완료되면 [[M0]]의 "홈페이지 v0" 범위와 완료 체크리스트의 홈페이지 관련 항목을 만족한다.

## 학습 목표

이 Task를 마치면 다음을 본인 말로 설명할 수 있어야 한다.

- 정적 사이트가 어떻게 "동적인 정보(최신 빌드)"를 보여줄 수 있는가 (정적 호스팅 + 클라이언트 fetch)
- CORS는 무엇이고, 왜 R2의 manifest를 브라우저에서 fetch할 때 명시적 설정이 필요한가
- `Cache-Control` 헤더가 manifest 갱신 즉시 반영을 좌우하는 이유
- platform 감지를 클라이언트에서 처리하는 방법과 한계

## 배경 — 홈페이지는 manifest의 첫 소비자

[[A01-manifest-and-build-storage|A01]]에서 manifest를 만든 이유는 "모든 소비자가 한 곳을 본다"는 SSOT 원칙이었다. 홈페이지는 그 첫 번째 소비자다.

홈페이지가 manifest를 직접 읽으면:

- 새 빌드 배포 시 manifest만 갱신하면 홈페이지의 "Latest Version" 표시도 자동으로 바뀐다 (HTML 수정·재배포 불필요).
- 다운로드 버튼이 manifest의 `downloadUrl`을 그대로 가리키므로, 빌드 URL이 바뀌어도 manifest 한 줄만 고치면 끝.

이게 "정적 사이트인데도 동적"의 핵심 패턴이다. HTML은 빈 뼈대이고, 브라우저가 manifest를 fetch해서 살을 채운다.

## 핵심 개념

### 1) 정적 사이트는 어떻게 "동적"일 수 있는가

| 분류 | 동작 |
|---|---|
| 서버 측 동적 (SSR) | 매 요청마다 서버가 HTML을 생성. 비용·복잡도 큼. |
| 정적 + 클라이언트 fetch | 빌드 시 HTML은 고정. 브라우저가 로드 후 별도 API/JSON을 fetch해 DOM 업데이트. |

정적 + fetch 패턴은 정적 호스팅(저렴·빠름)의 장점을 유지하면서 데이터 부분만 동적으로 갱신한다. 우리 manifest 패턴과 정확히 맞는다.

### 2) CORS (Cross-Origin Resource Sharing)

브라우저는 보안상 "스크립트가 다른 origin의 응답을 읽는 것"을 기본적으로 막는다. 이게 same-origin policy다.

- 홈페이지 origin: `https://<your-page>.pages.dev`
- manifest origin: `https://pub-<hash>.r2.dev`

두 origin이 다르므로 R2가 응답에 `Access-Control-Allow-Origin` 헤더를 명시적으로 보내야 브라우저 JS가 응답을 읽을 수 있다. 보내지 않으면 fetch는 성공하지만 JS는 응답 본문에 접근하지 못한다 (콘솔에 CORS 에러).

R2 public bucket은 기본적으로 CORS 헤더를 보내지 않는다. `wrangler r2 bucket cors put` 명령으로 명시 설정이 필요하다.

> 학습 포인트: CORS는 서버가 "이 origin에서 와도 좋다"고 허락하는 메커니즘이다. 클라이언트가 우회할 수 없고, 우회해선 안 된다. 보안 모델이 그렇게 설계됐기 때문이다.

### 3) Cache-Control과 manifest 갱신 시점

manifest는 자주 바뀌고, 바뀐 즉시 사용자에게 보여야 한다. 그런데 CDN(Cloudflare 포함)은 응답을 캐시하려는 성질이 있다.

- HTML/CSS/JS: 길게 캐시해도 됨 (`Cache-Control: public, max-age=31536000, immutable` — 파일명에 hash 포함 전제)
- **manifest.json**: 짧게 캐시하거나 캐시하지 않아야 함 (`Cache-Control: no-cache` 또는 `max-age=60`)

manifest를 길게 캐시하면, 우리가 PUT으로 갱신해도 사용자 브라우저는 옛 manifest를 캐시에서 꺼내 본다. "배포했는데 안 보임" 현상의 가장 흔한 원인이다.

### 4) Platform 자동 감지

브라우저에서 사용자 OS를 추정하는 API:

- `navigator.platform` (deprecated, 대체로 동작)
- `navigator.userAgentData.platform` (modern, 일부 브라우저만)
- `navigator.userAgent` 문자열 파싱 (호환성 최고, 정확도 보장 안 됨)

100% 정확하지 않으므로 자동 감지 결과는 **기본 선택을 강조**하는 데만 쓰고, 사용자가 다른 플랫폼도 명시적으로 선택할 수 있게 둔다.

## 구현 선택지

### 프레임워크

| 옵션 | 장점 | 약점 |
|---|---|---|
| **순수 HTML + vanilla JS** | 의존성 0, 학습 부담 없음, 핵심 개념(fetch·DOM)이 그대로 드러남 | 페이지 늘어나면 중복 늘어남 |
| Astro | 컴포넌트화, 마크다운 통합, 정적 출력 우수 | 학습 곡선, 도구 부담 |
| Next.js | 강력하지만 정적 한 페이지에는 과함 | 과한 도구, SSR 기능 미사용 |

**결정: 순수 HTML + vanilla JS**. M0 단계는 "테스터 포털 한 페이지" 수준이라 도구를 더 들이면 핵심 학습 포인트(fetch·CORS·캐시)가 가려진다. 페이지가 늘어나면 Astro 등으로 이전한다.

### 호스팅

**Cloudflare Pages** 확정. R2와 같은 계정·생태계라 wrangler 도구 한 벌로 관리. 무료, 자동 HTTPS, 글로벌 CDN, git 연동 또는 wrangler 수동 배포.

### 도메인

`*.pages.dev` 자동 발급 서브도메인을 그대로 사용. 커스텀 도메인은 A01과 동일하게 M0 이후로 보류.

## 페이지 구조 (와이어프레임)

```
┌────────────────────────────────────────────────────────┐
│ Rivai                                            [Logo] │
├────────────────────────────────────────────────────────┤
│  최신 빌드                                              │
│  ─────────                                              │
│  Version 0.0.1-dev  ·  Build 2026.05.17.001            │
│  배포: 2026-05-17  ·  Server: Test Server 01           │
│                                                         │
│  ┌──────────────────┐  ┌──────────────────┐            │
│  │ Download Windows │  │ Download Mac     │            │
│  │ (1.5 GB)         │  │ (1.6 GB)         │            │
│  └──────────────────┘  └──────────────────┘            │
│  ↑ 자동 감지된 OS는 강조 표시                          │
│                                                         │
│  → 런처 다운로드는 D01 완료 후 별도 카드로 추가        │
├────────────────────────────────────────────────────────┤
│  [Patch Notes]  [Known Issues]  [Install Guide]        │
│  [Log Submit Guide]  [Send Feedback]                   │
└────────────────────────────────────────────────────────┘
```

원칙:

- 첫 화면에서 "어떻게 받지?"가 1초 안에 보여야 한다.
- Version·Build ID는 피드백 폼에서 사용자가 직접 복사하므로 **눈에 잘 보이게** 배치.
- 패치노트·가이드·Known Issues·피드백 링크는 보조 영역. M0 단계엔 외부 URL로 충분.

## 데이터 흐름

```
브라우저가 index.html 로드
  └─ JS가 fetch('https://pub-<hash>.r2.dev/manifest/dev.json')
       └─ R2가 CORS 헤더 포함해 JSON 응답
            └─ JS가 navigator.platform으로 OS 감지
                 └─ DOM 업데이트
                     - Version·Build ID·releasedAt·Server 텍스트
                     - Download 버튼의 href = manifest.client.<os>.downloadUrl
                     - sizeBytes를 GB로 환산해 표시
                     - 감지된 OS 버튼에 .recommended 클래스
```

## 구현 절차

### Step 1. 페이지 스캐폴드

작업 디렉토리는 `Distribution/portal/`. 빈 디렉토리가 이미 있다.

```
Distribution/portal/
├─ index.html
├─ style.css
└─ app.js
```

학습 포인트: 정적 사이트는 빌드 도구 없이도 동작한다. 단순함이 곧 신뢰성이다.

### Step 2. HTML — 빈 뼈대

`index.html`은 데이터 슬롯만 가진 뼈대. 텍스트는 JS가 채운다. 예시 슬롯:

```html
<span data-slot="latestVersion">로딩 중...</span>
<a data-slot="downloadWin64" href="#">Windows 다운로드</a>
<a data-slot="downloadMac" href="#">Mac 다운로드</a>
```

학습 포인트: `data-slot` 같은 data attribute는 JS가 DOM을 찾아 채우는 표준 방식이다. id를 남발하지 않고도 잘 동작한다.

### Step 3. JS — manifest fetch와 DOM 갱신

```js
const MANIFEST_URL = 'https://pub-0ac7d3ef69e344e1bb87f0d1475315cb.r2.dev/manifest/dev.json';

async function load() {
  const res = await fetch(MANIFEST_URL, { cache: 'no-store' });
  if (!res.ok) throw new Error(`manifest fetch failed: ${res.status}`);
  const m = await res.json();

  fill('latestVersion', m.latestVersion);
  fill('buildId', m.buildId);
  fill('releasedAt', formatDate(m.releasedAt));
  fillLink('downloadWin64', m.client.win64?.downloadUrl, sizeLabel(m.client.win64));
  fillLink('downloadMac', m.client.mac?.downloadUrl, sizeLabel(m.client.mac));

  highlightPlatform();
}

function highlightPlatform() {
  const os = detectOS(); // 'win' | 'mac' | 'other'
  const target = document.querySelector(`[data-slot="download${os === 'win' ? 'Win64' : 'Mac'}"]`);
  target?.classList.add('recommended');
}

load().catch(err => showError(err.message));
```

학습 포인트:

- `cache: 'no-store'`로 fetch에 캐시 우회를 명시. 그래도 CDN/브라우저가 캐시할 수 있으므로 서버 측 `Cache-Control`이 진짜 통제 수단.
- `m.client.win64?.downloadUrl`의 optional chaining으로 "특정 플랫폼 빌드가 빠진 경우"를 자연스럽게 처리.
- 에러는 사용자가 볼 수 있게 화면에 표시한다. 콘솔로만 던지면 테스터는 "왜 안 받아져?"만 본다.

### Step 4. CSS — 최소 스타일

테스터 포털 목적이라 화려하지 않게. 가독성·터치 영역만 확보. `.recommended` 클래스는 굵은 테두리나 배경 강조로 시각적 우선순위 부여.

### Step 5. R2 CORS 설정

`Distribution/cors.json`을 만들고 R2 버킷에 적용.

```json
[
  {
    "AllowedOrigins": ["*"],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedHeaders": ["*"],
    "MaxAgeSeconds": 3600
  }
]
```

```bash
wrangler r2 bucket cors put rivai-dist --file=cors.json
```

학습 포인트: `AllowedOrigins: ["*"]`는 누구나 fetch 가능하다는 뜻. 공개 빌드 배포에는 적절. 비공개로 갈 땐 특정 도메인만 허용으로 좁힌다.

### Step 6. manifest 응답에 Cache-Control 추가

manifest 갱신이 즉시 보이게 하려면 R2가 응답에 짧은 캐시 헤더를 주도록 한다.

```bash
wrangler r2 object put rivai-dist/manifest/dev.json \
  --file=manifest/dev.json \
  --content-type=application/json \
  --cache-control="public, max-age=60, must-revalidate"
```

학습 포인트: `max-age=60`이면 CDN/브라우저가 최대 60초 동안만 캐시. 즉시 반영이 필요하면 `no-cache`도 가능하지만, 트래픽이 많아지면 CDN을 활용해야 비용이 통제된다.

### Step 7. Cloudflare Pages 배포

```bash
cd Distribution/portal
wrangler pages deploy . --project-name=rivai-portal
```

처음 실행 시 프로젝트 생성을 묻고, 이후엔 같은 명령으로 새 배포가 만들어진다. 결과로 `https://rivai-portal.pages.dev` 같은 URL이 나온다.

학습 포인트: Pages는 매 배포마다 고유 preview URL(`https://<hash>.rivai-portal.pages.dev`)을 만들고 production URL(`rivai-portal.pages.dev`)이 최신을 가리킨다. 빠른 롤백이 가능하다.

### Step 8. 검증

브라우저로 `https://rivai-portal.pages.dev` 열기:

- Latest Version·Build ID·releasedAt이 표시됨
- Windows·Mac 다운로드 버튼이 manifest URL을 그대로 가리킴
- 자동 감지된 OS 버튼이 강조 표시됨
- 개발자 도구 Network 탭에서 manifest 응답에 `Access-Control-Allow-Origin`과 `Cache-Control` 헤더 확인
- manifest를 갱신하고 60초 후 새로고침하면 새 값이 보임

## 검증 기준

- [ ] 홈페이지에 최신 Version·Build ID·releasedAt·Server 이름이 manifest 값과 일치하게 표시된다.
- [ ] Windows·Mac 다운로드 버튼이 각각 `client.win64.downloadUrl`, `client.mac.downloadUrl`로 연결된다.
- [ ] 자동 감지된 OS의 다운로드 버튼이 시각적으로 강조된다.
- [ ] manifest 응답에 적절한 CORS·Cache-Control 헤더가 붙어 있다.
- [ ] manifest를 갱신하면 60초 이내(또는 강제 새로고침 시) 홈페이지에 반영된다.
- [ ] 패치노트·Known Issues·가이드·피드백 링크가 모두 동작한다 (당분간 placeholder URL이어도 무방).
- [ ] 새 PC의 팀원이 portal URL만으로 다운로드까지 도달 가능하다.

## 학습 체크포인트

다음을 본인 말로 설명할 수 있으면 다음 단계로 넘어가도 좋다.

- [ ] "정적 사이트인데도 최신 버전이 자동으로 갱신되는" 원리
- [ ] CORS가 막는 것과 막지 못하는 것 (보안 모델의 본질)
- [ ] `Cache-Control`을 manifest와 정적 자산에 다르게 설정하는 이유
- [ ] platform 자동 감지의 한계와, 그래서 왜 "강조만, 강제는 아님"으로 두는가
- [ ] R2 public bucket에 CORS를 명시 설정하지 않으면 어떤 증상이 나타나는가

## 산출물

| 산출물 | 설명 |
|---|---|
| `Distribution/portal/{index.html, style.css, app.js}` | 테스터 포털 정적 사이트 |
| Cloudflare Pages 프로젝트 (`rivai-portal`) | 호스팅·HTTPS·CDN |
| `Distribution/cors.json` + 적용된 R2 CORS 정책 | 홈페이지가 manifest를 fetch 가능하게 |
| manifest의 `Cache-Control` 헤더 정책 | 갱신 반영 시점 통제 |
| Production URL | 팀원에게 공유할 단일 진입점 |

## 관련 문서

- [[M0]]
- [[A01-manifest-and-build-storage|A01 — Manifest and Build Storage]]
- [[B02-patch-notes-and-known-issues|B02 — Patch Notes and Known Issues]]
- [[D01-launcher-v0|D01 — Launcher v0]]
- [[F01-feedback-and-log-loop|F01 — Feedback and Log Loop]]
