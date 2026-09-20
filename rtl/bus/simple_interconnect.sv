`timescale 1ns/1ps

module simple_interconnect (
  input  logic [31:0] cpu_addr_i,
  input  logic        cpu_read_i,
  input  logic        cpu_write_i,
  input  logic [31:0] cpu_write_data_i,
  input  logic [3:0]  cpu_write_strobes_i,
  output logic [31:0] cpu_read_data_o,
  output logic        ram_select_o,
  output logic        ram_read_o,
  output logic        ram_write_o,
  output logic [31:0] ram_addr_o,
  output logic [31:0] ram_write_data_o,
  output logic [3:0]  ram_write_strobes_o,
  input  logic [31:0] ram_read_data_i,
  output logic        uart_select_o,
  output logic        uart_read_o,
  output logic        uart_write_o,
  output logic [31:0] uart_addr_o,
  output logic [31:0] uart_write_data_o,
  output logic [3:0]  uart_write_strobes_o,
  input  logic [31:0] uart_read_data_i,
  output logic        gpio_select_o,
  output logic        gpio_read_o,
  output logic        gpio_write_o,
  output logic [31:0] gpio_addr_o,
  output logic [31:0] gpio_write_data_o,
  output logic [3:0]  gpio_write_strobes_o,
  input  logic [31:0] gpio_read_data_i,
  output logic        timer_select_o,
  output logic        timer_read_o,
  output logic        timer_write_o,
  output logic [31:0] timer_addr_o,
  output logic [31:0] timer_write_data_o,
  output logic [3:0]  timer_write_strobes_o,
  input  logic [31:0] timer_read_data_i
);
  // Selects decode the address even when idle. Enables qualify CPU intent.
  // Regions do not overlap; unmapped addresses select no target.
  assign ram_select_o   = (cpu_addr_i[31:12] == 20'h00000);
  assign uart_select_o  = (cpu_addr_i[31:8] == 24'h100000);
  assign gpio_select_o  = (cpu_addr_i[31:8] == 24'h100001);
  assign timer_select_o = (cpu_addr_i[31:8] == 24'h100002);

  assign ram_read_o = ram_select_o && cpu_read_i;
  assign ram_write_o = ram_select_o && cpu_write_i;
  assign ram_addr_o = ram_select_o ? {20'b0, cpu_addr_i[11:0]} : 32'b0;
  assign ram_write_data_o = cpu_write_data_i;
  assign ram_write_strobes_o = ram_write_o ? cpu_write_strobes_i : 4'b0;

  assign uart_read_o = uart_select_o && cpu_read_i;
  assign uart_write_o = uart_select_o && cpu_write_i;
  assign uart_addr_o = uart_select_o ? {24'b0, cpu_addr_i[7:0]} : 32'b0;
  assign uart_write_data_o = cpu_write_data_i;
  assign uart_write_strobes_o = uart_write_o ? cpu_write_strobes_i : 4'b0;

  assign gpio_read_o = gpio_select_o && cpu_read_i;
  assign gpio_write_o = gpio_select_o && cpu_write_i;
  assign gpio_addr_o = gpio_select_o ? {24'b0, cpu_addr_i[7:0]} : 32'b0;
  assign gpio_write_data_o = cpu_write_data_i;
  assign gpio_write_strobes_o = gpio_write_o ? cpu_write_strobes_i : 4'b0;

  assign timer_read_o = timer_select_o && cpu_read_i;
  assign timer_write_o = timer_select_o && cpu_write_i;
  assign timer_addr_o = timer_select_o ? {24'b0, cpu_addr_i[7:0]} : 32'b0;
  assign timer_write_data_o = cpu_write_data_i;
  assign timer_write_strobes_o = timer_write_o ? cpu_write_strobes_i : 4'b0;

  // No read intent or no address match returns zero.
  always_comb begin
    cpu_read_data_o = 32'b0;
    if (cpu_read_i) begin
      if (ram_select_o) cpu_read_data_o = ram_read_data_i;
      else if (uart_select_o) cpu_read_data_o = uart_read_data_i;
      else if (gpio_select_o) cpu_read_data_o = gpio_read_data_i;
      else if (timer_select_o) cpu_read_data_o = timer_read_data_i;
    end
  end
endmodule
