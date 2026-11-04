class apb_gpio_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(apb_gpio_virtual_sequencer)

  // env connect_phase에서 각 agent의 sequencer 핸들을 연결 (직접 create 하지 않음)
  uvm_sequencer #(apb_item)  m_sqr;
  uvm_sequencer #(gpio_item) g_sqr;

  function new(string name = "apb_gpio_virtual_sequencer", uvm_component parent);
    super.new(name, parent);
  endfunction

endclass
