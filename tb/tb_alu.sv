`timescale 1ns/1ps

module tb_alu;
  import alu_pkg::*;

  logic [31:0] lhs;
  logic [31:0] rhs;
  alu_op_t     op;
  logic [31:0] result;
  int unsigned tests_run = 0;

  alu dut (
    .lhs_i    (lhs),
    .rhs_i    (rhs),
    .op_i     (op),
    .result_o (result)
  );

  task automatic check(
    input alu_op_t    test_op,
    input logic [31:0] test_lhs,
    input logic [31:0] test_rhs,
    input logic [31:0] expected
  );
    begin
      op  = test_op;
      lhs = test_lhs;
      rhs = test_rhs;
      #1;
      tests_run++;

      if (result !== expected) begin
        $fatal(1,
               "ALU test %0d failed: op=%0d lhs=%h rhs=%h expected=%h got=%h",
               tests_run, test_op, test_lhs, test_rhs, expected, result);
      end
    end
  endtask

  initial begin
    // Basic arithmetic and logic.
    check(ALU_ADD,  32'd20,       32'd22,       32'd42);
    check(ALU_SUB,  32'd20,       32'd22,       32'hffff_fffe);
    check(ALU_AND,  32'ha5a5_0ff0, 32'h0ff0_f0f0, 32'h05a0_00f0);
    check(ALU_OR,   32'ha5a5_0ff0, 32'h0ff0_f0f0, 32'haff5_fff0);
    check(ALU_XOR,  32'ha5a5_0ff0, 32'h0ff0_f0f0, 32'haa55_ff00);

    // RV32 arithmetic wraps modulo 2^32.
    check(ALU_ADD, 32'hffff_ffff, 32'd1, 32'h0000_0000);
    check(ALU_SUB, 32'h0000_0000, 32'd1, 32'hffff_ffff);
    check(ALU_ADD, 32'h7fff_ffff, 32'd1, 32'h8000_0000);

    // The same bit patterns compare differently as signed and unsigned values.
    check(ALU_SLT,  32'hffff_ffff, 32'd1, 32'd1);
    check(ALU_SLTU, 32'hffff_ffff, 32'd1, 32'd0);
    check(ALU_SLT,  32'd1, 32'hffff_ffff, 32'd0);
    check(ALU_SLTU, 32'd1, 32'hffff_ffff, 32'd1);

    // Shift amounts use only the low five bits, as required by RV32I.
    check(ALU_SLL, 32'h1234_5678, 32'd0,  32'h1234_5678);
    check(ALU_SLL, 32'h0000_0001, 32'd31, 32'h8000_0000);
    check(ALU_SRL, 32'h8000_0000, 32'd0,  32'h8000_0000);
    check(ALU_SRL, 32'h8000_0000, 32'd31, 32'h0000_0001);
    check(ALU_SRA, 32'h8000_0000, 32'd0,  32'h8000_0000);
    check(ALU_SRA, 32'h8000_0000, 32'd31, 32'hffff_ffff);
    check(ALU_SRL, 32'h8000_0000, 32'd1,  32'h4000_0000);
    check(ALU_SRA, 32'h8000_0000, 32'd1,  32'hc000_0000);

    $display("PASS: %0d ALU checks completed", tests_run);
    $finish;
  end
endmodule
