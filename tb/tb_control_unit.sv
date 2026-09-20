`timescale 1ns/1ps

module tb_control_unit;
  import alu_pkg::*;
  import imm_gen_pkg::*;
  import control_unit_pkg::*;

  logic [31:0]         instruction;
  logic                instruction_valid;
  logic                register_write;
  alu_src_a_t          alu_src_a;
  alu_src_b_t          alu_src_b;
  alu_op_t             alu_op;
  imm_format_t         immediate_format;
  logic                memory_read;
  logic                memory_write;
  memory_size_t        memory_size;
  logic                load_unsigned;
  writeback_source_t   writeback_source;
  branch_control_t     branch_control;
  jump_control_t       jump_control;
  int unsigned         checks_run = 0;

  control_unit dut (
    .instruction_i       (instruction),
    .instruction_valid_o (instruction_valid),
    .register_write_o    (register_write),
    .alu_src_a_o         (alu_src_a),
    .alu_src_b_o         (alu_src_b),
    .alu_op_o            (alu_op),
    .immediate_format_o  (immediate_format),
    .memory_read_o       (memory_read),
    .memory_write_o      (memory_write),
    .memory_size_o       (memory_size),
    .load_unsigned_o     (load_unsigned),
    .writeback_source_o  (writeback_source),
    .branch_control_o    (branch_control),
    .jump_control_o      (jump_control)
  );

  task automatic check(
    input logic [31:0]       test_instruction,
    input logic              expected_valid,
    input logic              expected_register_write,
    input alu_src_a_t        expected_src_a,
    input alu_src_b_t        expected_src_b,
    input alu_op_t           expected_alu_op,
    input imm_format_t       expected_immediate_format,
    input logic              expected_memory_read,
    input logic              expected_memory_write,
    input memory_size_t      expected_memory_size,
    input logic              expected_load_unsigned,
    input writeback_source_t expected_writeback_source,
    input branch_control_t   expected_branch_control,
    input jump_control_t     expected_jump_control
  );
    begin
      instruction = test_instruction;
      #1;
      checks_run++;

      if ((instruction_valid !== expected_valid) ||
          (register_write !== expected_register_write) ||
          (alu_src_a !== expected_src_a) ||
          (alu_src_b !== expected_src_b) ||
          (alu_op !== expected_alu_op) ||
          (immediate_format !== expected_immediate_format) ||
          (memory_read !== expected_memory_read) ||
          (memory_write !== expected_memory_write) ||
          (memory_size !== expected_memory_size) ||
          (load_unsigned !== expected_load_unsigned) ||
          (writeback_source !== expected_writeback_source) ||
          (branch_control !== expected_branch_control) ||
          (jump_control !== expected_jump_control)) begin
        $fatal(1, "Control check %0d failed for instruction %h", checks_run,
               test_instruction);
      end
    end
  endtask

  initial begin
    // LUI and AUIPC.
    check(32'h1234_52b7, 1'b1, 1'b1,
          ALU_SRC_A_ZERO, ALU_SRC_B_IMM, ALU_ADD, IMM_U,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_ALU, BRANCH_NONE, JUMP_NONE);
    check(32'h1234_5297, 1'b1, 1'b1,
          ALU_SRC_A_PC, ALU_SRC_B_IMM, ALU_ADD, IMM_U,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_ALU, BRANCH_NONE, JUMP_NONE);

    // Direct and indirect jumps.
    check(32'h0080_00ef, 1'b1, 1'b1,
          ALU_SRC_A_PC, ALU_SRC_B_IMM, ALU_ADD, IMM_J,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_PC_PLUS_4, BRANCH_NONE, JUMP_JAL);
    check(32'h0001_00e7, 1'b1, 1'b1,
          ALU_SRC_A_RS1, ALU_SRC_B_IMM, ALU_ADD, IMM_I,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_PC_PLUS_4, BRANCH_NONE, JUMP_JALR);

    // Signed/equality and unsigned branch classes.
    check(32'h0020_8463, 1'b1, 1'b0,
          ALU_SRC_A_RS1, ALU_SRC_B_RS2, ALU_SUB, IMM_B,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_ALU, BRANCH_EQ, JUMP_NONE);
    check(32'h0020_e463, 1'b1, 1'b0,
          ALU_SRC_A_RS1, ALU_SRC_B_RS2, ALU_SLTU, IMM_B,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_ALU, BRANCH_LTU, JUMP_NONE);

    // Signed word load and unsigned byte load.
    check(32'h0041_2283, 1'b1, 1'b1,
          ALU_SRC_A_RS1, ALU_SRC_B_IMM, ALU_ADD, IMM_I,
          1'b1, 1'b0, MEM_WORD, 1'b0, WB_MEMORY, BRANCH_NONE, JUMP_NONE);
    check(32'h0041_4283, 1'b1, 1'b1,
          ALU_SRC_A_RS1, ALU_SRC_B_IMM, ALU_ADD, IMM_I,
          1'b1, 1'b0, MEM_BYTE, 1'b1, WB_MEMORY, BRANCH_NONE, JUMP_NONE);

    // Word and halfword stores.
    check(32'h0051_2223, 1'b1, 1'b0,
          ALU_SRC_A_RS1, ALU_SRC_B_IMM, ALU_ADD, IMM_S,
          1'b0, 1'b1, MEM_WORD, 1'b0, WB_ALU, BRANCH_NONE, JUMP_NONE);
    check(32'h0051_1223, 1'b1, 1'b0,
          ALU_SRC_A_RS1, ALU_SRC_B_IMM, ALU_ADD, IMM_S,
          1'b0, 1'b1, MEM_HALF, 1'b0, WB_ALU, BRANCH_NONE, JUMP_NONE);

    // OP-IMM arithmetic and shift decoding.
    check(32'h0011_0093, 1'b1, 1'b1,
          ALU_SRC_A_RS1, ALU_SRC_B_IMM, ALU_ADD, IMM_I,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_ALU, BRANCH_NONE, JUMP_NONE);
    check(32'h4011_5093, 1'b1, 1'b1,
          ALU_SRC_A_RS1, ALU_SRC_B_IMM, ALU_SRA, IMM_I,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_ALU, BRANCH_NONE, JUMP_NONE);

    // OP subtraction and unsigned comparison.
    check(32'h4020_81b3, 1'b1, 1'b1,
          ALU_SRC_A_RS1, ALU_SRC_B_RS2, ALU_SUB, IMM_I,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_ALU, BRANCH_NONE, JUMP_NONE);
    check(32'h0020_b1b3, 1'b1, 1'b1,
          ALU_SRC_A_RS1, ALU_SRC_B_RS2, ALU_SLTU, IMM_I,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_ALU, BRANCH_NONE, JUMP_NONE);

    // Unknown opcodes and reserved funct fields retain all safe defaults.
    check(32'hffff_ffff, 1'b0, 1'b0,
          ALU_SRC_A_RS1, ALU_SRC_B_RS2, ALU_ADD, IMM_I,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_ALU, BRANCH_NONE, JUMP_NONE);
    check(32'h0000_1067, 1'b0, 1'b0,
          ALU_SRC_A_RS1, ALU_SRC_B_RS2, ALU_ADD, IMM_I,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_ALU, BRANCH_NONE, JUMP_NONE);
    check(32'h0200_0033, 1'b0, 1'b0,
          ALU_SRC_A_RS1, ALU_SRC_B_RS2, ALU_ADD, IMM_I,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_ALU, BRANCH_NONE, JUMP_NONE);
    check(32'h0000_2063, 1'b0, 1'b0,
          ALU_SRC_A_RS1, ALU_SRC_B_RS2, ALU_ADD, IMM_I,
          1'b0, 1'b0, MEM_WORD, 1'b0, WB_ALU, BRANCH_NONE, JUMP_NONE);

    $display("PASS: %0d control-unit checks completed", checks_run);
    $finish;
  end
endmodule
