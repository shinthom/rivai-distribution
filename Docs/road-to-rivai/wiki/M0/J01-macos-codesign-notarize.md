---
title: J01 — macOS Codesign & Notarization
type: task
status: active
---

# J01. macOS Codesign + Notarization + DMG 배포

## 목적

사용자가 portal에서 런처를 받아 더블클릭하면 **xattr 우회 명령 없이 바로 실행되도록** macOS Gatekeeper를 정식으로 통과한다. zip 형식이 quarantine inheritance로 깨지는 문제를 dmg 표준 배포로 해결한다.

## 학습 목표

- Apple의 macOS 배포 3단계 — **Code Sign** → **Notarize** → **Staple** — 각각의 역할
- Gatekeeper가 quarantine xattr을 어떻게 평가하는가, sequoia(15) / macOS 26에서 강화된 정책
- zip 압축 해제 시 `_CodeSignature/` 내부 파일까지 quarantine이 전파되어 서명이 "손상됨"으로 잘못 판정되는 결함
- dmg 마운트 → drag-to-Applications 모델이 quarantine을 .app 전체에만 두는 이유

## 핵심 개념

### 3단계 흐름

```
codesign --deep --options runtime --timestamp
         --sign "Developer ID Application: <Name> (<TeamID>)" App.app
                              │
                              ▼
xcrun notarytool submit App.dmg --keychain-profile <name> --wait
                              │  Apple 서버 검사 (30초~10분)
                              ▼
              Accepted (또는 Invalid + log)
                              │
                              ▼
xcrun stapler staple App.dmg
              (Apple ticket을 dmg에 부착, 오프라인 검증 가능)
                              │
                              ▼
              spctl -a -t open -vv → "accepted, source=Notarized Developer ID"
```

### zip vs dmg

| 형식 | 다운로드 후 동작 |
|---|---|
| zip | 압축 해제 시 모든 entry에 quarantine 상속 → `_CodeSignature/` 내부 파일까지 적용 → Sequoia/26에서 "손상됨" 거부 |
| **dmg** ★ | 마운트하면 .app은 read-only volume 안. Applications으로 drag 복사 → quarantine은 .app 자체에만 → notarized라 정상 처리 |

zip은 정식 사인·공증을 해도 macOS 15+ 에서 깨질 수 있다. **dmg가 정식 배포 형식**이다.

### App-Specific Password vs Keychain Profile

Notarization은 매번 비밀번호 필요. 보안 패턴:

1. **App-Specific Password** 발급 (appleid.apple.com)
2. **한 번만** `xcrun notarytool store-credentials "<profile>"` 로 Keychain에 저장
3. 이후 명령은 `--keychain-profile <profile>` 만 — 비밀번호 노출 없음

## 결정 요약

| 항목 | 결정 |
|---|---|
| 사인 ID | Developer ID Application (개발자 명의, $99/년) |
| Notarization tool | `notarytool` (legacy `altool` 아님) |
| 자격 보관 | Keychain profile `rivai-notary` |
| 배포 형식 | **DMG** (zip 폐기) |
| Tauri 자동 사인 | `tauri.conf.json` 의 `bundle.macOS.signingIdentity` 설정 → `cargo tauri build` 시 .app·.dmg 자동 사인 |

## 검증 기준

- [ ] `spctl -a -t open --context context:primary-signature -vv <dmg>` → `accepted ... source=Notarized Developer ID`
- [ ] `xcrun stapler validate <dmg>` → `The validate action worked!`
- [ ] R2에서 dmg round-trip 다운로드 후 동일 검증 통과
- [ ] 새 macOS 사용자 계정에서 다운 → 더블클릭 → mount → Applications 드래그 → 정상 실행 (xattr 명령 0회)
- [ ] portal의 런처 카드 라벨이 "DMG"로 표시

## 산출물

| 자산 | 역할 |
|---|---|
| Developer ID Application 인증서 (Keychain) | 사인 권한 |
| `rivai-notary` Keychain profile | Notarization 자격 |
| `tauri.conf.json` 의 `bundle.macOS` 섹션 | 자동 사인 설정 |
| Signed + notarized + stapled `Rivai Launcher.dmg` | 배포 산출물 |
| `launcher manifest.mac.format = "dmg"` | portal app.js가 라벨 분기 |

## 운영 규칙

1. **새 런처 빌드마다**: codesign → notarytool submit --wait → stapler staple → R2 업로드. 자동화는 `release-launcher.sh` 확장.
2. **App-Specific Password 회전**: 채팅·외부 노출 시 즉시 https://appleid.apple.com 에서 revoke.
3. **인증서 만료**: Developer ID Application은 5년. 만료 전 갱신 + 신규 사인.

## 관련 문서

- [[M0]]
- [[D01-launcher-v0|D01]] — Tauri 런처 (사인 대상)
- [[B02-patch-notes-and-known-issues|B02]] — Mac 우회 안내 (사인 후엔 불필요)
- [[G01-build-automation-draft|G01]] — `release-launcher.sh` 에 codesign + notarize + staple 단계 통합
