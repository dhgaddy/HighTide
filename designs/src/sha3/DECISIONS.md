# sha3 Design Decisions

Per-platform notes on tuning, workarounds, and platform-specific quirks for `sha3` (SHA3 hash engine, Verilog).  See `CLAUDE.md` (root) for the canonical upstream-bug index.

Mid-size combinational-heavy core (~20k stdcells, no macros).

## asap7

**Status**: finishing
**Last updated**: 2026-03-19 (commit `187ef139`)

### Configuration
- `CORE_UTILIZATION = 70` — combinational logic packs tight
- `PLACE_DENSITY = 0.75`
- Clock: `1000 ps` (Fmax ~1 GHz)

### Decisions
- None recorded — initial port closed at these values.

### Known issues / open questions
- None.

## nangate45

**Status**: finishing
**Last updated**: 2026-03-21 (commit `205e9ff0`)

### Configuration
- `CORE_UTILIZATION = 45`
- `PLACE_DENSITY_LB_ADDON = 0.20`
- Clock: `2.5 ns` (Fmax ~400 MHz)

### Decisions
- None recorded.

### Known issues / open questions
- None.

## sky130hd

**Status**: finishing
**Last updated**: 2026-04-25 (commit `caba4c83`)

### Configuration
- `CORE_UTILIZATION = 25` — sky130hd's coarse pitches force a much lower util than asap7/nangate45 to avoid routing congestion
- `PLACE_DENSITY_LB_ADDON = 0.20`
- Clock: `10 ns` (Fmax ~100 MHz)

### Decisions
- None recorded.

### Known issues / open questions
- None.
