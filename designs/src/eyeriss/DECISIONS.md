# eyeriss Design Decisions

Per-platform notes for the `eyeriss` design (Eyeriss-v2 CNN accelerator, top `TOP`).
See `CLAUDE.md` (root) for the canonical upstream-bug index.

Macro-heavy (GLB iact/Psum SRAM spads). Uses RTLMP for macro placement.

## Active workarounds (all platforms)

- **`SKIP_INCREMENTAL_REPAIR` + `SKIP_LAST_GASP`** — post-GRT `repair_timing` makes only
  ~5 ps/iteration progress on the Psum spad/SRAM write paths and never converges in
  reasonable time. These are **convergence pragmatics, not a fixed-bug workaround**, so they
  are kept after the 2026-06 upgrade.
- ~~`SETUP_MOVE_SEQUENCE` (split_load-drop, ODB-1200)~~ **removed 2026-06-04** — ODB-1200 is
  fixed in OpenROAD 299f3015; the default move sequence is restored and CTS repair runs clean.

## 2026-06 toolchain upgrade (bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64)

- **nangate45**: builds unchanged (minus the removed SETUP_MOVE_SEQUENCE) — WNS +340.8 →
  +133.4 ps (still positive), util 38.5 %, 307 701 logic cells (≈ baseline 307 085), Fmax
  0.24 → 0.23 GHz. Pass.
- **sky130hd**: WNS ≈ +1.9 ns (positive), 221 703 logic cells (≈ baseline 222 731). Pass.
- **asap7**: the new RTLMP fails **MPL-0040** annealing on `ClusterGroup_array.ClusterGroup_0_1`
  at util 40 (where the old RTLMP succeeded). Lowered `CORE_UTILIZATION` 40 → 30 to enlarge
  each cluster's macro sub-region so annealing converges (flow knob; costs die area). See the
  asap7 section for the result.

## asap7

**Status**: finishing — util 40→30 clears the new-RTLMP MPL-0040; WNS +122.5 ps, util 30.8 %, 301 586 logic cells, Fmax 0.42 GHz. Die area grew (the util drop) but the design now floorplans and routes to `6_final`.

## nangate45

**Status**: finishing — WNS +133.4 ps, util 38.5 %, 307 701 cells.

## sky130hd

**Status**: finishing — WNS ≈ +1.9 ns, 221 703 cells.
