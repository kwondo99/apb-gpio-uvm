`include "apb_gpio_defines.svh"

package apb_gpio_pkg;
	import uvm_pkg::*;
	`include "uvm_macros.svh"

	`include "apb_item.sv"

	// master agent (apb-uvm-vip)
	`include "apb_master_sequencer.sv"
	`include "apb_gpio_master_sequence.sv"
	`include "apb_master_driver.sv"
	`include "apb_master_monitor.sv"
	`include "apb_master_agent.sv"

	// gpio agent
	`include "gpio_item.sv"
	`include "gpio_sequence.sv"
	`include "gpio_driver.sv"
	`include "gpio_monitor.sv"
	`include "gpio_agent.sv"
	`include "gpio_coverage.sv"

	`include "apb_gpio_virtual_sequencer.sv"
	`include "apb_gpio_virtual_sequence.sv"

	// common
	`include "apb_gpio_coverage.sv"
	`include "apb_gpio_scoreboard.sv"
	`include "apb_gpio_env.sv"
	`include "apb_gpio_test.sv"
endpackage
