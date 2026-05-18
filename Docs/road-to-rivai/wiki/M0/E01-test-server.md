---
title: E01 — Test Server
type: task
status: active
---

# E01. Test Server

## 목적

팀원이 같은 고정 테스트 서버에 접속해 네트워크 플레이와 서버 로그를 확인할 수 있게 한다.

이 Task가 완료되면 [[M0]]의 M0.3 Test Server 세부 마일스톤과 테스트 서버 관련 완료 체크리스트를 만족한다.

## 절차

1. M0.1에서는 Listen 서버 허용 여부를 결정하고, M0.3부터 Dedicated 서버를 목표로 둔다.
2. 테스트 서버 이름, host, port를 확정한다.
3. 서버 빌드 산출물 위치와 실행 명령을 문서화한다.
4. 방화벽과 포트 접근 가능 여부를 확인한다.
5. `manifest.json`의 `server` 필드에 서버 정보를 기록한다.
6. 클라이언트에서 테스트 서버 접속 UI 또는 콘솔 명령을 제공한다.
7. 2인 이상 동시 접속을 테스트한다.
8. 서버 로그 위치와 수집 절차를 문서화한다.

## 검증 기준

- [ ] 테스트 서버 주소와 port가 문서화되어 있다.
- [ ] manifest의 서버 정보가 실제 접속 정보와 일치한다.
- [ ] 런처로 실행한 클라이언트가 테스트 서버에 접속할 수 있다.
- [ ] 2인 이상이 동시에 접속할 수 있다.
- [ ] 서버 로그 위치와 보관 절차가 문서화되어 있다.
- [ ] 접속 실패 시 테스터가 보고할 최소 정보가 정리되어 있다.

## 산출물

| 산출물 | 설명 |
| --- | --- |
| 테스트 서버 | 팀원이 접속하는 고정 서버 |
| 서버 접속 문서 | host, port, 접속 방법 |
| 서버 로그 문서 | 로그 위치와 수집 방법 |
| 서버 빌드 산출물 | Dedicated 또는 Listen 서버 운영 파일 |

## 관련 문서

- [[M0]]
- [[A01-manifest-and-build-storage|A01 — Manifest and Build Storage]]
- [[F01-feedback-and-log-loop|F01 — Feedback and Log Loop]]
- [[H01-end-to-end-validation|H01 — End-to-End Validation]]
