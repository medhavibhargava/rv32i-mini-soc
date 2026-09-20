`timescale 1ns/1ps

module hazard_unit (
  input  logic       younger_valid_i,
  input  logic       younger_rs1_used_i,
  input  logic       younger_rs2_used_i,
  input  logic [4:0] younger_rs1_i,
  input  logic [4:0] younger_rs2_i,
  input  logic       id_ex_load_i,
  input  logic [4:0] id_ex_destination_i,
  output logic       load_use_stall_o
);
  always_comb begin
    load_use_stall_o = 1'b0;

    if (younger_valid_i &&
        id_ex_load_i &&
        (id_ex_destination_i != 5'd0)) begin
      load_use_stall_o =
          (younger_rs1_used_i &&
           (younger_rs1_i == id_ex_destination_i)) ||
          (younger_rs2_used_i &&
           (younger_rs2_i == id_ex_destination_i));
    end
  end
endmodule
