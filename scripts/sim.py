"""Portable simulation entry point.

macOS:   python3 scripts/sim.py
Windows: py -3 scripts/sim.py
"""

from pathlib import Path
import shutil
import subprocess
import sys


def main():
    project_root = Path(__file__).resolve().parent.parent
    build_dir = project_root / "build"

    iverilog = shutil.which("iverilog")
    vvp = shutil.which("vvp")
    if not iverilog or not vvp:
        print("Error: Icarus Verilog (iverilog and vvp) is required.", file=sys.stderr)
        return 1

    build_dir.mkdir(exist_ok=True)
    tests = {
        "tb_simple_interconnect": [
            project_root / "rtl" / "bus" / "simple_interconnect.sv",
            project_root / "tb" / "tb_simple_interconnect.sv",
        ],
        "tb_data_ram": [
            project_root / "rtl" / "memory" / "data_ram.sv",
            project_root / "tb" / "tb_data_ram.sv",
        ],
        "tb_alu": [
            project_root / "rtl" / "cpu" / "alu_pkg.sv",
            project_root / "rtl" / "cpu" / "alu.sv",
            project_root / "tb" / "tb_alu.sv",
        ],
        "tb_regfile": [
            project_root / "rtl" / "cpu" / "regfile.sv",
            project_root / "tb" / "tb_regfile.sv",
        ],
        "tb_imm_gen": [
            project_root / "rtl" / "cpu" / "imm_gen_pkg.sv",
            project_root / "rtl" / "cpu" / "imm_gen.sv",
            project_root / "tb" / "tb_imm_gen.sv",
        ],
        "tb_control_unit": [
            project_root / "rtl" / "cpu" / "alu_pkg.sv",
            project_root / "rtl" / "cpu" / "imm_gen_pkg.sv",
            project_root / "rtl" / "cpu" / "control_unit_pkg.sv",
            project_root / "rtl" / "cpu" / "control_unit.sv",
            project_root / "tb" / "tb_control_unit.sv",
        ],
        "tb_rv32i_core_singlecycle": [
            project_root / "rtl" / "cpu" / "alu_pkg.sv",
            project_root / "rtl" / "cpu" / "imm_gen_pkg.sv",
            project_root / "rtl" / "cpu" / "control_unit_pkg.sv",
            project_root / "rtl" / "cpu" / "alu.sv",
            project_root / "rtl" / "cpu" / "regfile.sv",
            project_root / "rtl" / "cpu" / "imm_gen.sv",
            project_root / "rtl" / "cpu" / "control_unit.sv",
            project_root / "rtl" / "cpu" / "rv32i_core_singlecycle.sv",
            project_root / "tb" / "tb_rv32i_core_singlecycle.sv",
        ],
        "tb_rv32i_core_pipeline": [
            project_root / "rtl" / "cpu" / "alu_pkg.sv",
            project_root / "rtl" / "cpu" / "imm_gen_pkg.sv",
            project_root / "rtl" / "cpu" / "control_unit_pkg.sv",
            project_root / "rtl" / "cpu" / "alu.sv",
            project_root / "rtl" / "cpu" / "regfile.sv",
            project_root / "rtl" / "cpu" / "imm_gen.sv",
            project_root / "rtl" / "cpu" / "control_unit.sv",
            project_root / "rtl" / "cpu" / "forwarding_unit.sv",
            project_root / "rtl" / "cpu" / "hazard_unit.sv",
            project_root / "rtl" / "cpu" / "rv32i_core_pipeline.sv",
            project_root / "tb" / "tb_rv32i_core_pipeline.sv",
        ],
    }

    for top_module, sources in tests.items():
        output_file = build_dir / f"{top_module}.vvp"
        subprocess.run(
            [
                iverilog,
                "-g2012",
                "-Wall",
                "-s",
                top_module,
                "-o",
                output_file,
                *sources,
            ],
            check=True,
        )
        subprocess.run([vvp, output_file], check=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
