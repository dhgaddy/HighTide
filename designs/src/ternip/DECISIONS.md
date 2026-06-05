# ternip Design Decisions

Per-platform notes for the ternip SystemVerilog ternary matmul inference accelerator.

| Variant | Description |
|---|---|
| `ternip_core` | Single-issue accelerator with a vector register file and a 16-bit tile matmul (TMATMUL) datapath. |

FakeRAM macros live at `designs/asap7/ternip/sram/{lef,lib}/`.

## FakeRAM regeneration (2026-05-13)

- **Generator**: `bsg_fakeram` (VLSIDA fork @ `asap7-area-calib-v2`), invoked via `tools/regenerate_sram.sh ternip asap7`.
- **Cfg**: `designs/src/ternip/dev/generated/fakeram_asap7.cfg` — 1 entry, `fakeram7_512x16` (16×512=8 Kb, 1rw, `no_wmask`).
- **Prior generator**: in-repo `designs/src/ternip/dev/gen_fakeram.py` (area_per_bit heuristic, now deleted).
- **Size delta**: `fakeram7_512x16` shrinks from 90.56 × 45.36 µm² (aspect 2.0:1, 4108 µm²) to **34.56 × 43.20 µm² (aspect 1.25:1, 1493 µm²)** — −64 % area. The bsg_fakeram analytical formula uses Clark et al.'s ASAP7 6T bitcell (0.029 µm²) with a 2.5× per-dim periphery overhead and dynamic column muxing.

## Active workarounds

None — ternip closes with RTLMP placement.

## asap7

**Status**: finishing
**Last updated**: 2026-06-04 (bazel-orfs 553c1c3 upgrade validation).

### Decisions
- **2026-06-04 toolchain upgrade (bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64)**: all three platforms close clean, no change needed — asap7 WNS +808 → +837 ps (util 71.2 %, 18 833 cells), nangate45 +3454 → +3410 ps, sky130hd +9916 → +9286 ps (all huge positive margins; Fmax within ~7 %). No workarounds.
- **2026-05-28 `187957b5`**: bumped `dev/repo` to upstream `187957b5` — single commit, improves rowwise multioperand combinational operations in `rtl/fus/ternip_rowwise_operation.sv`. Closes #148.
- **2026-05-28 `b48037e2`**: bumped `dev/basejump_stl` to `b48037e2` (3 commits: rp_groups `.v` extensions, `bsg_fifo_1r1w_narrowed.sv` update, `bsg_reduce balanced_p` param). None touch files in `_BSG_FILES` — regenerated `dev/bsg/` is bit-identical, build is pure cache hit. Closes #149.

### Configuration

| Util | Density | Halo | Clock (ps) | Notes |
|---:|---:|---:|---:|---|
| 45 | 0.55 | 4 4 | (per `constraint.sdc`) | RTLMP places the 10 banked SRAMs; `macro_placement.tcl` removed when the regenerated 34×43 µm macros made the old hand-placement coords (sized for 90×45 µm macros) obsolete. |
