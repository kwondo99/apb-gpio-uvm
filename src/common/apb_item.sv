class apb_item extends uvm_sequence_item;

  rand bit          [31:0] PADDR;
  rand bit                 PSEL;
  bit                      PENABLE;
  rand bit                 PWRITE;
  rand bit          [31:0] PWDATA;
  rand bit          [31:0] PRDATA;
  bit                      PREADY;
  rand bit          [ 3:0] PSTRB;
  rand bit                 PSLVERR;
  rand int unsigned        PREADY_DELAY;

  constraint delay_length {PREADY_DELAY < 5;}

  // [apb-gpio] Read / Write 비율 1 : 1
  //  아래 pstrb_c 때문에 Write는 PSTRB 16가지, Read는 1가지 조합만 가능해져
  //  dist 없이 랜덤화하면 Write가 16/17 확률로 생성됨
  constraint pwrite_c {PWRITE dist {0 := 1, 1 := 1};}

  // [apb-gpio] APB4 규칙 : Read일 때 PSTRB = 0, Write일 때는 랜덤
  constraint pstrb_c {if (PWRITE == 0) PSTRB == 4'h0;}

  `uvm_object_utils_begin(apb_item)
    `uvm_field_int(PADDR, UVM_DEFAULT)
    `uvm_field_int(PSEL, UVM_DEFAULT)
    `uvm_field_int(PENABLE, UVM_DEFAULT)
    `uvm_field_int(PWRITE, UVM_DEFAULT)
    `uvm_field_int(PWDATA, UVM_DEFAULT)
    `uvm_field_int(PRDATA, UVM_DEFAULT)
    `uvm_field_int(PREADY, UVM_DEFAULT)
    `uvm_field_int(PSTRB, UVM_DEFAULT)
    `uvm_field_int(PSLVERR, UVM_DEFAULT)
    `uvm_field_int(PREADY_DELAY, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "apb_item");
    super.new(name);
  endfunction

endclass
