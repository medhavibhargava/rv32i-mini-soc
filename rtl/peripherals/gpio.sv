`timescale 1ns/1ps

module gpio #(
  parameter int unsigned GPIO_WIDTH = 32
) (
  input  logic                  clk_i,
  input  logic                  reset_i,
  input  logic                  select_i,
  input  logic                  read_i,
  input  logic                  write_i,
  input  logic [31:0]           addr_i,
  input  logic [31:0]           write_data_i,
  input  logic [3:0]            write_strobes_i,
  output logic [31:0]           read_data_o,
  output logic [GPIO_WIDTH-1:0] gpio_out_o,
  input  logic [GPIO_WIDTH-1:0] gpio_in_i,
  output logic [GPIO_WIDTH-1:0] gpio_dir_o
);
  // GPIO_WIDTH must be 1..32. Addresses are peripheral-relative byte offsets.
  // Direction 1 means output, 0 means input. Pad output-enable/tristate logic
  // and any required input synchronization belong outside this register block.
  always_comb begin
    read_data_o = 32'b0;
    if (select_i && read_i) begin
      case (addr_i)
        32'h00: read_data_o[GPIO_WIDTH-1:0] = gpio_out_o;
        32'h04: read_data_o[GPIO_WIDTH-1:0] = gpio_in_i;
        32'h08: read_data_o[GPIO_WIDTH-1:0] = gpio_dir_o;
        default: read_data_o = 32'b0;
      endcase
    end
  end

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      gpio_out_o <= '0;
      gpio_dir_o <= '0;
    end else if (select_i && write_i) begin
      // Per-bit enables also handle a final, partially populated byte lane.
      for (int bit_index = 0; bit_index < GPIO_WIDTH; bit_index++) begin
        if (write_strobes_i[bit_index / 8]) begin
          if (addr_i == 32'h00)
            gpio_out_o[bit_index] <= write_data_i[bit_index];
          if (addr_i == 32'h08)
            gpio_dir_o[bit_index] <= write_data_i[bit_index];
        end
      end
    end
  end
endmodule
