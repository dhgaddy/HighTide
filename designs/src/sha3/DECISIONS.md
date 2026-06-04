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
- **2026-06-04**: validated on the bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64 upgrade. Closes clean: WNS +136 ps on the 1000 ps clock (Fmax 1.16 GHz), util 72.5%, 18245 logic cells. No change needed.

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
- **2026-06-04**: validated on the bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64 upgrade. Closes clean: WNS +487 ps on the 2.5 ns clock, util 45.4%, 20181 logic cells. No change needed.

### Known issues / open questions
- None.

## sky130hd

**Status**: finishing
**Last updated**: 2026-05-18 (PPA optimization)

### Configuration
- `CORE_UTILIZATION = 35`, `PLACE_DENSITY = 0.42`, `TNS_END_PERCENT = 100`
- Clock: `10 ns` (Fmax ~100 MHz)

### Decisions
- **PPA area optimization (2026-05-18):** old `CORE_UTILIZATION = 25`
  (commit `caba4c83`) was over-conservative — sha3 is pure std-cell
  logic (no macros) so the coarse-macro-pitch rationale didn't apply.
  Util sweep on sky130hd (clock fixed at 10 ns):
  - `25` (baseline): 33.6% achieved, die 519 372 µm², WNS +0.823 ns
  - `55`: **unroutable** — GRT met2 105 % usage, ~9 000 total overflow
  - `35`: **clean** — 44.6 % achieved, die **371 356 µm² (−28.5 %)**,
    power −7 %, GRT 0 overflow, 0 DRC, WNS +0.079 ns (still met)
  Settled at `35`: the practical ceiling at the 10 ns clock. Denser
  packing spends nearly all the timing slack (WNS +0.823 → +0.079), so
  util can't go higher without WNS going negative and the clock can't be
  tightened (no slack left) — the 28.5 % die / 7 % power cut at
  iso-frequency is the right trade. Still far below asap7's util 70 /
  nangate45's 45 for the same RTL: sky130hd's 5-metal stack, not cell
  packing, is the wall here. `PLACE_DENSITY = 0.42` tracks the target;
  `TNS_END_PERCENT = 100` gives repair_timing full budget for the thin
  positive slack.
- **2026-06-04**: validated on the bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64 upgrade. Closes clean with markedly more slack than before — WNS +0.079 → +0.636 ns at the 10 ns clock (the new synth/place leaves the thin-slack design more headroom), util 45.1%, die 387 780 µm² (+4.4% vs the 2026-05-18 number, within tolerance). Left as-is; a future util sweep could reclaim the new slack as area.

### Known issues / open questions
- None.
