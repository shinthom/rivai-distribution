---
title: I01 — Multiplayer Game Content
type: task
status: active
---

# I01. Multiplayer Game Content

## 목적

ThirdPerson template 위에 **Main Menu → Listen Server Host/Join → 같은 맵에서 만남 + 머리 위 닉네임** 흐름을 구축한다. 이 Task가 완료되면 PIE 2-player에서 두 캐릭터가 서로 인식되고, 패키지 빌드에서도 동일 동작이 검증된다.

## 학습 목표

- UE의 GameInstance / PlayerState / PlayerController / GameMode가 각자 어디에 살아남고 무엇을 책임지는가
- **Replicated 변수**와 **Server RPC**의 사용 분기 — 누가 setter, 누가 reader인가
- WidgetComponent를 3D 공간에 부착해 캐릭터 메타데이터를 실시간 표시하는 패턴
- Listen Server 모델의 본질 — 클라이언트 한 명이 동시에 호스트 역할

## 핵심 개념

### 데이터 흐름

```
Main Menu  ─▶ GameInstance.Nickname (영구, 맵 전환에도 살아남음)
              │
              ▼
ThirdPerson 맵 진입 (Host: Open Level "listen" / Join: open IP)
              │
              ▼
PlayerController.BeginPlay (각 client의 local)
   ─▶ Server RPC: Server_SetMyNickname(GI.Nickname)
              │
              ▼ (서버 권위)
PlayerState.Nickname = NewNickname  (Replicated → 모든 client에 자동 전파)
              │
              ▼
BP_RivaiCharacter의 NameTag 위젯이 1초 timer로 PlayerState.Nickname 읽어 표시
```

### 자산 분리 원칙

| 영역 | 자산 | 위치 |
|---|---|---|
| 메뉴·UI | `WBP_MainMenu`, `WBP_NameTag` | `/Game/Rivai/UI/` |
| 플레이어 | `BP_RivaiPlayerState`, `BP_RivaiPlayerController`, `BP_RivaiCharacter` | `/Game/Rivai/Player/` |
| 게임 룰 | `BP_RivaiGameMode`, `BP_MainMenuGameMode` | `/Game/Rivai/GameModes/` |
| 영구 세션 | `BP_RivaiGameInstance` | `/Game/Rivai/Core/` |
| 맵 | `L_MainMenu` (시작), ThirdPerson 맵 (게임) | `/Game/Rivai/Maps/`, `/Game/ThirdPerson/Maps/` |

ThirdPerson template 자산은 손대지 않고, 우리 자산은 모두 `/Game/Rivai/` 아래.

## 결정 요약

| 항목 | 결정 |
|---|---|
| 서버 모델 | Listen Server (호스트 = 첫 클라이언트). 인터넷 너머 만남은 [[L01-ue-source-build\|L01]] 통해 Dedicated로 승격. |
| 로그인 | 닉네임 입력만 (계정·OAuth X) |
| 캐릭터 부모 | ThirdPerson template 캐릭터를 그대로 상속 (`BP_RivaiCharacter`) |
| NameTag 갱신 | 1초 looping timer (PlayerState 늦게 attach되는 경우 자연 복구) |
| Main Menu GameMode | `Default Pawn = None` — 메뉴에서 캐릭터 spawn 안 됨 |

## 검증 기준

- [ ] L_MainMenu가 시작 시 자동 로드되고 닉네임 + Host/Join UI가 보인다.
- [ ] Host → ThirdPerson 맵으로 전환되며 listen server가 시작된다.
- [ ] Join → 입력한 IP의 listen server에 접속한다 (`open IP` 콘솔 명령).
- [ ] PIE Number of Players=2, Net Mode=Standalone에서 두 캐릭터가 같은 맵에 spawn된다.
- [ ] 각 캐릭터 머리 위에 본인 닉네임이 모든 클라이언트에서 동일하게 보인다.
- [ ] 한 쪽 캐릭터의 이동·회전이 다른 쪽에서 동기화 보인다.

## 산출물

| 자산 | 역할 |
|---|---|
| `L_MainMenu` (Empty Level) | 시작 화면, UI 위젯만 띄움 |
| `WBP_MainMenu` | 닉네임 입력 + Host + IP + Join 버튼 |
| `WBP_NameTag` | 캐릭터 머리 위 닉네임 표시 |
| `BP_RivaiGameInstance` | `Nickname:String` 영구 보관 |
| `BP_RivaiPlayerState` | `Nickname:String` Replicated |
| `BP_RivaiPlayerController` | BeginPlay → `Server_SetMyNickname` RPC |
| `BP_RivaiCharacter` | ThirdPerson 자식 + NameTag WidgetComponent |
| `BP_RivaiGameMode` | PlayerController/PlayerState/Pawn 클래스 지정 |
| `BP_MainMenuGameMode` | Default Pawn=None (메뉴 전용) |

## 관련 문서

- [[M0]]
- [[A01-manifest-and-build-storage|A01]] — manifest의 `server.host` 필드가 우리 게임 클라이언트가 접속할 곳
- [[D01-launcher-v0|D01]] — 런처가 manifest 읽어 게임 실행
- [[L01-ue-source-build|L01]] — Listen Server를 Dedicated Server로 승격 (UE source build 필요)
