class apb_master_agent extends uvm_agent;
	`uvm_component_utils(apb_master_agent)

	apb_master_driver drv;
	apb_master_monitor mon;
	uvm_sequencer #(apb_item) sqr;
	
	function new(string name = "apb_master_agnet", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		drv = apb_master_driver::type_id::create("drv", this);
		mon = apb_master_monitor::type_id::create("mon", this);
		sqr = uvm_sequencer#(apb_item)::type_id::create("sqr", this);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		drv.seq_item_port.connect(sqr.seq_item_export);
	endfunction

endclass
