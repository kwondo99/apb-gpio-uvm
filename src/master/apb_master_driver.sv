class apb_master_driver extends uvm_driver #(apb_item);
  `uvm_component_utils(apb_master_driver)

  virtual apb_master_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(virtual apb_master_if)::get(this, "", "apb_master_if", vif);
  endfunction

  // if tr.PWRTIE = 1'b1
  task write_drive(apb_item tr);
    vif.cb.psel <= tr.PSEL;
    vif.cb.paddr <= tr.PADDR;
    vif.cb.pwrite <= tr.PWRITE;
    vif.cb.pwdata <= tr.PWDATA;
    vif.cb.pstrb <= tr.PSTRB;
    vif.cb.penable <= 1'b0;
    if (tr.PSEL) begin
      @(vif.cb);
      vif.cb.penable <= 1'b1;
      while (!vif.cb.pready) begin
        @(vif.cb);
      end
    end else begin
      @(vif.cb);
      vif.cb.penable <= 1'b1;
      repeat (tr.PREADY_DELAY) @(vif.cb);
      vif.cb.penable <= 1'b0;
    end
  endtask

  // if tr.PWRITE = 1'b0
  task read_drive(apb_item tr);
    vif.cb.psel <= tr.PSEL;
    vif.cb.paddr <= tr.PADDR;
    vif.cb.pwrite <= tr.PWRITE;
    vif.cb.pstrb <= tr.PSTRB;
    vif.cb.penable <= 1'b0;
    if (tr.PSEL) begin
      @(vif.cb);
      vif.cb.penable <= 1'b1;
      while (!vif.cb.pready) begin
        @(vif.cb);
      end
    end else begin
      @(vif.cb);
      vif.cb.penable <= 1'b1;
      repeat (tr.PREADY_DELAY) @(vif.cb);
      vif.cb.penable <= 1'b0;
    end
  endtask

  task run_phase(uvm_phase phase);
    apb_item tr;
    vif.cb.paddr <= 0;
    vif.cb.pwrite <= 0;
		vif.cb.pwdata <= 0;
    vif.cb.psel <= 0;
    vif.cb.penable <= 0;
    vif.cb.pstrb <= 0;
    @(posedge vif.preset_n);
    @(vif.cb);
    forever begin
      seq_item_port.get_next_item(tr);
      `uvm_info(
          "M_DRV", $sformatf(
          "paddr = %h, psel = %b, pwrite = %b, pwdata= %h", tr.PADDR, tr.PSEL, tr.PWRITE, tr.PWDATA)
          , UVM_MEDIUM)
      if (tr.PWRITE) write_drive(tr);
      else read_drive(tr);
      seq_item_port.item_done();
    end
  endtask

endclass

