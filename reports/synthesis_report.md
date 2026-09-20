# RV32I Mini-SoC generic synthesis report

## Result

- Status: PASS
- Top module: `rv32i_mini_soc`
- Tool: Yosys 0.69 (YoWASP build, git 9f75ca1f9)
- Flow: technology-independent coarse synthesis through memory collection
- Structural check: 0 problems
- Output netlist: `build/rv32i_mini_soc_coarse.json`

Run from the repository root with:

```text
yosys -l reports/yosys_synthesis.log -s scripts/synth.ys
```

## Statistics

| Metric | Count |
| --- | ---: |
| Generic cells | 395 |
| Wires | 565 |
| Wire bits | 5,883 |
| Inferred memory cells (`$mem_v2`) | 2 |
| Muxes (`$mux` + `$pmux`) | 129 |
| Equality comparators (`$eq`) | 75 |
| Synchronous flip-flop groups (`$sdff` + `$sdffe`) | 61 |
| Generic ALU cells (`$alu`) | 8 |

Other major logic categories are 43 `$logic_and`, 19 `$logic_not`, 19
`$reduce_or`, 14 `$reduce_and`, and 7 `$reduce_bool` cells. Shift logic
contains four `$shl`, two `$shr`, and one `$sshr` cell.

## Inferred memories

| Memory | Organization | Capacity | Generic cell |
| --- | ---: | ---: | --- |
| Data RAM | 1,024 x 32 bits | 32,768 bits (4 KiB) | `$mem_v2` |
| CPU register file | 32 x 32 bits | 1,024 bits | `$mem_v2` |

The data RAM has a combinational read port and byte-enabled synchronous write
port. The register file has two combinational read ports and one synchronous
write port.

## Warnings and limitations

Yosys emitted no warnings, and `check -assert` reported no structural problems.
The flow deliberately stops after generic coarse synthesis so inferred memories
remain visible. It does not map to an FPGA or ASIC cell library, estimate area,
run static timing analysis, insert clocks/resets, or produce a bitstream.

Memory realization is target-dependent. In particular, asynchronous RAM reads
and the register file's two asynchronous read ports may prevent direct mapping
to synchronous block RAM on some FPGAs. The instruction memory remains an
external top-level interface and is not included in the synthesized memory
capacity.
