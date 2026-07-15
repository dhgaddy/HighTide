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

- **2026-07 re-validation (bazel-orfs 6c1bbca / OpenROAD b65c274c)**: **PASS** — 1 538 886
  logic cells (+0.1 %), WNS **+253 ps** (met; base +387), Fmax 0.174 GHz (−3.3 %, within
  tolerance), power 1033 mW. Very slow on the new resizer: detail route needed 5 ripup-reroute
  optimization passes (337 k → 53 k → 30 k → 973 → 41 → 0 violations) and the report/STA
  stage took ~3 h; the whole flow ~16 h and briefly overran a 16 h wall-clock cap mid-report
  (re-run from the cached route to finish). Workarounds kept, no SDC/RTL/flow change.

## nangate45

**Status**: **PASS on bazel-orfs 6c1bbca / OpenROAD b65c274c** (the 553c1c3 GP hang is resolved).

- **2026-06 toolchain upgrade (bazel-orfs 553c1c3)**: synth + floorplan complete, but the
  OpenROAD global placer **hung** on the 1.5M-cell nangate45 design — ran ~8 h, dropped to
  0 % CPU at ~iter 472 / overflow 0.63 (deadlocked), killed. Stopped at `2_floorplan`.
- **2026-07 re-validation (bazel-orfs 6c1bbca / OpenROAD b65c274c)**: **PASS** — the newer
  OpenROAD no longer hangs; global placement converges (overflow → <0.10) though it is slow:
  the new timing-driven `place_gp` runs **two** timing-driven iterations, each a full
  `repair_design` over ~1.3M nets (~295 k nets/hr), so placement alone took ~8 h and the whole
  flow ~14 h. Detail route converged cleanly (0 violations in 4 passes). Result: 1 333 473
  logic cells (+2.1 %), WNS **+5801 ps** (met; base +6035), Fmax 0.082 GHz (+2.5 %),
  power 368 mW. No SDC/RTL/flow change.
