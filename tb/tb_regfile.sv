`timescale 1ns/1ps

module tb_regfile;
  logic        clk = 1'b0;
  logic        write_enable;
  logic [4:0]  write_addr;
  logic [31:0] write_data;
  logic [4:0]  read_addr_a;
  logic [4:0]  read_addr_b;
  logic [31:0] read_data_a;
  logic [31:0] read_data_b;
  int unsigned checks_run = 0;

  always #5 clk = ~clk;

  regfile dut (
    .clk_i          (clk),
    .write_enable_i (write_enable),
    .write_addr_i   (write_addr),
    .write_data_i   (write_data),
    .read_addr_a_i  (read_addr_a),
    .read_addr_b_i  (read_addr_b),
    .read_data_a_o  (read_data_a),
    .read_data_b_o  (read_data_b)
  );

  task automatic write_register(
    input logic [4:0]  address,
    input logic [31:0] data
  );
    begin
      @(negedge clk);
      write_enable = 1'b1;
      write_addr   = address;
      write_data   = data;
      @(posedge clk);
      #1;
      write_enable = 1'b0;
    end
  endtask

  task automatic check_reads(
    input logic [4:0]  address_a,
    input logic [31:0] expected_a,
    input logic [4:0]  address_b,
    input logic [31:0] expected_b
  );
    begin
      read_addr_a = address_a;
      read_addr_b = address_b;
      #1;
      checks_run++;

      if ((read_data_a !== expected_a) || (read_data_b !== expected_b)) begin
        $fatal(1,
               "Register-file check %0d failed: x%0d expected=%h got=%h; x%0d expected=%h got=%h",
               checks_run,
               address_a, expected_a, read_data_a,
               address_b, expected_b, read_data_b);
      end
    end
  endtask

  initial begin
    write_enable = 1'b0;
    write_addr   = 5'd0;
    write_data   = 32'b0;

    // x0 reads as zero before any clocked write.
    check_reads(5'd0, 32'b0, 5'd0, 32'b0);

    // Normal writes and simultaneous reads from distinct registers.
    write_register(5'd5,  32'h1234_5678);
    write_register(5'd12, 32'hcafe_babe);
    check_reads(5'd5, 32'h1234_5678, 5'd12, 32'hcafe_babe);

    // A later write replaces the old value.
    write_register(5'd5, 32'hdead_beef);
    check_reads(5'd5, 32'hdead_beef, 5'd12, 32'hcafe_babe);

    // Writes to x0 are ignored, and either read port still returns zero.
    write_register(5'd0, 32'hffff_ffff);
    check_reads(5'd0, 32'b0, 5'd5, 32'hdead_beef);
    check_reads(5'd12, 32'hcafe_babe, 5'd0, 32'b0);

    $display("PASS: %0d register-file checks completed", checks_run);
    $finish;
  end
endmodule
