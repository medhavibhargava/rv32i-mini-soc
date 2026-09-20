# Verification notes

## Regression model

Every testbench is self-checking: a mismatch calls `$fatal`, while a successful
run prints its completed check count. `scripts/sim.py` compiles each test as an
independent SystemVerilog top with Icarus Verilog and stops immediately if
compilation or execution fails.

The final regression has 12 testbench tops and 2,491 explicit checks:

| Testbench | Checks | Verification focus |
| --- | ---: | --- |
| `tb_alu` | 20 | ALU functions, signed/unsigned comparisons, and shifts |
| `tb_regfile` | 5 | Dual-port reads, synchronous writes, overwrite, and x0 |
| `tb_imm_gen` | 8 | I/S/B/U/J immediate extraction and sign extension |
| `tb_control_unit` | 18 | Legal instruction decode and generated controls |
| `tb_rv32i_core_singlecycle` | 9 | Reference-core execution and data interface |
| `tb_rv32i_core_pipeline` | 28 | Dependencies, three load-use cases, redirects, and wrong-path suppression |
| `tb_data_ram` | 16 | Word/byte/halfword writes, byte preservation, and combinational reads |
| `tb_simple_interconnect` | 1,536 | All regions, exact boundaries, intents, strobes, read muxing, and unmapped addresses |
| `tb_uart_tx` | 581 | Two divider configurations, complete framing, busy, ignored writes, and reads |
| `tb_gpio` | 183 | Widths 32, 13, and 1; all byte lanes; input, direction, and reset |
| `tb_timer` | 77 | Enable, count, compare, sticky pending, IRQ mask, W1C, and reset priority |
| `tb_rv32i_mini_soc` | 10 | Program-driven RAM and peripheral integration |

Run all tests from the repository root:

```text
python scripts/sim.py
```

The runner requires `iverilog` and `vvp` on `PATH` and writes compiled simulation
artifacts under `build/`.

## Pipeline scenarios

The pipeline integration test uses hand-encoded instructions and a combinational
instruction-memory array. Its checks cover:

- consecutive ALU producers and consumers;
- simultaneous forwarding from EX/MEM and MEM/WB;
- newest-producer priority when both stages target the same register;
- immediate producer-to-store forwarding;
- load-to-ALU and load-to-store dependencies;
- avoidance of false stalls for x0 and unused instruction fields;
- byte stores and unsigned byte loads;
- taken and not-taken branches;
- `JAL` and `JALR` link values and redirects;
- suppression of wrong-path register writes and stores.

The test also counts exactly three load-use stalls and five redirect events,
making control-flow behavior observable rather than inferred only from final
memory values.

## End-to-end SoC program

`tb_rv32i_mini_soc` supplies instructions through the top-level instruction
interface and lets the integrated pipeline execute normally. The program:

1. Stores `0x5A` in data RAM.
2. Loads it, immediately adds one through the load-use hazard path, and stores
   `0x5B` to a second RAM word.
3. Builds the `0x1000_0100` GPIO base address and writes `0xA5` to GPIO_OUT.
4. Writes all ones to GPIO_DIR and verifies the external direction pins.
5. Writes byte `0x55` to UART TXDATA. The test detects the start edge and samples
   all ten bits from the top-level UART pin at bit-period midpoints.
6. Writes timer COMPARE, enables counting and IRQ generation, waits through
   normal instruction execution, and observes the external IRQ.
7. Loads timer STATUS through the interconnect and stores the pending value into
   RAM, proving peripheral readback through the complete CPU data path.

This test complements peripheral unit tests: it verifies instruction fetch,
pipeline hazards, address generation, decode, byte strobes, read-data muxing,
peripheral state, and top-level outputs together.

## Synthesis cross-check

The Yosys flow runs `hierarchy -check` and `check -assert` around generic coarse
synthesis. The checked-in result reports zero structural problems and preserves
the data RAM and register file as two `$mem_v2` cells. Synthesis results and
limitations are recorded in [the synthesis report](../reports/synthesis_report.md).
