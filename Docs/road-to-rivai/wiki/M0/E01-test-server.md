---
title: E01 — Test Server
type: task
status: active
---

# E01. Test Server (Dedicated, 자동 접속)

## 목적

팀원이 portal에서 런처를 받고 더블클릭 → Play 한 번으로 **즉시 서버에 접속해 다른 팀원과 만나도록** 한다. Listen Server의 호스트 의존성·NAT 통과 부담을 제거하고, 사용자가 어떤 추가 셋업도 안 하게.

이 Task가 끝나면 [[M0]]의 M0.3 Test Server 마일스톤을 만족하고, *받자마자 곧바로 테스트*라는 사용자 의도를 달성한다.

## 학습 목표

이 Task를 마치면 다음을 본인 말로 설명할 수 있어야 한다.

- Listen Server와 Dedicated Server의 본질적 차이 (누가 시뮬레이션 권한을 가지는가)
- UE Server Target이 클라이언트 Target과 다른 점 (render 모듈 제외, headless)
- Linux cross-compile toolchain이 왜 필요한가 (macOS에서 Linux ELF 생성)
- Oracle Cloud Always Free Ampere A1의 위치와 한계
- systemd로 게임 서버를 데몬화하는 표준 패턴
- 게임 클라이언트에 server 정보를 전달하는 방법 (commandline vs hardcoded vs manifest fetch)

## 배경 — Listen에서 Dedicated로 가는 이유

Listen Server는 셋업 비용 0이지만 다음 한계가 명확하다.

1. **호스트가 항상 켜둬야 함** — 호스트 = 사용자. 사용자가 게임을 끄면 서버도 꺼짐.
2. **인터넷 너머 만남 불가능** — NAT 통과를 위해 호스트가 라우터 포트 포워딩 또는 VPN 셋업 필요. 모든 팀원에게 부담.
3. **권위가 한 클라이언트에** — 그 클라이언트의 네트워크·HW가 게임 전체 경험을 좌우. 호스트의 패킷이 가장 적게 흐름 (cheating 가능성).

Dedicated Server는 위 셋을 모두 해결한다.

1. 서버가 클라우드에 항상 떠있음 → 누가 접속해도 만남.
2. 서버의 public IP/도메인이 알려져 있어 NAT 부담은 클라이언트 측 outgoing connection만 (대부분 자동 통과).
3. 클라이언트는 모두 동등한 client. 서버 권위 명확.

대가: 서버 빌드 + 클라우드 호스팅 + 운영. M0 단계에선 Oracle Cloud Always Free로 비용 0원 가능.

## 핵심 개념

### 1) Server Target vs Game Target

UE 프로젝트는 여러 "Target"을 가진다. 각 Target은 빌드 산출물 한 종류를 정의:

| Target | 용도 | render 모듈 | UI 모듈 | 산출물 |
|---|---|---|---|---|
| `Rivai` (Game) | 클라이언트 | ✅ | ✅ | Rivai.exe / Rivai.app |
| `RivaiEditor` | 에디터 | ✅ | ✅ | UnrealEditor + Rivai 로드 |
| **`RivaiServer` (Server)** | Dedicated 서버 | ❌ headless | ❌ | RivaiServer (binary) |

Server Target은 grade/PhysX는 있지만 render를 제외 → 작고 가벼움. 클라우드 VM에서 GPU 없이 동작.

### 2) Cross-compile (Linux 빌드 from macOS)

Oracle Cloud Ampere A1 = ARM Linux. 우리 개발 머신은 ARM macOS. 같은 ARM이지만 OS·toolchain이 달라 binary 호환 안 됨.

Epic이 제공하는 **Linux cross-compile toolchain** (clang based)을 macOS에 설치 → `RunUAT.sh BuildCookRun -platform=Linux -server` 명령 한 번으로 Linux ELF 생성. 우리는 Linux VM이나 docker 불필요.

UE 5.7 toolchain 버전: `v23_clang-18.1.0-rockylinux8` (구체 버전 확인 후 다운로드).

### 3) Oracle Cloud Always Free Ampere A1

- ARM Ampere CPU (4 OCPU, 24GB RAM 무료 영구)
- Ubuntu 22.04 또는 24.04 ARM 이미지
- 가입 시 신용카드 인증 필요하나 **명시 동의 없이는 영구 0원**
- region: Asia 가까운 곳 선택 (Tokyo, Singapore, Seoul)
- 한계: 모든 사용자가 노리는 무료 자원이라 가끔 capacity 없음 (재시도)

### 4) systemd 데몬화

게임 서버는 24/7 떠있어야 한다. SSH 세션 끊겨도 살아있게:

- systemd unit 파일(`/etc/systemd/system/rivai-server.service`)에 ExecStart, Restart=always
- `systemctl enable rivai-server` → 부팅 시 자동 시작
- `systemctl status rivai-server` → 상태 확인
- `journalctl -u rivai-server -f` → 로그 streaming

### 5) 클라이언트가 server 정보를 받는 방법

세 가지 후보:

| 방법 | 장점 | 약점 |
|---|---|---|
| **런처가 commandline 인자 전달** ★ | manifest 변경 시 게임 재빌드 X. 런처가 manifest fetch. | 게임 시작 코드 변경 필요 |
| 게임 빌드에 server 정보 hardcoded | 단순 | manifest 변경 = 게임 재빌드 |
| 게임이 자체 manifest fetch | manifest 갱신 즉시 반영 | 게임에 HTTP·JSON 코드 추가 |

**결정: 런처 commandline**. 런처는 이미 manifest를 fetch하고 있고, 게임 spawn 시 인자 전달이 자연스럽다.

흐름:
```
런처: launcher.json 또는 manifest fetch → server.host:port 추출
     → open -a Rivai.app --args -ServerAddr=test.rivai.example:7777 -Nickname=alpha

게임: GameInstance.Init → commandline 파싱 → GameInstance.Nickname 저장 + ServerAddr 저장
    → Open Level Console Command "open ServerAddr"
    → Dedicated server에 client 모드로 접속

서버: GameMode.PostLogin → 새 PlayerController → BeginPlay → Server_SetMyNickname RPC
    → PlayerState.Nickname 갱신 (replicated)
```

## 구현 선택지

이미 사용자 결정 (옵션 A):
- **호스팅**: Oracle Cloud Always Free Ampere A1 (Ubuntu ARM)
- **클라이언트 흐름**: Play 한 버튼 (Host/Join UI 제거, 메뉴는 닉네임 입력 + Play만)

남은 결정 (구현 단계에서):
- 도메인: 처음에는 raw IP. 안정화 후 `test.rivai.example` 같은 서브도메인 추가.
- region: Asia (Seoul/Tokyo) — Oracle이 가용 시점에 따라.
- 서버 자동 재시작 정책: systemd Restart=always (장애 시 자동 복구).

## 디렉토리·구성 변경 요약

### UE 프로젝트 변경

```
Rivai/
├─ Source/
│  ├─ Rivai.Target.cs                # 기존 (클라이언트)
│  ├─ RivaiEditor.Target.cs          # 기존
│  └─ RivaiServer.Target.cs          # 신규 — Dedicated Server Target
├─ Content/Rivai/
│  ├─ UI/WBP_MainMenu                # 변경 (Play 한 버튼)
│  └─ Core/BP_RivaiGameInstance      # 변경 (commandline 파싱)
```

### 우리 인프라

```
Distribution/
├─ scripts/
│  └─ release-server.sh              # 신규 — 서버 빌드 → VM 배포 자동화
└─ launcher/src-tauri/src/lib.rs     # launch_game이 server/nickname commandline 전달
```

### 운영 환경 (Oracle Cloud VM)

```
/opt/rivai-server/
├─ RivaiServer                       # ELF binary
├─ Rivai/Content/...                 # cooked content
└─ Rivai/Saved/Logs/                 # 로그
/etc/systemd/system/rivai-server.service
```

## 구현 절차 (큰 5단계)

### Phase 1. UE Server Target 추가 + 로컬 Linux 빌드 (제가 + 사용자)

1. `Source/RivaiServer.Target.cs` 생성 (제가)
2. UE Linux cross-compile toolchain 다운로드 + 환경변수 설정 (사용자)
3. `RunUAT.sh BuildCookRun -platform=Linux -server` (사용자, 30분 ~ 1시간 첫 빌드)
4. 결과 binary 위치 확인

### Phase 2. Oracle Cloud VM 셋업 (사용자)

1. 계정 생성 + Always Free 자격 확인
2. Ampere A1 ARM VM 생성 (Ubuntu 22.04, 4 OCPU, 24GB RAM)
3. SSH key 등록 + 첫 SSH 접속
4. Security List + ufw에 7777 UDP/TCP 허용
5. 기본 패키지 설치 (`libssl`, `libstdc++`)

### Phase 3. 서버 배포 (제가 + 사용자)

1. `release-server.sh` 작성 (제가)
2. rsync로 binary + content를 VM에 업로드
3. systemd unit 파일 작성 + 활성화
4. 서버 시작 + `journalctl`로 로그 확인
5. `manifest/dev.json`의 `server` 필드 갱신 (host, port)

### Phase 4. 클라이언트 흐름 단순화 (제가)

1. `WBP_MainMenu`의 Host/Join/IpInput 제거, **Play 버튼**만 (BP 변경, prompt로)
2. `BP_RivaiGameInstance.Init` — commandline 파싱, ServerAddr·Nickname 저장
3. Play 버튼 OnClicked — `open <ServerAddr>` 콘솔 명령
4. `release-launcher.sh` 단계에서 launcher.json에 server 정보 저장
5. Tauri 런처의 `launch_game` Rust 함수 — server·nickname 인자 전달

### Phase 5. 새 빌드 + 검증

1. 클라이언트 재패키지 (Mac, 0.2.0-dev)
2. release-game.sh로 R2 배포
3. 런처에서 Update → Play → 자동 서버 접속
4. 다른 머신(또는 다른 사용자 계정)에서 같은 흐름 → 두 명 만남
5. 인터넷 너머 (다른 네트워크 환경) 검증

## 검증 기준

- [ ] `Source/RivaiServer.Target.cs` 존재, Type=TargetType.Server.
- [ ] Linux ARM64 server binary가 빌드된다.
- [ ] Oracle Cloud VM에 서버가 systemd로 떠 있고, 부팅 시 자동 시작.
- [ ] 7777 포트가 VM 외부에서 접근 가능 (`nc -zv <ip> 7777`).
- [ ] 클라이언트 빌드의 Play 버튼이 자동으로 서버에 접속한다 (Host/Join 입력 0).
- [ ] 서로 다른 네트워크의 두 클라이언트가 동시에 같은 서버에서 만난다.
- [ ] 서버 로그에서 클라이언트 접속·퇴장 이벤트가 보인다.
- [ ] 서버 재시작 시 자동 복구된다 (Restart=always 검증).

## 학습 체크포인트

다음을 본인 말로 설명할 수 있으면 다음 단계로.

- [ ] Server Target이 Game Target과 다른 모듈을 포함/제외하는 이유
- [ ] cross-compile이 우리 시간을 어떻게 절약하는가 (Linux VM·docker 우회)
- [ ] systemd의 `Restart=always`가 운영에서 주는 안정성
- [ ] commandline 인자로 server 정보를 전달하는 패턴이 manifest 변경을 어떻게 게임 재빌드 없이 처리하는가
- [ ] Oracle Cloud Always Free의 "Always Free"가 의미하는 것과 그 한계 (capacity, region)

## 산출물

| 산출물 | 설명 |
|---|---|
| `Source/RivaiServer.Target.cs` | Dedicated Server Target |
| Linux ARM64 server binary | `RivaiServer` ELF (cross-compiled) |
| Oracle Cloud VM | Ubuntu 22.04, 24GB RAM, 7777 open |
| `/etc/systemd/system/rivai-server.service` | 서버 데몬화 |
| `Distribution/scripts/release-server.sh` | 빌드·배포 자동화 |
| 갱신된 `manifest/dev.json` (server.host/port) | 실제 도메인/IP |
| 단순화된 `WBP_MainMenu` (Play 한 버튼) | 사용자 UX |
| 단순화된 Tauri 런처 (commandline 인자 전달) | 받자마자 곧바로 |

## 관련 문서

- [[M0]]
- [[A01-manifest-and-build-storage|A01 — Manifest and Build Storage]]
- [[D01-launcher-v0|D01 — Launcher v0]]
- [[G01-build-automation-draft|G01 — Build Automation Draft]]
- [[F01-feedback-and-log-loop|F01 — Feedback and Log Loop]]
- [[H01-end-to-end-validation|H01 — End-to-End Validation]]
