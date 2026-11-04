class apb_gpio_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(apb_gpio_virtual_sequence)
  `uvm_declare_p_sequencer(apb_gpio_virtual_sequencer)

  apb_gpio_reg_rw_seq m_reg_rw_seq;
  apb_gpio_strb_seq   m_strb_seq;
  apb_gpio_idr_seq    m_idr_seq;
  apb_gpio_err_seq    m_err_seq;
  apb_gpio_random_seq m_random_seq;
  apb_gpio_idle_seq   m_idle_seq;
  gpio_random_seq     g_random_seq;
  gpio_pattern_seq    g_pattern_seq;

  function new(string name = "apb_gpio_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    m_reg_rw_seq  = apb_gpio_reg_rw_seq::type_id::create("m_reg_rw_seq");
    m_strb_seq    = apb_gpio_strb_seq::type_id::create("m_strb_seq");
    m_idr_seq     = apb_gpio_idr_seq::type_id::create("m_idr_seq");
    m_err_seq     = apb_gpio_err_seq::type_id::create("m_err_seq");
    m_random_seq  = apb_gpio_random_seq::type_id::create("m_random_seq");
    m_idle_seq    = apb_gpio_idle_seq::type_id::create("m_idle_seq");
    g_random_seq  = gpio_random_seq::type_id::create("g_random_seq");
    g_pattern_seq = gpio_pattern_seq::type_id::create("g_pattern_seq");

    // 1. 레지스터 Read/Write : 외부 입력은 고정 패턴
    fork
      begin
        m_reg_rw_seq.start(p_sequencer.m_sqr);
        m_strb_seq.start(p_sequencer.m_sqr);
        m_idle_seq.start(p_sequencer.m_sqr);
        g_pattern_seq.stop = 1;
      end
      g_pattern_seq.start(p_sequencer.g_sqr);
    join

    // 2. IDR / 에러 / 랜덤(Fault Injection 포함) : 외부 입력도 랜덤으로 변화
    fork
      begin
        m_idr_seq.start(p_sequencer.m_sqr);
        m_err_seq.start(p_sequencer.m_sqr);
        m_random_seq.start(p_sequencer.m_sqr);
        m_idle_seq.start(p_sequencer.m_sqr);
        g_random_seq.stop = 1;
      end
      g_random_seq.start(p_sequencer.g_sqr);
    join
  endtask

endclass
