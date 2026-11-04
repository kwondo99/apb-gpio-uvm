// =============================================================================
// GPIO 외부 입력 Sequence
//  - APB 시퀀스가 도는 동안 계속 입력을 바꿔주는 Reactive Sequence
//  - stop = 1 이 되면 현재 아이템까지 끝내고 종료
//    (disable fork로 끊으면 driver가 아이템을 잡은 채 시퀀스가 죽어서 item_done 에러 발생)
// =============================================================================

// 랜덤 입력
class gpio_random_seq extends uvm_sequence #(gpio_item);
  `uvm_object_utils(gpio_random_seq)

  bit stop = 0;

  function new(string name = "gpio_random_seq");
    super.new(name);
  endfunction

  virtual task body();
    gpio_item tr;
    while (!stop) begin
      tr = gpio_item::type_id::create("tr");
      `uvm_do(tr)
    end
  endtask

endclass : gpio_random_seq

// 0x0000 / 0xFFFF / 0xAAAA / 0x5555 고정 패턴을 번갈아 입력
class gpio_pattern_seq extends uvm_sequence #(gpio_item);
  `uvm_object_utils(gpio_pattern_seq)

  bit                   stop = 0;
  bit [`GPIO_WIDTH-1:0] pattern[4];

  function new(string name = "gpio_pattern_seq");
    super.new(name);
    pattern[0] = {(`GPIO_WIDTH / 2) {2'b00}};
    pattern[1] = {(`GPIO_WIDTH / 2) {2'b11}};
    pattern[2] = {(`GPIO_WIDTH / 2) {2'b10}};
    pattern[3] = {(`GPIO_WIDTH / 2) {2'b01}};
  endfunction

  virtual task body();
    gpio_item tr;
    while (!stop) begin
      foreach (pattern[p]) begin
        tr = gpio_item::type_id::create("tr");
        `uvm_do_with(tr, {GPIO_IN == pattern[p];})
      end
    end
  endtask

endclass : gpio_pattern_seq
