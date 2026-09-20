`timescale 1ns/1ps

module tb_simple_interconnect;
  logic [31:0] addr;
  logic read_intent, write_intent;
  logic [31:0] write_data, read_data;
  logic [3:0] strobes;
  // Vector lane order: RAM, UART, GPIO, TIMER.
  wire [3:0] selected, reads, writes;
  wire [31:0] slave_addr [0:3];
  wire [31:0] slave_write_data [0:3];
  wire [3:0] slave_strobes [0:3];
  logic [31:0] slave_read_data [0:3];
  int unsigned checks_run = 0;

  simple_interconnect dut (
    .cpu_addr_i(addr), .cpu_read_i(read_intent), .cpu_write_i(write_intent),
    .cpu_write_data_i(write_data), .cpu_write_strobes_i(strobes),
    .cpu_read_data_o(read_data),
    .ram_select_o(selected[0]), .ram_read_o(reads[0]), .ram_write_o(writes[0]),
    .ram_addr_o(slave_addr[0]), .ram_write_data_o(slave_write_data[0]),
    .ram_write_strobes_o(slave_strobes[0]), .ram_read_data_i(slave_read_data[0]),
    .uart_select_o(selected[1]), .uart_read_o(reads[1]), .uart_write_o(writes[1]),
    .uart_addr_o(slave_addr[1]), .uart_write_data_o(slave_write_data[1]),
    .uart_write_strobes_o(slave_strobes[1]), .uart_read_data_i(slave_read_data[1]),
    .gpio_select_o(selected[2]), .gpio_read_o(reads[2]), .gpio_write_o(writes[2]),
    .gpio_addr_o(slave_addr[2]), .gpio_write_data_o(slave_write_data[2]),
    .gpio_write_strobes_o(slave_strobes[2]), .gpio_read_data_i(slave_read_data[2]),
    .timer_select_o(selected[3]), .timer_read_o(reads[3]), .timer_write_o(writes[3]),
    .timer_addr_o(slave_addr[3]), .timer_write_data_o(slave_write_data[3]),
    .timer_write_strobes_o(slave_strobes[3]), .timer_read_data_i(slave_read_data[3])
  );

  task automatic check_address(
    input logic [31:0] address,
    input int target,
    input logic [31:0] offset
  );
    logic [3:0] expected_select;
    logic [31:0] expected_read;
    expected_select = 4'b0;
    if (target >= 0) expected_select[target] = 1'b1;
    addr = address;
    // Idle, read, write, and simultaneous intents; every strobe pattern.
    for (int mode = 0; mode < 4; mode++) begin
      for (int mask = 0; mask < 16; mask++) begin
        read_intent = mode[0];
        write_intent = mode[1];
        strobes = mask[3:0];
        write_data = 32'ha5c3_7e19 ^ address ^ mask;
        for (int lane = 0; lane < 4; lane++)
          slave_read_data[lane] = 32'h1122_3344 ^ (32'h1010_1010 * lane) ^ mask;
        expected_read = 32'b0;
        if (read_intent && target >= 0) expected_read = slave_read_data[target];
        #1;
        checks_run++;
        if (selected !== expected_select ||
            reads !== (expected_select & {4{read_intent}}) ||
            writes !== (expected_select & {4{write_intent}}) ||
            read_data !== expected_read)
          $fatal(1, "Decode/mux failure addr=%h mode=%0d mask=%h selects=%b reads=%b writes=%b data=%h expected=%h",
                 address, mode, strobes, selected, reads, writes, read_data, expected_read);
        for (int lane = 0; lane < 4; lane++) begin
          if (slave_addr[lane] !== ((lane == target) ? offset : 32'b0) ||
              slave_write_data[lane] !== write_data ||
              slave_strobes[lane] !== ((lane == target && write_intent) ? strobes : 4'b0))
            $fatal(1, "Routing failure addr=%h mode=%0d mask=%h lane=%0d",
                   address, mode, strobes, lane);
        end
      end
    end
  endtask

  initial begin
    // Include exact byte boundaries; the decoder does not enforce alignment.
    check_address(32'h00000000, 0, 32'h000);
    check_address(32'h00000004, 0, 32'h004);
    check_address(32'h00000800, 0, 32'h800);
    check_address(32'h00000ffc, 0, 32'hffc);
    check_address(32'h00000fff, 0, 32'hfff);
    check_address(32'h00001000, -1, 32'h0);
    check_address(32'h0fffffff, -1, 32'h0);
    check_address(32'h10000000, 1, 32'h0);
    check_address(32'h10000080, 1, 32'h80);
    check_address(32'h100000fc, 1, 32'hfc);
    check_address(32'h100000ff, 1, 32'hff);
    check_address(32'h10000100, 2, 32'h0);
    check_address(32'h10000180, 2, 32'h80);
    check_address(32'h100001fc, 2, 32'hfc);
    check_address(32'h100001ff, 2, 32'hff);
    check_address(32'h10000200, 3, 32'h0);
    check_address(32'h10000280, 3, 32'h80);
    check_address(32'h100002fc, 3, 32'hfc);
    check_address(32'h100002ff, 3, 32'hff);
    check_address(32'h10000300, -1, 32'h0);
    check_address(32'h10001000, -1, 32'h0);
    check_address(32'h20000000, -1, 32'h0);
    check_address(32'hffffffff, -1, 32'h0);
    check_address(32'h00000000, 0, 32'h0);
    $display("PASS: %0d simple-interconnect checks completed", checks_run);
    $finish;
  end
endmodule
