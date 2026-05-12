# LiteDRAM Core

Standalone configuration of the [LiteDRAM](https://github.com/enjoy-digital/litedram)
DRAM controller from EnjoyDigital, generated for the HighTide benchmark
suite. The generator picks the vendor-agnostic Generic SDR PHY
(`GENSDRPHY`) so the resulting `litedram_core` synthesizes cleanly on
asap7 / nangate45 / sky130hd.

## Quick Start

Build the design from the pre-generated release RTL:

```bash
bazel build //designs/asap7/litedram:litedram_final
bazel build //designs/nangate45/litedram:litedram_final
bazel build //designs/sky130hd/litedram:litedram_final
```

## Regenerating `litedram_core.v`

The release RTL is checked in. To regenerate from the upstream
submodule (pin in `.gitmodules`):

```bash
# One-time: fetch the submodule and create the venv with pinned deps.
git submodule update --init designs/src/litedram/dev/repo
bash designs/src/litedram/dev/setup.sh

# Each regen:
bash designs/src/litedram/gen.sh \
     designs/src/litedram/litedram.yml \
     designs/src/litedram \
     litedram
```

This writes `designs/src/litedram/litedram_core.v` and archives the
LiteX build directory under `dev/litedram_build_<timestamp>/`.

## Configuration

See `litedram.yml` for the standalone-core configuration:

- `memtype: SDR` and `sdram_phy: GENSDRPHY` — vendor-agnostic PHY, no
  Xilinx/Intel/Altera primitives in the controller core.
- `cpu: null` — controller-only; no SoC scaffolding (CPU, UART, ROM).
- `sdram_module: MT48LC16M16`, `sdram_module_nb: 2` — 16-bit data bus,
  256 Mbit SDR module timings.
- `user_ports`: AXI + Wishbone + native, to exercise the frontend
  crossbar.

## Vendor primitives

`GENSDRPHY` still wraps its SDR I/O cells in Lattice ECP5 primitives
because `gen.py` instantiates a `LatticePlatform` (with a `# FIXME:
Allow other Vendors.` comment). Four primitives appear in the generated
Verilog and have ASIC-synthesizable RTL stubs under
`libraries/lattice/`:

| Primitive    | Role                                            |
|--------------|-------------------------------------------------|
| `FD1S3BX`    | Reset synchronizer D flip-flop (async preset).  |
| `OFS1P3BX`   | SDR output flip-flop (sync set + async preset). |
| `IFS1P3BX`   | SDR input flip-flop (sync set + async preset).  |
| `TRELLIS_IO` | Bidirectional IO buffer (DQ tristate path).     |

## Pinned upstream versions

| Component | Repo                                          | Commit                                   |
|-----------|-----------------------------------------------|------------------------------------------|
| migen     | https://github.com/m-labs/migen.git           | 4c2ae8dfeea37f235b52acb8166f12acaaae4f7c |
| litex     | https://github.com/enjoy-digital/litex.git    | a25eeecd27309b2a04a9cf74a1d4849e38ff2090 |
| litedram  | https://github.com/enjoy-digital/litedram.git | submodule HEAD (see `.gitmodules`)       |
