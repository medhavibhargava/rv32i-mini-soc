`timescale 1ns/1ps

module rv32i_mini_soc #(
  parameter int unsigned CLOCK_FREQ_HZ = 50_000_000,
  parameter int unsigned UART_BAUD_RATE = 115_200,
  parameter int unsigned GPIO_WIDTH = 32
) (
  input  logic                  clk_i,
  input  logic                  reset_i,
  output logic [31:0]           instruction_address_o,
  input  logic [31:0]           instruction_data_i,
  output logic                  uart_tx_o,
  input  logic [GPIO_WIDTH-1:0] gpio_in_i,
  output logic [GPIO_WIDTH-1:0] gpio_out_o,
  output logic [GPIO_WIDTH-1:0] gpio_dir_o,
  output logic                  timer_irq_o
);
  logic [31:0] cpu_data_address;
  logic        cpu_data_read;
  logic        cpu_data_write;
  logic [31:0] cpu_data_write_data;
  logic [3:0]  cpu_data_write_strobes;
  logic [31:0] cpu_data_read_data;

  logic        ram_select, ram_read, ram_write;
  logic [31:0] ram_address, ram_write_data, ram_read_data;
  logic [3:0]  ram_write_strobes;
  logic        uart_select, uart_read, uart_write;
  logic [31:0] uart_address, uart_write_data, uart_read_data;
  logic [3:0]  uart_write_strobes;
  logic        gpio_select, gpio_read, gpio_write;
  logic [31:0] gpio_address, gpio_write_data, gpio_read_data;
  logic [3:0]  gpio_write_strobes;
  logic        timer_select, timer_read, timer_write;
  logic [31:0] timer_address, timer_write_data, timer_read_data;
  logic [3:0]  timer_write_strobes;

  rv32i_core_pipeline cpu_i (
    .clk_i                 (clk_i),
    .reset_i               (reset_i),
    .instruction_address_o (instruction_address_o),
    .instruction_data_i    (instruction_data_i),
    .data_address_o        (cpu_data_address),
    .data_read_o           (cpu_data_read),
    .data_write_o          (cpu_data_write),
    .data_write_strobe_o   (cpu_data_write_strobes),
    .data_write_data_o     (cpu_data_write_data),
    .data_read_data_i      (cpu_data_read_data)
  );

  simple_interconnect interconnect_i (
    .cpu_addr_i          (cpu_data_address),
    .cpu_read_i          (cpu_data_read),
    .cpu_write_i         (cpu_data_write),
    .cpu_write_data_i    (cpu_data_write_data),
    .cpu_write_strobes_i (cpu_data_write_strobes),
    .cpu_read_data_o     (cpu_data_read_data),
    .ram_select_o        (ram_select),
    .ram_read_o          (ram_read),
    .ram_write_o         (ram_write),
    .ram_addr_o          (ram_address),
    .ram_write_data_o    (ram_write_data),
    .ram_write_strobes_o (ram_write_strobes),
    .ram_read_data_i     (ram_read_data),
    .uart_select_o       (uart_select),
    .uart_read_o         (uart_read),
    .uart_write_o        (uart_write),
    .uart_addr_o         (uart_address),
    .uart_write_data_o   (uart_write_data),
    .uart_write_strobes_o(uart_write_strobes),
    .uart_read_data_i    (uart_read_data),
    .gpio_select_o       (gpio_select),
    .gpio_read_o         (gpio_read),
    .gpio_write_o        (gpio_write),
    .gpio_addr_o         (gpio_address),
    .gpio_write_data_o   (gpio_write_data),
    .gpio_write_strobes_o(gpio_write_strobes),
    .gpio_read_data_i    (gpio_read_data),
    .timer_select_o      (timer_select),
    .timer_read_o        (timer_read),
    .timer_write_o       (timer_write),
    .timer_addr_o        (timer_address),
    .timer_write_data_o  (timer_write_data),
    .timer_write_strobes_o(timer_write_strobes),
    .timer_read_data_i   (timer_read_data)
  );

  data_ram #(.MEM_SIZE_BYTES(4096)) data_ram_i (
    .clk_i           (clk_i),
    .addr_i          (ram_address),
    .write_data_i    (ram_write_data),
    .write_strobes_i (ram_write_strobes),
    .read_data_o     (ram_read_data)
  );

  uart_tx #(
    .CLOCK_FREQ_HZ (CLOCK_FREQ_HZ),
    .BAUD_RATE     (UART_BAUD_RATE)
  ) uart_tx_i (
    .clk_i           (clk_i),
    .reset_i         (reset_i),
    .select_i        (uart_select),
    .read_i          (uart_read),
    .write_i         (uart_write),
    .addr_i          (uart_address),
    .write_data_i    (uart_write_data),
    .write_strobes_i (uart_write_strobes),
    .read_data_o     (uart_read_data),
    .tx_o            (uart_tx_o)
  );

  gpio #(.GPIO_WIDTH(GPIO_WIDTH)) gpio_i (
    .clk_i           (clk_i),
    .reset_i         (reset_i),
    .select_i        (gpio_select),
    .read_i          (gpio_read),
    .write_i         (gpio_write),
    .addr_i          (gpio_address),
    .write_data_i    (gpio_write_data),
    .write_strobes_i (gpio_write_strobes),
    .read_data_o     (gpio_read_data),
    .gpio_out_o      (gpio_out_o),
    .gpio_in_i       (gpio_in_i),
    .gpio_dir_o      (gpio_dir_o)
  );

  timer timer_i (
    .clk_i           (clk_i),
    .reset_i         (reset_i),
    .select_i        (timer_select),
    .read_i          (timer_read),
    .write_i         (timer_write),
    .addr_i          (timer_address),
    .write_data_i    (timer_write_data),
    .write_strobes_i (timer_write_strobes),
    .read_data_o     (timer_read_data),
    .irq_o           (timer_irq_o)
  );
endmodule
