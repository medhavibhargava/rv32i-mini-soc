`timescale 1ns/1ps

module tb_rv32i_core_singlecycle;
  logic        clk = 1'b0;
  logic        reset;
  logic [31:0] instruction_address;
  logic [31:0] instruction_data;
  logic [31:0] data_address;
  logic        data_read;
  logic        data_write;
  logic [3:0]  data_write_strobe;
  logic [31:0] data_write_data;
  logic [31:0] data_read_data;

  logic [31:0] instruction_memory [0:63];
  logic [31:0] data_memory [0:31];
  integer index;
  int unsigned checks_run = 0;

  always #5 clk = ~clk;

  assign instruction_data = instruction_memory[instruction_address[7:2]];
  assign data_read_data    = data_read ? data_memory[data_address[6:2]]
                                       : 32'b0;

  rv32i_core_singlecycle dut (
    .clk_i                 (clk),
    .reset_i               (reset),
    .instruction_address_o (instruction_address),
    .instruction_data_i    (instruction_data),
    .data_address_o        (data_address),
    .data_read_o           (data_read),
    .data_write_o          (data_write),
    .data_write_strobe_o   (data_write_strobe),
    .data_write_data_o     (data_write_data),
    .data_read_data_i      (data_read_data)
  );

  always @(posedge clk) begin
    if (data_write) begin
      if (data_write_strobe[0]) begin
        data_memory[data_address[6:2]][7:0] <= data_write_data[7:0];
      end
      if (data_write_strobe[1]) begin
        data_memory[data_address[6:2]][15:8] <= data_write_data[15:8];
      end
      if (data_write_strobe[2]) begin
        data_memory[data_address[6:2]][23:16] <= data_write_data[23:16];
      end
      if (data_write_strobe[3]) begin
        data_memory[data_address[6:2]][31:24] <= data_write_data[31:24];
      end
    end
  end

  task automatic check_word(
    input int unsigned address,
    input logic [31:0] expected
  );
    logic [31:0] actual;
    begin
      actual = data_memory[address >> 2];
      checks_run++;
      if (actual !== expected) begin
        $fatal(1, "Memory check %0d failed at address %0d: expected=%h got=%h",
               checks_run, address, expected, actual);
      end
    end
  endtask

  initial begin
    for (index = 0; index < 64; index++) begin
      instruction_memory[index] = 32'h0000_0013;
    end
    for (index = 0; index < 32; index++) begin
      data_memory[index] = 32'b0;
    end

    // Hand-written RV32I program. Branch and jump instructions skip the
    // deliberately incorrect ADDI instructions at addresses 24, 40, and 116.
    instruction_memory[0]  = 32'h0050_0093; // addi  x1,  x0, 5
    instruction_memory[1]  = 32'h0070_0113; // addi  x2,  x0, 7
    instruction_memory[2]  = 32'h0020_81b3; // add   x3,  x1, x2
    instruction_memory[3]  = 32'h0030_2023; // sw    x3,  0(x0)
    instruction_memory[4]  = 32'h0000_2203; // lw    x4,  0(x0)
    instruction_memory[5]  = 32'h0032_0463; // beq   x4,  x3, +8 (taken)
    instruction_memory[6]  = 32'h0630_0293; // addi  x5,  x0, 99 (skipped)
    instruction_memory[7]  = 32'h0032_1463; // bne   x4,  x3, +8 (not taken)
    instruction_memory[8]  = 32'h0010_0293; // addi  x5,  x0, 1
    instruction_memory[9]  = 32'h0080_036f; // jal   x6,  +8
    instruction_memory[10] = 32'h0642_8293; // addi  x5,  x5, 100 (skipped)
    instruction_memory[11] = 32'h0062_83b3; // add   x7,  x5, x6
    instruction_memory[12] = 32'h0070_0223; // sb    x7,  4(x0)
    instruction_memory[13] = 32'h0040_4403; // lbu   x8,  4(x0)
    instruction_memory[14] = 32'h0080_1323; // sh    x8,  6(x0)
    instruction_memory[15] = 32'h0060_1483; // lh    x9,  6(x0)
    instruction_memory[16] = 32'hfff0_0513; // addi  x10, x0, -1
    instruction_memory[17] = 32'h00a0_02a3; // sb    x10, 5(x0)
    instruction_memory[18] = 32'h00a0_1323; // sh    x10, 6(x0)
    instruction_memory[19] = 32'h0050_0583; // lb    x11, 5(x0)
    instruction_memory[20] = 32'h0050_4603; // lbu   x12, 5(x0)
    instruction_memory[21] = 32'h0060_1a03; // lh    x20, 6(x0)
    instruction_memory[22] = 32'h0060_5a83; // lhu   x21, 6(x0)
    instruction_memory[23] = 32'h00c5_86b3; // add   x13, x11, x12
    instruction_memory[24] = 32'h00d0_2423; // sw    x13, 8(x0)
    instruction_memory[25] = 32'h0140_2c23; // sw    x20, 24(x0)
    instruction_memory[26] = 32'h0150_2e23; // sw    x21, 28(x0)
    instruction_memory[27] = 32'h0790_0713; // addi  x14, x0, 121
    instruction_memory[28] = 32'h0007_07e7; // jalr  x15, 0(x14), target 120
    instruction_memory[29] = 32'h0642_8293; // addi  x5,  x5, 100 (skipped)
    instruction_memory[30] = 32'h00f0_2623; // sw    x15, 12(x0)
    instruction_memory[31] = 32'h1234_5837; // lui   x16, 0x12345
    instruction_memory[32] = 32'h0100_2823; // sw    x16, 16(x0)
    instruction_memory[33] = 32'h0000_0897; // auipc x17, 0
    instruction_memory[34] = 32'h0110_2a23; // sw    x17, 20(x0)
    instruction_memory[35] = 32'h0000_006f; // jal   x0,  0

    reset = 1'b1;
    repeat (2) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;

    repeat (40) @(posedge clk);
    #1;

    check_word(0,  32'd12);        // ADD, SW, and LW result
    check_word(4,  32'hffff_ff29); // SB/SH lane placement and load values
    check_word(8,  32'd254);       // LB sign extension plus LBU zero extension
    check_word(12, 32'd116);       // JALR link value; odd target was masked
    check_word(16, 32'h1234_5000); // LUI writeback
    check_word(20, 32'd132);       // AUIPC uses its instruction address
    check_word(24, 32'hffff_ffff); // signed LH
    check_word(28, 32'h0000_ffff); // unsigned LHU

    checks_run++;
    if (instruction_address !== 32'd140) begin
      $fatal(1, "Final PC check failed: expected=140 got=%0d",
             instruction_address);
    end

    $display("PASS: %0d single-cycle core integration checks completed",
             checks_run);
    $finish;
  end
endmodule
