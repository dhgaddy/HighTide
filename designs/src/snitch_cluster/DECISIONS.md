# snitch_cluster Design Decisions

Per-platform notes for `snitch_cluster` (PULP Snitch multi-core cluster, top
`snitch_cluster_wrapper`). See `CLAUDE.md` (root) for the canonical upstream-bug index.

Very large logic design (~1.5M std cells), no hard macros on asap7 beyond the 38 the
wrapper instantiates. Carries `SKIP_CTS_REPAIR_TIMING` + `SKIP_INCREMENTAL_REPAIR`
(repair non-convergence on the RTL-bounded endpoints) and, on asap7, a DPL-0036
`PRE_CTS_TCL`. Only asap7 / nangate45 are in scope (no sky130hd port).

## asap7

**Status**: finishing on bazel-orfs 553c1c3.

- **2026-06 toolchain upgrade (bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64)**:
  closes clean — WNS +407 → **+387 ps** (−5 %, within tolerance), util 16.0 %, 1 537 838
  logic cells (≈ baseline 1 530 612, +0.5 %), Fmax 0.18 GHz unchanged. The 1.5M-cell global
  placement is very slow (several hours under shared-machine contention) but converges
  (overflow 0.63 → <0.10). Workarounds kept. No SDC/RTL/flow change.

## nangate45

**Status**: **flagged — global-placement hang on bazel-orfs 553c1c3.**

- **2026-06 toolchain upgrade**: synth + floorplan complete, but the new OpenROAD global
  placer **hangs** on the 1.5M-cell nangate45 design — it ran ~8 h, dropped to 0 % CPU at
  ~iter 472 / overflow 0.63 (deadlocked, no further progress), and was killed. asap7 (same
  RTL) converges, so this is nangate45-specific GP behaviour under the new GPL. Needs GP
  parameter work (e.g. `GPL_*` density/routability settings) or an upstream fix; out of
  scope for the flow-knob upgrade. Stops at `2_floorplan`.
