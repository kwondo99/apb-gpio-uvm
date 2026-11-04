class gpio_driver extends uvm_driver #(gpio_item);
  `uvm_component_utils(gpio_driver)

  virtual gpio_if vif;

  function new(string name = "gpio_driver", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(virtual gpio_if)::get(this, "", "gpio_if", vif);
  endfunction

  task run_phase(uvm_phase phase);
    gpio_item tr;
    vif.cb.gpio_in <= 0;
    @(posedge vif.preset_n);
    @(vif.cb);
    forever begin
      seq_item_port.get_next_item(tr);
      `uvm_info("G_DRV", $sformatf("gpio_in = %h, delay = %0d", tr.GPIO_IN, tr.DELAY), UVM_HIGH)
      vif.cb.gpio_in <= tr.GPIO_IN;
      repeat (tr.DELAY) @(vif.cb);
      seq_item_port.item_done();
    end
  endtask

endclass
