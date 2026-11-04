class gpio_item extends uvm_sequence_item;

  rand bit          [`GPIO_WIDTH-1:0] GPIO_IN;  // 외부에서 핀에 넣을 값 (driver 구동 / monitor 수집)
  rand int unsigned                   DELAY;  // GPIO_IN 유지 사이클
  bit               [`GPIO_WIDTH-1:0] IO_PORT;  // monitor : 실제 핀 값

  constraint delay_length {
    DELAY > 0;
    DELAY < 10;
  }

  `uvm_object_utils_begin(gpio_item)
    `uvm_field_int(GPIO_IN, UVM_DEFAULT)
    `uvm_field_int(DELAY, UVM_DEFAULT)
    `uvm_field_int(IO_PORT, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "gpio_item");
    super.new(name);
  endfunction

endclass
