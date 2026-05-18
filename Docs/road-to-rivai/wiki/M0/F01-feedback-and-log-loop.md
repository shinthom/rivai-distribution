---
title: F01 — Feedback and Log Loop
type: task
status: active
---

# F01. Feedback and Log Loop

## 목적

테스터 피드백이 Build Version, 재현 절차, 로그와 함께 수집되도록 하여 개발자가 발생 버전을 추적하고 재현할 수 있게 한다.

이 Task가 완료되면 [[M0]]의 M0.4 Feedback Loop 세부 마일스톤과 피드백·로그 관련 완료 체크리스트를 만족한다.

## 절차

1. Google Form, Notion, Discord 중 피드백 수집 도구를 하나 선택한다.
2. 폼 필드를 `Tester Name`, `Build Version`, `Build ID`, `Test Date`, `PC Spec`, `Ping`, `What did you test`, `Bug/Feedback Type`, `Steps to Reproduce`, `Expected Result`, `Actual Result`, `Screenshot URL`, `Log Attached`로 만든다.
3. 게임 또는 런처에서 Build Info 복사 기능을 제공한다.
4. 런처에서 Open Logs 버튼으로 클라이언트 Logs 폴더를 열게 한다.
5. 로그 파일 첨부 또는 업로드 방식의 최소 절차를 문서화한다.
6. 샘플 버그 리포트를 제출해 필드가 실제 분석에 충분한지 확인한다.
7. 개발자가 Build Version과 Build ID로 피드백을 필터링할 수 있게 한다.

## 검증 기준

- [ ] 피드백 폼에 Build Version과 Build ID 필드가 있다.
- [ ] 피드백 폼에 재현 절차와 Expected/Actual Result 필드가 있다.
- [ ] 테스터가 Logs 폴더를 열 수 있다.
- [ ] Build Info 복사 결과가 폼에 붙여넣기 가능한 형식이다.
- [ ] 샘플 피드백 1건 이상이 제출되어 수집 위치에서 확인된다.
- [ ] 개발자가 발생 버전 기준으로 피드백을 추적할 수 있다.

## 산출물

| 산출물 | 설명 |
| --- | --- |
| 피드백 폼 | 버그, 조작감, 네트워크 피드백 수집 |
| 로그 제출 가이드 | 클라이언트 Logs 폴더 찾기와 첨부 방법 |
| Build Info 형식 | Version, Build ID, 서버, PC 정보를 포함한 복사 텍스트 |
| 샘플 리포트 | 실제 분석 가능한 제출 예시 |

## 관련 문서

- [[M0]]
- [[B01-homepage-v0|B01 — Homepage v0]]
- [[D01-launcher-v0|D01 — Launcher v0]]
- [[E01-test-server|E01 — Test Server]]
