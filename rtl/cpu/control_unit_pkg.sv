`timescale 1ns/1ps

package control_unit_pkg;
  typedef enum logic [1:0] {
    ALU_SRC_A_RS1  = 2'd0,
    ALU_SRC_A_PC   = 2'd1,
    ALU_SRC_A_ZERO = 2'd2
  } alu_src_a_t;

  typedef enum logic [1:0] {
    ALU_SRC_B_RS2  = 2'd0,
    ALU_SRC_B_IMM  = 2'd1,
    ALU_SRC_B_FOUR = 2'd2
  } alu_src_b_t;

  typedef enum logic [1:0] {
    WB_ALU       = 2'd0,
    WB_MEMORY    = 2'd1,
    WB_PC_PLUS_4 = 2'd2
  } writeback_source_t;

  typedef enum logic [2:0] {
    BRANCH_NONE = 3'd0,
    BRANCH_EQ   = 3'd1,
    BRANCH_NE   = 3'd2,
    BRANCH_LT   = 3'd3,
    BRANCH_GE   = 3'd4,
    BRANCH_LTU  = 3'd5,
    BRANCH_GEU  = 3'd6
  } branch_control_t;

  typedef enum logic [1:0] {
    JUMP_NONE = 2'd0,
    JUMP_JAL  = 2'd1,
    JUMP_JALR = 2'd2
  } jump_control_t;

  typedef enum logic [1:0] {
    MEM_BYTE = 2'd0,
    MEM_HALF = 2'd1,
    MEM_WORD = 2'd2
  } memory_size_t;
endpackage
