# minimax Design Decisions

Per-platform notes on tuning, workarounds, and platform-specific quirks for `minimax` (RV32I core, SystemVerilog → sv2v).  See `CLAUDE.md` (root) for the canonical upstream-bug index.

A small RISC-V core (~10–20k stdcells, no macros).  Used as a real-RTL smoke test on every platform.

## asap7

**Status**: finishing
**Last updated**: 2026-05-01 (commit `49c7aee5`)

### Configuration
- `CORE_UTILIZATION = 65` — packs std cells tight; design fits at higher util than typical for asap7
- `PLACE_DENSITY = 0.7`
- `CORE_ASPECT_RATIO = 1.0`, `CORE_MARGIN = 4`
- Clock: `900 ps` (Fmax ~1.11 GHz, WNS +4.8 ps)

### Decisions
- **2026-05-01 `49c7aee5`**: clock relaxed from 400 ps → 900 ps in PR #108.  Old 400 ps was ~50% of the design's actual capability; period_min after FP was ~750 ps and the resizer chased 2000+ violators on every build.  900 ps (vs naive 800 ps) chosen because synthesis becomes less aggressive at relaxed targets, drifting period_min upward — 900 ps is the first round number that closes cleanly.
- **2026-06-04**: validated on the bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64 upgrade. WNS +4.8 → −1.49 ps on the 900 ps clock (achievable-period +0.7%, i.e. Fmax change <1% — within the ~5% tolerance); 16799 logic cells, util 66.3%. The new resizer leaves a single endpoint ~1.5 ps short; not re-tuned since clawing it back via lower util would cost more die area than the sub-1% Fmax gain is worth. No SDC/RTL change.

### Known issues / open questions
- WNS marginally negative (−1.5 ps) post-upgrade; within Fmax tolerance, design routes and reaches 6_final.

## nangate45

**Status**: finishing
**Last updated**: 2026-05-01 (commit `49c7aee5`)

### Configuration
- `CORE_UTILIZATION = 60`
- `PLACE_DENSITY = 0.7`
- `CORE_ASPECT_RATIO = 1.0`, `CORE_MARGIN = 6`
- Clock: `1.6 ns` (Fmax ~629 MHz, WNS +9.9 ps)

### Decisions
- **2026-05-01 `49c7aee5`**: clock relaxed from 0.8 ns → 1.6 ns in PR #108.  Same shape as asap7 — original constraint was ~50% of achievable Fmax.
- **2026-06-04**: validated on the bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64 upgrade. WNS +9.9 → −1.51 ps on the 1.6 ns clock (achievable-period +0.07%, Fmax change <1% — within tolerance); 13795 logic cells, util 62.5%. Single endpoint ~1.5 ps short; not re-tuned (same rationale as asap7). No SDC/RTL change.

### Known issues / open questions
- None.

## sky130hd

**Status**: finishing
**Last updated**: 2026-05-01 (commit `49c7aee5`)

### Configuration
- `CORE_UTILIZATION = 40`
- `PLACE_DENSITY = 0.6`
- `CORE_ASPECT_RATIO = 1.0`, `CORE_MARGIN = 12`
- Clock: `8 ns` (Fmax ~130 MHz, WNS +310 ps)

### Decisions
- **2026-05-01 `49c7aee5`**: clock relaxed from 4 ns → 8 ns in PR #108.  sky130hd's coarse pitches and slower std cells push period_min above the original target by ~2×.
- **2026-06-04**: validated on the bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64 upgrade. WNS +310 → +263 ps on the 8 ns clock (still comfortably positive; achievable-period change <1%); 6760 logic cells, util 46.5%. No change needed.

### Known issues / open questions
- None.

## gt2n

**Status**: finishing
**Last updated**: 2026-07-07

### Configuration
- `CORE_UTILIZATION = 60` — slightly below asap7's 65%; gt2n's M2/M3 pitches (24/28 nm) require more routing headroom
- `PLACE_DENSITY = 0.7`
- `CORE_ASPECT_RATIO = 1.0`, `CORE_MARGIN = 4`
- `MAX_ROUTING_LAYER = M9` — mid-size design (~10–20k cells); two layers above sha3's M7, below floonoc's M11
- `TNS_END_PERCENT = 100`
- Clock: `780 ps` (Fmax 1.28 GHz; period_min 778 ps, WNS +2.1 ps, ratio 1.003 — just below the [1.05, 1.15] HighTide convergence window)

### Decisions
- **2026-07-07**: Initial gt2n port. Adapted from asap7 configuration: reduced `CORE_UTILIZATION` 65 → 60 to give the router margin at gt2n's tighter pitches; increased `MAX_ROUTING_LAYER` from its asap7 value to M9 to provide sufficient global-routing capacity for the ~15k-cell design. Closes cleanly at 780 ps (WNS +2.1 ps, 0 DRC violations).
- `MAX_ROUTING_LAYER = M9` chosen empirically between sha3 (M7, ~20k combinational cells) and floonoc (M11, 6k+ IO pins and many wide buses); minimax's sequential RISC-V core at ~15k cells fits at M9.
- See `designs/src/lfsr/DECISIONS.md` gt2n section for platform-level infrastructure notes (ORFS pin bump, two patches, OpenROAD pin bump) that apply to all gt2n designs.

### Known issues / open questions
- Clock at 780 ps is at the timing-closure limit (period_min 778 ps, ratio 1.003 — below the HighTide [1.05, 1.15] convergence target). A proper convergence pass would loosen the target to ~856 ps (= 778 × 1.10), verify it still closes, and re-read period_min. Left at 780 ps as part of the initial port.
