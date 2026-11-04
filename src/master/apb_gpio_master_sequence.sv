// =============================================================================
// APB GPIO 레지스터 접근용 Master Sequence
//  - apb-uvm-vip의 apb_item / master driver를 그대로 사용
//  - Read는 PSTRB == 0 (APB4 규칙)
// =============================================================================

// OE / O 레지스터 Write 후 Read-back
class apb_gpio_reg_rw_seq extends uvm_sequence #(apb_item);
  `uvm_object_utils(apb_gpio_reg_rw_seq)

  function new(string name = "apb_gpio_reg_rw_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_item tr;
    repeat (50) begin
      tr = apb_item::type_id::create("tr");
      `uvm_do_with(tr, {PSEL == 1; PWRITE == 1; PADDR == `ADDR_OE; PSTRB == 4'hF;})
      `uvm_do_with(tr, {PSEL == 1; PWRITE == 0; PADDR == `ADDR_OE; PSTRB == 4'h0;})
      `uvm_do_with(tr, {PSEL == 1; PWRITE == 1; PADDR == `ADDR_O; PSTRB == 4'hF;})
      `uvm_do_with(tr, {PSEL == 1; PWRITE == 0; PADDR == `ADDR_O; PSTRB == 4'h0;})
      `uvm_info("M_SEQ", "make reg_rw sequence", UVM_HIGH)
    end
  endtask

endclass : apb_gpio_reg_rw_seq

// 랜덤 PSTRB로 부분 Write 후 Read-back
class apb_gpio_strb_seq extends uvm_sequence #(apb_item);
  `uvm_object_utils(apb_gpio_strb_seq)

  function new(string name = "apb_gpio_strb_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_item tr;
    repeat (50) begin
      tr = apb_item::type_id::create("tr");
      `uvm_do_with(tr, {PSEL == 1; PWRITE == 1; PADDR inside {`ADDR_OE, `ADDR_O};})
      `uvm_do_with(tr, {PSEL == 1; PWRITE == 0; PADDR inside {`ADDR_OE, `ADDR_O}; PSTRB == 4'h0;})
      `uvm_info("M_SEQ", "make strb sequence", UVM_HIGH)
    end
  endtask

endclass : apb_gpio_strb_seq

// 방향(OE)을 바꿔가며 IDR을 반복해서 Read (gpio agent가 동시에 입력을 바꿈)
class apb_gpio_idr_seq extends uvm_sequence #(apb_item);
  `uvm_object_utils(apb_gpio_idr_seq)

  function new(string name = "apb_gpio_idr_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_item tr;
    repeat (20) begin
      tr = apb_item::type_id::create("tr");
      // 전체 Input / 전체 Output / 혼합 방향
      `uvm_do_with(tr, {
        PSEL == 1; PWRITE == 1; PADDR == `ADDR_OE; PSTRB == 4'hF;
        PWDATA[`GPIO_WIDTH-1:0] dist {0 := 1, {`GPIO_WIDTH{1'b1}} := 1, [1:{`GPIO_WIDTH{1'b1}}-1] :/ 3};
      })
      `uvm_do_with(tr, {PSEL == 1; PWRITE == 1; PADDR == `ADDR_O; PSTRB == 4'hF;})
      repeat (10) begin
        `uvm_do_with(tr, {PSEL == 1; PWRITE == 0; PADDR == `ADDR_I; PSTRB == 4'h0;})
      end
      `uvm_info("M_SEQ", "make idr sequence", UVM_HIGH)
    end
  endtask

endclass : apb_gpio_idr_seq

// PSLVERR 시나리오 : RO(IDR) Write, 정의되지 않은 주소 Read/Write
class apb_gpio_err_seq extends uvm_sequence #(apb_item);
  `uvm_object_utils(apb_gpio_err_seq)

  function new(string name = "apb_gpio_err_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_item     tr;
    int unsigned n_write = 0, n_read = 0;

    repeat (30) begin
      tr = apb_item::type_id::create("tr");
      `uvm_do_with(tr, {PSEL == 1; PWRITE == 1; PADDR == `ADDR_I;})

      // 정의되지 않은 주소 접근 (Read / Write는 apb_item의 pwrite_c로 1 : 1)
      `uvm_do_with(tr, {
        PSEL == 1;
        !(PADDR inside {`ADDR_OE, `ADDR_I, `ADDR_O});
        PADDR dist {[0 : 32'h3F] :/ 3, [32'h40 : 32'hFFFF_FFFF] :/ 1};
      })
      if (tr.PWRITE) n_write++;
      else n_read++;

      // 에러 후 레지스터 값이 유지되는지 확인
      `uvm_do_with(tr, {PSEL == 1; PWRITE == 0; PADDR inside {`ADDR_OE, `ADDR_O};})
      `uvm_info("M_SEQ", "make err sequence", UVM_HIGH)
    end

    `uvm_info("M_SEQ", $sformatf(
              "[err_seq] invalid address access : write = %0d, read = %0d", n_write, n_read),
              UVM_LOW)
  endtask

endclass : apb_gpio_err_seq

// 주소/방향/PSEL 랜덤 (PSEL = 0 이면 Fault Injection : DUT는 무시해야 함)
class apb_gpio_random_seq extends uvm_sequence #(apb_item);
  `uvm_object_utils(apb_gpio_random_seq)

  function new(string name = "apb_gpio_random_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_item     tr;
    int unsigned n_write = 0, n_read = 0, n_fault = 0;

    repeat (300) begin
      tr = apb_item::type_id::create("tr");
      // Read / Write는 apb_item의 pwrite_c로 1 : 1, Read면 PSTRB = 0 (pstrb_c)
      `uvm_do_with(tr, {
        PREADY_DELAY > 0;
        PSEL dist {1 := 4, 0 := 1};
        PADDR dist {`ADDR_OE := 3, `ADDR_I := 3, `ADDR_O := 3, 32'h0C := 1};
      })
      if (!tr.PSEL) n_fault++;
      else if (tr.PWRITE) n_write++;
      else n_read++;
      `uvm_info("M_SEQ", "make random sequence", UVM_HIGH)
    end

    `uvm_info("M_SEQ", $sformatf(
              "[random_seq] write = %0d, read = %0d, fault_injection = %0d", n_write, n_read, n_fault
              ), UVM_LOW)
  endtask

endclass : apb_gpio_random_seq

// 버스를 IDLE로 되돌림
// master driver는 마지막 전송 후 PSEL/PENABLE을 유지하므로, 테스트 끝에 넣어서 내려줌
// (PSEL == 0, PREADY_DELAY == 0 이면 같은 사이클에 PENABLE 1 -> 0 이 되어 Fault Injection 펄스가 생기지 않음)
class apb_gpio_idle_seq extends uvm_sequence #(apb_item);
  `uvm_object_utils(apb_gpio_idle_seq)

  function new(string name = "apb_gpio_idle_seq");
    super.new(name);
  endfunction

  virtual task body();
    apb_item tr;
    repeat (3) begin
      tr = apb_item::type_id::create("tr");
      `uvm_do_with(tr, {PSEL == 0; PREADY_DELAY == 0;})
    end
  endtask

endclass : apb_gpio_idle_seq
