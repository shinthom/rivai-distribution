# Roadmap

- **Engine:** Unreal Engine 5.7.4 Hotfix
- **Platform:** Windows, Mac
- **Networking:** Dedicated Server + Custom CMC
- **Version:** 1.0.0 (2026-05-17)
- **원칙:** 작게 검증하고, 서버 권위와 피드백 루프를 선제적으로 확보한다.

---

## 마일스톤 매트릭스

모든 산출물은 M0 배포 인프라(런처/manifest)를 통해 즉시 팀에 전파된다.

| MS | 목표 | 검증 질문 | 핵심 산출물 |
| --- | --- | --- | --- |
| **M0** | 빌드 배포·피드백 자동화 | 새 PC에서 자동 업데이트·접속이 가능한가? | 홈페이지, 런처, 테스트 서버, 피드백·로그 수집 |
| **M1** | 지상 이동의 손맛 | Dash 100회를 눌러도 조작감이 유지되는가? | Movement Gym, Debug HUD, Ground Dash |
| **M2** | 공중 통제감 | 공중 대시·낙하가 지상 감각과 이어지는가? | Air Dash, Capsule Trace 벽 감지, 입력 버퍼, 코요테 타임 |
| **M3** | 3차원 입체 기동 | 바닥 없이 벽만으로 맵을 주파할 수 있는가? | Wall Run(카메라 틸트), Wall Jump, 재진입 쿨다운 |
| **M4** | 이동 결합 근접 전투 | 이동·공격·방어·전환의 캔슬 윈도우가 의도대로 동작하는가? | Slash 콤보, Block, Weapon Swap, Dash Attack |
| **M5** | 100ms+ 환경 검증 | 원격 테스터가 로컬과 같은 싱크로 플레이하는가? | Dedicated 동기화, SavedMove 기반 예측 보정 |
| **M6** | 반복 가능한 멀티 게임 루프 | 2~8인이 라운드·스폰·판정 흐름을 끊김 없이 반복할 수 있는가? | Network Polish, Lag Compensation 1차, Match State, Scoreboard |
| **M7** | GunZ-style 멀티 Alpha | Butterfly·Slashshot·Half Step으로 Duel/Small Room이 성립하는가? | Technique Set v1, Weapon Rhythm, Wall Cancel, Duel Map v1 |

### 의존 관계

```
M0 ──► M1 ──► M2 ──► M3 ──► M4 ──► M5 ──► M6 ──► M7
       │
       └─[상시 배포] M0 런처 → manifest.json 갱신만으로 자동 전파
```

---

## 마일스톤 요약

### M0. Test Distribution Pipeline
- **목적:** 개발 속도와 피드백 루프 극대화 (게임성 아님).
- **흐름:** 홈페이지 ➔ 런처 ➔ 자동 패치 ➔ Play ➔ Dedicated 접속 ➔ 인게임 피드백·로그 자동 전송.
- **Sign-off:** *"zip을 직접 안 보내도 되네요."*

### M1. Movement Prototype (Ground)
- **목적:** 고속 대시 손맛과 가속도 분석 기반 확보.
- **핵심:** Movement Gym(점프대·경사·격자), Debug HUD(속도/가속도/입력 이력), 8방향 Ground Dash, 카메라 쉐이크·동적 FOV.
- **구현:** CMC 확장 (`FSavedMove_Character`, Network Move Data, Compressed Flag 패킹).
- **Sign-off:** *"손맛이 좋다, 기본 베이스로 합격."*

### M2. Air Movement
- **목적:** 공중에서 자유로운 궤적 제어.
- **핵심:** Air Dash(횟수 제한·착지 리셋), 4방향 Capsule Trace 벽 감지, 입력 버퍼, 코요테 타임.
- **Sign-off:** `점프 → Air Dash → 착지` 콤보가 끊김 없이 연결될 때.

### M3. Wall Movement
- **목적:** 수직 지형을 활용한 입체 기동.
- **핵심:** Wall Run(중력 감쇠·카메라 틸트), Wall Jump(Normal + 입력 합성 리펄션), 재진입 쿨다운, 표면 재질별 사운드/이펙트 훅.
- **Sign-off:** *"바닥을 안 밟고 벽만으로 맵을 주파한다."*

### M4. Combat & Cancel Window
- **목적:** 속도감을 유지한 채 근접·원거리·방어 유기 전환.
- **핵심:** Melee Slash 콤보(프레임 단위 Cancel Window), Block(FOV·히트스톱), Weapon Swap(딜레이 0), Dash Attack, 콤보별 Trace.
- **Sign-off:** *"공격하며 도망치고, 벽 타며 접근해 칼로 치고 빠지는 플레이가 연계된다."*

### M5. Network Validation
- **목적:** 100ms+ 환경에서 M1~M4 액션이 싱크를 유지하는지 검증.
- **핵심:** Dedicated 전수 재검증, Server Reconciliation 보간 튜닝, 30/80/150/250ms 핑 시뮬, 서버 권위 기초 레이어, 4v4·8v8 스트레스 테스트.
- **Sign-off:** *"로컬 연습과 같은 판정으로 체감된다."*

### M6. Network Polish & Playable Loop
- **목적:** 가능성 검증을 반복 가능한 멀티 게임 루프로 전환.
- **핵심:** Correction Budget, Lag Compensation 1차, Hit Validation Audit, 라운드/스폰/리스폰, Scoreboard, 2~8인 30분 테스트.
- **Sign-off:** *"방을 만들고 라운드를 반복해도 이동·전투·판정 흐름이 유지된다."*

### M7. GunZ-style Tech & Multiplayer Game Alpha
- **목적:** GunZ와 같은 메커니즘을 활용한 고속 이동·캔슬·무기 리듬 완성.
- **핵심:** Butterfly, Slashshot, Half Step, Reload Shot, Wall Cancel, Weapon Rhythm, Duel Map v1.
- **Sign-off:** *"테스터가 GunZ-style 테크닉으로 접근하고, 피하고, 쏘고, 막으며 Duel을 반복한다."*

---

## 기술 스택

### 확정
- **Engine:** UE 5.7.4 Hotfix 고정.
- **Movement:** Custom `UCharacterMovementComponent` — `FSavedMove_Character` / `FCharacterNetworkMoveData` 확장 검증.
- **Networking:** 표준 Replication + RPC + Dedicated Server.
- **Language:** Core C++, 튜닝만 Blueprint.
- **Input:** Enhanced Input System.

### 보류 (M5 이후 재평가)
- **Mover 2.0** — Experimental. CMC로 속도 확보 후 별도 브랜치 비교.
- **Iris Replication** — Beta. 표준 Replication 한계 시 Opt-in.
- **Gameplay Ability System** — 초기엔 경량 커스텀 컴포넌트. M4~M5 전환기 재검토.

### Out of Scope (M8 이전)
- 계정·매치메이킹·상점·랭킹·커스터마이즈.
- Nanite Foliage, PCG, Substrate, MetaHuman — 회색 블록과 더미 애니메이션만 사용.

---

## 리스크 매트릭스

| 리스크 | 영향 | 대응 |
| --- | --- | --- |
| 고속 이동 예측 실패 | Rubber-banding | `SavedMove`에 속도·가속도·플래그 정밀 패킹, HUD에 오차 실시간 표시 |
| 벽 Trace 불일치 | 클라/서버 위치 어긋남 | Collision Channel 통일, Trace 주기·서버 틱 동기화 |
| 전투·이동 보정 충돌 | 히트 미스 판정 | M4부터 서버 검증 로그 강제, 판정창 완충지대, M6에서 Lag Compensation 1차 |
| Cancel Window 남용 | 무한 콤보·상태머신 붕괴 | `Cancel Rule Table` 데이터테이블 중앙 제어 |
| Reliable RPC 남발 | 패킷 손실·입력 딜레이 | 이동·콤보는 Unreliable/Movement 플래그, 중대 이벤트만 Reliable |
| GunZ-style 테크닉 규칙화 실패 | 원작 손맛 부재·버그성 플레이 | M7에서 Technique Set v1과 Weapon Rhythm을 명시적 데이터로 관리 |

---

## 포스트 마일스톤 (M8~M10)

```
M8  External Playtest Readiness
    ─ Steam Playtest 연동, 안티치트, Telemetry, Crash/Disconnect 추적

M9  Content & Balance Beta
    ─ 정식 규격 맵 2~3종, 무기·방어 밸런싱, 튜토리얼·훈련장

M10 Live Ops Foundation
    ─ 계정·매치메이킹·랭킹·서버 운영 자동화
```

---

## 게이트 리뷰 (각 마일스톤 종료 시)

1. Sign-off를 정량/정성적으로 충족했는가?
2. 다음 단계로 즉시 넘어가도 안전한가, 스테이징이 필요한가?
3. 발견된 문제로 다음 마일스톤 Scope 수정이 필요한가?
4. 기술 스택 결정에 변경이 필요한가? (CMC 한계 → Mover/Iris 조기 검토 등)
5. 이번에 무엇을 배웠는가? — 즉시 `Patch Notes`에 영구 기록.
