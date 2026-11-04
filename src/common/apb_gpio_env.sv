class apb_gpio_env extends uvm_env;
  `uvm_component_utils(apb_gpio_env);

  apb_master_agent master_agt;  // apb-uvm-vip master agent 재사용
  gpio_agent gpio_agt;
  apb_gpio_virtual_sequencer v_sqr;
  apb_gpio_scoreboard scb;
  apb_gpio_coverage cov;
  gpio_coverage g_cov;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    master_agt = apb_master_agent::type_id::create("master_agt", this);
    gpio_agt = gpio_agent::type_id::create("gpio_agt", this);
    scb = apb_gpio_scoreboard::type_id::create("scb", this);
    cov = apb_gpio_coverage::type_id::create("cov", this);
    g_cov = gpio_coverage::type_id::create("g_cov", this);
    v_sqr = apb_gpio_virtual_sequencer::type_id::create("v_sqr", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    // connect monitor to scb, cov
    master_agt.mon.ap.connect(scb.m_fifo.analysis_export);
    gpio_agt.mon.ap.connect(scb.g_fifo.analysis_export);
    master_agt.mon.ap.connect(cov.analysis_export);
    gpio_agt.mon.ap.connect(g_cov.analysis_export);
    v_sqr.m_sqr = master_agt.sqr;
    v_sqr.g_sqr = gpio_agt.sqr;
  endfunction

endclass
