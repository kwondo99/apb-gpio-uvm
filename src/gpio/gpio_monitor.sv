class gpio_monitor extends uvm_monitor;
  `uvm_component_utils(gpio_monitor)

  virtual gpio_if vif;

  uvm_analysis_port #(gpio_item) ap;

  function new(string name = "gpio_monitor", uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(virtual gpio_if)::get(this, "", "gpio_if", vif);
  endfunction

  // 매 사이클 io_port(핀 값)와 gpio_in(외부 입력)을 scoreboard로 전송
  task run_phase(uvm_phase phase);
    gpio_item tr;
    @(posedge vif.preset_n);
    forever begin
      tr = gpio_item::type_id::create("tr");
      @(vif.mon_cb);
      tr.IO_PORT = vif.mon_cb.io_port;
      tr.GPIO_IN = vif.mon_cb.gpio_in;
      `uvm_info("G_MON", $sformatf("io_port = %h, gpio_in = %h", tr.IO_PORT, tr.GPIO_IN), UVM_HIGH)
      ap.write(tr);
    end
  endtask

endclass
