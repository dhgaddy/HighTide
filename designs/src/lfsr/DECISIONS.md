# lfsr Design Decisions

Per-platform notes on tuning, workarounds, and platform-specific quirks for `lfsr` (LFSR / PRBS generator, top-level module `lfsr_prbs_gen`).  See `CLAUDE.md` (root) for the canonical upstream-bug index.

This is a small std-cell-only design (~200 cells, no macros) used as a smoke test for the flow on every platform.

## asap7

**Status**: finishing
**Last updated**: 2026-05-01 (commit `6511fb56`)

### Configuration
- `CORE_UTILIZATION = 55` — std-cell-only, fits comfortably tight
- `TNS_END_PERCENT = 100` — repair every violator (small design, cheap to fix all)
- Clock: `700 ps` (Fmax ~1.43 GHz)

### Decisions
- **2026-05-01 `6511fb56`**: clock relaxed from 200 ps → 700 ps in PR #109 to match achievable Fmax — at the prior aggressive target the resizer inserted dozens of buffers chasing an unreachable bound.
- **2026-06-04**: validated on the bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64 upgrade. QoR essentially unchanged (WNS 12.38 → 13.22 ps, Fmax 1.45 → 1.46 GHz, 154 cells). No workarounds; no changes needed.

### Known issues / open questions
- None.

## nangate45

**Status**: finishing
**Last updated**: 2026-03-21 (commit `fb6ec1d4`)

### Configuration
- `CORE_UTILIZATION = 20` — design is so small (~200 cells) that lower util just gives breathing room for IO placement
- `PLACE_DENSITY_LB_ADDON = 0.20`
- `TNS_END_PERCENT = 100`
- Clock: `0.46 ns` (Fmax ~2.17 GHz)

### Decisions
- None recorded — initial port closed cleanly with these values.
- **2026-06-04**: validated on the bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64 upgrade. QoR within tolerance (WNS 127.61 → 125.49 ps, Fmax 3.01 → 2.99 GHz, 121 → 126 cells). No changes needed.

### Known issues / open questions
- None.

## sky130hd

**Status**: finishing
**Last updated**: 2026-05-01 (commit `6511fb56`)

### Configuration
- `CORE_UTILIZATION = 40`
- `TNS_END_PERCENT = 100`
- Clock: `1.4 ns` (Fmax ~715 MHz)

### Decisions
- **2026-05-01 `6511fb56`**: clock relaxed in PR #109 (same shape as asap7) to match achievable Fmax on sky130hd's coarser cells.
- **2026-06-04**: validated on the bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64 upgrade. QoR within tolerance (WNS 10.95 → 22.01 ps, Fmax 0.72 → 0.73 GHz, 139 → 135 cells). No changes needed.

### Known issues / open questions
- None.

## gt2n

**Status**: finishing
**Last updated**: 2026-07-07

### Configuration
- `CORE_UTILIZATION = 25` — lower than asap7's 55%; gt2n's M2/M3 pitches (24/28 nm) are ~2.3× tighter than asap7 so equivalent cell count needs more routing headroom
- `MAX_ROUTING_LAYER = M5` — small ~200-cell design; M5 provides adequate routing capacity without opening unnecessary higher layers
- `TNS_END_PERCENT = 100`
- Clock: `500 ps` (period_min 230.14 ps; ratio 2.17 — timing tightening to ~253 ps = 230 × 1.10 is deferred; initial platform porting is separate from the HighTide tightening loop)

### Decisions
- **2026-07-07 (platform bringup)**: lfsr was the first gt2n design ported; four infrastructure changes were required before any gt2n build could complete, and apply to every subsequent gt2n design:
  - **ORFS pin bump** (`d90873f4` → `c06bf3c2`, the June 16 gt2n merge commit): gt2n PDK support was not yet in the pinned ORFS commit — bumping brought in the platform files.
  - **`orfs-gt2n-build.patch`**: ORFS `flow/BUILD` registers PDK targets via a list comprehension that omitted gt2n. Patch adds gt2n so Bazel can resolve `//platforms/gt2n` targets.
  - **`orfs-gt2n-spef.patch`**: gt2n has no OpenRCX rules file (`rcx_patterns.rules`) so ORFS never writes a SPEF. Bazel's declared-output contract requires `6_final.spef` to exist; without it the build fails with a missing-output error at finish. Patch adds an `else` branch to `final_report.tcl` that writes an empty SPEF when `OPENRCX_RULES` is unset.
  - **OpenROAD local pin bump** (to latest HEAD): DRT crashed with SIGSEGV (Signal 11) during track assignment on backside layers in the then-pinned OpenROAD commit. Bumping to HEAD resolved the crash.
- **2026-07-07 (lfsr-specific)**: with platform bringup complete, lfsr closes cleanly. WNS = 0, 0 DRC violations. `CORE_UTILIZATION = 25` chosen to give the router adequate channel capacity — the ~200-cell design packs at 25% without waste. `MAX_ROUTING_LAYER = M5` adds two routing planes beyond M3/M4, which alone are insufficient even for a small design at gt2n's tight pitches.
- **No antenna cells**: gt2n PDK ships no antenna filler cells. GRT-0246 ("no antenna cell found in the design library") fires on every gt2n build — benign; the router uses wire-jumping to resolve antenna violations, reaching 0 antenna DRC violations in the final report.
- **Backside PDN**: gt2n uses BSPDN (BPR followpins → BM1 → BM2 stripes, entirely on the backside stack). Signal layers M1–M13 carry no power. No `pdn.tcl` override is needed for std-cell-only designs — `platforms/gt2n/pdn.cfg` handles BSPDN correctly out of the box.

### Known issues / open questions
- Clock tightening not yet done (period_min 230.14 ps vs 500 ps target; ratio 2.17 is well above the [1.05, 1.15] convergence window). Next target: 253 ps (= 230.14 × 1.10).
