`timescale 1ns/1ps

module tb_data_ram;
  // Exercise a non-power-of-two capacity, including its last word.
  localparam int unsigned MEM_SIZE_BYTES = 20;
  logic        clk = 1'b0;
  logic [31:0] addr = 32'b0;
  logic [31:0] write_data = 32'b0;
  logic [3:0]  write_strobes = 4'b0;
  logic [31:0] read_data;
  int unsigned checks_run = 0;

  always #5 clk = ~clk;

  data_ram #(.MEM_SIZE_BYTES(MEM_SIZE_BYTES)) dut (
    .clk_i           (clk),
    .addr_i          (addr),
    .write_data_i    (write_data),
    .write_strobes_i (write_strobes),
    .read_data_o     (read_data)
  );

  task automatic check_read(
    input logic [31:0] address,
    input logic [31:0] expected
  );
    addr = address;
    #1;
    checks_run++;
    if (read_data !== expected) begin
      $fatal(1, "RAM check %0d failed: addr=%h expected=%h got=%h",
             checks_run, address, expected, read_data);
    end
  endtask

  task automatic write_word(
    input logic [31:0] address,
    input logic [31:0] data,
    input logic [3:0] strobes
  );
    @(negedge clk);
    addr = address;
    write_data = data;
    write_strobes = strobes;
    @(posedge clk);
    #1;
    write_strobes = 4'b0;
  endtask

  initial begin
    write_word(0, 32'h1234_5678, 4'b1111);
    check_read(0, 32'h1234_5678);
    write_word(4, 32'h89ab_cdef, 4'b1111);
    write_word(MEM_SIZE_BYTES - 4, 32'hfeed_face, 4'b1111);
    check_read(MEM_SIZE_BYTES - 4, 32'hfeed_face);
    check_read(4, 32'h89ab_cdef);
    check_read(0, 32'h1234_5678);

    // Each lane updates only its byte, despite nonzero data in other lanes.
    write_word(0, 32'hffff_ffaa, 4'b0001);
    check_read(0, 32'h1234_56aa);
    write_word(0, 32'hffff_bbff, 4'b0010);
    check_read(0, 32'h1234_bbaa);
    write_word(0, 32'hffcc_ffff, 4'b0100);
    check_read(0, 32'h12cc_bbaa);
    write_word(0, 32'hddff_ffff, 4'b1000);
    check_read(0, 32'hddcc_bbaa);

    // Both aligned halfwords preserve the opposite halfword.
    write_word(0, 32'hffff_1357, 4'b0011);
    check_read(0, 32'hddcc_1357);
    write_word(0, 32'h2468_ffff, 4'b1100);
    check_read(0, 32'h2468_1357);
    write_word(0, 32'hffff_ffff, 4'b0000);
    check_read(0, 32'h2468_1357);

    // A pending full overwrite must not affect reads before the rising edge.
    @(negedge clk);
    addr = 0;
    write_data = 32'hdead_beef;
    write_strobes = 4'b1111;
    check_read(0, 32'h2468_1357);
    @(posedge clk);
    #1;
    write_strobes = 4'b0;
    check_read(0, 32'hdead_beef);

    // Change read addresses between rising edges: no read clock is required.
    @(negedge clk);
    check_read(4, 32'h89ab_cdef);
    check_read(MEM_SIZE_BYTES - 4, 32'hfeed_face);
    check_read(0, 32'hdead_beef);

    $display("PASS: %0d data-RAM checks completed", checks_run);
    $finish;
  end
endmodule
