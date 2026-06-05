# gemmini Design Decisions

Per-platform notes on tuning, workarounds, and platform-specific quirks for `gemmini` (Berkeley ML systolic array accelerator, Chisel/Scala).  See `CLAUDE.md` (root) for the canonical upstream-bug index.

Large macro-heavy ML accelerator with FakeRAM black-boxes for the accumulator and scratchpad SRAMs.

## Active workarounds (all platforms)

- ~~**ODB-1200** in CTS-time `repair_timing` — `SETUP_MOVE_SEQUENCE = "unbuffer,sizeup,swap,buffer,clone"` (drop `split_load`).~~ **Removed 2026-06-04** on the bazel-orfs 553c1c3 / OpenROAD 299f3015 upgrade — the resizer bug is fixed, so the default move sequence (with `split_load`) is restored and all three platforms close cleanly with no ODB-1200. See [HighTide#75](https://github.com/VLSIDA/HighTide/issues/75).

## asap7

**Status**: finishing
**Last updated**: 2026-05-03 (commit `45b54bd1`)

### Configuration
- `CORE_UTILIZATION = 35` — macro-heavy; lower std-cell density helps router around macro pin clusters
- `SETUP_MOVE_SEQUENCE` removed 2026-06-04 (ODB-1200 fixed upstream) — default sequence restored
- `io.tcl`, `pdn.tcl` present (manual IO placement + power grid)
- Clock: `1.5 ns` (Fmax ~667 MHz)

### Decisions
- **2026-05-03 `45b54bd1`**: closed timing in PR #114 by combining the SETUP_MOVE_SEQUENCE workaround for ODB-1200 with appropriate clock period.
- **2026-06-04 toolchain upgrade**: removed the SETUP_MOVE_SEQUENCE workaround (ODB-1200 fixed in OpenROAD 299f3015). Closes clean on the 1.5 ns clock: WNS +70.5 ps (Fmax 0.70 GHz), util 44.8%, 675388 logic cells. No SDC/RTL change.

### Known issues / open questions
- None.

## nangate45

**Status**: finishing
**Last updated**: 2026-05-03 (commit `45b54bd1`)

### Configuration
- `CORE_UTILIZATION = 35`
- `SETUP_MOVE_SEQUENCE` removed 2026-06-04 (ODB-1200 fixed upstream)
- Clock: `3.0 ns` (Fmax ~333 MHz)

### Decisions
- **2026-05-03 `45b54bd1`**: closed timing in PR #114, same workaround as asap7.
- **2026-06-04 toolchain upgrade**: removed SETUP_MOVE_SEQUENCE (ODB-1200 fixed). Closes clean: WNS +115.7 ps on the 3.0 ns clock, util 43.7%, 376009 cells.

### Known issues / open questions
- None.

## sky130hd

**Status**: finishing
**Last updated**: 2026-05-03 (commit `45b54bd1`)

### Configuration
- `CORE_UTILIZATION = 30` — lowest util across the three platforms; sky130hd macro-pin congestion is worst here
- `SETUP_MOVE_SEQUENCE` removed 2026-06-04 (ODB-1200 fixed upstream)
- Clock: `13 ns` (Fmax ~77 MHz)

### Decisions
- **2026-05-03 `45b54bd1`**: closed timing in PR #114.  Util had to drop further than asap7/nangate45 to keep GP overflow under control on the macro-heavy floorplan.
- **2026-06-04 toolchain upgrade**: removed SETUP_MOVE_SEQUENCE (ODB-1200 fixed). Closes clean: WNS +338.5 ps on the 13 ns clock, util 33.8%, 323582 cells.

### Known issues / open questions
- None.
