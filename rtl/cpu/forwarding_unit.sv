`timescale 1ns/1ps

module forwarding_unit (
  input  logic [4:0]  source_a_i,
  input  logic [4:0]  source_b_i,
  input  logic [31:0] source_data_a_i,
  input  logic [31:0] source_data_b_i,

  input  logic        ex_mem_write_i,
  input  logic        ex_mem_result_ready_i,
  input  logic [4:0]  ex_mem_destination_i,
  input  logic [31:0] ex_mem_data_i,

  input  logic        mem_wb_write_i,
  input  logic [4:0]  mem_wb_destination_i,
  input  logic [31:0] mem_wb_data_i,

  output logic [31:0] forwarded_data_a_o,
  output logic [31:0] forwarded_data_b_o
);
  always_comb begin
    forwarded_data_a_o = source_data_a_i;

    if (ex_mem_write_i &&
        (ex_mem_destination_i != 5'd0) &&
        (ex_mem_destination_i == source_a_i)) begin
      if (ex_mem_result_ready_i) begin
        forwarded_data_a_o = ex_mem_data_i;
      end
    end else if (mem_wb_write_i &&
                 (mem_wb_destination_i != 5'd0) &&
                 (mem_wb_destination_i == source_a_i)) begin
      forwarded_data_a_o = mem_wb_data_i;
    end
  end

  always_comb begin
    forwarded_data_b_o = source_data_b_i;

    if (ex_mem_write_i &&
        (ex_mem_destination_i != 5'd0) &&
        (ex_mem_destination_i == source_b_i)) begin
      if (ex_mem_result_ready_i) begin
        forwarded_data_b_o = ex_mem_data_i;
      end
    end else if (mem_wb_write_i &&
                 (mem_wb_destination_i != 5'd0) &&
                 (mem_wb_destination_i == source_b_i)) begin
      forwarded_data_b_o = mem_wb_data_i;
    end
  end
endmodule
