`timescale 1ns/1ps

module control_unit (
  input  logic [31:0]                              instruction_i,
  output logic                                     instruction_valid_o,
  output logic                                     rs1_used_o,
  output logic                                     rs2_used_o,
  output logic                                     register_write_o,
  output control_unit_pkg::alu_src_a_t             alu_src_a_o,
  output control_unit_pkg::alu_src_b_t             alu_src_b_o,
  output alu_pkg::alu_op_t                         alu_op_o,
  output imm_gen_pkg::imm_format_t                 immediate_format_o,
  output logic                                     memory_read_o,
  output logic                                     memory_write_o,
  output control_unit_pkg::memory_size_t           memory_size_o,
  output logic                                     load_unsigned_o,
  output control_unit_pkg::writeback_source_t      writeback_source_o,
  output control_unit_pkg::branch_control_t        branch_control_o,
  output control_unit_pkg::jump_control_t          jump_control_o
);
  import alu_pkg::*;
  import imm_gen_pkg::*;
  import control_unit_pkg::*;

  localparam logic [6:0] OPCODE_LUI      = 7'b0110111;
  localparam logic [6:0] OPCODE_AUIPC    = 7'b0010111;
  localparam logic [6:0] OPCODE_JAL      = 7'b1101111;
  localparam logic [6:0] OPCODE_JALR     = 7'b1100111;
  localparam logic [6:0] OPCODE_BRANCH   = 7'b1100011;
  localparam logic [6:0] OPCODE_LOAD     = 7'b0000011;
  localparam logic [6:0] OPCODE_STORE    = 7'b0100011;
  localparam logic [6:0] OPCODE_OP_IMM   = 7'b0010011;
  localparam logic [6:0] OPCODE_OP       = 7'b0110011;

  logic [6:0] opcode;
  logic [2:0] funct3;
  logic [6:0] funct7;

  assign opcode = instruction_i[6:0];
  assign funct3 = instruction_i[14:12];
  assign funct7 = instruction_i[31:25];

  always_comb begin
    instruction_valid_o = 1'b0;
    rs1_used_o          = 1'b0;
    rs2_used_o          = 1'b0;
    register_write_o    = 1'b0;
    alu_src_a_o         = ALU_SRC_A_RS1;
    alu_src_b_o         = ALU_SRC_B_RS2;
    alu_op_o            = ALU_ADD;
    immediate_format_o  = IMM_I;
    memory_read_o       = 1'b0;
    memory_write_o      = 1'b0;
    memory_size_o       = MEM_WORD;
    load_unsigned_o     = 1'b0;
    writeback_source_o  = WB_ALU;
    branch_control_o    = BRANCH_NONE;
    jump_control_o      = JUMP_NONE;

    case (opcode)
      OPCODE_LUI: begin
        instruction_valid_o = 1'b1;
        register_write_o    = 1'b1;
        alu_src_a_o         = ALU_SRC_A_ZERO;
        alu_src_b_o         = ALU_SRC_B_IMM;
        immediate_format_o  = IMM_U;
      end

      OPCODE_AUIPC: begin
        instruction_valid_o = 1'b1;
        register_write_o    = 1'b1;
        alu_src_a_o         = ALU_SRC_A_PC;
        alu_src_b_o         = ALU_SRC_B_IMM;
        immediate_format_o  = IMM_U;
      end

      OPCODE_JAL: begin
        instruction_valid_o = 1'b1;
        register_write_o    = 1'b1;
        alu_src_a_o         = ALU_SRC_A_PC;
        alu_src_b_o         = ALU_SRC_B_IMM;
        immediate_format_o  = IMM_J;
        writeback_source_o  = WB_PC_PLUS_4;
        jump_control_o      = JUMP_JAL;
      end

      OPCODE_JALR: begin
        if (funct3 == 3'b000) begin
          instruction_valid_o = 1'b1;
          rs1_used_o          = 1'b1;
          register_write_o    = 1'b1;
          alu_src_a_o         = ALU_SRC_A_RS1;
          alu_src_b_o         = ALU_SRC_B_IMM;
          immediate_format_o  = IMM_I;
          writeback_source_o  = WB_PC_PLUS_4;
          jump_control_o      = JUMP_JALR;
        end
      end

      OPCODE_BRANCH: begin
        case (funct3)
          3'b000: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SUB;
            branch_control_o    = BRANCH_EQ;
          end
          3'b001: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SUB;
            branch_control_o    = BRANCH_NE;
          end
          3'b100: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SLT;
            branch_control_o    = BRANCH_LT;
          end
          3'b101: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SLT;
            branch_control_o    = BRANCH_GE;
          end
          3'b110: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SLTU;
            branch_control_o    = BRANCH_LTU;
          end
          3'b111: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SLTU;
            branch_control_o    = BRANCH_GEU;
          end
          default: begin
          end
        endcase

        if (instruction_valid_o) begin
          rs1_used_o         = 1'b1;
          rs2_used_o         = 1'b1;
          immediate_format_o = IMM_B;
        end
      end

      OPCODE_LOAD: begin
        case (funct3)
          3'b000: begin
            instruction_valid_o = 1'b1;
            memory_size_o       = MEM_BYTE;
          end
          3'b001: begin
            instruction_valid_o = 1'b1;
            memory_size_o       = MEM_HALF;
          end
          3'b010: begin
            instruction_valid_o = 1'b1;
            memory_size_o       = MEM_WORD;
          end
          3'b100: begin
            instruction_valid_o = 1'b1;
            memory_size_o       = MEM_BYTE;
            load_unsigned_o     = 1'b1;
          end
          3'b101: begin
            instruction_valid_o = 1'b1;
            memory_size_o       = MEM_HALF;
            load_unsigned_o     = 1'b1;
          end
          default: begin
          end
        endcase

        if (instruction_valid_o) begin
          rs1_used_o          = 1'b1;
          register_write_o   = 1'b1;
          alu_src_b_o        = ALU_SRC_B_IMM;
          immediate_format_o = IMM_I;
          memory_read_o      = 1'b1;
          writeback_source_o = WB_MEMORY;
        end
      end

      OPCODE_STORE: begin
        case (funct3)
          3'b000: begin
            instruction_valid_o = 1'b1;
            memory_size_o       = MEM_BYTE;
          end
          3'b001: begin
            instruction_valid_o = 1'b1;
            memory_size_o       = MEM_HALF;
          end
          3'b010: begin
            instruction_valid_o = 1'b1;
            memory_size_o       = MEM_WORD;
          end
          default: begin
          end
        endcase

        if (instruction_valid_o) begin
          rs1_used_o         = 1'b1;
          rs2_used_o         = 1'b1;
          alu_src_b_o        = ALU_SRC_B_IMM;
          immediate_format_o = IMM_S;
          memory_write_o     = 1'b1;
        end
      end

      OPCODE_OP_IMM: begin
        case (funct3)
          3'b000: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_ADD;
          end
          3'b001: begin
            if (funct7 == 7'b0000000) begin
              instruction_valid_o = 1'b1;
              alu_op_o            = ALU_SLL;
            end
          end
          3'b010: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SLT;
          end
          3'b011: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SLTU;
          end
          3'b100: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_XOR;
          end
          3'b101: begin
            if (funct7 == 7'b0000000) begin
              instruction_valid_o = 1'b1;
              alu_op_o            = ALU_SRL;
            end else if (funct7 == 7'b0100000) begin
              instruction_valid_o = 1'b1;
              alu_op_o            = ALU_SRA;
            end
          end
          3'b110: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_OR;
          end
          3'b111: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_AND;
          end
          default: begin
          end
        endcase

        if (instruction_valid_o) begin
          rs1_used_o          = 1'b1;
          register_write_o   = 1'b1;
          alu_src_b_o        = ALU_SRC_B_IMM;
          immediate_format_o = IMM_I;
        end
      end

      OPCODE_OP: begin
        case ({funct7, funct3})
          {7'b0000000, 3'b000}: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_ADD;
          end
          {7'b0100000, 3'b000}: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SUB;
          end
          {7'b0000000, 3'b001}: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SLL;
          end
          {7'b0000000, 3'b010}: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SLT;
          end
          {7'b0000000, 3'b011}: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SLTU;
          end
          {7'b0000000, 3'b100}: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_XOR;
          end
          {7'b0000000, 3'b101}: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SRL;
          end
          {7'b0100000, 3'b101}: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_SRA;
          end
          {7'b0000000, 3'b110}: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_OR;
          end
          {7'b0000000, 3'b111}: begin
            instruction_valid_o = 1'b1;
            alu_op_o            = ALU_AND;
          end
          default: begin
          end
        endcase

        if (instruction_valid_o) begin
          rs1_used_o        = 1'b1;
          rs2_used_o        = 1'b1;
          register_write_o = 1'b1;
        end
      end

      default: begin
      end
    endcase
  end
endmodule
