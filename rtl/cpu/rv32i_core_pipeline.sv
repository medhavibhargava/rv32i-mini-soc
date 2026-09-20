`timescale 1ns/1ps

module rv32i_core_pipeline (
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

  // IF stage and IF/ID pipeline register.
  logic [31:0] pc_q;
  logic [31:0] next_pc;
  logic        if_id_valid_q;
  logic [31:0] if_id_pc_q;
  logic [31:0] if_id_instruction_q;

  // ID-stage decode and register-file outputs.
  logic              id_instruction_valid;
  logic              id_rs1_used;
  logic              id_rs2_used;
  logic              id_register_write;
  alu_src_a_t        id_alu_src_a;
  alu_src_b_t        id_alu_src_b;
  alu_op_t           id_alu_operation;
  imm_format_t       id_immediate_format;
  logic              id_memory_read;
  logic              id_memory_write;
  memory_size_t      id_memory_size;
  logic              id_load_unsigned;
  writeback_source_t id_writeback_source;
  branch_control_t   id_branch_control;
  jump_control_t     id_jump_control;
  logic [31:0]       id_immediate;
  logic [31:0]       id_register_data_a;
  logic [31:0]       id_register_data_b;
  logic [31:0]       id_register_data_a_bypassed;
  logic [31:0]       id_register_data_b_bypassed;
  logic [4:0]        id_rs1;
  logic [4:0]        id_rs2;

  // ID/EX pipeline register.
  logic              id_ex_valid_q;
  logic [31:0]       id_ex_pc_q;
  logic [31:0]       id_ex_register_data_a_q;
  logic [31:0]       id_ex_register_data_b_q;
  logic [31:0]       id_ex_immediate_q;
  logic [4:0]        id_ex_source_a_q;
  logic [4:0]        id_ex_source_b_q;
  logic [4:0]        id_ex_destination_q;
  logic              id_ex_register_write_q;
  alu_src_a_t        id_ex_alu_src_a_q;
  alu_src_b_t        id_ex_alu_src_b_q;
  alu_op_t           id_ex_alu_operation_q;
  logic              id_ex_memory_read_q;
  logic              id_ex_memory_write_q;
  memory_size_t      id_ex_memory_size_q;
  logic              id_ex_load_unsigned_q;
  writeback_source_t id_ex_writeback_source_q;
  branch_control_t   id_ex_branch_control_q;
  jump_control_t     id_ex_jump_control_q;

  // EX-stage datapath and redirect decision.
  logic [31:0] ex_alu_lhs;
  logic [31:0] ex_alu_rhs;
  logic [31:0] ex_source_data_a;
  logic [31:0] ex_source_data_b;
  logic [31:0] ex_alu_result;
  logic        ex_alu_result_lsb;
  logic [31:0] ex_pc_plus_four;
  logic [31:0] ex_branch_target;
  logic [31:0] ex_jalr_target;
  logic        ex_branch_taken;
  logic        ex_redirect;
  logic [31:0] ex_redirect_target;

  // EX/MEM pipeline register.
  logic              ex_mem_valid_q;
  logic [31:0]       ex_mem_alu_result_q;
  logic [31:0]       ex_mem_store_data_q;
  logic [31:0]       ex_mem_pc_plus_four_q;
  logic [4:0]        ex_mem_destination_q;
  logic              ex_mem_register_write_q;
  logic              ex_mem_memory_read_q;
  logic              ex_mem_memory_write_q;
  memory_size_t      ex_mem_memory_size_q;
  logic              ex_mem_load_unsigned_q;
  writeback_source_t ex_mem_writeback_source_q;

  // MEM-stage load/store formatting.
  logic [1:0]  mem_byte_offset;
  logic [4:0]  mem_bit_shift;
  logic [31:0] mem_shifted_read_data;
  logic [31:0] mem_signed_byte;
  logic [31:0] mem_unsigned_byte;
  logic [31:0] mem_signed_half;
  logic [31:0] mem_unsigned_half;
  logic [31:0] mem_load_data;
  logic [31:0] mem_shifted_store_data;

  // MEM/WB pipeline register and WB-stage signals.
  logic              mem_wb_valid_q;
  logic [31:0]       mem_wb_alu_result_q;
  logic [31:0]       mem_wb_load_data_q;
  logic [31:0]       mem_wb_pc_plus_four_q;
  logic [4:0]        mem_wb_destination_q;
  logic              mem_wb_register_write_q;
  writeback_source_t mem_wb_writeback_source_q;
  logic [31:0]       wb_write_data;
  logic              wb_write_enable;
  logic [31:0]       ex_mem_forward_data;
  logic              ex_mem_forward_write;
  logic              ex_mem_forward_ready;
  logic              load_use_stall;

  assign instruction_address_o = pc_q;
  assign next_pc = ex_redirect ? ex_redirect_target : (pc_q + 32'd4);
  assign id_rs1 = if_id_instruction_q[19:15];
  assign id_rs2 = if_id_instruction_q[24:20];

  control_unit control_unit_i (
    .instruction_i       (if_id_instruction_q),
    .instruction_valid_o (id_instruction_valid),
    .rs1_used_o          (id_rs1_used),
    .rs2_used_o          (id_rs2_used),
    .register_write_o    (id_register_write),
    .alu_src_a_o         (id_alu_src_a),
    .alu_src_b_o         (id_alu_src_b),
    .alu_op_o            (id_alu_operation),
    .immediate_format_o  (id_immediate_format),
    .memory_read_o       (id_memory_read),
    .memory_write_o      (id_memory_write),
    .memory_size_o       (id_memory_size),
    .load_unsigned_o     (id_load_unsigned),
    .writeback_source_o  (id_writeback_source),
    .branch_control_o    (id_branch_control),
    .jump_control_o      (id_jump_control)
  );

  hazard_unit hazard_unit_i (
    .younger_valid_i       (if_id_valid_q && id_instruction_valid),
    .younger_rs1_used_i    (id_rs1_used),
    .younger_rs2_used_i    (id_rs2_used),
    .younger_rs1_i         (id_rs1),
    .younger_rs2_i         (id_rs2),
    .id_ex_load_i          (id_ex_valid_q && id_ex_memory_read_q),
    .id_ex_destination_i   (id_ex_destination_q),
    .load_use_stall_o      (load_use_stall)
  );

  imm_gen imm_gen_i (
    .instruction_i (if_id_instruction_q),
    .format_i      (id_immediate_format),
    .immediate_o   (id_immediate)
  );

  regfile regfile_i (
    .clk_i          (clk_i),
    .write_enable_i (wb_write_enable),
    .write_addr_i   (mem_wb_destination_q),
    .write_data_i   (wb_write_data),
    .read_addr_a_i  (id_rs1),
    .read_addr_b_i  (id_rs2),
    .read_data_a_o  (id_register_data_a),
    .read_data_b_o  (id_register_data_b)
  );

  // Cover the clock edge where WB writes while ID reads the same register.
  always_comb begin
    id_register_data_a_bypassed = id_register_data_a;
    id_register_data_b_bypassed = id_register_data_b;

    if (wb_write_enable &&
        (mem_wb_destination_q != 5'd0) &&
        (mem_wb_destination_q == id_rs1)) begin
      id_register_data_a_bypassed = wb_write_data;
    end

    if (wb_write_enable &&
        (mem_wb_destination_q != 5'd0) &&
        (mem_wb_destination_q == id_rs2)) begin
      id_register_data_b_bypassed = wb_write_data;
    end
  end

  always_comb begin
    case (ex_mem_writeback_source_q)
      WB_ALU:       ex_mem_forward_data = ex_mem_alu_result_q;
      WB_PC_PLUS_4: ex_mem_forward_data = ex_mem_pc_plus_four_q;
      default:      ex_mem_forward_data = 32'b0;
    endcase
  end

  assign ex_mem_forward_write = ex_mem_valid_q &&
                                ex_mem_register_write_q &&
                                !reset_i;
  assign ex_mem_forward_ready = (ex_mem_writeback_source_q != WB_MEMORY);

  forwarding_unit forwarding_unit_i (
    .source_a_i             (id_ex_source_a_q),
    .source_b_i             (id_ex_source_b_q),
    .source_data_a_i        (id_ex_register_data_a_q),
    .source_data_b_i        (id_ex_register_data_b_q),
    .ex_mem_write_i         (ex_mem_forward_write),
    .ex_mem_result_ready_i  (ex_mem_forward_ready),
    .ex_mem_destination_i   (ex_mem_destination_q),
    .ex_mem_data_i          (ex_mem_forward_data),
    .mem_wb_write_i         (wb_write_enable),
    .mem_wb_destination_i   (mem_wb_destination_q),
    .mem_wb_data_i          (wb_write_data),
    .forwarded_data_a_o     (ex_source_data_a),
    .forwarded_data_b_o     (ex_source_data_b)
  );

  always_comb begin
    case (id_ex_alu_src_a_q)
      ALU_SRC_A_RS1:  ex_alu_lhs = ex_source_data_a;
      ALU_SRC_A_PC:   ex_alu_lhs = id_ex_pc_q;
      ALU_SRC_A_ZERO: ex_alu_lhs = 32'b0;
      default:        ex_alu_lhs = 32'b0;
    endcase

    case (id_ex_alu_src_b_q)
      ALU_SRC_B_RS2:  ex_alu_rhs = ex_source_data_b;
      ALU_SRC_B_IMM:  ex_alu_rhs = id_ex_immediate_q;
      ALU_SRC_B_FOUR: ex_alu_rhs = 32'd4;
      default:        ex_alu_rhs = 32'b0;
    endcase
  end

  alu alu_i (
    .lhs_i    (ex_alu_lhs),
    .rhs_i    (ex_alu_rhs),
    .op_i     (id_ex_alu_operation_q),
    .result_o (ex_alu_result)
  );

  assign ex_alu_result_lsb = ex_alu_result[0];
  assign ex_pc_plus_four   = id_ex_pc_q + 32'd4;
  assign ex_branch_target  = id_ex_pc_q + id_ex_immediate_q;
  assign ex_jalr_target    = {ex_alu_result[31:1], 1'b0};

  always_comb begin
    ex_branch_taken = 1'b0;

    case (id_ex_branch_control_q)
      BRANCH_EQ:  ex_branch_taken = (ex_alu_result == 32'b0);
      BRANCH_NE:  ex_branch_taken = (ex_alu_result != 32'b0);
      BRANCH_LT:  ex_branch_taken = ex_alu_result_lsb;
      BRANCH_GE:  ex_branch_taken = !ex_alu_result_lsb;
      BRANCH_LTU: ex_branch_taken = ex_alu_result_lsb;
      BRANCH_GEU: ex_branch_taken = !ex_alu_result_lsb;
      default:    ex_branch_taken = 1'b0;
    endcase
  end

  always_comb begin
    ex_redirect        = 1'b0;
    ex_redirect_target = 32'b0;

    if (id_ex_valid_q) begin
      case (id_ex_jump_control_q)
        JUMP_JAL: begin
          ex_redirect        = 1'b1;
          ex_redirect_target = ex_alu_result;
        end
        JUMP_JALR: begin
          ex_redirect        = 1'b1;
          ex_redirect_target = ex_jalr_target;
        end
        default: begin
          if (ex_branch_taken) begin
            ex_redirect        = 1'b1;
            ex_redirect_target = ex_branch_target;
          end
        end
      endcase
    end
  end

  assign data_address_o       = ex_mem_alu_result_q;
  assign data_read_o          = ex_mem_valid_q && ex_mem_memory_read_q && !reset_i;
  assign data_write_o         = ex_mem_valid_q && ex_mem_memory_write_q && !reset_i;
  assign mem_byte_offset      = ex_mem_alu_result_q[1:0];
  assign mem_bit_shift        = {mem_byte_offset, 3'b000};
  assign mem_shifted_read_data = data_read_data_i >> mem_bit_shift;
  assign mem_signed_byte      = {{24{mem_shifted_read_data[7]}},
                                 mem_shifted_read_data[7:0]};
  assign mem_unsigned_byte    = {24'b0, mem_shifted_read_data[7:0]};
  assign mem_signed_half      = {{16{mem_shifted_read_data[15]}},
                                 mem_shifted_read_data[15:0]};
  assign mem_unsigned_half    = {16'b0, mem_shifted_read_data[15:0]};
  assign mem_shifted_store_data = ex_mem_store_data_q << mem_bit_shift;

  always_comb begin
    case (ex_mem_memory_size_q)
      MEM_BYTE: mem_load_data = ex_mem_load_unsigned_q ? mem_unsigned_byte
                                                       : mem_signed_byte;
      MEM_HALF: mem_load_data = ex_mem_load_unsigned_q ? mem_unsigned_half
                                                       : mem_signed_half;
      MEM_WORD: mem_load_data = data_read_data_i;
      default:  mem_load_data = 32'b0;
    endcase
  end

  always_comb begin
    data_write_data_o   = ex_mem_store_data_q;
    data_write_strobe_o = 4'b0000;

    if (data_write_o) begin
      case (ex_mem_memory_size_q)
        MEM_BYTE: begin
          data_write_data_o   = mem_shifted_store_data;
          data_write_strobe_o = 4'b0001 << mem_byte_offset;
        end
        MEM_HALF: begin
          data_write_data_o   = mem_shifted_store_data;
          data_write_strobe_o = 4'b0011 << mem_byte_offset;
        end
        MEM_WORD: begin
          data_write_data_o   = ex_mem_store_data_q;
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
    case (mem_wb_writeback_source_q)
      WB_ALU:       wb_write_data = mem_wb_alu_result_q;
      WB_MEMORY:    wb_write_data = mem_wb_load_data_q;
      WB_PC_PLUS_4: wb_write_data = mem_wb_pc_plus_four_q;
      default:      wb_write_data = 32'b0;
    endcase
  end

  assign wb_write_enable = mem_wb_valid_q && mem_wb_register_write_q && !reset_i;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      pc_q                     <= 32'b0;
      if_id_valid_q            <= 1'b0;
      if_id_pc_q               <= 32'b0;
      if_id_instruction_q      <= 32'h0000_0013;
      id_ex_valid_q            <= 1'b0;
      id_ex_pc_q               <= 32'b0;
      id_ex_register_data_a_q  <= 32'b0;
      id_ex_register_data_b_q  <= 32'b0;
      id_ex_immediate_q        <= 32'b0;
      id_ex_source_a_q         <= 5'b0;
      id_ex_source_b_q         <= 5'b0;
      id_ex_destination_q      <= 5'b0;
      id_ex_register_write_q   <= 1'b0;
      id_ex_alu_src_a_q        <= ALU_SRC_A_RS1;
      id_ex_alu_src_b_q        <= ALU_SRC_B_RS2;
      id_ex_alu_operation_q    <= ALU_ADD;
      id_ex_memory_read_q      <= 1'b0;
      id_ex_memory_write_q     <= 1'b0;
      id_ex_memory_size_q      <= MEM_WORD;
      id_ex_load_unsigned_q    <= 1'b0;
      id_ex_writeback_source_q <= WB_ALU;
      id_ex_branch_control_q   <= BRANCH_NONE;
      id_ex_jump_control_q     <= JUMP_NONE;
      ex_mem_valid_q           <= 1'b0;
      ex_mem_alu_result_q      <= 32'b0;
      ex_mem_store_data_q      <= 32'b0;
      ex_mem_pc_plus_four_q    <= 32'b0;
      ex_mem_destination_q     <= 5'b0;
      ex_mem_register_write_q  <= 1'b0;
      ex_mem_memory_read_q     <= 1'b0;
      ex_mem_memory_write_q    <= 1'b0;
      ex_mem_memory_size_q     <= MEM_WORD;
      ex_mem_load_unsigned_q   <= 1'b0;
      ex_mem_writeback_source_q <= WB_ALU;
      mem_wb_valid_q           <= 1'b0;
      mem_wb_alu_result_q      <= 32'b0;
      mem_wb_load_data_q       <= 32'b0;
      mem_wb_pc_plus_four_q    <= 32'b0;
      mem_wb_destination_q     <= 5'b0;
      mem_wb_register_write_q  <= 1'b0;
      mem_wb_writeback_source_q <= WB_ALU;
    end else begin
      if (ex_redirect) begin
        // Redirect wins over a younger stall request. Flush both younger
        // instruction slots while the redirecting instruction advances.
        pc_q                <= ex_redirect_target;
        if_id_valid_q       <= 1'b0;
        if_id_pc_q          <= 32'b0;
        if_id_instruction_q <= 32'h0000_0013;

        id_ex_valid_q            <= 1'b0;
        id_ex_pc_q               <= 32'b0;
        id_ex_register_data_a_q  <= 32'b0;
        id_ex_register_data_b_q  <= 32'b0;
        id_ex_immediate_q        <= 32'b0;
        id_ex_source_a_q         <= 5'b0;
        id_ex_source_b_q         <= 5'b0;
        id_ex_destination_q      <= 5'b0;
        id_ex_register_write_q   <= 1'b0;
        id_ex_alu_src_a_q        <= ALU_SRC_A_RS1;
        id_ex_alu_src_b_q        <= ALU_SRC_B_RS2;
        id_ex_alu_operation_q    <= ALU_ADD;
        id_ex_memory_read_q      <= 1'b0;
        id_ex_memory_write_q     <= 1'b0;
        id_ex_memory_size_q      <= MEM_WORD;
        id_ex_load_unsigned_q    <= 1'b0;
        id_ex_writeback_source_q <= WB_ALU;
        id_ex_branch_control_q   <= BRANCH_NONE;
        id_ex_jump_control_q     <= JUMP_NONE;
      end else if (load_use_stall) begin
        // Hold the fetch state and replace the dependent ID instruction with
        // one invalid cycle in EX. Older instructions continue to advance.
        pc_q                <= pc_q;
        if_id_valid_q       <= if_id_valid_q;
        if_id_pc_q          <= if_id_pc_q;
        if_id_instruction_q <= if_id_instruction_q;

        id_ex_valid_q            <= 1'b0;
        id_ex_pc_q               <= 32'b0;
        id_ex_register_data_a_q  <= 32'b0;
        id_ex_register_data_b_q  <= 32'b0;
        id_ex_immediate_q        <= 32'b0;
        id_ex_source_a_q         <= 5'b0;
        id_ex_source_b_q         <= 5'b0;
        id_ex_destination_q      <= 5'b0;
        id_ex_register_write_q   <= 1'b0;
        id_ex_alu_src_a_q        <= ALU_SRC_A_RS1;
        id_ex_alu_src_b_q        <= ALU_SRC_B_RS2;
        id_ex_alu_operation_q    <= ALU_ADD;
        id_ex_memory_read_q      <= 1'b0;
        id_ex_memory_write_q     <= 1'b0;
        id_ex_memory_size_q      <= MEM_WORD;
        id_ex_load_unsigned_q    <= 1'b0;
        id_ex_writeback_source_q <= WB_ALU;
        id_ex_branch_control_q   <= BRANCH_NONE;
        id_ex_jump_control_q     <= JUMP_NONE;
      end else begin
        // IF/ID
        pc_q                <= next_pc;
        if_id_valid_q       <= 1'b1;
        if_id_pc_q          <= pc_q;
        if_id_instruction_q <= instruction_data_i;

        // ID/EX
        id_ex_valid_q            <= if_id_valid_q && id_instruction_valid;
        id_ex_pc_q               <= if_id_pc_q;
        id_ex_register_data_a_q  <= id_register_data_a_bypassed;
        id_ex_register_data_b_q  <= id_register_data_b_bypassed;
        id_ex_immediate_q        <= id_immediate;
        id_ex_source_a_q         <= id_rs1;
        id_ex_source_b_q         <= id_rs2;
        id_ex_destination_q      <= if_id_instruction_q[11:7];
        id_ex_register_write_q   <= id_register_write;
        id_ex_alu_src_a_q        <= id_alu_src_a;
        id_ex_alu_src_b_q        <= id_alu_src_b;
        id_ex_alu_operation_q    <= id_alu_operation;
        id_ex_memory_read_q      <= id_memory_read;
        id_ex_memory_write_q     <= id_memory_write;
        id_ex_memory_size_q      <= id_memory_size;
        id_ex_load_unsigned_q    <= id_load_unsigned;
        id_ex_writeback_source_q <= id_writeback_source;
        id_ex_branch_control_q   <= id_branch_control;
        id_ex_jump_control_q     <= id_jump_control;
      end

      // EX/MEM
      ex_mem_valid_q            <= id_ex_valid_q;
      ex_mem_alu_result_q       <= ex_alu_result;
      ex_mem_store_data_q       <= ex_source_data_b;
      ex_mem_pc_plus_four_q     <= ex_pc_plus_four;
      ex_mem_destination_q      <= id_ex_destination_q;
      ex_mem_register_write_q   <= id_ex_register_write_q;
      ex_mem_memory_read_q      <= id_ex_memory_read_q;
      ex_mem_memory_write_q     <= id_ex_memory_write_q;
      ex_mem_memory_size_q      <= id_ex_memory_size_q;
      ex_mem_load_unsigned_q    <= id_ex_load_unsigned_q;
      ex_mem_writeback_source_q <= id_ex_writeback_source_q;

      // MEM/WB
      mem_wb_valid_q            <= ex_mem_valid_q;
      mem_wb_alu_result_q       <= ex_mem_alu_result_q;
      mem_wb_load_data_q        <= mem_load_data;
      mem_wb_pc_plus_four_q     <= ex_mem_pc_plus_four_q;
      mem_wb_destination_q      <= ex_mem_destination_q;
      mem_wb_register_write_q   <= ex_mem_register_write_q;
      mem_wb_writeback_source_q <= ex_mem_writeback_source_q;
    end
  end
endmodule
