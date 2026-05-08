# lfsr Design Decisions

Per-platform notes on tuning, workarounds, and platform-specific quirks for `lfsr` (LFSR / PRBS generator, top-level module `lfsr_prbs_gen`).  See `CLAUDE.md` (root) for the canonical upstream-bug index.

This is a small std-cell-only design (~200 cells, no macros) used as a smoke test for the flow on every platform.

## asap7

**Status**: closing
**Last updated**: 2026-05-01 (commit `6511fb56`)

### Configuration
- `CORE_UTILIZATION = 55` — std-cell-only, fits comfortably tight
- `TNS_END_PERCENT = 100` — repair every violator (small design, cheap to fix all)
- Clock: `700 ps` (Fmax ~1.43 GHz)

### Decisions
- **2026-05-01 `6511fb56`**: clock relaxed from 200 ps → 700 ps in PR #109 to match achievable Fmax — at the prior aggressive target the resizer inserted dozens of buffers chasing an unreachable bound.

### Known issues / open questions
- None.

## nangate45

**Status**: closing
**Last updated**: 2026-03-21 (commit `fb6ec1d4`)

### Configuration
- `CORE_UTILIZATION = 20` — design is so small (~200 cells) that lower util just gives breathing room for IO placement
- `PLACE_DENSITY_LB_ADDON = 0.20`
- `TNS_END_PERCENT = 100`
- Clock: `0.46 ns` (Fmax ~2.17 GHz)

### Decisions
- None recorded — initial port closed cleanly with these values.

### Known issues / open questions
- None.

## sky130hd

**Status**: closing
**Last updated**: 2026-05-01 (commit `6511fb56`)

### Configuration
- `CORE_UTILIZATION = 40`
- `TNS_END_PERCENT = 100`
- Clock: `1.4 ns` (Fmax ~715 MHz)

### Decisions
- **2026-05-01 `6511fb56`**: clock relaxed in PR #109 (same shape as asap7) to match achievable Fmax on sky130hd's coarser cells.

### Known issues / open questions
- None.
