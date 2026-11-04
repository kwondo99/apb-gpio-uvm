// =============================================================================
// APB 쪽 Functional Coverage (Transfer 완료 시점에만 샘플링)
// =============================================================================
class apb_gpio_coverage extends uvm_subscriber #(apb_item);
  `uvm_component_utils(apb_gpio_coverage)

  apb_item tr;

  // 레지스터 접근 x Read/Write, 에러 응답
  covergroup cov_access;
    option.per_instance = 1;
    cp_addr: coverpoint tr.PADDR {
      bins oe = {`ADDR_OE};
      bins i = {`ADDR_I};
      bins o = {`ADDR_O};
      bins invalid = {[1 : 3], [5 : 7], [32'h09 : 32'hFFFF_FFFF]};
    }
    cp_rw: coverpoint tr.PWRITE {bins read = {0}; bins write = {1};}
    cp_slverr: coverpoint tr.PSLVERR {bins okay = {0}; bins error = {1};}
    cx_addr_rw: cross cp_addr, cp_rw;
  endgroup

  // Write 데이터 / Byte Strobe
  covergroup cov_write;
    option.per_instance = 1;
    cp_wdata: coverpoint tr.PWDATA[`GPIO_WIDTH-1:0] {option.auto_bin_max = 16;}
    cp_strb: coverpoint tr.PSTRB[`GPIO_WIDTH/8-1:0];
    cp_addr: coverpoint tr.PADDR {bins oe = {`ADDR_OE}; bins o = {`ADDR_O};}
    cx_strb_addr: cross cp_strb, cp_addr;
    // OE Write 값으로 방향 설정 종류 측정 : 전체 Input / 전체 Output / 혼합
    cp_oe_mode: coverpoint tr.PWDATA[`GPIO_WIDTH-1:0] iff (tr.PADDR == `ADDR_OE) {
      bins all_in = {0};
      bins all_out = {{`GPIO_WIDTH{1'b1}}};
      bins mixed = {[1 : {`GPIO_WIDTH{1'b1}} - 1]};
    }
  endgroup

  // Read 데이터
  covergroup cov_read;
    option.per_instance = 1;
    cp_rdata: coverpoint tr.PRDATA[`GPIO_WIDTH-1:0] {option.auto_bin_max = 16;}
    cp_addr: coverpoint tr.PADDR {bins oe = {`ADDR_OE}; bins i = {`ADDR_I}; bins o = {`ADDR_O};}
  endgroup

  function new(string name = "apb_gpio_coverage", uvm_component parent);
    super.new(name, parent);
    cov_access = new();
    cov_write  = new();
    cov_read   = new();
  endfunction

  function void write(apb_item t);
    tr = t;
    if (tr.PSEL && tr.PENABLE && tr.PREADY) begin
      cov_access.sample();
      if (!tr.PSLVERR) begin
        if (tr.PWRITE) cov_write.sample();
        else cov_read.sample();
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", "******** APB Functional Coverage result ***********", UVM_LOW)
    `uvm_info("COV", $sformatf(" access_coverage : %6.2f %%", cov_access.get_inst_coverage()),
              UVM_LOW)
    `uvm_info("COV", $sformatf(" write_coverage  : %6.2f %%", cov_write.get_inst_coverage()),
              UVM_LOW)
    `uvm_info("COV", $sformatf(" read_coverage   : %6.2f %%", cov_read.get_inst_coverage()),
              UVM_LOW)
    `uvm_info("COV", "***************************************************", UVM_LOW)
  endfunction

endclass
