# bp_processor Design Decisions

Per-platform notes for Black-Parrot, an open-source RISC-V multicore from the BSG group at UW.

| Variant | Description |
|---|---|
| `bp_uno` | Single-core BP (`e_bp_unicore_cfg`) — minimal config for first-bring-up. |
| `bp_quad` | Four-core multicore (`e_bp_multicore_4_cfg`) — exercises the on-chip mesh + LLC + coherency. |

FakeRAM macros live at `designs/<platform>/bp_processor/sram/{lef,lib}/`. The wrapper `designs/<platform>/bp_processor/macros.v` swaps `bsg_mem_*_synth` instances for hard macros above a 1024-bit threshold and lets the rest synthesize as FF arrays.

## FakeRAM regeneration (2026-05-13)

- **Generator**: `bsg_fakeram` (VLSIDA fork @ `asap7-area-calib-v2`, with `write_granularity: 1` enabled for per-bit write masks). Run via `tools/regenerate_sram.sh bp_processor <platform>`.
- **Cfg**: `designs/src/bp_processor/dev/generated/fakeram_{asap7,nangate45,sky130hd}.cfg` — 6 macros each, `1rw + per-bit wmask`.
- **Macros.v generator**: `designs/src/bp_processor/dev/gen_macros_v.py` produces `designs/{asap7,nangate45,sky130hd}/bp_processor/macros.v` with bsg_fakeram's port-index pin names (`rw0_clk`, `rw0_ce_in`, `rw0_we_in`, `rw0_wmask_in`, `rw0_addr_in`, `rw0_wd_in`, `rw0_rd_out`).
- **Prior generator**: in-repo `designs/src/bp_processor/dev/gen_fakeram.py` (area_per_bit heuristic + macros.v emission, now deleted).

### Macro vs FF fallback

The original 8-size LARGE_CONFIGS list shrinks to 6; two sizes become FF arrays via the `else begin : nz` branch of `macros.v`:

| (D, W) | Bits | Status | Reason |
|---|---:|---|---|
| 512x64 | 32 768 | macro | |
| 64x184 | 11 776 | macro | |
| 512x8 | 4 096 | macro | |
| 64x50 | 3 200 | macro | |
| **32x66** | 2 112 | **FF** | depth-32 fails CACTI on nangate45 (the +8-bit retry can't recover) |
| 32x48 | 1 536 | macro | |
| **8x174** | 1 392 | **FF** | depth-8 fails CACTI on nangate45 |
| 128x8 | 1 024 | macro | |

Per-bit write masking is necessary for the `bsg_mem_1rw_sync_mask_write_bit_synth` flavour — bp_processor passes `w_mask_i[width_p-1:0]` straight through to `rw0_wmask_in`. The bsg_fakeram fork patch (`write_granularity: 1`) is what makes that legal LEF/LIB/.v emission.

## sky130hd port — bp_uno (2026-05-26)

| Knob | Value | Notes |
|---|---|---|
| `DIE_AREA` / `CORE_AREA` | `0 0 8000 8000` / `20 20 7980 7980` | Fixed, not `CORE_UTILIZATION` — the auto-sized 5887 µm core can't host the macro grid (needs ~7600 µm y for 10 rows + channels). |
| `PLACE_DENSITY_LB_ADDON` | `0.10` | Std-cell utilization ends at 18.6% — plenty of room for routing. |
| `clk_period` | 36 ns | 3.6× nangate45's 9 ns, in line with the litedram nangate45→sky130hd ratio. Closes at +4.4 ns WNS. |
| `MACRO_PLACEMENT_TCL` | `macro_placement.tcl` (140 macros, R0, FIRM) | RTLMP's pin-edge-blind clustering of the 64 icache/dcache `data_mems[*]` collided their met2 escape lanes → unroutable congestion (`GRT-0116` at halo=60, then `GRT-0229` overflow saturation at halo=80). Same failure shape as cnn-sky130hd / NVDLA partition_c. |

### Macro grid regeneration

Dump the 140 macro instances from a freshly-floorplanned ODB, then run the grid generator:

```bash
bazel build //designs/sky130hd/bp_processor/bp_uno:bp_processor_floorplan
$OPENROAD -no_init tools/dump_macros.tcl >| \
    designs/src/bp_processor/dev/generated/bp_uno_sky130hd_macros.txt
python3 tools/gen_macro_grid.py \
    designs/src/bp_processor/dev/generated/bp_uno_sky130hd_macros.txt \
    designs/sky130hd/bp_processor/bp_uno/macro_placement.tcl \
    --gap-x 250 --chan 450
```

`--chan 450` mirrors NVDLA partition_c — gives every macro's bottom met2 pin edge a routing channel south of the row. `--gap-x 250` keeps adjacent macros' pin escape from colliding. The script sets every macro to R0 + FIRM at the end, so the post-source `rtl_macro_placer` leaves them alone.

### QoR (cached locally — see CLAUDE.md Cloudflare 100 MB note)

| Metric | Value |
|---|---|
| Setup WNS / TNS | +4.375 ns / 0 |
| Hold WNS / TNS | +0.129 ns / 0 |
| Route DRC | 0 |
| Sequential cells | 39 641 |
| Combinational cells | 248 260 |
| Inverters | 35 155 |
| Clock buffers | 8 538 |
| Timing-repair buffers | 28 111 |
| Total power | 0.294 W |
| Core utilization | 18.6 % |

`6_final.odb` is ~2.9 GB — far past the Cloudflare-tunnel 100 MB ceiling, so the remote cache reports `NOT CACHED`. Build locally to populate `~/.cache/bazel-disk-cache`; the local-build list in CLAUDE.md tracks this.

## 2026-06 toolchain upgrade (bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64) — bp_uno

- **nangate45**: clean pass, no change — WNS +1963 → **+1943 ps**, util 15.9 %, 439 607 logic
  cells (≈ baseline 439 722), Fmax 0.19 → 0.20 GHz. Workarounds kept.
- **asap7**: **flagged regression.** WNS +78 → −459 ps (Fmax 0.31 → 0.26, −16 %), 452 k cells
  (−2 %). Re-enabling repair (removing `SKIP_INCREMENTAL_REPAIR`) was tried and converged
  without the old hang, but gave the same −467 ps — the slowdown is netlist/placement-bound
  on the new RTLMP/router, not repair-fixable (same class as cnn-asap7). Original config
  (skip kept) restored; not recoverable via flow knobs without RTL/SDC changes.
- **sky130hd**: clean pass on the new tools — WNS **+4.14 ns** (≈ the +4.4 ns baseline), util
  18.6 %, 367 437 logic cells, 140 macros. 7.6 M-cell-class / local-only (over the Cloudflare
  ceiling); built + cached locally. Workarounds (MACRO_PLACEMENT_TCL hand-grid, repair skip) kept.
