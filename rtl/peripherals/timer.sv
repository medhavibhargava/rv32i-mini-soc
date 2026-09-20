`timescale 1ns/1ps

module timer (
  input  logic        clk_i,
  input  logic        reset_i,
  input  logic        select_i,
  input  logic        read_i,
  input  logic        write_i,
  input  logic [31:0] addr_i,
  input  logic [31:0] write_data_i,
  input  logic [3:0]  write_strobes_i,
  output logic [31:0] read_data_o,
  output logic        irq_o
);
  logic [31:0] count;
  logic [31:0] compare_value;
  logic enable, irq_enable, pending;

  assign irq_o = pending && irq_enable;

  // Peripheral-relative byte offsets; reserved bits and unused reads are zero.
  always_comb begin
    read_data_o = 32'b0;
    if (select_i && read_i) begin
      case (addr_i)
        32'h00: read_data_o = count;
        32'h04: read_data_o = compare_value;
        32'h08: read_data_o = {30'b0, irq_enable, enable};
        32'h0c: read_data_o = {31'b0, pending};
        default: read_data_o = 32'b0;
      endcase
    end
  end

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      count <= 32'b0;
      compare_value <= 32'b0;
      enable <= 1'b0;
      irq_enable <= 1'b0;
      pending <= 1'b0;
    end else begin
      if (select_i && write_i) begin
        case (addr_i)
          32'h04: begin
            for (int lane = 0; lane < 4; lane++) begin
              if (write_strobes_i[lane])
                compare_value[8*lane +: 8] <= write_data_i[8*lane +: 8];
            end
          end
          32'h08: begin
            if (write_strobes_i[0]) begin
              enable <= write_data_i[0];
              irq_enable <= write_data_i[1];
            end
          end
          32'h0c: begin
            if (write_strobes_i[0] && write_data_i[0]) pending <= 1'b0;
          end
          default: begin end // COUNT and unused addresses ignore writes.
        endcase
      end

      // Compare pre-edge values only while enabled. Writes to CONTROL and
      // COMPARE take effect on the next edge's count/match evaluation.
      // COUNT wraps modulo 2^32 and never reloads on a match.
      if (enable) begin
        count <= count + 32'd1;
        // A new match wins over a simultaneous write-one-to-clear request.
        if (count == compare_value) pending <= 1'b1;
      end
    end
  end
endmodule
