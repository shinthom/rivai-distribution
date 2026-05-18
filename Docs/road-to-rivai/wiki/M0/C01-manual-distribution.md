---
title: C01 — Manual Distribution
type: task
status: active
---

# C01. Manual Distribution

## 목적

런처가 완성되기 전에도 팀원이 홈페이지에서 클라이언트 zip을 직접 받아 실행하고 피드백을 제출할 수 있게 한다.

이 Task가 완료되면 [[M0]]의 M0.1 Manual Distribution 세부 마일스톤을 만족한다.

## 절차

1. Development 클라이언트 빌드를 만든다.
2. 실행 파일과 필수 파일을 포함한 폴더를 zip으로 압축한다.
3. zip 파일명에 project, client, version, channel을 포함한다.
4. zip을 빌드 저장소에 업로드한다.
5. sha256과 sizeBytes를 계산한다.
6. `manifest.json`과 홈페이지 다운로드 링크를 갱신한다.
7. 새 PC 또는 깨끗한 폴더에서 zip을 내려받아 압축 해제 후 실행한다.
8. 게임 화면에서 Build Version을 확인한다.
9. 피드백 폼에 Build Version과 Build ID를 입력해 샘플 제출한다.

## 검증 기준

- [ ] 팀원이 홈페이지 링크만으로 클라이언트 zip을 다운로드할 수 있다.
- [ ] 압축 해제 후 추가 개발 도구 없이 실행 파일을 열 수 있다.
- [ ] 게임 내 Build Version을 확인할 수 있다.
- [ ] 피드백 폼에 Build Version과 Build ID를 입력할 수 있다.
- [ ] 수동 다운로드 링크의 zip과 manifest 값이 일치한다.

## 산출물

| 산출물 | 설명 |
| --- | --- |
| 수동 배포 zip | 런처 없이 실행 가능한 클라이언트 빌드 |
| 수동 설치 가이드 | 다운로드, 압축 해제, 실행 절차 |
| 샘플 피드백 제출 | 폼이 실제로 수집 가능한지 확인하는 기록 |

## 관련 문서

- [[M0]]
- [[B01-homepage-v0|B01 — Homepage v0]]
- [[A01-manifest-and-build-storage|A01 — Manifest and Build Storage]]
- [[F01-feedback-and-log-loop|F01 — Feedback and Log Loop]]
