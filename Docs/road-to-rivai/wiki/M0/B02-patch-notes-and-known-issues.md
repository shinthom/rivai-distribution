---
title: B02 — Patch Notes and Known Issues
type: task
status: active
---

# B02. Patch Notes and Known Issues

## 목적

빌드별 변경 사항과 알려진 문제를 남겨 테스터가 무엇을 테스트해야 하는지 알 수 있게 하고, 개발자가 피드백 발생 버전을 추적할 수 있게 한다. 이 Task가 완료되면 [[M0]]의 "패치노트" 범위와 "패치노트 자동 기록" 검증의 수동 기준을 먼저 만족하고, [[B01-homepage-v0|B01]] manifest의 `patchNotesUrl`·`knownIssuesUrl`이 placeholder에서 실제 페이지로 교체된다.

## 학습 목표

이 Task를 마치면 다음을 본인 말로 설명할 수 있어야 한다.

- 패치노트가 "변경 기록"과 "테스트 가이드"라는 두 역할을 동시에 하는 이유
- Known Issues가 패치노트와 분리되어야 하는 이유 (갱신 주기와 수명이 다름)
- 패치노트 URL에 version을 박는 vs `latest` alias를 두는 패턴의 trade-off
- 단순 HTML 직접 작성에서 시작해 마크다운 자동화로 진화하는 점진적 설계의 가치

## 배경 — 패치노트는 누가, 언제 읽는가

세 부류의 독자가 있다.

| 독자 | 시점 | 알고 싶은 것 |
|---|---|---|
| 테스터 | 빌드 받기 직전 | "이번 빌드에서 뭐가 바뀌었지? 뭘 중점적으로 봐야 하지?" |
| 개발자 | 피드백 받은 후 | "이 버그가 생긴 빌드가 어떤 거였더라?" |
| 미래의 나 | 회고 시점 | "이 시점에 우리가 뭘 결정했었지?" |

각각이 원하는 정보가 다르므로 한 페이지에 모두 담되 **섹션을 명확히 구분**해야 한다. 변경 사항·수정 사항·Known Issues·테스트 초점이 그 섹션이다.

## 핵심 개념

### 1) 패치노트의 두 역할

- **변경 기록(Changelog)**: 어떤 빌드에서 무엇이 바뀌었나. 시간 순으로 누적.
- **테스트 가이드(Test Focus)**: 이번 빌드의 테스터가 어디를 봐야 하나. 빌드 단위로 사라짐.

두 역할을 한 페이지에 두되, "Changes / Fixes / Test Focus" 같이 섹션으로 분리한다. 섹션 이름을 일관되게 두면 자동 파싱·자동 알림에도 활용된다.

### 2) Known Issues는 왜 분리되는가

같은 페이지에 두기 쉬운 유혹이 있지만, 두 정보의 **수명**이 다르다.

- 패치노트: 빌드별. 한 번 작성하면 그 빌드의 영구 기록.
- Known Issues: 현재 살아있는 이슈 목록. 다음 빌드에서 고쳐지면 사라짐.

같은 페이지에 두면 "이 빌드의 Known Issues"가 빌드가 지나도 그대로 남아 혼란을 준다. 별도 페이지(`/known-issues/`)에 두고 항상 **현재 채널의 미해결 이슈**만 표시한다. 해결되면 다음 패치노트의 "Fixes" 섹션에 옮겨 적는다.

### 3) URL 패턴: version vs latest alias

| 패턴 | 예시 | 장점 | 약점 |
|---|---|---|---|
| Version 박힌 URL | `/patch-notes/0.0.1/` | 영구 링크. 피드백 폼에서 "어느 빌드 패치노트인지" 명확 | manifest의 `patchNotesUrl`을 매번 새 값으로 갱신해야 함 |
| `latest` alias | `/patch-notes/latest/` | 홈페이지 링크가 고정 | 시간이 지나면 "이 URL이 가리키던 빌드"를 잃음 |
| 둘 다 | `/patch-notes/0.0.1/` + `/patch-notes/latest/` redirect | 두 장점 모두 | redirect 관리 한 번 더 |

**결정: 둘 다 사용**. 패치노트는 영구 URL을 두고, `latest`는 가장 최신 패치노트로 리다이렉트. manifest의 `patchNotesUrl`은 영구 URL을 사용해 "이 빌드 패치노트"임을 명확히 한다.

### 4) 단순 HTML → 마크다운 자동화로의 진화

M0에서는 패치노트가 1~2개라 HTML을 직접 쓰는 게 가장 단순하다. 그러나 빌드가 10개를 넘으면 직접 작성은 부담이다. **단순함 → 자동화** 순서로 가는 것이 학습에 좋다.

- M0.4 (지금): HTML 직접 작성. 빌드 도구 없음. 일관된 템플릿 유지.
- G01 (빌드 자동화): 패치노트 마크다운 → HTML 변환 스크립트. CI에서 자동 생성.

이렇게 가면 "왜 자동화가 필요한지" 직접 체감한 뒤 도입하게 되어, 자동화의 트레이드오프(빌드 도구 학습 비용)에 대해 납득이 생긴다.

## 구현 선택지

### 호스팅 위치

| 옵션 | 장점 | 약점 |
|---|---|---|
| **portal 같은 Pages 프로젝트 내부** | 같은 도메인·디자인·HTTPS. portal CSS 재사용 | 패치노트 갱신 시 portal 재배포 필요 |
| 별도 Pages 프로젝트 | 독립 배포 | 도메인 분리, 디자인 동기화 부담 |
| R2 raw 파일 | 가장 단순 | 다운로드로 보임. 브라우저 렌더 X. 디자인 X |

**결정: portal 내부**. URL이 `rivai-portal.pages.dev/patch-notes/0.0.1/`이 되어 일관됨. wrangler pages deploy 한 번에 portal·패치노트가 함께 갱신.

### 소스 형식

| 옵션 | 장점 | 약점 |
|---|---|---|
| **HTML 직접 작성** | 빌드 도구 0. M0의 단순함 원칙 유지 | 작성 부담. 변경 시 깜빡 누락 위험 |
| 마크다운 + 빌드 스크립트 | 작성이 가벼움. CI 친화 | 빌드 도구 학습·도입 부담 |

**결정: HTML 직접 작성** (M0 단계). G01에서 마크다운 자동화로 진화.

## 디렉토리·URL 구조

`Distribution/portal/` 안에 다음을 추가한다.

```
Distribution/portal/
├─ index.html                        # 기존 (B01)
├─ style.css                         # 기존
├─ app.js                            # 기존
├─ patch-notes/
│  ├─ index.html                     # 전체 목록
│  ├─ latest/
│  │  └─ index.html                  # → 0.0.1로 redirect (meta refresh)
│  └─ 0.0.1/
│     └─ index.html                  # 빌드별 패치노트
└─ known-issues/
   └─ index.html                     # 현재 dev 채널 미해결 이슈
```

배포 후 URL:

- `rivai-portal.pages.dev/patch-notes/` — 전체 목록
- `rivai-portal.pages.dev/patch-notes/0.0.1/` — 특정 빌드 (영구)
- `rivai-portal.pages.dev/patch-notes/latest/` — 최신으로 redirect (홈에서 빠르게 보고 싶을 때)
- `rivai-portal.pages.dev/known-issues/` — 현재 살아있는 이슈

## 패치노트 템플릿

각 빌드 패치노트는 다음 섹션을 반드시 가진다. 섹션 이름·순서는 모든 패치노트에서 동일.

```
1. Header
   - Version, Build ID, 배포일, 채널
   - manifest 값과 정확히 일치

2. Test Focus  (이번 빌드에서 우선 확인할 것 — 5줄 이내)

3. Changes  (새 기능·신규 동작)

4. Fixes  (수정된 버그)

5. Known Issues at Release  (배포 시점에 알려진 문제 — 보통은 /known-issues 로 위임)

6. Footer
   - 피드백 폼 링크
   - 이전 빌드 패치노트 링크
```

원칙:

- **빌드 한 번 = 패치노트 한 개**. 작은 변경이라도 새 빌드면 새 패치노트.
- **manifest와 1:1 매칭**. Version·Build ID가 manifest의 값과 정확히 일치해야 함.
- **사용자 언어로**. 내부 코드명·티켓 번호 노출은 최소화.

## Known Issues 운영 규칙

- `known-issues/index.html`은 항상 **현재 채널의 미해결 이슈**만 보여준다.
- 각 이슈에 등록일·발견 빌드·영향 범위·우회 방법(있다면)을 표기.
- 이슈가 해결되면 known-issues에서 제거하고, 다음 빌드의 패치노트 "Fixes"로 옮긴다.
- 신규 이슈가 발견되면 즉시 known-issues에 추가 (다음 빌드 기다리지 말 것).
- known-issues는 패치노트와 다르게 **수시 갱신**된다.

## 구현 절차

### Step 1. 패치노트 0.0.1 페이지 작성

`Distribution/portal/patch-notes/0.0.1/index.html`에 위 템플릿 따라 작성. portal의 `style.css`를 `../../style.css`로 링크해 디자인 일관성 유지.

학습 포인트: 정적 페이지지만 brand 헤더·footer·CSS는 같다. 페이지 늘면 공통 부분을 include하고 싶어진다 — 그게 빌드 도구를 도입할 때다.

### Step 2. `latest/` redirect 작성

`patch-notes/latest/index.html`에 meta refresh redirect.

```html
<!doctype html>
<meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=../0.0.1/">
<link rel="canonical" href="../0.0.1/">
<title>Redirecting…</title>
<p><a href="../0.0.1/">최신 패치노트로 이동</a></p>
```

학습 포인트: 정적 호스팅에서 redirect는 보통 (1) HTML meta refresh, (2) 호스팅 측의 `_redirects` 파일 두 방법이 있다. meta refresh가 도구 독립적이고 단순.

### Step 3. 전체 목록 페이지 작성

`patch-notes/index.html`에 빌드 목록을 정적으로 나열. M0에서는 항목 1~2개라 손으로 충분.

### Step 4. Known Issues 페이지 작성

`known-issues/index.html`에 현재 dev 채널의 미해결 이슈 목록. M0.1 첫 배포 시점에는 "현재 알려진 문제 없음" 또는 더미 zip 관련 한두 줄로 시작.

### Step 5. manifest 갱신

`patchNotesUrl`과 `knownIssuesUrl`을 placeholder에서 실제 URL로 교체.

```json
"patchNotesUrl": "https://rivai-portal.pages.dev/patch-notes/0.0.1/",
"knownIssuesUrl": "https://rivai-portal.pages.dev/known-issues/"
```

R2에 다시 PUT (Cache-Control 헤더 포함).

### Step 6. portal 재배포

`wrangler pages deploy .` 한 번으로 portal·패치노트·known-issues가 함께 갱신.

### Step 7. 검증

- 홈에서 "Patch Notes" 버튼이 0.0.1 페이지로 이동
- "Known Issues" 버튼이 known-issues 페이지로 이동
- `/patch-notes/latest/`가 0.0.1로 redirect
- 패치노트의 Version·Build ID가 manifest 값과 정확히 일치
- 새로고침 60초 후 portal에서 갱신된 manifest의 링크가 반영됨

## 배포 사이클과의 통합

새 빌드 배포 절차에 패치노트 단계가 끼어든다 (G01에서 자동화 대상).

```
1. 새 빌드 zip 만들기 (G01 자동화 전엔 수동)
2. zip을 R2에 업로드 + sha256·sizeBytes 기록
3. patch-notes/<new-version>/index.html 작성       ← 이 Task에서 추가
4. patch-notes/index.html에 새 빌드 추가           ← 이 Task에서 추가
5. patch-notes/latest/index.html의 redirect 대상 갱신  ← 이 Task에서 추가
6. known-issues 갱신 (해결된 항목 제거, 신규 항목 추가)  ← 수시
7. manifest의 latestVersion·buildId·downloadUrl·patchNotesUrl 갱신 후 PUT
8. wrangler pages deploy로 portal·patch-notes 함께 배포
```

학습 포인트: 배포가 8단계로 늘어났다. 이게 바로 G01(빌드 자동화)이 필요한 이유다. 수동으로 몇 번 해보고 G01에서 스크립트로 묶는다.

## 검증 기준

- [ ] `patch-notes/0.0.1/` 페이지가 200으로 응답하고 Version·Build ID·배포일·Test Focus·Changes·Fixes·Footer 섹션을 모두 포함한다.
- [ ] `patch-notes/0.0.1/`의 Version·Build ID가 manifest 값과 정확히 일치한다.
- [ ] `patch-notes/latest/`가 `patch-notes/0.0.1/`로 redirect 된다.
- [ ] `patch-notes/`(인덱스)에서 0.0.1 빌드를 클릭해 패치노트로 이동할 수 있다.
- [ ] `known-issues/` 페이지가 200으로 응답하고 현재 채널의 이슈를 보여준다.
- [ ] manifest의 `patchNotesUrl`·`knownIssuesUrl`이 placeholder가 아닌 실제 URL을 가리킨다.
- [ ] portal 홈에서 "Patch Notes"·"Known Issues" 버튼이 60초 이내(또는 강제 새로고침 시) 새 URL로 이동한다.

## 학습 체크포인트

다음을 본인 말로 설명할 수 있으면 다음 단계로 넘어가도 좋다.

- [ ] 패치노트와 Known Issues를 같은 페이지에 두면 어떤 운영 혼란이 생기는지
- [ ] 패치노트 URL을 version 박힌 영구 링크로 두는 이유 (피드백 추적 관점)
- [ ] `latest` alias가 주는 이득과, 그게 없다면 사용자 동선이 어떻게 달라지는지
- [ ] M0에서 HTML 직접 작성 → G01에서 마크다운 자동화로 진화시키는 단계적 설계의 의미
- [ ] 새 빌드 배포 절차가 왜 자동화 대상이 되는지

## 산출물

| 산출물 | 설명 |
|---|---|
| `Distribution/portal/patch-notes/0.0.1/index.html` | 빌드별 패치노트 (영구 URL) |
| `Distribution/portal/patch-notes/latest/index.html` | 최신으로 redirect |
| `Distribution/portal/patch-notes/index.html` | 전체 빌드 목록 |
| `Distribution/portal/known-issues/index.html` | 현재 채널 미해결 이슈 |
| 갱신된 `manifest/dev.json` | `patchNotesUrl`·`knownIssuesUrl` 실제 URL |
| 갱신된 배포 절차 메모 | 새 빌드 배포 시 패치노트 갱신 단계 포함 |

## 관련 문서

- [[M0]]
- [[A01-manifest-and-build-storage|A01 — Manifest and Build Storage]]
- [[B01-homepage-v0|B01 — Homepage v0]]
- [[G01-build-automation-draft|G01 — Build Automation Draft]]
- [[F01-feedback-and-log-loop|F01 — Feedback and Log Loop]]
