`timescale 1ns/1ps

module imm_gen (
  input  logic [31:0]                instruction_i,
  input  imm_gen_pkg::imm_format_t   format_i,
  output logic [31:0]                immediate_o
);
  import imm_gen_pkg::*;

  logic [31:0] immediate_i;
  logic [31:0] immediate_s;
  logic [31:0] immediate_b;
  logic [31:0] immediate_u;
  logic [31:0] immediate_j;

  assign immediate_i = {{20{instruction_i[31]}},
                        instruction_i[31:20]};
  assign immediate_s = {{20{instruction_i[31]}},
                        instruction_i[31:25],
                        instruction_i[11:7]};
  assign immediate_b = {{19{instruction_i[31]}},
                        instruction_i[31],
                        instruction_i[7],
                        instruction_i[30:25],
                        instruction_i[11:8],
                        1'b0};
  assign immediate_u = {instruction_i[31:12], 12'b0};
  assign immediate_j = {{11{instruction_i[31]}},
                        instruction_i[31],
                        instruction_i[19:12],
                        instruction_i[20],
                        instruction_i[30:21],
                        1'b0};

  always_comb begin
    immediate_o = 32'b0;

    case (format_i)
      IMM_I: immediate_o = immediate_i;
      IMM_S: immediate_o = immediate_s;
      IMM_B: immediate_o = immediate_b;
      IMM_U: immediate_o = immediate_u;
      IMM_J: immediate_o = immediate_j;
      default: immediate_o = 32'b0;
    endcase
  end
endmodule
