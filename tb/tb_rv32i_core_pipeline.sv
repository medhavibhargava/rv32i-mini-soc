`timescale 1ns/1ps

module tb_rv32i_core_pipeline;
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

  logic [31:0] instruction_memory [0:255];
  logic [31:0] data_memory [0:31];
  integer index;
  int unsigned checks_run = 0;
  int unsigned stall_count = 0;
  int unsigned redirect_count = 0;

  always #5 clk = ~clk;

  assign instruction_data = instruction_memory[instruction_address[9:2]];
  assign data_read_data    = data_read ? data_memory[data_address[6:2]]
                                       : 32'b0;

  rv32i_core_pipeline dut (
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
    if (reset) begin
      stall_count <= 0;
      redirect_count <= 0;
    end else if (dut.load_use_stall) begin
      stall_count <= stall_count + 1;
    end

    if (!reset && dut.ex_redirect) begin
      redirect_count <= redirect_count + 1;
    end

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
        $fatal(1, "Pipeline memory check %0d failed at address %0d: expected=%h got=%h",
               checks_run, address, expected, actual);
      end
    end
  endtask

  initial begin
    for (index = 0; index < 256; index++) begin
      instruction_memory[index] = 32'h0000_0013;
    end
    for (index = 0; index < 32; index++) begin
      data_memory[index] = 32'b0;
    end

    // Dependencies are separated by three NOPs because this first pipeline
    // intentionally has no forwarding or interlocks.
    instruction_memory[0]  = 32'h0050_0093; // addi  x1, x0, 5
    instruction_memory[4]  = 32'h0070_0113; // addi  x2, x0, 7
    instruction_memory[8]  = 32'h0020_81b3; // add   x3, x1, x2
    instruction_memory[12] = 32'h0030_2023; // sw    x3, 0(x0)
    instruction_memory[13] = 32'h0000_2203; // lw    x4, 0(x0)
    instruction_memory[17] = 32'h0012_0293; // addi  x5, x4, 1
    instruction_memory[21] = 32'h0050_2223; // sw    x5, 4(x0)
    instruction_memory[22] = 32'hfff0_0313; // addi  x6, x0, -1
    instruction_memory[26] = 32'h0060_0423; // sb    x6, 8(x0)
    instruction_memory[27] = 32'h0080_4383; // lbu   x7, 8(x0)
    instruction_memory[31] = 32'h0070_2623; // sw    x7, 12(x0)
    instruction_memory[32] = 32'h1234_5437; // lui   x8, 0x12345
    instruction_memory[36] = 32'h0080_2823; // sw    x8, 16(x0)
    instruction_memory[37] = 32'h0000_0497; // auipc x9, 0
    instruction_memory[41] = 32'h0090_2a23; // sw    x9, 20(x0)

    // These target sequences retain NOP spacing from the pre-flush test.
    instruction_memory[42] = 32'h0000_0663; // beq   x0, x0, +12
    instruction_memory[45] = 32'h02a0_0513; // addi  x10, x0, 42
    instruction_memory[49] = 32'h00a0_2c23; // sw    x10, 24(x0)
    instruction_memory[50] = 32'h00c0_05ef; // jal   x11, +12
    instruction_memory[54] = 32'h00b0_2e23; // sw    x11, 28(x0)

    // Focused forwarding sequence with no dependency-spacing NOPs.
    instruction_memory[60] = 32'h00a0_0b13; // addi  x22, x0, 10
    instruction_memory[61] = 32'h005b_0b93; // addi  x23, x22, 5 (EX/MEM rs1)
    instruction_memory[62] = 32'h017b_0c33; // add   x24, x22, x23 (WB rs1, EX/MEM rs2)
    instruction_memory[63] = 32'h017c_0cb3; // add   x25, x24, x23 (both sources)
    instruction_memory[64] = 32'h0010_0d13; // addi  x26, x0, 1
    instruction_memory[65] = 32'h002d_0d13; // addi  x26, x26, 2
    instruction_memory[66] = 32'h004d_0d93; // addi  x27, x26, 4 (newest x26 wins)
    instruction_memory[67] = 32'h063d_8013; // addi  x0,  x27, 99
    instruction_memory[68] = 32'h0080_0e13; // addi  x28, x0, 8 (x0 never forwards)
    instruction_memory[69] = 32'h0370_2023; // sw    x23, 32(x0)
    instruction_memory[70] = 32'h0380_2223; // sw    x24, 36(x0)
    instruction_memory[71] = 32'h0390_2423; // sw    x25, 40(x0)
    instruction_memory[72] = 32'h03b0_2623; // sw    x27, 44(x0)
    instruction_memory[73] = 32'h03c0_2823; // sw    x28, 48(x0)
    instruction_memory[74] = 32'h04d0_0e93; // addi  x29, x0, 77
    instruction_memory[75] = 32'h03d0_2a23; // sw    x29, 52(x0) (forwarded store data)

    // Focused load-use cases. Each true dependency should insert one bubble.
    instruction_memory[80] = 32'h0000_2083; // lw    x1, 0(x0)
    instruction_memory[81] = 32'h0030_8113; // addi  x2, x1, 3 (rs1 hazard)
    instruction_memory[82] = 32'h0000_2183; // lw    x3, 0(x0)
    instruction_memory[83] = 32'h0030_0233; // add   x4, x0, x3 (rs2 hazard)
    instruction_memory[84] = 32'h0000_2283; // lw    x5, 0(x0)
    instruction_memory[85] = 32'h0250_2c23; // sw    x5, 56(x0) (store-data hazard)

    // Neither sequence below should stall: x0 is ignored, and ADDI does not
    // use instruction[24:20] as rs2 even though those bits equal the load rd.
    instruction_memory[86] = 32'h0000_2003; // lw    x0, 0(x0)
    instruction_memory[87] = 32'h0090_0313; // addi  x6, x0, 9
    instruction_memory[88] = 32'h0000_2383; // lw    x7, 0(x0)
    instruction_memory[89] = 32'h0070_0413; // addi  x8, x0, 7
    instruction_memory[90] = 32'h0220_2e23; // sw    x2, 60(x0)
    instruction_memory[91] = 32'h0440_2023; // sw    x4, 64(x0)
    instruction_memory[92] = 32'h0460_2223; // sw    x6, 68(x0)
    instruction_memory[93] = 32'h0480_2423; // sw    x8, 72(x0)

    // Taken BEQ with both source values supplied by forwarding. The ADDI and
    // store on the wrong path must be flushed before they can change state.
    instruction_memory[100] = 32'h0010_0513; // addi  x10, x0, 1
    instruction_memory[101] = 32'h0010_0593; // addi  x11, x0, 1
    instruction_memory[102] = 32'h00b5_0663; // beq   x10, x11, +12 (taken)
    instruction_memory[103] = 32'h0630_0513; // addi  x10, x0, 99 (flushed)
    instruction_memory[104] = 32'h04a0_2e23; // sw    x10, 92(x0) (flushed)
    instruction_memory[105] = 32'h04a0_2623; // sw    x10, 76(x0)

    // Not-taken branch preserves normal sequential execution.
    instruction_memory[106] = 32'h00b5_1663; // bne   x10, x11, +12 (not taken)
    instruction_memory[107] = 32'h0020_0693; // addi  x13, x0, 2
    instruction_memory[108] = 32'h04d0_2823; // sw    x13, 80(x0)

    // JAL flushes a wrong-path register write and store, then writes its link.
    instruction_memory[109] = 32'h00c0_076f; // jal   x14, +12
    instruction_memory[110] = 32'h0370_0793; // addi  x15, x0, 55 (flushed)
    instruction_memory[111] = 32'h06a0_2023; // sw    x10, 96(x0) (flushed)
    instruction_memory[113] = 32'h04e0_2a23; // sw    x14, 84(x0)

    // JALR consumes an immediately preceding value through forwarding. Its
    // odd source address is redirected to 476 after clearing target bit zero.
    instruction_memory[114] = 32'h1dd0_0813; // addi  x16, x0, 477
    instruction_memory[115] = 32'h0008_08e7; // jalr  x17, 0(x16)
    instruction_memory[116] = 32'h0580_0913; // addi  x18, x0, 88 (flushed)
    instruction_memory[117] = 32'h06a0_2223; // sw    x10, 100(x0) (flushed)
    instruction_memory[120] = 32'h0510_2c23; // sw    x17, 88(x0)

    reset = 1'b1;
    repeat (2) @(posedge clk);
    @(negedge clk);
    reset = 1'b0;

    repeat (140) @(posedge clk);
    #1;

    check_word(0,  32'd12);        // ALU dependency and word load/store
    check_word(4,  32'd13);        // load result consumed after NOP spacing
    check_word(8,  32'h0000_00ff); // byte store lane
    check_word(12, 32'd255);       // unsigned byte-load writeback
    check_word(16, 32'h1234_5000); // LUI through EX and WB
    check_word(20, 32'd148);       // AUIPC uses the ID/EX instruction PC
    check_word(24, 32'd42);        // taken branch reached its target
    check_word(28, 32'd204);       // JAL wrote PC+4 before redirect
    check_word(32, 32'd15);        // immediately forwarded rs1 result
    check_word(36, 32'd25);        // simultaneous WB rs1 and EX/MEM rs2 paths
    check_word(40, 32'd40);        // both ALU inputs receive forwarded values
    check_word(44, 32'd7);         // newest of two writes to x26 has priority
    check_word(48, 32'd8);         // destination x0 was never forwarded
    check_word(52, 32'd77);        // immediate producer-to-store dependency
    check_word(56, 32'd12);        // load result forwarded into store data
    check_word(60, 32'd15);        // load-to-ALU dependency through rs1
    check_word(64, 32'd12);        // load-to-ALU dependency through rs2
    check_word(68, 32'd9);         // load destination x0 caused no stall
    check_word(72, 32'd7);         // immediate field overlap caused no stall
    check_word(76, 32'd1);         // taken BEQ target; wrong register write flushed
    check_word(80, 32'd2);         // not-taken BNE continued sequentially
    check_word(84, 32'd440);       // JAL link writeback and redirect
    check_word(88, 32'd464);       // JALR link and masked odd target
    check_word(92, 32'b0);         // wrong-path BEQ store suppressed
    check_word(96, 32'b0);         // wrong-path JAL store suppressed
    check_word(100, 32'b0);        // wrong-path JALR store suppressed

    checks_run++;
    if (stall_count !== 3) begin
      $fatal(1, "Stall-count check failed: expected=3 got=%0d", stall_count);
    end

    checks_run++;
    if (redirect_count !== 5) begin
      $fatal(1, "Redirect-count check failed: expected=5 got=%0d", redirect_count);
    end

    $display("PASS: %0d pipeline integration checks completed", checks_run);
    $finish;
  end
endmodule
