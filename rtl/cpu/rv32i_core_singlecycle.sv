`timescale 1ns/1ps

module rv32i_core_singlecycle (
  input  logic        clk_i,
  input  logic        reset_i,

  output logic [31:0] instruction_address_o,
  input  logic [31:0] instruction_data_i,

  output logic [31:0] data_address_o,
  output logic        data_read_o,
  output logic        data_write_o,
  output logic [3:0]  data_write_strobe_o,
  output logic [31:0] data_write_data_o,
  input  logic [31:0] data_read_data_i
);
  import alu_pkg::*;
  import imm_gen_pkg::*;
  import control_unit_pkg::*;

  logic [31:0] pc;
  logic [31:0] next_pc;
  logic [31:0] pc_plus_four;
  logic [31:0] branch_target;

  logic        instruction_valid;
  logic        register_write;
  alu_src_a_t  alu_src_a;
  alu_src_b_t  alu_src_b;
  alu_op_t     alu_operation;
  imm_format_t immediate_format;
  logic        memory_read;
  logic        memory_write;
  memory_size_t memory_size;
  logic        load_unsigned;
  writeback_source_t writeback_source;
  branch_control_t branch_control;
  jump_control_t jump_control;

  logic [31:0] immediate;
  logic [31:0] register_data_a;
  logic [31:0] register_data_b;
  logic [31:0] register_write_data;
  logic        register_write_enable;
  logic [31:0] alu_lhs;
  logic [31:0] alu_rhs;
  logic [31:0] alu_result;
  logic        alu_result_lsb;
  logic        branch_taken;
  logic [31:0] jalr_target;

  logic [1:0]  data_byte_offset;
  logic [4:0]  data_bit_shift;
  logic [31:0] shifted_load_data;
  logic [31:0] signed_load_byte;
  logic [31:0] unsigned_load_byte;
  logic [31:0] signed_load_half;
  logic [31:0] unsigned_load_half;
  logic [31:0] load_data;
  logic [31:0] shifted_store_data;

  assign instruction_address_o = pc;
  assign pc_plus_four          = pc + 32'd4;
  assign branch_target        = pc + immediate;

  assign data_address_o      = alu_result;
  assign data_read_o         = memory_read && instruction_valid && !reset_i;
  assign data_write_o        = memory_write && instruction_valid && !reset_i;
  assign data_byte_offset    = alu_result[1:0];
  assign data_bit_shift      = {data_byte_offset, 3'b000};
  assign shifted_load_data   = data_read_data_i >> data_bit_shift;
  assign signed_load_byte    = {{24{shifted_load_data[7]}},
                                shifted_load_data[7:0]};
  assign unsigned_load_byte  = {24'b0, shifted_load_data[7:0]};
  assign signed_load_half    = {{16{shifted_load_data[15]}},
                                shifted_load_data[15:0]};
  assign unsigned_load_half  = {16'b0, shifted_load_data[15:0]};
  assign shifted_store_data  = register_data_b << data_bit_shift;
  assign register_write_enable = register_write && instruction_valid && !reset_i;
  assign alu_result_lsb      = alu_result[0];
  assign jalr_target         = {alu_result[31:1], 1'b0};

  control_unit control_unit_i (
    .instruction_i       (instruction_data_i),
    .instruction_valid_o (instruction_valid),
    .register_write_o    (register_write),
    .alu_src_a_o         (alu_src_a),
    .alu_src_b_o         (alu_src_b),
    .alu_op_o            (alu_operation),
    .immediate_format_o  (immediate_format),
    .memory_read_o       (memory_read),
    .memory_write_o      (memory_write),
    .memory_size_o       (memory_size),
    .load_unsigned_o     (load_unsigned),
    .writeback_source_o  (writeback_source),
    .branch_control_o    (branch_control),
    .jump_control_o      (jump_control)
  );

  imm_gen imm_gen_i (
    .instruction_i (instruction_data_i),
    .format_i      (immediate_format),
    .immediate_o   (immediate)
  );

  regfile regfile_i (
    .clk_i          (clk_i),
    .write_enable_i (register_write_enable),
    .write_addr_i   (instruction_data_i[11:7]),
    .write_data_i   (register_write_data),
    .read_addr_a_i  (instruction_data_i[19:15]),
    .read_addr_b_i  (instruction_data_i[24:20]),
    .read_data_a_o  (register_data_a),
    .read_data_b_o  (register_data_b)
  );

  alu alu_i (
    .lhs_i    (alu_lhs),
    .rhs_i    (alu_rhs),
    .op_i     (alu_operation),
    .result_o (alu_result)
  );

  always_comb begin
    case (alu_src_a)
      ALU_SRC_A_RS1:  alu_lhs = register_data_a;
      ALU_SRC_A_PC:   alu_lhs = pc;
      ALU_SRC_A_ZERO: alu_lhs = 32'b0;
      default:        alu_lhs = 32'b0;
    endcase

    case (alu_src_b)
      ALU_SRC_B_RS2:  alu_rhs = register_data_b;
      ALU_SRC_B_IMM:  alu_rhs = immediate;
      ALU_SRC_B_FOUR: alu_rhs = 32'd4;
      default:        alu_rhs = 32'b0;
    endcase
  end

  always_comb begin
    case (memory_size)
      MEM_BYTE: load_data = load_unsigned ? unsigned_load_byte
                                          : signed_load_byte;
      MEM_HALF: load_data = load_unsigned ? unsigned_load_half
                                          : signed_load_half;
      MEM_WORD: load_data = data_read_data_i;
      default:  load_data = 32'b0;
    endcase
  end

  always_comb begin
    data_write_data_o   = register_data_b;
    data_write_strobe_o = 4'b0000;

    if (data_write_o) begin
      case (memory_size)
        MEM_BYTE: begin
          data_write_data_o   = shifted_store_data;
          data_write_strobe_o = 4'b0001 << data_byte_offset;
        end
        MEM_HALF: begin
          data_write_data_o   = shifted_store_data;
          data_write_strobe_o = 4'b0011 << data_byte_offset;
        end
        MEM_WORD: begin
          data_write_data_o   = register_data_b;
          data_write_strobe_o = 4'b1111;
        end
        default: begin
          data_write_data_o   = 32'b0;
          data_write_strobe_o = 4'b0000;
        end
      endcase
    end
  end

  always_comb begin
    case (writeback_source)
      WB_ALU:       register_write_data = alu_result;
      WB_MEMORY:    register_write_data = load_data;
      WB_PC_PLUS_4: register_write_data = pc_plus_four;
      default:      register_write_data = 32'b0;
    endcase
  end

  always_comb begin
    branch_taken = 1'b0;

    case (branch_control)
      BRANCH_EQ:  branch_taken = (alu_result == 32'b0);
      BRANCH_NE:  branch_taken = (alu_result != 32'b0);
      BRANCH_LT:  branch_taken = alu_result_lsb;
      BRANCH_GE:  branch_taken = !alu_result_lsb;
      BRANCH_LTU: branch_taken = alu_result_lsb;
      BRANCH_GEU: branch_taken = !alu_result_lsb;
      default:    branch_taken = 1'b0;
    endcase
  end

  always_comb begin
    next_pc = pc_plus_four;

    case (jump_control)
      JUMP_JAL:  next_pc = alu_result;
      JUMP_JALR: next_pc = jalr_target;
      default: begin
        if (branch_taken) begin
          next_pc = branch_target;
        end
      end
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      pc <= 32'b0;
    end else begin
      pc <= next_pc;
    end
  end
endmodule
