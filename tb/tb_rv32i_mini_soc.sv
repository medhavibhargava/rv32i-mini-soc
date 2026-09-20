`timescale 1ns/1ps

module tb_rv32i_mini_soc;
  localparam int CLOCK_FREQ_HZ = 40;
  localparam int UART_BAUD_RATE = 10;
  localparam int CLOCKS_PER_UART_BIT = CLOCK_FREQ_HZ / UART_BAUD_RATE;
  logic clk = 1'b0;
  logic reset = 1'b1;
  wire [31:0] instruction_address;
  logic [31:0] instruction_data;
  wire uart_tx;
  logic [31:0] gpio_in = 32'h1234_5678;
  wire [31:0] gpio_out, gpio_dir;
  wire timer_irq;
  logic [31:0] instruction_memory [0:63];
  logic saw_uart_start = 1'b0;
  logic [9:0] observed_uart_frame = 10'b0;
  logic uart_frame_captured = 1'b0;
  int unsigned checks_run = 0;

  always #5 clk = ~clk;

  assign instruction_data = (instruction_address[31:2] < 64)
                            ? instruction_memory[instruction_address[31:2]]
                            : 32'h0000_0013;

  always @(negedge uart_tx) begin
    if (!reset) saw_uart_start = 1'b1;
  end

  initial begin
    wait (!reset);
    @(negedge uart_tx);
    // Sample the center of each externally visible UART bit period.
    #(CLOCKS_PER_UART_BIT * 5);
    for (int bit_index = 0; bit_index < 10; bit_index++) begin
      observed_uart_frame[bit_index] = uart_tx;
      if (bit_index != 9) #(CLOCKS_PER_UART_BIT * 10);
    end
    uart_frame_captured = 1'b1;
  end

  rv32i_mini_soc #(
    .CLOCK_FREQ_HZ  (CLOCK_FREQ_HZ),
    .UART_BAUD_RATE (UART_BAUD_RATE),
    .GPIO_WIDTH     (32)
  ) dut (
    .clk_i                 (clk),
    .reset_i               (reset),
    .instruction_address_o (instruction_address),
    .instruction_data_i    (instruction_data),
    .uart_tx_o             (uart_tx),
    .gpio_in_i             (gpio_in),
    .gpio_out_o            (gpio_out),
    .gpio_dir_o            (gpio_dir),
    .timer_irq_o           (timer_irq)
  );

  task automatic check_value(input string name,
                             input logic [31:0] actual,
                             input logic [31:0] expected);
    checks_run++;
    if (actual !== expected)
      $fatal(1, "SoC check %0d (%s) failed: got=%h expected=%h",
             checks_run, name, actual, expected);
  endtask

  initial begin
    for (int index = 0; index < 64; index++)
      instruction_memory[index] = 32'h0000_0013;

    // Hand-written RV32I program. It stores and reloads RAM, then accesses
    // GPIO, UART, and timer through their mapped addresses.
    instruction_memory[0]  = 32'h05a0_0113; // addi x2, x0, 0x5a
    instruction_memory[1]  = 32'h0020_2023; // sw   x2, 0(x0)
    instruction_memory[2]  = 32'h0000_2183; // lw   x3, 0(x0)
    instruction_memory[3]  = 32'h0011_8193; // addi x3, x3, 1
    instruction_memory[4]  = 32'h0030_2223; // sw   x3, 4(x0)
    instruction_memory[5]  = 32'h1000_0237; // lui  x4, 0x10000
    instruction_memory[6]  = 32'h1002_0293; // addi x5, x4, 0x100 (GPIO)
    instruction_memory[7]  = 32'h0a50_0313; // addi x6, x0, 0xa5
    instruction_memory[8]  = 32'h0062_a023; // sw   x6, 0(x5) (GPIO_OUT)
    instruction_memory[9]  = 32'hfff0_0393; // addi x7, x0, -1
    instruction_memory[10] = 32'h0072_a423; // sw   x7, 8(x5) (GPIO_DIR)
    instruction_memory[11] = 32'h0550_0413; // addi x8, x0, 0x55
    instruction_memory[12] = 32'h0082_0023; // sb   x8, 0(x4) (UART TXDATA)
    instruction_memory[13] = 32'h2002_0493; // addi x9, x4, 0x200 (timer)
    instruction_memory[14] = 32'h00a0_0513; // addi x10, x0, 10
    instruction_memory[15] = 32'h00a4_a223; // sw   x10, 4(x9) (COMPARE)
    instruction_memory[16] = 32'h0030_0593; // addi x11, x0, 3
    instruction_memory[17] = 32'h00b4_a423; // sw   x11, 8(x9) (enable+IRQ)
    // Twelve NOPs allow COUNT to pass COMPARE before reading STATUS.
    for (int index = 18; index < 30; index++)
      instruction_memory[index] = 32'h0000_0013;
    instruction_memory[30] = 32'h00c4_a603; // lw   x12, 12(x9) (STATUS)
    instruction_memory[31] = 32'h00c0_2423; // sw   x12, 8(x0)
    instruction_memory[32] = 32'h0000_006f; // jal  x0, 0

    repeat (3) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;

    repeat (120) @(posedge clk);
    #1;

    check_value("RAM store", dut.data_ram_i.memory[0], 32'h0000_005a);
    check_value("RAM load/use/store", dut.data_ram_i.memory[1], 32'h0000_005b);
    check_value("timer STATUS read through CPU", dut.data_ram_i.memory[2], 1);
    check_value("GPIO_OUT", gpio_out, 32'h0000_00a5);
    check_value("GPIO_DIR", gpio_dir, 32'hffff_ffff);
    check_value("timer IRQ", {31'b0, timer_irq}, 1);
    check_value("UART start observed", {31'b0, saw_uart_start}, 1);
    check_value("UART returned idle", {31'b0, uart_tx}, 1);

    // The byte sent by the program is 0x55: start, alternating data LSB-first,
    // and stop, sampled from the top-level pin.
    checks_run++;
    if (!uart_frame_captured || observed_uart_frame !== 10'b1_01010101_0)
      $fatal(1, "SoC UART frame mismatch: captured=%b got=%b",
             uart_frame_captured, observed_uart_frame);

    checks_run++;
    if (dut.timer_i.count < 32'd10 || !dut.timer_i.pending)
      $fatal(1, "SoC timer did not reach compare: count=%0d pending=%b",
             dut.timer_i.count, dut.timer_i.pending);

    $display("PASS: %0d RV32I mini-SoC integration checks completed", checks_run);
    $finish;
  end

  initial begin
    #(300 * 10);
    $fatal(1, "RV32I mini-SoC integration test timed out");
  end
endmodule
