# coralnpu Design Decisions

Per-platform notes on tuning, workarounds, and platform-specific quirks for `coralnpu` (Google CoreMiniAxi NPU).  See `CLAUDE.md` (root) for the canonical upstream-bug index.

Mid-large NPU with several FakeRAM macros.  Hierarchical synthesis required for tractable build times.

## Common to all platforms

- `SYNTH_HIERARCHICAL = 1` — flat synthesis runs out of memory / time on this design's hierarchy.
- `TNS_END_PERCENT = 100` — repair every violator (target Fmax is loose enough that this converges).

## asap7

**Status**: finishing
**Last updated**: 2026-04-26 (commit `643ba623`)

### Configuration
- `CORE_UTILIZATION = 40`
- `PLACE_DENSITY_LB_ADDON = 0.20`
- `MACRO_PLACE_HALO = "6 6"` — small halo since asap7 cells are physically tiny
- Clock: `3000 ps` (Fmax ~333 MHz)

### Decisions
- **2026-04-26 `643ba623`**: initial close.  Halo 6×6 chosen to keep std cells out of macro shadow but avoid wasting die area.

### Known issues / open questions
- None.

## nangate45

**Status**: finishing
**Last updated**: 2026-04-26 (commit `643ba623`)

### Configuration
- `CORE_UTILIZATION = 40`
- `PLACE_DENSITY_LB_ADDON = 0.20`
- `MACRO_PLACE_HALO = "40 40"` — much larger than asap7 because nangate45's cells are ~10× wider, so the equivalent stdcell-rows-of-clearance value scales up
- Clock: `9 ns` (Fmax ~111 MHz)

### Decisions
- **2026-04-26 `643ba623`**: halo bumped to 40×40 (vs asap7's 6×6) — same number of stdcell tracks of macro clearance, just expressed in micrometers at nangate45's pitch.

### Known issues / open questions
- None.

## sky130hd

**Status**: finishing
**Last updated**: 2026-04-26 (commit `6d6f2dc2`)

### Configuration
- `CORE_UTILIZATION = 20` — much lower than asap7/nangate45; sky130hd's coarse pitches plus this design's macro count create heavy local-density hot spots
- `PLACE_DENSITY = 0.15` — explicit (not addon)
- `MACRO_PLACE_HALO = "30 30"`
- Clock: `30 ns` (Fmax ~33 MHz)

### Decisions
- **2026-04-26 `6d6f2dc2`**: util dropped to 20%, density set explicitly to 0.15 to relieve sky130hd routing congestion on this macro-heavy NPU.

### Known issues / open questions
- None.
