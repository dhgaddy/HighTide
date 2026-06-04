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
