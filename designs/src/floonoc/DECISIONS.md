# floonoc Design Decisions

Per-platform notes on tuning, workarounds, and platform-specific quirks for `floonoc` (PULP Network-on-Chip mesh).  See `CLAUDE.md` (root) for the canonical upstream-bug index.

Network-on-chip with std-cell-only logic; the only physical-design knobs are clock period, util, and IO placement (the design has many ports).  An `io.tcl` is shared across platforms to spread the IO ring.

## Upstream history

- **2026-05-30**: bumped `dev/repo` `ed3e41de` → `064df165` (11 commits, v0.7.x → v0.8.1). v0.8.0 introduced the Reduction Feature (`floo_alu.sv`, `floo_reduction_unit.sv`, `floo_reduction_arbiter.sv`, `floo_reduction_sync.sv`) which pulls in the full `fpnew` (cvfpu) tree as a dependency — a significant scope expansion. v0.8.1 adds collective check and an exclusion knob for floogen RDL gen. Tail commit `064df16` adds a floogen collective-model check. Closes #83.

## asap7

**Status**: finishing
**Last updated**: 2026-04-29 (commit `ec7be591`)

### Configuration
- `TNS_END_PERCENT = 100`
- `io.tcl` present — spreads NoC ports around the die perimeter to relieve IO-region congestion
- Clock: `2000 ps` (Fmax ~500 MHz)

### Decisions
- **2026-04-29 `ec7be591`**: closed at 2 ns clock; manual io.tcl was needed because the auto IO placer clustered ports along one edge and choked routing in that region.
- **2026-06-04 toolchain upgrade (bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64)**: closes clean, no change — WNS +1089 → +1114 ps on the 2 ns clock, util 20.4 %, 80 125 logic cells (slang frontend on yosys 0.64).

### Known issues / open questions
- None.

## nangate45

**Status**: finishing
**Last updated**: 2026-04-29 (commit `ec7be591`)

### Configuration
- `TNS_END_PERCENT = 100`
- `io.tcl` present (same purpose as asap7)
- Clock: `5.0 ns` (Fmax ~200 MHz, ~311 MHz reported on results.html)

### Decisions
- **2026-04-29 `ec7be591`**: same shape as asap7 — io.tcl carried over with platform-appropriate metal-layer references.
- **2026-06-04 toolchain upgrade**: closes clean — WNS +1822 → +1838 ps on the 5 ns clock, util 18.2 %, 71 700 logic cells (+3.4 % vs baseline 69 332, within tolerance).

### Known issues / open questions
- None.

## sky130hd

**Status**: finishing
**Last updated**: 2026-06-26 (commit `bbc7fd0`)

### Configuration
- `TNS_END_PERCENT = 100`
- `io.tcl` present — `edge_margin = 4.37 µm` (see Decisions for why)
- Clock: `20.0 ns` (Fmax target ~50 MHz)

### Decisions
- **2026-04-29 `ec7be591`**: gave the same treatment as the working platforms (io.tcl + 20 ns clock) but synthesis still doesn't reach `_final` on sky130hd.  Stops at `1_synth` per `tools/summary.sh` "Incomplete builds" output.
- **2026-06-04 toolchain upgrade (bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64)**: big step forward — the old-tools synth stall is gone and the flow runs all the way to `6_final.odb`. **But the final report fails PSM-0069**: `Check connectivity failed on VSS` — many TAP/FILLER/stdcell `VGND` pins are left unconnected by the default sky130hd PDN under the new tools (PSM-0039 warnings precede it). So it produces a routed DB but not a clean signoff. **Flagged** — needs a PDN fix (followpin/strap coverage of VSS, likely a `pdn.tcl`) to close PSM; out of scope for the flow-knob upgrade. asap7 + nangate45 floonoc pass clean.
- **2026-06-26 `bbc7fd0`**: PSM-0069 root cause found and fixed. The 1598 bottom-edge IO pins on met2 at `edge_margin=5.0 µm` had their spacing-expanded obstruction (obs_yMax=5381 nm) overlapping the row-0 VSS via area (y_min=5200 nm); `pdngen` silently dropped all row-0 met1×met4 via candidates with no PDN-0110 warning. Fix: reduced `edge_margin` to **4.37 µm** (nearest valid met2 y-track below the 4.82 µm threshold); obs_yMax drops to 4751 nm, clearing the via area. `_final` passes with `[INFO PSM-0040] All shapes on net VSS are connected.` See CLAUDE.md bugs table for the threshold formula.

### Known issues / open questions
- None.

## gt2n

**Status**: finishing
**Last updated**: 2026-07-07

### Configuration
- `FOOTPRINT_TCL = io.tcl` — custom pin placement for 6,395 IO pins (see Decisions)
- `DIE_AREA = "0 0 129 129"`, `CORE_AREA = "6 6 123 123"` — 129×129 µm die, 6 µm margin each side; sized to match the asap7→gt2n area scaling ratio of ~4.1× (see Decisions)
- `MAX_ROUTING_LAYER = M11` — large design with wide HBM buses; needs the full routing stack
- `TNS_END_PERCENT = 100`
- Clock: `1151 ps` (Fmax 917 MHz; period_min 1089.54 ps, ratio 1.056 — converged within [1.05, 1.15] ✓)

### Decisions
- **2026-07-07 (custom io.tcl — mandatory for 6,395 pins)**: The ORFS auto IO placer cannot distribute this many ports evenly at gt2n's tight pitches — without a custom io.tcl all ports cluster along one or two edges and the router overflows in that region. The gt2n io.tcl places all 6,395 pins explicitly using the platform defaults from `platforms/gt2n/config.mk`: **M2** (`IO_PLACER_H`, horizontal metal) on the left/right edges (pitch 24 nm, width 12 nm) and **M3** (`IO_PLACER_V`, vertical metal) on the top/bottom edges (pitch 28 nm, width 14 nm). Pins are distributed ~1,599 per edge clockwise, with numerically-adjacent bus bits on adjacent physical slots. An earlier attempt that moved IO pins to M4/M5 was reverted — those are not the platform IO-placer defaults for gt2n and introduced routing conflicts on the non-default layers.
- **2026-07-07 (`edge_margin = 5.0 µm` — no PSM-0069 reduction needed)**: sky130hd requires `edge_margin` reduced to 4.37 µm to avoid PSM-0069 (IO pin obstruction overlapping the boundary-row PDN via area). gt2n uses BSPDN: all power delivery is on BPR/BM1/BM2 (backside stack only); there are no frontside power stripes or vias on M1–M13 that IO pin halos could obstruct. The PSM-0069 mechanism does not apply on gt2n, so 5.0 µm is safe.
- **2026-07-07 (die sizing — asap7→gt2n area ratio ~4.1×)**: floonoc on asap7 has a core area of ~576 µm². gt2n standard cells are physically larger relative to the routing pitch, and the fine M2/M3 pitch raises routing demand per unit area, so the die had to be sized empirically rather than by direct area scaling — smaller dies left DRT with persistent, non-converging congestion. Settled at a 129×129 µm die (117×117 µm core, 13,689 µm², ≈4.1× asap7's core area), where DRT converges cleanly; the 6 µm margin on each side provides a full usable border row.
- **2026-07-07 (`MAX_ROUTING_LAYER = M11`)**: floonoc carries four wide HBM buses (hbm_wide_out_req_o[2987:0], hbm_wide_out_rsp_i[2103:0], hbm_narrow_out_req_o[979:0], hbm_narrow_out_rsp_i[319:0]) plus internal NoC routing totalling 6,000+ signal nets. M7 (sufficient for sha3) was insufficient here; M11 is required for the router to find clean global routes across the 129 µm die.
- **2026-07-07 (clock tightening)**: applied the standard HighTide tightening loop (target = period_min × 1.10, iterate until ratio ∈ [1.05, 1.15]) once the die size stabilized. Converged at **1151 ps** (period_min 1089.54 ps, ratio 1.056, WNS = 0, 0 DRC violations, Fmax 917 MHz).
- See `designs/src/lfsr/DECISIONS.md` gt2n section for platform-level infrastructure notes (ORFS pin bump, two patches, OpenROAD pin bump) that apply to all gt2n designs.

### Known issues / open questions
- None.
