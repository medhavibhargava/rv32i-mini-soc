`timescale 1ns/1ps

module tb_timer;
  logic clk = 0;
  logic reset = 0;
  logic selected = 0;
  logic read_intent = 0;
  logic write_intent = 0;
  logic [31:0] addr = 0;
  logic [31:0] write_data = 0;
  logic [3:0] strobes = 0;
  wire [31:0] read_data;
  wire irq;
  int checks_run = 0;

  timer dut (
    .clk_i(clk), .reset_i(reset), .select_i(selected),
    .read_i(read_intent), .write_i(write_intent), .addr_i(addr),
    .write_data_i(write_data), .write_strobes_i(strobes),
    .read_data_o(read_data), .irq_o(irq)
  );

  // Explicit clock steps keep register inspections from advancing the timer.
  task automatic tick;
    #5;
    clk = 1;
    #1;
    clk = 0;
  endtask

  task automatic check_read(input logic [31:0] address,
                            input logic [31:0] expected,
                            input logic sel = 1, input logic rd = 1);
    addr = address;
    selected = sel;
    read_intent = rd;
    #1;
    checks_run++;
    if (read_data !== expected)
      $fatal(1, "Timer check=%0d addr=%h got=%h expected=%h",
             checks_run, address, read_data, expected);
  endtask

  task automatic check_irq(input logic expected);
    #1;
    checks_run++;
    if (irq !== expected)
      $fatal(1, "Timer IRQ check=%0d got=%b expected=%b", checks_run, irq, expected);
  endtask

  task automatic write_reg(input logic [31:0] address,
                           input logic [31:0] data,
                           input logic [3:0] mask = 4'b1111,
                           input logic sel = 1, input logic wr = 1);
    selected = sel;
    read_intent = 0;
    write_intent = wr;
    addr = address;
    write_data = data;
    strobes = mask;
    tick();
    write_intent = 0;
    strobes = 0;
  endtask

  task automatic check_reset;
    check_read(0, 0);
    check_read(4, 0);
    check_read(8, 0);
    check_read(12, 0);
    check_irq(0);
  endtask

  initial begin
    reset = 1;
    tick();
    check_reset();
    reset = 0;
    repeat (3) tick();
    check_read(0, 0);
    check_read(12, 0); // Reset COUNT==COMPARE does not match while disabled.

    write_reg(4, 32'h1234_5678);
    check_read(4, 32'h1234_5678);
    write_reg(4, 32'hffff_ffaa, 4'b0001);
    check_read(4, 32'h1234_56aa);
    write_reg(4, 32'hffff_bbff, 4'b0010);
    check_read(4, 32'h1234_bbaa);
    write_reg(4, 32'hffcc_ffff, 4'b0100);
    check_read(4, 32'h12cc_bbaa);
    write_reg(4, 32'hddff_ffff, 4'b1000);
    check_read(4, 32'hddcc_bbaa);
    write_reg(4, 32'hffff_1357, 4'b0011);
    check_read(4, 32'hddcc_1357);
    write_reg(4, 0, 4'b0000);
    write_reg(4, 0, 4'b1111, 0, 1);
    write_reg(4, 0, 4'b1111, 1, 0);
    check_read(4, 32'hddcc_1357);
    write_reg(0, 32'hffff_ffff);
    check_read(0, 0);
    write_reg(8, 3, 4'b1110);
    write_reg(8, 3, 4'b0000);
    check_read(8, 0);
    write_reg(16, 32'hffff_ffff);
    write_reg(32'h104, 0);
    write_reg(5, 0);
    check_read(4, 32'hddcc_1357);
    check_read(16, 0);
    check_read(32'h104, 0);
    check_read(5, 0);
    check_read(4, 0, 0, 1);
    check_read(4, 0, 1, 0);

    write_reg(4, 3);
    write_reg(8, 1, 4'b0001);
    check_read(8, 1);
    check_read(0, 0); // The enable write does not itself increment COUNT.
    for (int value = 1; value <= 3; value++) begin
      tick();
      check_read(0, value);
      check_read(12, 0);
      check_irq(0);
    end
    tick(); // Pre-edge COUNT is 3: latch pending and advance COUNT to 4.
    check_read(0, 4);
    check_read(12, 1);
    check_irq(0);
    write_reg(8, 0);
    check_read(0, 5); // Disabling uses the old enable on this edge.
    repeat (3) tick();
    check_read(0, 5);
    check_read(12, 1);

    // Interrupt masking never clears the sticky pending flag.
    write_reg(8, 32'hffff_fffe, 4'b0001);
    check_read(8, 2);
    check_irq(1);
    write_reg(8, 0, 4'b0010);
    check_read(8, 2);
    check_irq(1);
    write_reg(8, 0);
    check_irq(0);
    check_read(12, 1);
    write_reg(8, 2);
    check_irq(1);

    write_reg(12, 0);
    write_reg(12, 2);
    write_reg(12, 1, 4'b1110);
    write_reg(12, 1, 4'b0000);
    write_reg(12, 1, 4'b0001, 0, 1);
    write_reg(12, 1, 4'b0001, 1, 0);
    check_read(12, 1);
    check_irq(1);
    write_reg(12, 1, 4'b0001);
    check_read(12, 0);
    check_irq(0);
    check_read(0, 5);

    write_reg(4, 5);
    tick();
    check_read(12, 0); // Matching while disabled still cannot set pending.
    write_reg(8, 3);
    check_read(0, 5);
    write_reg(12, 1, 4'b0001); // Match and clear on the same edge: match wins.
    check_read(0, 6);
    check_read(12, 1);
    check_irq(1);
    write_reg(12, 1, 4'b0001);
    check_read(0, 7);
    check_read(12, 0);
    check_irq(0);
    write_reg(0, 32'hffff_ffff); // COUNT write cannot replace normal increment.
    check_read(0, 8);
    write_reg(4, 9);
    check_read(0, 9);
    tick();
    check_read(0, 10);
    check_read(12, 1);
    check_irq(1);

    // Synchronous reset holds state until a rising edge and overrides writes.
    reset = 1;
    check_read(0, 10);
    check_read(4, 9);
    check_read(8, 3);
    check_read(12, 1);
    check_irq(1);
    write_reg(4, 32'hffff_ffff);
    check_reset();
    reset = 0;
    write_reg(8, 3);
    tick(); // COMPARE=0 matches the first enabled pre-edge count.
    check_read(0, 1);
    check_read(12, 1);
    check_irq(1);
    $display("PASS: %0d timer checks completed", checks_run);
    $finish;
  end
endmodule
