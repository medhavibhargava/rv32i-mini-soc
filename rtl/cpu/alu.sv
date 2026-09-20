`timescale 1ns/1ps

module alu (
  input  logic [31:0]      lhs_i,
  input  logic [31:0]      rhs_i,
  input  alu_pkg::alu_op_t op_i,
  output logic [31:0]      result_o
);
  import alu_pkg::*;

  logic [4:0] shift_amount;

  assign shift_amount = rhs_i[4:0];

  always_comb begin
    result_o = 32'b0;

    case (op_i)
      ALU_ADD:  result_o = lhs_i + rhs_i;
      ALU_SUB:  result_o = lhs_i - rhs_i;
      ALU_AND:  result_o = lhs_i & rhs_i;
      ALU_OR:   result_o = lhs_i | rhs_i;
      ALU_XOR:  result_o = lhs_i ^ rhs_i;
      ALU_SLT:  result_o = {31'b0, $signed(lhs_i) < $signed(rhs_i)};
      ALU_SLTU: result_o = {31'b0, lhs_i < rhs_i};
      ALU_SLL:  result_o = lhs_i << shift_amount;
      ALU_SRL:  result_o = lhs_i >> shift_amount;
      ALU_SRA:  result_o = $signed(lhs_i) >>> shift_amount;
      default:  result_o = 32'b0;
    endcase
  end
endmodule
