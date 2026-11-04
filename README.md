# APB GPIO UVM Verification

직접 설계한 **APB GPIO**를, 직접 만든 **APB UVM VIP([apb-uvm-vip](https://github.com/kwondo99/apb-uvm-vip))의 Master Agent**로 구동하여 검증한 프로젝트이다.
GPIO 핀 쪽은 별도의 **GPIO Agent**를 만들어 외부 장치 역할(입력 구동)과 핀 관찰(출력 검증)을 수행한다.

**사용 언어:** SystemVerilog, UVM
**사용 tool:** VCS, Verdi

## 검증 대상 (DUT)

| 항목 | 내용 |
|------|------|
| 버스 | AMBA APB4 Completer (Wait state 1) |
| 핀 | `inout io_port[GPIO_WIDTH-1:0]` (기본 16bit) |
| 입력 동기화 | `gpio_i_reg` 1단 (IDR은 1 사이클 전 핀 값) |

| Offset | 이름 | Access | 설명 |
|--------|------|--------|------|
| 0x00 | OE | RW | 방향 (1 = Output) |
| 0x04 | I  | RO | 핀 입력 값 (Output 핀은 자기가 내보낸 값) |
| 0x08 | O  | RW | 출력 값 |

- Write는 `PSTRB` Byte 단위로 반영
- `PSLVERR = 1` : I(0x04)에 Write, 0x00/0x04/0x08 외 주소 접근

## UVM Verification Environment

```
                         ┌──────────────── apb_gpio_env ─────────────────┐
                         │                                                │
 apb_gpio_virtual_seq ──▶│ v_sqr ─┬─▶ master_agt (apb-uvm-vip) ──APB──┐   │
                         │        │     └ mon ──┬─▶ scb.master_imp      │   │
                         │        │             └─▶ cov                 ▼   │
                         │        │                              [ apb_gpio ]
                         │        └─▶ gpio_agt ─────io_port───────────▲   │
                         │              └ mon ──┬─▶ scb.gpio_imp          │
                         │                      └─▶ g_cov                 │
                         └────────────────────────────────────────────────┘
```

| 구성 | 출처 | 내용 |
|------|------|------|
| `apb_master_agent` (driver/monitor/sequencer), `apb_item`, `apb_master_if` | apb-uvm-vip | 재사용 (아래 2가지만 수정) |
| `apb_gpio_master_sequence` | 신규 | GPIO 레지스터 접근 시나리오 |
| `gpio_agent` (if/item/driver/monitor/sequence) | 신규 | 외부 입력 구동 + 핀 관찰 |
| `apb_gpio_scoreboard` | 신규 | GPIO 레지스터 Reference Model 기반 체크 |
| `apb_gpio_coverage`, `gpio_coverage` | 신규 | APB 접근 / 핀 상태 Functional Coverage |

VIP의 Slave Agent는 실제 DUT가 Slave 역할을 하므로 사용하지 않는다.

### VIP Master 수정 사항

| 파일 | 수정 | 이유 |
|------|------|------|
| `apb_master_monitor.sv` | `PSLVERR` 수집 추가 | 기존 Monitor는 PSLVERR를 담지 않아 DUT 에러 응답을 검증할 수 없음 |
| `apb_master_monitor.sv` | 리셋 해제(`@(posedge preset_n)`) 후 샘플링 시작 | GPIO Monitor와 같은 클럭부터 보내야 Scoreboard FIFO에서 클럭 단위로 짝이 맞음 |
| `apb_master_if.sv`, `apb_master_monitor.sv` | Monitor 전용 Clocking Block(`mon_cb`) 추가, `@(vif.cb)` 후 raw 신호 대신 `vif.mon_cb.*`로 샘플링 | raw 신호를 클럭 이벤트 직후 읽으면 DUT의 posedge 갱신 **전/후 값 중 무엇이 읽힐지 보장되지 않음(race)**. Dummy DUT(조합 연결)에서는 드러나지 않았지만, PREADY를 플립플롭으로 만드는 실제 DUT에서는 Transfer 완료 사이클의 PREADY를 놓칠 수 있음 |

### GPIO Agent

- **Driver** : `gpio_in`을 랜덤 값으로 `DELAY`(1~9) 사이클씩 구동
- **Monitor** : 매 사이클 외부에서 보이는 `io_port`(핀 값)와 `gpio_in`(외부 입력)만 샘플링 (`mon_cb` Clocking Block). DUT 내부 신호는 수집하지 않음
- **외부 장치 모델 (tb_top)** : DUT가 Output으로 쓰는 핀은 `'z`로 놓아 버스 충돌을 막고, Input 핀에만 `gpio_in`을 구동
  - 이를 위해서만 tb_top에서 `dut.gpio_oe`를 `gpio_if.dut_oe`로 연결 (Monitor / Scoreboard는 사용하지 않음)
  - tri-state 구동은 tb_top의 `io_port` wire에서 DUT와 함께 수행하고, `gpio_if.io_port`는 그 값을 관찰만 함
    (interface 내부 wire를 여러 모듈이 tri-state로 구동하면 시뮬레이터에 따라 해석이 달라질 수 있어 모듈 레벨로 둠)

## Scoreboard (Reference Model)

DUT 내부 신호는 보지 않고, **APB로 Write한 값만으로** 기대값을 계산한다.

| 단계 | 입력 | 체크 | 기대값 |
|------|------|------|--------|
| (1) | APB Monitor : OE / O Write | Model 갱신 (PSTRB Byte 단위, 에러 응답 시 갱신 안 함) | - |
| (2) | GPIO Monitor : `io_port` (매 사이클) | - | - |
| (3) | O Write 직후 첫 핀 샘플 | 출력 핀에 O 값이 나왔는지 | `io_port & OE == O & OE` |
| (4) | APB Read (PWRITE = 0) | PRDATA | OE / O : Model 값 |
| (5) | GPIO Monitor : 랜덤 `gpio_in` (매 사이클) | - | - |
| (6) | 매 사이클 | 출력 핀은 O, 입력 핀은 gpio_in | `io_port == (O & OE) \| (gpio_in & ~OE)` |
| (7) | I Read | PRDATA | 1 사이클 전 (6)의 기대 io_port |

공통 체크

| 체크 | 시점 | 기대값 |
|------|------|--------|
| PSLVERR | Transfer 완료 (`PSEL & PENABLE & PREADY`) | 주소/방향으로 계산한 에러 여부 |
| PSLVERR 비정상 구동 | 매 사이클 | Transfer 완료가 아닌 사이클에 PSLVERR = 0 |
| Fault Injection | 매 사이클 | PSEL = 0, PENABLE = 1 횟수 리포트 (이후 Read로 레지스터 유지 확인) |

### 처리 순서

두 Monitor가 같은 posedge에 `write()`를 호출하지만 호출 순서는 보장되지 않는다.
→ Scoreboard가 두 Monitor를 `uvm_tlm_analysis_fifo`로 받아두고, `run_phase`에서 매 클럭 **GPIO → APB** 순서로 꺼내 처리한다.

```
forever begin
  g_fifo.get(g_tr);  m_fifo.get(m_tr);   // 같은 클럭의 두 샘플
  check_gpio(g_tr);                      // (2)(3)(5)(6)
  check_apb(m_tr);                       // (1)(4)(7)
end
```

| 순서를 고정해서 얻는 것 | 이유 |
|---|---|
| Write가 끝난 클럭의 핀 샘플은 항상 **갱신 전 Model**로 계산 | GPIO를 먼저 처리하고, APB Write로 Model 갱신은 그 다음 |
| I Read는 `exp_prev`(1 클럭 전 기대 io_port)와 비교 | 이번 클럭 GPIO 처리에서 `exp_prev = exp_cur; exp_cur = 이번 값` 이 항상 먼저 일어남 |

- 시각(`$time`) 비교 없이 처리 순서만으로 타이밍을 맞춤
- 전제 : 두 Monitor 모두 리셋 해제 후 매 클럭 1개씩 전송 (그래서 APB Monitor도 `@(posedge preset_n)` 후 시작하도록 수정)
- I는 관찰한 핀 값이 아니라 Model로 계산한 값과 비교하므로, 핀 출력(6)과 I 경로(7)를 서로 독립적으로 검증

## Sequence 시나리오

`apb_gpio_virtual_sequence`가 아래 순서로 실행한다.

| 단계 | APB (master_agt) | GPIO (gpio_agt) |
|------|------------------|-----------------|
| 1 | `apb_gpio_reg_rw_seq` : OE/O Write → Read-back (50회) | `gpio_pattern_seq` : 0000/FFFF/AAAA/5555 |
|   | `apb_gpio_strb_seq` : 랜덤 PSTRB Write → Read-back (50회) | |
| 2 | `apb_gpio_idr_seq` : OE(전체 In/전체 Out/혼합) 설정 후 IDR 10회 Read (20회) | `gpio_random_seq` : 랜덤 입력 |
|   | `apb_gpio_err_seq` : I Write, 미정의 주소 접근 후 Read로 값 유지 확인 (30회) | |
|   | `apb_gpio_random_seq` : 주소/방향/PSEL 랜덤, Fault Injection 포함 (300회) | |

- 각 단계 끝에 `apb_gpio_idle_seq`로 PSEL/PENABLE을 내려 버스를 IDLE로 되돌림
  (VIP master driver는 마지막 전송 후 PSEL/PENABLE을 유지하기 때문)
- GPIO 시퀀스는 `stop` 플래그로 종료 (`disable fork`로 끊으면 driver가 아이템을 잡은 채 종료되어 item_done 에러 발생)

## 검증 결과

| Test | Write (OE / O) | Read | PSLVERR | Fault Injection | (3) O Write 체크 | (4) Transfer 체크 | (6) 핀 체크 | (7) I Read 체크 | 결과 |
|------|----------------|------|---------|-----------------|------------------|-------------------|-------------|-----------------|------|
| `apb_gpio_base_test` | 100 (50 / 50) | 100 | 0 | 0 | 50 | 200 | 413 | 0 | PASS (UVM_ERROR 0) |
| `apb_gpio_virtual_test` | 353 (99 / 113) | 403 | 158 | 174 | 113 | 756 | 2223 | 202 | PASS (UVM_ERROR 0) |

### 버그 주입 확인

Scoreboard가 실제로 오류를 검출하는지 확인하기 위해 DUT에 버그 3개를 넣고 `apb_gpio_virtual_test`를 실행했다.

| 주입한 버그 | 검출한 체크 |
|-------------|-------------|
| I(0x04) Write 시 PSLVERR를 내지 않음 | `PSLVERR mismatch` 34건 |
| OE Write가 PSTRB를 무시하고 전체 Byte를 씀 | (4) OE Read 불일치 12건, (3) O Write 후 출력 불일치 21건, (6) 핀 불일치 550건 |
| I(0x04) Read 시 핀 값 대신 O 레지스터 반환 | (7) I Read 불일치 199건 |

결과: (3) 21건, (4) 12건, (6) 550건, (7) 199건, PSLVERR 34건 → TEST FAILED

## Directory Structure

```
.
├── README.md
├── rtl
│   └── apb_gpio.v
├── sim
│   └── Makefile
└── src
    ├── common
    │   ├── apb_gpio_defines.svh        # GPIO_WIDTH, 레지스터 주소
    │   ├── apb_gpio_pkg.sv
    │   ├── apb_gpio_tb_top.sv
    │   ├── apb_gpio_env.sv
    │   ├── apb_gpio_test.sv
    │   ├── apb_gpio_scoreboard.sv
    │   ├── apb_gpio_coverage.sv
    │   ├── apb_gpio_virtual_sequencer.sv
    │   ├── apb_gpio_virtual_sequence.sv
    │   └── apb_item.sv                 # apb-uvm-vip
    ├── master                          # apb-uvm-vip master agent
    │   ├── apb_master_if.sv
    │   ├── apb_master_agent.sv
    │   ├── apb_master_driver.sv
    │   ├── apb_master_monitor.sv       # PSLVERR 수집 추가
    │   ├── apb_master_sequencer.sv
    │   └── apb_gpio_master_sequence.sv # GPIO용 시퀀스 (신규)
    └── gpio
        ├── gpio_if.sv
        ├── gpio_item.sv
        ├── gpio_driver.sv
        ├── gpio_monitor.sv
        ├── gpio_agent.sv
        ├── gpio_sequence.sv
        └── gpio_coverage.sv
```

## 실행방법

```
cd sim

# 전체 시나리오 (기본값: apb_gpio_virtual_test)
make all

# 레지스터 Read/Write만
make all UVM_TESTNAME=apb_gpio_base_test

# 로그 상세 출력
make all UVM_VERBOSITY=UVM_HIGH

# Coverage 리포트 확인 (Verdi)
make coverage
```

`GPIO_WIDTH`를 바꿀 때는 `src/common/apb_gpio_defines.svh`의 값만 수정한다 (8의 배수).
