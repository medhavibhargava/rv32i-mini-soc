`timescale 1ns/1ps

module gpio_checker #(parameter int WIDTH = 32) (output logic done = 0);
  localparam logic [31:0] WIDTH_MASK = 32'hffff_ffff >> (32 - WIDTH);
  logic clk = 0;
  logic reset = 1;
  logic selected = 0;
  logic read_intent = 0;
  logic write_intent = 0;
  logic [31:0] addr = 0;
  logic [31:0] write_data = 0;
  logic [3:0] strobes = 0;
  wire [31:0] read_data;
  logic [WIDTH-1:0] gpio_in = '0;
  wire [WIDTH-1:0] gpio_out, gpio_dir;
  int checks_run = 0;

  always #5 clk = ~clk;
  gpio #(.GPIO_WIDTH(WIDTH)) dut (
    .clk_i(clk), .reset_i(reset), .select_i(selected),
    .read_i(read_intent), .write_i(write_intent), .addr_i(addr),
    .write_data_i(write_data), .write_strobes_i(strobes),
    .read_data_o(read_data), .gpio_out_o(gpio_out),
    .gpio_in_i(gpio_in), .gpio_dir_o(gpio_dir)
  );

  task automatic check_pins(input logic [31:0] expected_out,
                            input logic [31:0] expected_dir);
    checks_run++;
    if (gpio_out !== expected_out[WIDTH-1:0] ||
        gpio_dir !== expected_dir[WIDTH-1:0])
      $fatal(1, "GPIO width=%0d pin check=%0d out=%h dir=%h expected=%h/%h",
             WIDTH, checks_run, gpio_out, gpio_dir, expected_out, expected_dir);
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
      $fatal(1, "GPIO width=%0d addr=%h got=%h expected=%h",
             WIDTH, address, read_data, expected);
  endtask

  task automatic write_reg(input logic [31:0] address,
                           input logic [31:0] data,
                           input logic [3:0] mask,
                           input logic sel = 1, input logic wr = 1);
    @(negedge clk);
    selected = sel;
    read_intent = 0;
    write_intent = wr;
    addr = address;
    write_data = data;
    strobes = mask;
    @(posedge clk);
    #1;
    write_intent = 0;
    strobes = 0;
  endtask

  task automatic check_registers(input logic [31:0] expected_out,
                                 input logic [31:0] expected_dir);
    check_pins(expected_out, expected_dir);
    check_read(0, expected_out & WIDTH_MASK);
    check_read(8, expected_dir & WIDTH_MASK);
  endtask

  initial begin
    @(posedge clk);
    #1;
    check_registers(0, 0);
    @(negedge clk);
    reset = 0;
    write_reg(0, 32'h1234_5678, 4'b1111);
    check_registers(32'h1234_5678, 0);
    write_reg(8, 32'h8765_4321, 4'b1111);
    check_registers(32'h1234_5678, 32'h8765_4321);

    // Every output byte lane preserves its neighbors and the direction bank.
    write_reg(0, 32'hffff_ffaa, 4'b0001);
    check_registers(32'h1234_56aa, 32'h8765_4321);
    write_reg(0, 32'hffff_bbff, 4'b0010);
    check_registers(32'h1234_bbaa, 32'h8765_4321);
    write_reg(0, 32'hffcc_ffff, 4'b0100);
    check_registers(32'h12cc_bbaa, 32'h8765_4321);
    write_reg(0, 32'hddff_ffff, 4'b1000);
    check_registers(32'hddcc_bbaa, 32'h8765_4321);

    // Direction strobes include each lane, with zeros replacing old ones.
    write_reg(8, 0, 4'b0001);
    check_registers(32'hddcc_bbaa, 32'h8765_4300);
    write_reg(8, 0, 4'b0010);
    check_registers(32'hddcc_bbaa, 32'h8765_0000);
    write_reg(8, 0, 4'b0100);
    check_registers(32'hddcc_bbaa, 32'h8700_0000);
    write_reg(8, 0, 4'b1000);
    check_registers(32'hddcc_bbaa, 0);
    write_reg(8, 32'hffff_ffff, 4'b0101);
    check_registers(32'hddcc_bbaa, 32'h00ff_00ff);
    write_reg(0, 32'hffff_1357, 4'b0011);
    check_registers(32'hddcc_1357, 32'h00ff_00ff);

    // Live inputs read independently of output and direction state.
    gpio_in = '1;
    check_read(4, WIDTH_MASK);
    write_reg(4, 0, 4'b1111);
    check_read(4, WIDTH_MASK);
    gpio_in = 32'h5a5a_a5a5;
    check_read(4, 32'h5a5a_a5a5 & WIDTH_MASK);
    check_registers(32'hddcc_1357, 32'h00ff_00ff);

    write_reg(0, 0, 4'b0000);
    write_reg(8, 0, 4'b0000);
    write_reg(0, 0, 4'b1111, 0, 1);
    write_reg(8, 0, 4'b1111, 1, 0);
    write_reg(12, 0, 4'b1111);
    write_reg(32'h100, 0, 4'b1111);
    write_reg(1, 0, 4'b1111);
    check_registers(32'hddcc_1357, 32'h00ff_00ff);
    check_read(12, 0);
    check_read(32'h100, 0);
    check_read(1, 0);
    check_read(0, 0, 0, 1);
    check_read(8, 0, 1, 0);

    // Reset must be synchronous and win over an otherwise valid write.
    @(negedge clk);
    reset = 1;
    selected = 1;
    write_intent = 1;
    addr = 0;
    strobes = 4'b1111;
    write_data = 32'hffff_ffff;
    #1;
    check_pins(32'hddcc_1357, 32'h00ff_00ff);
    @(posedge clk);
    #1;
    write_intent = 0;
    check_registers(0, 0);
    check_read(4, 32'h5a5a_a5a5 & WIDTH_MASK);
    @(negedge clk);
    reset = 0;
    write_reg(0, 32'hdead_beef, 4'b1111);
    write_reg(8, 32'hffff_ffff, 4'b1111);
    check_registers(32'hdead_beef, 32'hffff_ffff);
    $display("PASS: %0d GPIO checks completed (width=%0d)", checks_run, WIDTH);
    done = 1;
  end
endmodule

module tb_gpio;
  wire done_default, done_partial, done_minimum;
  gpio_checker default_width (.done(done_default));
  gpio_checker #(.WIDTH(13)) partial_byte (.done(done_partial));
  gpio_checker #(.WIDTH(1)) minimum_width (.done(done_minimum));
  initial begin
    wait (done_default && done_partial && done_minimum);
    $display("PASS: GPIO regression completed");
    $finish;
  end
  initial begin
    #10000;
    $fatal(1, "GPIO regression timed out");
  end
endmodule
