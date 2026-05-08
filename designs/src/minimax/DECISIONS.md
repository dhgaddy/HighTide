# minimax Design Decisions

Per-platform notes on tuning, workarounds, and platform-specific quirks for `minimax` (RV32I core, SystemVerilog → sv2v).  See `CLAUDE.md` (root) for the canonical upstream-bug index.

A small RISC-V core (~10–20k stdcells, no macros).  Used as a real-RTL smoke test on every platform.

## asap7

**Status**: closing
**Last updated**: 2026-05-01 (commit `49c7aee5`)

### Configuration
- `CORE_UTILIZATION = 65` — packs std cells tight; design fits at higher util than typical for asap7
- `PLACE_DENSITY = 0.7`
- `CORE_ASPECT_RATIO = 1.0`, `CORE_MARGIN = 4`
- Clock: `900 ps` (Fmax ~1.11 GHz, WNS +4.8 ps)

### Decisions
- **2026-05-01 `49c7aee5`**: clock relaxed from 400 ps → 900 ps in PR #108.  Old 400 ps was ~50% of the design's actual capability; period_min after FP was ~750 ps and the resizer chased 2000+ violators on every build.  900 ps (vs naive 800 ps) chosen because synthesis becomes less aggressive at relaxed targets, drifting period_min upward — 900 ps is the first round number that closes cleanly.

### Known issues / open questions
- None.

## nangate45

**Status**: closing
**Last updated**: 2026-05-01 (commit `49c7aee5`)

### Configuration
- `CORE_UTILIZATION = 60`
- `PLACE_DENSITY = 0.7`
- `CORE_ASPECT_RATIO = 1.0`, `CORE_MARGIN = 6`
- Clock: `1.6 ns` (Fmax ~629 MHz, WNS +9.9 ps)

### Decisions
- **2026-05-01 `49c7aee5`**: clock relaxed from 0.8 ns → 1.6 ns in PR #108.  Same shape as asap7 — original constraint was ~50% of achievable Fmax.

### Known issues / open questions
- None.

## sky130hd

**Status**: closing
**Last updated**: 2026-05-01 (commit `49c7aee5`)

### Configuration
- `CORE_UTILIZATION = 40`
- `PLACE_DENSITY = 0.6`
- `CORE_ASPECT_RATIO = 1.0`, `CORE_MARGIN = 12`
- Clock: `8 ns` (Fmax ~130 MHz, WNS +310 ps)

### Decisions
- **2026-05-01 `49c7aee5`**: clock relaxed from 4 ns → 8 ns in PR #108.  sky130hd's coarse pitches and slower std cells push period_min above the original target by ~2×.

### Known issues / open questions
- None.
