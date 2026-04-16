# HighTide

A VLSI design benchmark suite that runs open-source hardware designs through the [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD) RTL-to-GDSII flow on academic and open-source technology nodes (ASAP7 7nm, NanGate 45nm, SkyWater 130nm).

**New here?** See the **[Quick Start Guide](docs/quickstart.md)** to build your first design in 5 minutes.

## Designs

8 designs across 3 technology platforms, ranging from a small LFSR to a quad-core RISC-V processor:

| Design | Type | asap7 | nangate45 | sky130hd |
|--------|------|:-----:|:---------:|:--------:|
| lfsr | LFSR/PRBS generator | x | x | x |
| minimax | RISC-V RV32I core | x | x | x |
| liteeth | Ethernet MAC (6 variants) | x | x | x |
| NyuziProcessor | Multi-threaded GPGPU | x | x | |
| bp_processor | Black-Parrot RISC-V (2 variants) | x | x | |
| gemmini | ML systolic array | x | x | |
| cnn | CNN accelerator | x | x | |
| sha3 | SHA3 hash | x | x | |

## How It Works

Each design's upstream source lives in a git submodule at `designs/src/<design>/dev/repo/`. A build script converts the source HDL (SystemVerilog, Chisel, LiteX, etc.) into plain Verilog, which is checked into the repo as the **release RTL** at `designs/src/<design>/`. The release RTL may include patches or modifications beyond simple conversion — for example, SRAM memories are replaced with FakeRAM black-box macros so the design can be synthesized without an SRAM compiler. This release RTL is what builds use by default — no submodule checkout or conversion tools needed.

To regenerate RTL from the upstream source (e.g., after updating the submodule to a newer commit):

```bash
bazel build --define update_rtl=true //designs/asap7/lfsr:lfsr_final
```

The release RTL is then run through the [OpenROAD-flow-scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts) RTL-to-GDSII flow: synthesis (Yosys) → floorplan → placement → clock tree synthesis → routing → GDSII output. Each design has per-platform configuration (clock constraints, utilization targets, pin placement) tuned for the target technology node.

## Documentation

- **[Quick Start Guide](docs/quickstart.md)** — install, build, and view results
- **[Design Catalog](docs/designs.md)** — all designs, platforms, variants, and complexity
- **[Architecture](docs/architecture.md)** — build system, flow stages, RTL management, caching
- **[Adding Designs](docs/adding-designs.md)** — how to add a new design to the suite
- **[Kubernetes Builds](k8s/README.md)** — building at scale on NRP Nautilus
