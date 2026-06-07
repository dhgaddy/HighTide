# vortex Design Decisions

Per-platform notes for the `vortex` design (Vortex GPGPU, Verilog top `Vortex`).
See `CLAUDE.md` (root) for the canonical upstream-bug index.

Vortex is a SystemVerilog GPGPU synthesized through the **yosys-slang** frontend
(`SYNTH_HDL_FRONTEND = slang`). It instantiates 6 hard FakeRAM macros
(`128x64`, `21x256`, `21x64`, `32x1024`, `512x64`, `128x256`) plus several
sub-CACTI arrays that fall through to a behavioral reg-array stub. Only **asap7**
reaches `_final` today; nangate45 / sky130hd are not yet closing and are out of scope.

## Active workarounds

- **yosys-slang `#304`** (phantom `1'x` driver on interface-array modport bits) — fixed
  by pinning `yosys-slang` at `eabdfd1` in `yosys_slang.bzl`. Still required; the plugin
  builds and parses Vortex cleanly against **yosys 0.64** after the 2026-06-04 upgrade
  (`read_slang` runs without the multidriver/`1'x` error).

## asap7

**Status**: reaches `_final` (setup-critical — worst path is SRAM-access bound; WNS negative)
**Last updated**: 2026-06-04 (bazel-orfs 553c1c3 upgrade)

### Configuration
- `SYNTH_HDL_FRONTEND = slang`, `SYNTH_HIERARCHICAL = 0`
- `CORE_UTILIZATION = 56`, `PLACE_DENSITY_LB_ADDON = 0.46`, `MACRO_PLACE_HALO = 5 5`
- `TNS_END_PERCENT = 100`
- Clock: `1100 ps`

### Decisions
- **2026-06-04 toolchain upgrade (bazel-orfs 553c1c3 / OpenROAD 299f3015 / yosys 0.64)**:
  builds clean; slang frontend parses Vortex on yosys 0.64. Netlist essentially unchanged
  (211 921 logic cells vs 214 803 baseline, −1.3 %; instance area −1.1 %; die ±0 %; power +1.4 %).
  Timing regressed: WNS −55.96 → **−134.82 ps** on the 1100 ps clock (Fmax 0.87 → 0.81 GHz,
  −6.9 %). The worst path runs **from a dcache `fakeram_128x256` macro output through the
  cache response-queue logic to a capture flop** — an SRAM-read-bound, single-cycle path.
  Flow knobs (util / density / halo) can't shorten the SRAM's intrinsic access delay, and
  RTL/SDC are off-limits for this upgrade, so the path is not recoverable without a
  pipeline/clock change. Accepted as-is: the design was already setup-negative pre-upgrade
  (−56 ps), area/power are within ~1.4 %, and it reaches `_final` exactly as before.

### Known issues / open questions
- Setup WNS negative (−134.82 ps); SRAM-bound critical path. Recovering it needs an RTL
  pipeline change or a looser clock — out of scope for the toolchain upgrade.

## nangate45

**Status**: reaches `_final` on bazel-orfs 553c1c3.
**Last updated**: 2026-06-04 (toolchain upgrade)

- **2026-06-04**: closes timing — WNS +661 → +626 ps, util 35.7 %. But yosys 0.64's slang
  frontend grows the netlist on this design's FF-fallback memories: **123 554 → 154 070
  logic cells (+24.7 %)**. `ABC_AREA=1` was tried as a synth flow knob and made it *worse*
  (211 910 cells), so it was reverted. The growth is inherent to the new front-/mid-end on
  this design; not recoverable without RTL changes. Accepted as a flagged QoR regression.

## sky130hd

**Status**: reaches `_final` on bazel-orfs 553c1c3 (setup-negative).
**Last updated**: 2026-06-04 (toolchain upgrade)

- **2026-06-04**: WNS +130 → **−172.6 ps** (SRAM-bound path, same as asap7) and **94 627 →
  121 621 logic cells (+28.5 %)** — same yosys-0.64 FF-fallback growth as nangate45;
  `ABC_AREA=1` reverted (made it 159 164). Reaches `_final`; flagged QoR regression (cells +
  setup), neither recoverable via flow knobs without RTL/SDC changes.
