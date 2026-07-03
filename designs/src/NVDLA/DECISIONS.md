# NVDLA Design Decisions

Per-platform notes for NVDLA `nv_small` (NVIDIA Deep Learning Accelerator), split into five partitions per the upstream `nv_small` build manifest: `a`, `c`, `m`, `o`, `p`.

| Partition | Description |
|---|---|
| `a` | Activation / convolution data path (was the largest SRAM consumer; now all SRAMs FF). |
| `c` | Configuration + post-processor; 2 SRAM macros. |
| `m` | Master controller / address generator. No SRAMs. |
| `o` | Output processor / pooling + scaling; 8 SRAM macros. |
| `p` | PDP (planar data processor); 4 SRAM macros. |

FakeRAM macros live at `designs/<platform>/NVDLA/sram/{lef,lib}/`; the per-partition filegroups in each platform's `BUILD.bazel` carry the macros each partition needs.

## FakeRAM regeneration (2026-05-13)

- **Generator**: `bsg_fakeram` (VLSIDA fork @ `asap7-area-calib-v2`), invoked via `tools/regenerate_sram.sh NVDLA <platform>` per platform.
- **Cfg**: `designs/src/NVDLA/dev/generated/fakeram_{asap7,nangate45,sky130hd}.cfg` — 14 entries each, all `1r1w` with `no_wmask`.
- **Prior generator**: in-repo `designs/src/NVDLA/dev/gen_fakeram.py` (area_per_bit heuristic, now deleted).

### Macro vs FF fallback

The original `gen_fakeram.py:SRAM_SIZES` list had 20 (width, depth) pairs. Six become flip-flop register arrays instead of hard macros:

| (W, D) | Bits | Reason |
|---|---:|---|
| (6, 128) | 768 | sub-1 KB (below CACTI's reach on the non-asap7 platforms) |
| (9, 80) | 720 | sub-1 KB |
| (66, 8) | 528 | sub-1 KB |
| (64, 16) | 1024 | depth-16, CACTI fails on nangate45 / sky130hd |
| (256, 16) | 4096 | depth-16, CACTI fails on nangate45 / sky130hd |
| (272, 16) | 4352 | depth-16, CACTI fails on nangate45 / sky130hd |

The FF stubs are emitted by `designs/src/NVDLA/dev/gen_ff_rams.py` into `designs/src/NVDLA/dev/generated/sram_ff/fakeram_<W>x<D>_1r1w.v` and included in the `:rtl` filegroup. Pin names mirror bsg_fakeram's `1r1w` convention (`r0_*` / `w0_*`) so the existing `designs/src/NVDLA/macros.v` wrappers don't change.

### Per-partition filegroups (after regen)

| Partition | Macros | FF instances (via the .v stubs) |
|---|---|---|
| a | – | 256x16, 272x16 |
| c | 64x256, 11x128 | 64x16, 6x128, 66x8 |
| m | – | – |
| o | 18x128, 8x256, 4x256, 7x256, 66x64, 15x80, 22x60, 32x128 | 9x80 |
| p | 16x160, 65x160, 14x80, 66x80 | – |

## asap7

**Status**: partitions `a`, `m`, `o` cached on remote build cache; partition `c` finishing locally (local sweep `6_final`, 2026-05-16); partition `p` not yet finishing.

### 2026-06 toolchain upgrade (bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64)
- **partition_a**: builds unchanged — WNS +344.8 ps on the 1500 ps clock, util 62.0 %, 62 350 logic cells. No change needed.
- **partition_o**: the new global router tipped util 45 into a GRT-0116 congestion failure at detailed route. Relaxed `CORE_UTILIZATION` 45→40 (flow knob): routes clean, WNS +74.3 ps, util 42.5 %, 241 685 logic cells, +die area only.
- **partition_m**: hit the new-OpenSTA `write_sdc` bug — expanding `set_false_path -to [get_pin */SETN|/RESETN]` emits corrupted (invalid-UTF8) instance names into `1_synth.sdc`, which Tcl 9 rejects at floorplan. Removed those two redundant async-set/reset false-paths (reset sources are already `-from` false-pathed and the reset nets are `set_ideal_network`) on **both asap7 and sky130hd**; the new flow then closes clean — asap7 WNS +503 ps @1500 ps (util 56.8 %, 19 667 cells), sky130hd WNS +3324 ps (util 58.1 %, 11 022 cells). Timing healthy; the dropped false-paths carried no real timed path.
- **partition_c** (asap7 + nangate45): same `write_sdc` SDC fix applied (the `*/SETN|/RESETN` removal). Both reach `_final` — asap7 WNS **−1245 → −183 ps** (improved; still setup-negative, util 30.6 %, 268 324 cells), nangate45 WNS +802 ps (util 30.8 %, 250 898 cells). No multibyte/floorplan failure after the fix. (sky130hd partition_c still does not finish — the documented GP plateau below.)

## nangate45

**Status**: partitions `a`, `m`, `o`, `p` all reach `_final`; partition `c` finishing locally.

### 2026-06 toolchain upgrade (bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64)
- **partition_a / _o / _p**: build unchanged, all close clean — `a` WNS +1525 ps (util 42.7 %, 53 030 cells), `o` WNS +1125 ps (util 36.0 %, 189 268 cells, Fmax 1.58 — multi-clock), `p` WNS +896 ps (util 35.6 %, 67 284 cells). No GRT congestion on nangate45 (unlike asap7 partition_o).
- **partition_m**: same OpenSTA `write_sdc` workaround (removed the `*/SETN|/RESETN` async false-paths) — closes WNS +1838 ps, util 50.7 %, 13 053 cells. (asap7 `partition_p` also passes here: WNS +62.8 ps, util 46.8 %, 98 602 cells.)

## sky130hd

**Status**: partitions `a`, `m`, `o`, `p` cached on remote build cache; **partition `c` finishing** (clean `_final`, 0 DRC, 2026-07-02, see below).

### 2026-06 toolchain upgrade (bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64)
- **partition_a / _o / _p**: build unchanged, all close clean — `a` WNS +4209 ps (util 48.5 %, 35 825 cells), `o` WNS +975 ps (util 23.8 %, 185 458 cells), `p` WNS +575 ps (util 31.1 %, 64 868 cells). No GRT congestion (unlike asap7 partition_o).
- **partition_m**: same OpenSTA `write_sdc` workaround as asap7 (removed the redundant `*/SETN|/RESETN` async false-paths) — closes at WNS +3324 ps, util 58.1 %, 11 022 cells.

### partition_c: GP plateau fixed + GRT-0183 fixed + DRC clean (2026-07-02)
- **GP plateau** (overflow ~0.31, target 0.10): fixed by hand-placed macro grid via `MACRO_PLACEMENT_TCL` — 8 columns, alternating R0/MX rows, gap-x 900 µm, cold channel 300 µm (R0→MX), hot channel 550 µm (MX→R0), fakeram_11x128 aside in left corridor (`tools/gen_macro_grid.py`). Alternating R0/MX is load-bearing — an all-R0 uniform-spacing control build exhausted the 64-iteration DRT budget with residual violations while alternating converged cleanly. gap-x 900 µm is required at macro corners: `nv_ram_rws_16x64` (16-deep, below CACTI floor) has no fakeram LEF — yosys synthesizes all 16 instances as FF arrays, RTLMP packs them into inter-column gaps adjacent to their functionally related macro corners, and the router runs out of tracks where horizontal and vertical routing pressure converge.
- **GRT-0183** (`repair_antennas` heap underflow, triggered by sky130hd's high antenna count): fixed by `patches/openroad-grt-0183-fix.patch` (upstream PR #10743, merged 2026-06-24 — remove once OR pin advances past that date).
- **SDC fix**: replaced `set_false_path -to [get_pin */RESETN|/SETN]` (asap7 pin names, silent no-ops on sky130hd) with port-level `-from` false-paths; added `set_ideal_network [get_nets {nvdla_core_rstn}]`.
- WNS +0.03 ns, Fmax **66.80 MHz** (`period_min` 14.97 ns vs 15 ns), 0 DRC violations, `CORE_UTILIZATION` 25, `PLACE_DENSITY` 0.20, ~265 k logic cells, core 128.9 mm².
