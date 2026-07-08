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

## gt2n

**Status**: finishing
**Last updated**: 2026-07-07

### Configuration
- `CORE_UTILIZATION = 50` — reduced from asap7's 70%; gt2n's M2/M3 pitches (24/28 nm) are ~2.3× tighter than asap7's, so the same cell density drives proportionally higher routing demand; 50% provides equivalent routing headroom
- `PLACE_DENSITY = 0.60` — explicit placer density cap; prevents the placer from over-packing individual bins even within the 50% core-level target
- `MAX_ROUTING_LAYER = M7` — two layers above asap7's M5; the extra capacity (M6 horizontal, M7 vertical) is needed for the router to escape congestion at gt2n's fine pitches
- `TNS_END_PERCENT = 100`
- Clock: `500 ps` (period_min 463.07 ps, WNS +36.92 ps, ratio 1.08 — converged within [1.05, 1.15] ✓)

### Decisions
- **2026-07-07**: Initial gt2n port. Started from the asap7 configuration (70% utilization, M5 routing cap). First build at those settings produced severe global routing overflow — M2/M3 utilization far exceeded 100% in dense cells. Fixed in a single re-parameter pass with three changes:
  1. **`CORE_UTILIZATION` 70 → 50**: the same RTL that packs well at asap7's 56 nm pitch is effectively 2.3× denser relative to the routing grid at gt2n's 24/28 nm M2/M3 pitches. Dropping to 50% provides comparable routing margin to what asap7 has at 70%.
  2. **`MAX_ROUTING_LAYER` M5 → M7**: the two additional layers (M6 horizontal, M7 vertical) give the router sufficient planes to spread the horizontal routing load that overflowed M2/M4 at the higher utilization.
  3. **`PLACE_DENSITY = 0.60`**: explicit density cap prevents the placer from creating locally over-dense bins that the router cannot recover from regardless of the global utilization setting.
- With these three changes sha3 converged in one build: 0 GRT overflow, 0 DRC violations, WNS +36.92 ps, period_min 463.07 ps, ratio 1.08.
- See `designs/src/lfsr/DECISIONS.md` gt2n section for platform-level infrastructure notes (ORFS pin bump, two patches, OpenROAD pin bump) that apply to all gt2n designs.

### Known issues / open questions
- None.
