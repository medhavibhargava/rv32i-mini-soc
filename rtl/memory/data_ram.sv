`timescale 1ns/1ps

module data_ram #(
  parameter int unsigned MEM_SIZE_BYTES = 1024
) (
  input  logic        clk_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] write_data_i,
  input  logic [3:0]  write_strobes_i,
  output logic [31:0] read_data_o
);
  // MEM_SIZE_BYTES must be a positive multiple of four. addr_i is a
  // RAM-relative byte address; accesses must be aligned and in range.
  // No reset/initialization: contents are unspecified until written.
  localparam int unsigned WORD_COUNT = MEM_SIZE_BYTES / 4;
  logic [31:0] memory [0:WORD_COUNT-1];

  assign read_data_o = memory[addr_i[31:2]];

  always_ff @(posedge clk_i) begin
    for (int lane = 0; lane < 4; lane++) begin
      // Little-endian lanes: strobe 0 updates the lowest-addressed byte.
      if (write_strobes_i[lane]) begin
        memory[addr_i[31:2]][8*lane +: 8] <= write_data_i[8*lane +: 8];
      end
    end
  end
endmodule
