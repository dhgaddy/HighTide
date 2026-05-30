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

### Known issues / open questions
- None.

## sky130hd

**Status**: not finishing
**Last updated**: 2026-04-29 (commit `ec7be591`)

### Configuration
- `TNS_END_PERCENT = 100`
- `io.tcl` present
- Clock: `20.0 ns` (Fmax target ~50 MHz)

### Decisions
- **2026-04-29 `ec7be591`**: gave the same treatment as the working platforms (io.tcl + 20 ns clock) but synthesis still doesn't reach `_final` on sky130hd.  Stops at `1_synth` per `tools/summary.sh` "Incomplete builds" output.

### Known issues / open questions
- Synthesis itself is failing on sky130hd; need to inspect the yosys log to determine whether it's a memory-inference issue, a slang-frontend incompatibility, or something else.
- Worth checking the yosys-slang log against the gallery of known failures before deeper debug.
