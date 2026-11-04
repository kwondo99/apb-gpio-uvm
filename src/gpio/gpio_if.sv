`include "apb_gpio_defines.svh"

interface gpio_if (
    input logic pclk,
    input logic preset_n
);
  logic [`GPIO_WIDTH-1:0] io_port;  // 실제 핀 값 (tb_top에서 연결, 관찰용)
  logic [`GPIO_WIDTH-1:0] gpio_in;  // 외부 장치가 핀에 넣는 값 (driver가 구동)

  // 외부 장치 모델 전용 : DUT가 출력 중인 핀은 외부 장치가 'z로 손을 떼야 하므로 사용
  // (monitor / scoreboard는 사용하지 않음. 기대 방향은 scoreboard가 APB Write로 직접 계산)
  logic [`GPIO_WIDTH-1:0] dut_oe;

  // driver
  clocking cb @(posedge pclk);
    default input #1ns output #1ns;
    output gpio_in;
  endclocking

  // monitor : 외부에서 볼 수 있는 핀 값과 외부 입력만 수집
  clocking mon_cb @(posedge pclk);
    default input #1ns;
    input io_port, gpio_in;
  endclocking

endinterface
