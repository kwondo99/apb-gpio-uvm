module apb_gpio #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter GPIO_WIDTH = 16
) (
    input  wire                    PCLK,
    input  wire                    PRESETn,
    input  wire [  ADDR_WIDTH-1:0] PADDR,
    input  wire                    PSEL,
    input  wire                    PENABLE,
    input  wire                    PWRITE,
    input  wire [  DATA_WIDTH-1:0] PWDATA,
    input  wire [DATA_WIDTH/8-1:0] PSTRB,
    output wire                    PREADY,
    output wire [  DATA_WIDTH-1:0] PRDATA,
    output wire                    PSLVERR,
    // GPIO pins
    inout  wire [GPIO_WIDTH - 1:0] io_port
);

  // GPIO registers
  reg  [GPIO_WIDTH - 1:0] gpio_oe_reg;
  reg  [GPIO_WIDTH - 1:0] gpio_i_reg;
  reg  [GPIO_WIDTH - 1:0] gpio_o_reg;

  wire [GPIO_WIDTH - 1:0] gpio_oe;  // offset 0x00
  wire [GPIO_WIDTH - 1:0] gpio_i;  //  offset 0x04
  wire [GPIO_WIDTH - 1:0] gpio_o;  //  offset 0x08


  assign gpio_oe = gpio_oe_reg;
  assign gpio_o  = gpio_o_reg;

  genvar i;
  generate
    for (i = 0; i < GPIO_WIDTH; i = i + 1) begin
      assign io_port[i] = gpio_oe[i] ? gpio_o[i] : 1'bz;
      assign gpio_i[i]  = io_port[i];
    end
  endgenerate

  // PREDAY
  reg pready_reg;

  assign PREADY = pready_reg;

  always @(posedge PCLK) begin
    if (!PRESETn) begin
      pready_reg <= 0;
    end else begin
      if (PSEL && PENABLE && !pready_reg) pready_reg <= 1;
      else pready_reg <= 0;
    end
  end

  // error check
  wire addr_valid = (PADDR == 8'h00) || (PADDR == 8'h04) || (PADDR == 8'h08);
  wire err = !addr_valid || (PWRITE && PADDR == 8'h04);

  // handshake
  wire access;
  assign access  = PSEL && PENABLE && PREADY;

  assign PSLVERR = access && err;

  // apb write

  integer j;

  always @(posedge PCLK) begin
    if (!PRESETn) begin
      gpio_oe_reg <= 0;
      gpio_o_reg  <= 0;
    end else begin
      if (access && PWRITE && !err) begin
        case (PADDR)
          8'h00: begin
            for (j = 0; j < GPIO_WIDTH / 8; j = j + 1)
            if (PSTRB[j]) gpio_oe_reg[j*8+:8] <= PWDATA[j*8+:8];
          end
          8'h08: begin
            for (j = 0; j < GPIO_WIDTH / 8; j = j + 1)
            if (PSTRB[j]) gpio_o_reg[j*8+:8] <= PWDATA[j*8+:8];
          end
        endcase
      end
    end
  end

  always @(posedge PCLK) begin
    if (!PRESETn) gpio_i_reg <= 0;
    else gpio_i_reg <= gpio_i;
  end

  // read
  reg [DATA_WIDTH - 1:0] prdata_reg;

  always @(*) begin
    prdata_reg = 0;
    if (PSEL && PENABLE && !PWRITE) begin
      case (PADDR)
        8'h00: prdata_reg[GPIO_WIDTH-1:0] = gpio_oe_reg;
        8'h04: prdata_reg[GPIO_WIDTH-1:0] = gpio_i_reg;
        8'h08: prdata_reg[GPIO_WIDTH-1:0] = gpio_o_reg;
      endcase
    end
  end

  assign PRDATA = prdata_reg;

endmodule
