---
title: H01 — End-to-End Validation
type: task
status: active
---

# H01. End-to-End Validation

## 목적

새 PC 기준으로 홈페이지에서 시작해 런처 설치, 최신 빌드 실행, 테스트 서버 접속, Build Version 확인, 피드백·로그 제출까지 전체 흐름을 검증한다.

이 Task가 완료되면 [[M0]]의 완료 한 줄과 최종 완료 체크리스트를 실제 사용자 흐름으로 검증한다.

## 절차

1. 테스트에 사용할 새 PC 또는 깨끗한 Windows/Mac 사용자 환경을 준비한다.
2. 홈페이지 링크만 전달받은 상태에서 시작한다.
3. 홈페이지에서 런처를 다운로드한다.
4. 런처를 실행해 manifest를 읽는지 확인한다.
5. Download/Update로 최신 빌드를 설치한다.
6. Play로 게임을 실행한다.
7. 게임 화면에서 Build Version을 확인한다.
8. 테스트 서버에 접속한다.
9. 2인 이상 접속 테스트를 실행한다.
10. 런처 또는 게임에서 Build Info를 복사한다.
11. Logs 폴더를 열고 로그 파일 위치를 확인한다.
12. 피드백 폼에 Build Info, 재현 절차, 로그 정보를 포함해 제출한다.
13. 개발자가 제출된 피드백과 로그를 확인한다.

## 검증 기준

- [ ] 홈페이지에서 런처 다운로드가 가능하다.
- [ ] 런처가 manifest를 읽고 최신/설치 버전을 표시한다.
- [ ] 런처가 다운로드, sha256 검증, 압축 해제, 실행을 완료한다.
- [ ] 게임 화면에 Build Version이 표시된다.
- [ ] `Version.txt` 또는 동등한 Build Info가 설치 빌드에 포함된다.
- [ ] 클라이언트가 테스트 서버에 접속한다.
- [ ] 2인 이상이 동시에 접속한다.
- [ ] Open Logs와 Copy Build Info가 동작한다.
- [ ] 피드백 폼 제출 결과에 Build Version, Build ID, 재현 절차, 로그 정보가 포함된다.
- [ ] 새 PC에서 홈페이지부터 피드백 제출까지 중간 수동 개발자 개입 없이 완료된다.

## 산출물

| 산출물 | 설명 |
| --- | --- |
| E2E 테스트 기록 | 새 PC에서 전체 흐름을 수행한 증거 |
| 제출된 샘플 피드백 | 개발자가 확인 가능한 테스트 리포트 |
| 발견 이슈 목록 | M0 완료 전 해결하거나 Known Issues로 공개할 항목 |

## 관련 문서

- [[M0]]
- [[B01-homepage-v0|B01 — Homepage v0]]
- [[D01-launcher-v0|D01 — Launcher v0]]
- [[E01-test-server|E01 — Test Server]]
- [[F01-feedback-and-log-loop|F01 — Feedback and Log Loop]]
