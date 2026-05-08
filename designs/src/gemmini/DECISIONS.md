# gemmini Design Decisions

Per-platform notes on tuning, workarounds, and platform-specific quirks for `gemmini` (Berkeley ML systolic array accelerator, Chisel/Scala).  See `CLAUDE.md` (root) for the canonical upstream-bug index.

Large macro-heavy ML accelerator with FakeRAM black-boxes for the accumulator and scratchpad SRAMs.

## Active workarounds (all platforms)

- **ODB-1200** in CTS-time `repair_timing` — fixed via `SETUP_MOVE_SEQUENCE = "unbuffer,sizeup,swap,buffer,clone"` (drop the default `split_load` move that triggers the bug).  Keeps the rest of repair_timing active, unlike `SKIP_CTS_REPAIR_TIMING` which other ODB-1200-affected designs use.  See [HighTide#75](https://github.com/VLSIDA/HighTide/issues/75).

## asap7

**Status**: closing
**Last updated**: 2026-05-03 (commit `45b54bd1`)

### Configuration
- `CORE_UTILIZATION = 35` — macro-heavy; lower std-cell density helps router around macro pin clusters
- `SETUP_MOVE_SEQUENCE = "unbuffer,sizeup,swap,buffer,clone"` (ODB-1200 workaround)
- `io.tcl`, `pdn.tcl` present (manual IO placement + power grid)
- Clock: `1.5 ns` (Fmax ~667 MHz)

### Decisions
- **2026-05-03 `45b54bd1`**: closed timing in PR #114 by combining the SETUP_MOVE_SEQUENCE workaround for ODB-1200 with appropriate clock period.

### Known issues / open questions
- None.

## nangate45

**Status**: closing
**Last updated**: 2026-05-03 (commit `45b54bd1`)

### Configuration
- `CORE_UTILIZATION = 35`
- `SETUP_MOVE_SEQUENCE = "unbuffer,sizeup,swap,buffer,clone"` (ODB-1200 workaround)
- Clock: `3.0 ns` (Fmax ~333 MHz)

### Decisions
- **2026-05-03 `45b54bd1`**: closed timing in PR #114, same workaround as asap7.

### Known issues / open questions
- None.

## sky130hd

**Status**: closing
**Last updated**: 2026-05-03 (commit `45b54bd1`)

### Configuration
- `CORE_UTILIZATION = 30` — lowest util across the three platforms; sky130hd macro-pin congestion is worst here
- `SETUP_MOVE_SEQUENCE = "unbuffer,sizeup,swap,buffer,clone"` (ODB-1200 workaround)
- Clock: `13 ns` (Fmax ~77 MHz)

### Decisions
- **2026-05-03 `45b54bd1`**: closed timing in PR #114.  Util had to drop further than asap7/nangate45 to keep GP overflow under control on the macro-heavy floorplan.

### Known issues / open questions
- None.
