`timescale 1ns/1ps

module tb_imm_gen;
  import imm_gen_pkg::*;

  logic [31:0] instruction;
  imm_format_t format;
  logic [31:0] immediate;
  int unsigned checks_run = 0;

  imm_gen dut (
    .instruction_i (instruction),
    .format_i      (format),
    .immediate_o   (immediate)
  );

  task automatic check(
    input imm_format_t test_format,
    input logic [31:0] test_instruction,
    input logic [31:0] expected
  );
    begin
      format      = test_format;
      instruction = test_instruction;
      #1;
      checks_run++;

      if (immediate !== expected) begin
        $fatal(1,
               "Immediate check %0d failed: format=%0d instruction=%h expected=%h got=%h",
               checks_run, test_format, test_instruction, expected, immediate);
      end
    end
  endtask

  initial begin
    // I-type: immediate occupies instruction[31:20].
    check(IMM_I, 32'h7a50_0000, 32'h0000_07a5);
    check(IMM_I, 32'h8000_0000, 32'hffff_f800);

    // S-type: immediate is split across instruction[31:25] and [11:7].
    check(IMM_S, 32'h5a00_0180, 32'h0000_05a3);

    // B-type: reconstructed signed offsets include an implicit low zero bit.
    check(IMM_B, 32'h0000_0800, 32'h0000_0010);
    check(IMM_B, 32'hfe00_0e80, 32'hffff_fffc);

    // U-type preserves the upper 20 bits and clears the lower 12 bits.
    check(IMM_U, 32'habcd_e123, 32'habcd_e000);

    // J-type: reconstructed signed offsets include an implicit low zero bit.
    check(IMM_J, 32'h4000_0000, 32'h0000_0400);
    check(IMM_J, 32'hffff_f000, 32'hffff_fffe);

    $display("PASS: %0d immediate-generator checks completed", checks_run);
    $finish;
  end
endmodule
