`ifndef APB_GPIO_DEFINES_SVH
`define APB_GPIO_DEFINES_SVH

// DUT parameter와 반드시 동일하게 유지 (8의 배수)
`define GPIO_WIDTH 16

// Register offset
`define ADDR_OE 32'h00  // RW : 방향 (1 = Output)
`define ADDR_I  32'h04  // RO : 입력 값
`define ADDR_O  32'h08  // RW : 출력 값

`endif
