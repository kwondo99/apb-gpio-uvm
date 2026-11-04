class apb_master_monitor extends uvm_monitor;
  `uvm_component_utils(apb_master_monitor)

  virtual apb_master_if vif;

	uvm_analysis_port#(apb_item) ap;

  function new(string name = "apb_master_monitor", uvm_component parent);
    super.new(name, parent);
		ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(virtual apb_master_if)::get(this, "", "apb_master_if", vif);
  endfunction

  task run_phase(uvm_phase phase);
    apb_item tr;
    // [apb-gpio] 리셋 해제 후 시작 : GPIO monitor와 같은 클럭부터 샘플링해야
    //            scoreboard FIFO에서 클럭 단위로 짝이 맞음
    @(posedge vif.preset_n);
    forever begin
      tr = apb_item::type_id::create("tr");
      // [apb-gpio] raw 신호 대신 mon_cb로 샘플링 (race 방지)
      @(vif.mon_cb);
      tr.PADDR   = vif.mon_cb.paddr;
      tr.PSEL    = vif.mon_cb.psel;
      tr.PENABLE = vif.mon_cb.penable;
      tr.PWRITE  = vif.mon_cb.pwrite;
      tr.PWDATA  = vif.mon_cb.pwdata;
      tr.PSTRB   = vif.mon_cb.pstrb;
      tr.PREADY  = vif.mon_cb.pready;
      tr.PRDATA  = vif.mon_cb.prdata;
      tr.PSLVERR = vif.mon_cb.pslverr;  // [apb-gpio] DUT 에러 응답 검증을 위해 추가
      `uvm_info("M_MON", $sformatf(
                "paddr = 8'h%h, psel = %b, penable = %b, pwrite = %b, pwdata = 8'h%h, pstrb = %b, pready = %b, prdata = 8'h%h",
                tr.PADDR,
                tr.PSEL,
                tr.PENABLE,
                tr.PWRITE,
                tr.PWDATA,
                tr.PSTRB,
                tr.PREADY,
                tr.PRDATA
                ), UVM_HIGH)
			ap.write(tr);
    end
  endtask
endclass
