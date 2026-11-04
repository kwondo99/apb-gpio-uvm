`timescale 1ns/1ps
`include "apb_gpio_defines.svh"

module apb_gpio_tb_top();
	import uvm_pkg::*;
	import apb_gpio_pkg::*;
	`include "uvm_macros.svh"

	logic clk;
	logic reset_n;

	apb_master_if master_if(clk, reset_n);
	gpio_if g_if(clk, reset_n);

	wire [`GPIO_WIDTH-1:0] io_port;

	apb_gpio #(
		.GPIO_WIDTH(`GPIO_WIDTH)
	) dut (
		.PCLK   (clk),
		.PRESETn(reset_n),
		.PADDR  (master_if.paddr),
		.PSEL   (master_if.psel),
		.PENABLE(master_if.penable),
		.PWRITE (master_if.pwrite),
		.PWDATA (master_if.pwdata),
		.PSTRB  (master_if.pstrb),
		.PREADY (master_if.pready),
		.PRDATA (master_if.prdata),
		.PSLVERR(master_if.pslverr),
		.io_port(io_port)
	);

	// DUT 방향 정보 (외부 장치 모델 / monitor에서 사용)
	assign g_if.dut_oe = dut.gpio_oe;

	// 외부 장치 모델
	// DUT가 Output으로 쓰는 핀은 'z로 놓아 버스 충돌 방지, Input 핀에만 gpio_in을 구동
	genvar k;
	generate
		for (k = 0; k < `GPIO_WIDTH; k = k + 1) begin : g_ext
			assign io_port[k] = g_if.dut_oe[k] ? 1'bz : g_if.gpio_in[k];
		end
	endgenerate

	// 실제 핀 값을 gpio_if로 전달 (monitor 관찰용)
	assign g_if.io_port = io_port;

	initial clk = 0;
	always #5 clk = ~clk;

	initial begin
		reset_n = 0;
		#20 reset_n = 1;
	end

`ifndef VERILATOR
	initial begin
		$fsdbDumpfile("apb_gpio_test.fsdb");
		$fsdbDumpvars(0, apb_gpio_tb_top);
	end
`endif

	initial begin
		uvm_config_db#(virtual apb_master_if)::set(null, "*", "apb_master_if", master_if);
		uvm_config_db#(virtual gpio_if)::set(null, "*", "gpio_if", g_if);
		run_test();
	end

endmodule
