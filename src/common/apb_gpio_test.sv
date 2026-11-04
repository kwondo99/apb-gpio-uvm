class apb_gpio_base_test extends uvm_test;
  `uvm_component_utils(apb_gpio_base_test)
  apb_gpio_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = apb_gpio_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  // 레지스터 Read/Write만 간단히 확인
  virtual task run_phase(uvm_phase phase);
    apb_gpio_reg_rw_seq m_seq;
    apb_gpio_idle_seq   m_idle_seq;
    gpio_random_seq     g_seq;
    phase.raise_objection(this);
    m_seq      = apb_gpio_reg_rw_seq::type_id::create("m_seq");
    m_idle_seq = apb_gpio_idle_seq::type_id::create("m_idle_seq");
    g_seq      = gpio_random_seq::type_id::create("g_seq");
    fork
      begin
        m_seq.start(env.master_agt.sqr);
        m_idle_seq.start(env.master_agt.sqr);
        g_seq.stop = 1;
      end
      g_seq.start(env.gpio_agt.sqr);
    join
    phase.drop_objection(this);
  endtask

endclass

class apb_gpio_virtual_test extends apb_gpio_base_test;
  `uvm_component_utils(apb_gpio_virtual_test)

  apb_gpio_virtual_sequence v_seq;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    v_seq = apb_gpio_virtual_sequence::type_id::create("v_seq");
    `uvm_info("TEST", $sformatf("virtual_sequence start"), UVM_LOW)
    v_seq.start(env.v_sqr);
    phase.drop_objection(this);
  endtask

endclass
