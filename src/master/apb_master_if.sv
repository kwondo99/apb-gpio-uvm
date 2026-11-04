interface apb_master_if (
    input logic pclk,
    input logic preset_n
);
  logic [31:0] paddr;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [ 3:0] pstrb;
  logic        pready;
  logic [31:0] prdata;
  logic        pslverr;

	clocking cb @(posedge pclk);
		default input #1ns output #1ns;
			input prdata, pslverr, pready;
			output paddr, psel, penable, pwrite, pwdata, pstrb;
	endclocking

	// [apb-gpio] monitor 전용 : 모든 신호를 posedge 직전(#1ns)에 샘플링
	// raw 신호를 @(cb) 직후 읽으면 DUT의 posedge 갱신 전/후 값 중 무엇을 읽을지 보장되지 않음 (race)
	clocking mon_cb @(posedge pclk);
		default input #1ns;
			input paddr, psel, penable, pwrite, pwdata, pstrb, prdata, pslverr, pready;
	endclocking

endinterface

