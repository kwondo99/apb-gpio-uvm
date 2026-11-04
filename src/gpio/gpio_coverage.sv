// =============================================================================
// GPIO 핀 쪽 Functional Coverage (매 사이클 샘플링)
//  - 방향(OE) 설정 Coverage는 APB 쪽(apb_gpio_coverage)에서 OE Write 값으로 측정
// =============================================================================
class gpio_coverage extends uvm_subscriber #(gpio_item);
  `uvm_component_utils(gpio_coverage)

  gpio_item tr;

  covergroup cov_pin;
    option.per_instance = 1;
    cp_io_port: coverpoint tr.IO_PORT {option.auto_bin_max = 16;}
    cp_gpio_in: coverpoint tr.GPIO_IN {option.auto_bin_max = 16;}
  endgroup

  function new(string name = "gpio_coverage", uvm_component parent);
    super.new(name, parent);
    cov_pin = new();
  endfunction

  function void write(gpio_item t);
    tr = t;
    cov_pin.sample();
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV", "******** GPIO Functional Coverage result ***********", UVM_LOW)
    `uvm_info("COV", $sformatf(" pin_coverage : %6.2f %%", cov_pin.get_inst_coverage()), UVM_LOW)
    `uvm_info("COV", "****************************************************", UVM_LOW)
  endfunction

endclass
