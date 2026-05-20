---
title: L01 — UE Source Build (Linux Native)
type: task
status: active
---

# L01. UE Source Build (Linux Native via EC2)

## 목적

UE Dedicated Server Linux binary를 생성한다. Mac Epic Launcher binary engine은 **Linux target을 제공하지 않으며**, Mac source build에서도 cross-compile은 source-level에서 거부된다. 해결: **EC2 Linux 인스턴스에서 native source build**.

## 학습 목표

- UE의 "binary engine"(Epic Launcher)과 "source engine"(GitHub)의 차이
- Mac binary engine의 Linux target 부재 — Epic의 platform distribution 정책
- Cross-compile vs Native build — host=target일 때 막힘이 사라지는 이유
- AWS EC2 spot/on-demand 큰 인스턴스를 빌드 1회용으로 활용하는 패턴 ($1 미만)
- UE Server Target (`*.Target.cs`) 작성

## 핵심 개념

### Engine distribution 차이

| Distribution | 출처 | 포함 platform (Mac host) | 수정 가능? |
|---|---|---|---|
| Binary (Epic Launcher) | `dmg` installer | Mac, iOS, tvOS, visionOS, Android | ❌ |
| **Source (GitHub)** ★ | clone EpicGames/UnrealEngine | 모든 platform (host에 따라 활성) | ✅ (C++ engine 수정 가능) |

Linux server 빌드는 source engine만 가능.

### Mac에서 Linux cross-compile이 막히는 이유

- UE 5.7 source의 `LinuxPlatformSDK.cs`는 `LINUX_MULTIARCH_ROOT` 환경변수 + InTree SDK path를 본다
- 환경변수 설정 + 정확한 toolchain (v26_clang-20.1.8-rockylinux8) + InTree symlink **모두 했어도** UBT가 `buildable: False`로 거부
- Epic의 macOS host에서 Linux build는 공식 지원되지 않는 시나리오 (Windows/Linux host만 공식)

### Linux Native build가 정답

- host=Linux이므로 SDK detection이 자동 통과
- toolchain은 Ubuntu 표준 (`build-essential`, `clang`)
- Setup.sh가 Linux deps 자연 다운로드

### EC2 1회용 빌더 패턴

- c5.2xlarge (8 vCPU, 16 GB), On-Demand ~$0.38/hr
- 빌드 2시간 → ~$0.77 → AWS Free Plan credit ($120)으로 cover
- 빌드 끝나면 인스턴스 **종료** → 디스크(EBS)만 남기거나 함께 삭제
- 결과 binary (~200 MB)만 추출 → 게임 운영 t2.micro로 rsync

## 결정 요약

| 항목 | 결정 |
|---|---|
| Build host | AWS EC2 **c5.2xlarge** (Seoul, On-Demand, 1회용) |
| UE version | source `5.7.4-release` (shallow clone) |
| 게임 운영 host | 기존 EC2 **t2.micro** (Free Tier 영구) |
| GitHub access | 사용자 Mac의 `gh auth token`을 EC2 git clone에 전달 (1회 사용) |
| Server Target | `Source/RivaiServer.Target.cs` — `Type = TargetType.Server` |
| Build 명령 | `make UnrealEditor` → `RunUAT.sh BuildCookRun -platform=Linux -server` |

## 단계 흐름

```
1. EC2 c5.2xlarge 인스턴스 생성 (Ubuntu 22.04, 100 GB EBS)
2. apt-get install build-essential clang lld libfreetype6-dev libsdl2-dev ...
3. git clone EpicGames/UnrealEngine (branch 5.7.4-release, shallow)
4. ./Setup.sh (~30 min, Linux deps 다운로드)
5. ./GenerateProjectFiles.sh
6. make UnrealEditor -j$(nproc)    (~1~2 h)
7. RunUAT.sh BuildCookRun -platform=Linux -server -build -cook -stage -pak -archive
8. RivaiServer binary 추출 (`Distribution/staging/linux-server/`)
9. rsync → t2.micro (운영 host)
10. EC2 c5.2xlarge 종료 (디스크 보존 또는 삭제)
```

## 검증 기준

- [ ] `Source/RivaiServer.Target.cs` 존재 (Type=Server).
- [ ] EC2에서 `make UnrealEditor` 빌드 성공 (UnrealEditor + UnrealEditor-Cmd binary 생성).
- [ ] `RunUAT BuildCookRun -platform=Linux -server` 가 RivaiServer ELF 생성.
- [ ] `file RivaiServer` → `ELF 64-bit LSB executable, x86-64`.
- [ ] t2.micro에 rsync 후 `./RivaiServer Rivai -log` 로 서버 부팅, 7777 포트 listen.
- [ ] Mac 클라이언트가 `open <ec2-ip>:7777` 로 접속해 캐릭터 spawn + NameTag 동기화.

## 산출물

| 자산 | 위치 |
|---|---|
| UE 5.7.4 source | `<builder>:~/UE_Source/` (빌드 후 인스턴스와 함께 삭제 가능) |
| UnrealEditor + UnrealEditor-Cmd | `~/UE_Source/Engine/Binaries/Linux/` |
| `RivaiServer` ELF + cooked content | `~/UE_Source/<staging>/LinuxServer/` |
| `Source/RivaiServer.Target.cs` | 프로젝트 영구 자산 |
| 운영 t2.micro의 `/opt/rivai-server/` | systemd로 실행 |

## 운영 규칙

- **재빌드 빈도**: 게임 코드/콘텐츠 변경 시. 매번 c5.2xlarge 띄울 필요 없이 EBS 보존하면 2번째부터 1시간 미만.
- **장기 자동화** (G01 확장): GitHub Actions Ubuntu runner + self-hosted UE source 캐시, 또는 EC2 EBS snapshot 기반 fast-start.
- **비용 통제**: Billing Alert 월 $5 셋업. AWS Free Plan credit 소진 모니터링.

## 관련 문서

- [[M0]]
- [[E01-test-server|E01]] — Dedicated Server 호스팅·운영 (이 task의 binary를 받아 실행)
- [[A01-manifest-and-build-storage|A01]] — manifest의 `server.host` 필드 갱신
- [[I01-multiplayer-game-content|I01]] — Server Target이 빌드할 게임 모듈
- [[G01-build-automation-draft|G01]] — 장기 자동화에 본 흐름 통합
