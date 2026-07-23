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

### 2026-07 re-validation (bazel-orfs 6c1bbca / OpenROAD b65c274c)
- **partition_o**: **finishes** on the newer pin (k8s, verified 2026-07-15). Detail route is *very* slow on this pin — ~10 h wall (single 5_route action), with the post-route antenna-repair pass converging 5391→23 violations — but it reaches `_final` cleanly. An earlier upgrade note had flagged partition_o-sky130hd as a "detail-route congestion" non-finisher; that was **wrong** — it is slow, not blocked. (Fresh QoR not re-captured locally: its stage ODBs are large and a local re-run would repeat the ~10 h route; `results.html` carries the 26Q3 QoR for this row with a note.)

### partition_c: GP plateau fixed + GRT-0183 fixed + DRC clean (2026-07-02)
- **GP plateau** (overflow ~0.31, target 0.10): fixed by hand-placed macro grid via `MACRO_PLACEMENT_TCL` — 8 columns, alternating R0/MX rows, gap-x 900 µm, cold channel 300 µm (R0→MX), hot channel 550 µm (MX→R0), fakeram_11x128 aside in left corridor (`tools/gen_macro_grid.py`). Alternating R0/MX is load-bearing — an all-R0 uniform-spacing control build exhausted the 64-iteration DRT budget with residual violations while alternating converged cleanly. gap-x 900 µm is required at macro corners: `nv_ram_rws_16x64` (16-deep, below CACTI floor) has no fakeram LEF — yosys synthesizes all 16 instances as FF arrays, RTLMP packs them into inter-column gaps adjacent to their functionally related macro corners, and the router runs out of tracks where horizontal and vertical routing pressure converge.
- **GRT-0183** (`repair_antennas` heap underflow, triggered by sky130hd's high antenna count): fixed by `patches/openroad-grt-0183-fix.patch` (upstream PR #10743, merged 2026-06-24 — remove once OR pin advances past that date).
- **SDC fix**: replaced `set_false_path -to [get_pin */RESETN|/SETN]` (asap7 pin names, silent no-ops on sky130hd) with port-level `-from` false-paths; added `set_ideal_network [get_nets {nvdla_core_rstn}]`.
- WNS +0.03 ns, Fmax **66.80 MHz** (`period_min` 14.97 ns vs 15 ns), 0 DRC violations, `CORE_UTILIZATION` 25, `PLACE_DENSITY` 0.20, ~265 k logic cells, core 128.9 mm².

## gt2n

**Status**: partitions `a`, `m`, `o`, and `p` reach `_final` cleanly; `c` not yet ported.

### 2026-07-15 initial port

- **partition_m**: no macros, clock 1300 ps. Closes clean: WNS +320.35 ps, util 53 %, 30 669 logic cells.

### 2026-07-16 partition_p (first gt2n macro-bearing NVDLA partition)

- **partition_p**: 6 macros (`16x160`, `65x160`, `14x80`, `66x80`) — no gt2n FakeRAM macros existed for NVDLA prior to this; generated fresh via a new `fakeram_gt2n.cfg`. Fixed a real bug found in `cnn`'s existing gt2n cfg while writing this one: `bsg_fakeram`'s `class_process.py` only reads `snapWidth_nm`/`snapHeight_nm` (camelCase) — `cnn`'s cfg used `snap_width_nm`/`snap_height_nm` (snake_case), silently falling back to a 1 nm grid. Fixed here and backported to `cnn`'s cfg. Also found the same key-mismatch bug on **every asap7 fakeram cfg in the repo** (see `CLAUDE.md` bug table) — not yet fixed/regenerated there. Closes clean: setup WNS +27.46 ps, hold WNS +0.80 ps, util 42 %, 115 375 logic cells.

### 2026-07-19 partition_o (multi-clock, largest gt2n NVDLA partition)

- **partition_o**: 8 macros (`18x128`, `8x256`, `4x256`, `7x256`, `66x64`, `15x80`, `22x60`, `32x128`). The only multi-clock partition (`nvdla_core_clk` + `nvdla_falcon_clk`, ratio held at the NVIDIA reference 1.25). `CORE_UTILIZATION=35` — 37 hit GRT-0232 routing congestion. Found and fixed a potential OpenROAD bug (DRT-0406): `dbBlock::getGCellTileSize()` sizes the global-routing GCell tile from just the median M2/M3/M4 pitch, independent of which layers are actually enabled — gt2n's top routing layer is ~30x coarser than M2, so the resulting tile is smaller than the top layer's own pitch and track assignment hard-fails. Fixed via `patches/openroad-gcell-tile-size-fix.patch`. Also tested `MIN_CLK_ROUTING_LAYER` M6/M10/M4/M2 to close timing — non-monotonic, M4 best. Closes clean: WNS +3.14 ps, util 37 %, 348 194 logic cells.

### 2026-07-20 partition_a

- **partition_a**: no macros (like partition_m) — both SRAMs (256x16, 272x16) are FF arrays. Clock 1097 ps. Closes clean: setup WNS +3.23 ps, hold WNS +1.16 ps, util 45 %, 98 138 logic cells, period_min 1093.77 ps.

### 2026-07-22 partition_p: hold closure after SRAM bitcell correction

- **partition_p**: a gt2n fakeram SRAM bitcell correction enlarged this design's 6 macros ~2.5x, raising clock skew to ~157 ps; `HOLD_SLACK_MARGIN` alone (up to 100) could not converge. Root cause: the 2 residual violators, `u_reg.req_pd[1]` and `u_wdma.u_dmaif_wr.mc_dma_wr_rsp_complete`, are zero-logic passthroughs of primary inputs (`csb2sdp_req_pd` from `csb_master`, `mcif2sdp_wr_rsp_complete` from the MCIF) — sibling-partition signals with no on-chip source register in this standalone build, so the blanket `set_input_delay` under-budgets their minimum arrival. Fixed with two scoped `-min` overrides (`-max`/setup untouched), each sized as blanket 286.6 ps + measured deficit × 1.3: `-min 341` on `csb2sdp_req_pd*`, `-min 311` on `mcif2sdp_wr_rsp_complete*`. Closes clean: setup WNS +2.51 ps, hold WNS +5.38 ps, util 43 %, 136 834 logic cells, `HOLD_SLACK_MARGIN=50`.
