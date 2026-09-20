`timescale 1ns/1ps

module uart_tx #(
  parameter int unsigned CLOCK_FREQ_HZ = 50_000_000,
  parameter int unsigned BAUD_RATE = 115_200
) (
  input  logic        clk_i,
  input  logic        reset_i,
  input  logic        select_i,
  input  logic        read_i,
  input  logic        write_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] write_data_i,
  input  logic [3:0]  write_strobes_i,
  output logic [31:0] read_data_o,
  output logic        tx_o
);
  // Require CLOCK_FREQ_HZ >= BAUD_RATE > 0. Integer division rounds down;
  // the actual baud rate is CLOCK_FREQ_HZ / CLOCKS_PER_BIT.
  localparam int unsigned CLOCKS_PER_BIT = CLOCK_FREQ_HZ / BAUD_RATE;
  localparam int unsigned COUNTER_WIDTH =
      (CLOCKS_PER_BIT > 1) ? $clog2(CLOCKS_PER_BIT) : 1;
  logic [COUNTER_WIDTH-1:0] baud_count;
  logic [9:0] frame;
  logic [3:0] bit_index;
  logic busy;

  // Addresses are peripheral-relative byte offsets. TXDATA is write-only;
  // STATUS is read-only. All other reads (including idle bus reads) are zero.
  assign read_data_o = (select_i && read_i && addr_i == 32'h04)
                       ? {31'b0, busy} : 32'b0;
  assign tx_o = busy ? frame[0] : 1'b1;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      busy <= 1'b0;
      baud_count <= '0;
      bit_index <= '0;
      frame <= '1;
    end else if (busy) begin
      // The stop bit occupies a full bit period before busy is released.
      // Writes on any busy edge, including the final stop edge, are ignored.
      if (baud_count == CLOCKS_PER_BIT - 1) begin
        baud_count <= '0;
        if (bit_index == 4'd9) begin
          busy <= 1'b0;
        end else begin
          frame <= {1'b1, frame[9:1]};
          bit_index <= bit_index + 1'b1;
        end
      end else begin
        baud_count <= baud_count + 1'b1;
      end
    end else if (select_i && write_i && addr_i == 32'h00 &&
                 write_strobes_i[0]) begin
      frame <= {1'b1, write_data_i[7:0], 1'b0};
      bit_index <= '0;
      baud_count <= '0;
      busy <= 1'b1;
    end
  end
endmodule
