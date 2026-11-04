// =============================================================================
// APB GPIO Scoreboard (Reference Model)
//
//  DUT 내부 신호(dut_oe 등)는 보지 않고, APB로 Write한 값만으로 기대값을 계산한다.
//
//  (1) APB monitor  : OE / O 레지스터에 Write한 값을 받아 Model에 저장
//  (2) GPIO monitor : io_port(핀 값)를 매 사이클 수신
//  (3) O Write 직후 : 저장된 OE Model에 따라 io_port가 O 값을 정상 출력하는지 확인
//  (4) PWRITE = 0   : PRDATA가 레지스터 Model 값과 같은지 확인
//  (5) GPIO monitor : 랜덤 gpio_in(외부 입력)을 매 사이클 수신
//  (6) 매 사이클    : OE Model에 따라 출력 핀은 O, 입력 핀은 gpio_in이 io_port에 나오는지 확인
//                     기대 io_port = (O & OE) | (gpio_in & ~OE)
//  (7) I Read       : 1 사이클 전 기대 io_port 값과 PRDATA 비교
//
//  [처리 순서]
//  두 monitor는 같은 posedge에 write()를 호출하지만 호출 순서는 보장되지 않는다.
//  -> analysis FIFO에 받아두고, run_phase에서 매 클럭 "GPIO -> APB" 순서로 꺼내 처리한다.
//     * GPIO를 먼저 처리 : 이번 클럭 핀은 Write 반영 전 Model로 계산됨
//     * APB를 나중 처리  : I Read 시 exp_prev가 항상 1 클럭 전 기대 핀 값
//  (두 monitor 모두 리셋 해제 후 매 클럭 1개씩 보내므로 FIFO에서 클럭 단위로 짝이 맞음)
// =============================================================================
class apb_gpio_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(apb_gpio_scoreboard)

  uvm_tlm_analysis_fifo #(apb_item)  m_fifo;
  uvm_tlm_analysis_fifo #(gpio_item) g_fifo;

  // Register Model (APB Write로만 갱신)
  bit          [`GPIO_WIDTH-1:0] oe_model;
  bit          [`GPIO_WIDTH-1:0] o_model;

  // (3) O Write 직후 핀 확인 대기
  bit                            o_check_pending;

  // (7) I Read 기대값 : 클럭마다 이전 값으로 밀어냄
  bit          [`GPIO_WIDTH-1:0] exp_cur;  // 이번 클럭 기대 io_port
  bit          [`GPIO_WIDTH-1:0] exp_prev;  // 1 클럭 전 기대 io_port

  // APB
  int unsigned                   m_write, m_read, m_slverr, m_pass, m_fail;
  int unsigned                   oe_write, o_write;
  int unsigned                   fault_injection;
  bit                            fault_flag;
  // (3) O Write 후 핀 확인
  int unsigned                   o_chk_pass, o_chk_fail;
  // (6) 매 사이클 핀 확인
  int unsigned                   pin_pass, pin_fail;
  // (7) I Read 확인
  int unsigned                   i_pass, i_fail;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    oe_model        = 0;
    o_model         = 0;
    o_check_pending = 0;
    exp_cur         = 0;
    exp_prev        = 0;
    m_write         = 0;
    m_read          = 0;
    m_slverr        = 0;
    m_pass          = 0;
    m_fail          = 0;
    oe_write        = 0;
    o_write         = 0;
    fault_injection = 0;
    fault_flag      = 0;
    o_chk_pass      = 0;
    o_chk_fail      = 0;
    pin_pass        = 0;
    pin_fail        = 0;
    i_pass          = 0;
    i_fail          = 0;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    m_fifo = new("m_fifo", this);
    g_fifo = new("g_fifo", this);
  endfunction

  // 매 클럭 GPIO -> APB 순서로 처리
  task run_phase(uvm_phase phase);
    apb_item  m_tr;
    gpio_item g_tr;
    forever begin
      g_fifo.get(g_tr);
      m_fifo.get(m_tr);
      check_gpio(g_tr);  // (2)(3)(5)(6)
      check_apb(m_tr);  // (1)(4)(7)
    end
  endtask

  // ---------------------------------------------------------------------------
  // Reference Model
  // ---------------------------------------------------------------------------
  function bit exp_err(apb_item tr);
    bit addr_valid;
    addr_valid = (tr.PADDR == `ADDR_OE) || (tr.PADDR == `ADDR_I) || (tr.PADDR == `ADDR_O);
    return (!addr_valid || (tr.PWRITE && tr.PADDR == `ADDR_I));
  endfunction

  // (1) OE / O Write 값을 Model에 저장 (PSTRB Byte 단위)
  function void model_write(apb_item tr);
    for (int b = 0; b < `GPIO_WIDTH / 8; b++) begin
      if (tr.PSTRB[b]) begin
        if (tr.PADDR == `ADDR_OE) oe_model[b*8+:8] = tr.PWDATA[b*8+:8];
        if (tr.PADDR == `ADDR_O) o_model[b*8+:8] = tr.PWDATA[b*8+:8];
      end
    end
    if (tr.PADDR == `ADDR_OE) begin
      oe_write++;
      `uvm_info("SCB", $sformatf("(1) OE model update : oe = %h", oe_model), UVM_MEDIUM)
    end else begin
      o_write++;
      o_check_pending = 1;  // (3) 다음 클럭 핀 샘플에서 출력 확인
      `uvm_info("SCB", $sformatf("(1) O model update : o = %h (oe = %h)", o_model, oe_model),
                UVM_MEDIUM)
    end
  endfunction

  // ---------------------------------------------------------------------------
  // GPIO side : (2)(5) io_port / gpio_in 수신, (3)(6) 핀 출력 확인
  // ---------------------------------------------------------------------------
  function void check_gpio(gpio_item tr);
    bit [`GPIO_WIDTH-1:0] exp_pin;

    `uvm_info("SCB", $sformatf(
              "Get item from GPIO Monitor : io_port = %h, gpio_in = %h", tr.IO_PORT, tr.GPIO_IN),
              UVM_HIGH)

    // (6) 출력 핀은 O, 입력 핀은 gpio_in (이번 클럭 APB Write 반영 전 Model)
    exp_pin  = (o_model & oe_model) | (tr.GPIO_IN & ~oe_model);

    // (7) I Read용 기대값 : 이전 값을 밀어내고 이번 값 저장
    exp_prev = exp_cur;
    exp_cur  = exp_pin;

    // (3) O Write 다음 클럭 : 출력 핀에 O 값이 나왔는지 확인
    if (o_check_pending) begin
      o_check_pending = 0;
      if ((tr.IO_PORT & oe_model) === (o_model & oe_model)) begin
        o_chk_pass++;
        `uvm_info("G_SCB", $sformatf(
                  "(3) PASS O write : oe = %h, o = %h, io_port = %h", oe_model, o_model, tr.IO_PORT),
                  UVM_MEDIUM)
      end else begin
        o_chk_fail++;
        `uvm_error("G_SCB", $sformatf(
                   "(3) FAIL O write : oe = %h, exp output = %h, got = %h",
                   oe_model,
                   o_model & oe_model,
                   tr.IO_PORT & oe_model
                   ))
      end
    end

    // (6) 매 사이클 전체 핀 확인
    if (tr.IO_PORT === exp_pin) begin
      pin_pass++;
    end else begin
      pin_fail++;
      `uvm_error("G_SCB", $sformatf(
                 "(6) FAIL pin : oe = %h, o = %h, gpio_in = %h, exp io_port = %h, got = %h",
                 oe_model,
                 o_model,
                 tr.GPIO_IN,
                 exp_pin,
                 tr.IO_PORT
                 ))
    end
  endfunction

  // ---------------------------------------------------------------------------
  // APB side : (1) Model 갱신, (4) PRDATA 확인, (7) I Read 확인
  // ---------------------------------------------------------------------------
  function void check_apb(apb_item tr);
    bit        err;
    bit [31:0] exp_rdata;

    `uvm_info("SCB", $sformatf(
              "Get item from Master Monitor : paddr = %h, psel = %b, penable = %b, pwrite = %b, pwdata = %h, pstrb = %b, pready = %b, prdata = %h, pslverr = %b",
              tr.PADDR,
              tr.PSEL,
              tr.PENABLE,
              tr.PWRITE,
              tr.PWDATA,
              tr.PSTRB,
              tr.PREADY,
              tr.PRDATA,
              tr.PSLVERR
              ), UVM_HIGH)

    // Fault Injection (PSEL = 0 에서 PENABLE = 1) : DUT는 응답하지 않아야 함
    if (!tr.PSEL && tr.PENABLE) begin
      if (!fault_flag) begin
        fault_injection++;
        `uvm_info("M_SCB", $sformatf("Fault injection detected"), UVM_HIGH)
      end
      fault_flag = 1;
    end else begin
      fault_flag = 0;
    end

    // PSLVERR는 Transfer 완료 사이클에서만 High
    if (tr.PSLVERR && !(tr.PSEL && tr.PENABLE && tr.PREADY)) begin
      m_fail++;
      `uvm_error("M_SCB", $sformatf("PSLVERR is High outside transfer completion"))
    end

    // Transfer 완료 시점
    if (!(tr.PSEL && tr.PENABLE && tr.PREADY)) return;

    err = exp_err(tr);

    if (tr.PSLVERR !== err) begin
      m_fail++;
      `uvm_error("M_SCB", $sformatf(
                 "PSLVERR mismatch : paddr = %h, pwrite = %b, exp = %b, got = %b",
                 tr.PADDR,
                 tr.PWRITE,
                 err,
                 tr.PSLVERR
                 ))
      return;
    end

    if (err) m_slverr++;

    // (1) Write : 에러가 아니면 OE / O Model 갱신
    if (tr.PWRITE) begin
      m_write++;
      if (!err) model_write(tr);
      m_pass++;
      return;
    end

    // (4) Read : PRDATA 확인
    m_read++;
    if (err) begin
      m_pass++;  // 에러 응답 시 PRDATA는 정의되지 않으므로 비교하지 않음
      return;
    end

    exp_rdata = 0;
    case (tr.PADDR)
      `ADDR_OE: exp_rdata[`GPIO_WIDTH-1:0] = oe_model;
      `ADDR_O:  exp_rdata[`GPIO_WIDTH-1:0] = o_model;
      `ADDR_I:  exp_rdata[`GPIO_WIDTH-1:0] = exp_prev;  // (7) I = 1 클럭 전 기대 io_port
    endcase

    if (tr.PRDATA === exp_rdata) begin
      m_pass++;
      if (tr.PADDR == `ADDR_I) i_pass++;
      `uvm_info("M_SCB", $sformatf(
                "%s PASS read : paddr = %h, prdata = %h",
                (tr.PADDR == `ADDR_I) ? "(7)" : "(4)",
                tr.PADDR,
                tr.PRDATA
                ), UVM_MEDIUM)
    end else begin
      m_fail++;
      if (tr.PADDR == `ADDR_I) begin
        i_fail++;
        `uvm_error("M_SCB", $sformatf(
                   "(7) FAIL I read : oe = %h, o = %h, exp = %h, got = %h",
                   oe_model,
                   o_model,
                   exp_rdata,
                   tr.PRDATA
                   ))
      end else begin
        `uvm_error("M_SCB", $sformatf(
                   "(4) FAIL read : paddr = %h, exp = %h, got = %h", tr.PADDR, exp_rdata, tr.PRDATA
                   ))
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", $sformatf("*********** End test ***********"), UVM_LOW)
    `uvm_info("SCB", $sformatf("*********** APB Scoreboard ***********"), UVM_LOW)
    `uvm_info("SCB", $sformatf(
              "** write : %0d (OE : %0d, O : %0d), read : %0d, pslverr : %0d, fault_injection : %0d **",
              m_write,
              oe_write,
              o_write,
              m_read,
              m_slverr,
              fault_injection
              ), UVM_LOW)
    `uvm_info("SCB", $sformatf("** (4) transfer check  pass : %0d, fail : %0d **", m_pass, m_fail),
              UVM_LOW)
    `uvm_info("SCB", $sformatf("** (7) I read check    pass : %0d, fail : %0d **", i_pass, i_fail),
              UVM_LOW)
    `uvm_info("SCB", $sformatf("*********** GPIO Scoreboard ***********"), UVM_LOW)
    `uvm_info("SCB", $sformatf(
              "** (3) O write check   pass : %0d, fail : %0d **", o_chk_pass, o_chk_fail), UVM_LOW)
    `uvm_info("SCB", $sformatf("** (6) pin check       pass : %0d, fail : %0d **", pin_pass, pin_fail
              ), UVM_LOW)
    `uvm_info("SCB", $sformatf("********************************"), UVM_LOW)
    if (m_fail == 0 && i_fail == 0 && o_chk_fail == 0 && pin_fail == 0 && m_write > 0 && m_read > 0)
      `uvm_info("SCB", "TEST PASSED", UVM_LOW)
    else `uvm_error("SCB", "TEST FAILED")
  endfunction

endclass
