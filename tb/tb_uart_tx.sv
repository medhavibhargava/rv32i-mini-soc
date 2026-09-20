`timescale 1ns/1ps

module uart_tx_checker #(
  parameter int CLOCK_HZ = 43,
  parameter int BAUD = 10
) (
  output logic done = 1'b0
);
  localparam int BIT_CYCLES = CLOCK_HZ / BAUD;
  logic clk = 1'b0;
  logic reset = 1'b1;
  logic selected = 1'b0;
  logic read_intent = 1'b0;
  logic write_intent = 1'b0;
  logic [31:0] addr = 0;
  logic [31:0] write_data = 0;
  logic [3:0] strobes = 0;
  wire [31:0] read_data;
  wire tx;
  int checks_run = 0;

  always #5 clk = ~clk;

  uart_tx #(.CLOCK_FREQ_HZ(CLOCK_HZ), .BAUD_RATE(BAUD)) dut (
    .clk_i(clk), .reset_i(reset), .select_i(selected),
    .read_i(read_intent), .write_i(write_intent), .addr_i(addr),
    .write_data_i(write_data), .write_strobes_i(strobes),
    .read_data_o(read_data), .tx_o(tx)
  );

  task automatic check_state(input logic expected_tx, input logic expected_busy);
    selected = 1;
    read_intent = 1;
    addr = 4;
    #1;
    checks_run++;
    if (tx !== expected_tx || read_data !== {31'b0, expected_busy})
      $fatal(1, "UART divisor=%0d check=%0d TX=%b expected=%b STATUS=%h expected busy=%b",
             BIT_CYCLES, checks_run, tx, expected_tx, read_data, expected_busy);
  endtask

  task automatic check_read(input logic sel, input logic rd,
                            input logic [31:0] address,
                            input logic [31:0] expected);
    selected = sel;
    read_intent = rd;
    addr = address;
    #1;
    checks_run++;
    if (read_data !== expected)
      $fatal(1, "UART read failure divisor=%0d addr=%h got=%h expected=%h",
             BIT_CYCLES, address, read_data, expected);
  endtask

  task automatic bus_write(input logic sel, input logic wr,
                           input logic [31:0] address,
                           input logic [31:0] data,
                           input logic [3:0] mask);
    @(negedge clk);
    selected = sel;
    write_intent = wr;
    read_intent = 0;
    addr = address;
    write_data = data;
    strobes = mask;
    @(posedge clk);
    #1;
    write_intent = 0;
    strobes = 0;
  endtask

  task automatic check_frame(input logic [7:0] data, input logic [3:0] mask);
    logic [9:0] expected_frame;
    expected_frame = {1'b1, data, 1'b0};
    bus_write(1, 1, 0, {24'habcdef, data}, mask);
    // Check every clock of all ten bits, including the complete stop period.
    for (int cycle = 0; cycle < 10 * BIT_CYCLES; cycle++) begin
      check_state(expected_frame[cycle / BIT_CYCLES], 1);
      @(negedge clk);
      // Attempt a different byte during the start bit and on the last busy
      // edge. Neither may corrupt this frame or queue a later transmission.
      write_intent = (cycle == 0 || cycle == 10 * BIT_CYCLES - 1);
      addr = 0;
      write_data = {24'b0, ~data};
      strobes = 4'b1111;
      @(posedge clk);
      #1;
      write_intent = 0;
      strobes = 0;
    end
    check_state(1, 0);
    repeat (11 * BIT_CYCLES) begin
      @(posedge clk);
      #1;
      check_state(1, 0);
    end
  endtask

  initial begin
    @(posedge clk);
    #1;
    check_state(1, 0);
    @(negedge clk);
    reset = 0;

    // Disabled writes, all masks without lane zero, and non-TXDATA offsets.
    bus_write(0, 1, 0, 32'hff, 4'b1111);
    check_state(1, 0);
    bus_write(1, 0, 0, 32'hff, 4'b1111);
    check_state(1, 0);
    for (int mask = 0; mask < 16; mask += 2) begin
      bus_write(1, 1, 0, 32'hff, mask[3:0]);
      check_state(1, 0);
    end
    bus_write(1, 1, 4, 32'hff, 4'b1111);
    check_state(1, 0);
    bus_write(1, 1, 8, 32'hff, 4'b1111);
    check_state(1, 0);
    bus_write(1, 1, 1, 32'hff, 4'b1111);
    check_state(1, 0);
    check_read(1, 1, 0, 0);
    check_read(1, 1, 8, 0);
    check_read(1, 1, 32'h104, 0);

    check_frame(8'h96, 4'b0001);
    check_frame(8'h69, 4'b1111);
    check_frame(8'h00, 4'b0001);
    check_frame(8'hff, 4'b1111);

    // Read gating while busy, then reset aborts transmission and restores idle.
    bus_write(1, 1, 0, 32'h55, 4'b0001);
    check_read(0, 1, 4, 0);
    check_read(1, 0, 4, 0);
    check_read(1, 1, 0, 0);
    check_read(1, 1, 8, 0);
    check_read(1, 1, 4, 1);
    @(negedge clk);
    reset = 1;
    @(posedge clk);
    #1;
    check_state(1, 0);
    @(negedge clk);
    reset = 0;
    check_frame(8'ha3, 4'b0001);

    $display("PASS: %0d UART checks completed (clocks per bit=%0d)",
             checks_run, BIT_CYCLES);
    done = 1;
  end
endmodule

module tb_uart_tx;
  wire done_normal, done_minimum;
  // Nonintegral ratio checks truncation; divisor one checks minimum counter width.
  uart_tx_checker #(.CLOCK_HZ(43), .BAUD(10)) normal (.done(done_normal));
  uart_tx_checker #(.CLOCK_HZ(10), .BAUD(10)) minimum (.done(done_minimum));
  initial begin
    wait (done_normal && done_minimum);
    $display("PASS: UART regression completed");
    $finish;
  end
  initial begin
    #100000;
    $fatal(1, "UART regression timed out");
  end
endmodule
