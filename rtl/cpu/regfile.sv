`timescale 1ns/1ps

module regfile (
  input  logic        clk_i,
  input  logic        write_enable_i,
  input  logic [4:0]  write_addr_i,
  input  logic [31:0] write_data_i,
  input  logic [4:0]  read_addr_a_i,
  input  logic [4:0]  read_addr_b_i,
  output logic [31:0] read_data_a_o,
  output logic [31:0] read_data_b_o
);
  logic [31:0] registers [0:31];

  assign read_data_a_o = (read_addr_a_i == 5'd0) ? 32'b0
                                                 : registers[read_addr_a_i];
  assign read_data_b_o = (read_addr_b_i == 5'd0) ? 32'b0
                                                 : registers[read_addr_b_i];

  always_ff @(posedge clk_i) begin
    if (write_enable_i && (write_addr_i != 5'd0)) begin
      registers[write_addr_i] <= write_data_i;
    end
  end
endmodule
