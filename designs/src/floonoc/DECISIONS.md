# floonoc Design Decisions

Per-platform notes on tuning, workarounds, and platform-specific quirks for `floonoc` (PULP Network-on-Chip mesh).  See `CLAUDE.md` (root) for the canonical upstream-bug index.

Network-on-chip with std-cell-only logic.  The dominant physical-design constraint is the **6,395 IO pin bits** spread across four wide HBM buses; floorplans are sized to fit the IO perimeter, not the cell area.  An `io.tcl` is shared across platforms to explicitly bank pins around the die and walk bus indices clockwise so each corner connects numerically-adjacent bits.

The io.tcl supports a `__SKIP__` placeholder that consumes a pin slot but emits no `place_pin`, which creates an empty region between adjacent pin groups.  This is used to keep `clk_i`/`rst_ni`/`test_enable_i` electrically separated from the bus pins at the bus-to-ctrl transition (and from each other on tight platforms).

## asap7

**Status**: finishing
**Last updated**: 2026-05-13 (commit `<pending>`)

### Configuration
- `DIE_AREA = 0 0 165 165` (51% smaller than the original 250×165 minimum gives ~2.2 tracks per pin on M5)
- `TNS_END_PERCENT = 100`
- `io.tcl` present — explicit place_pin per bit, no PLACE_DENSITY (cells naturally spread toward perimeter pins)
- Clock: `2000 ps` (achieved ~1.2 GHz fmax)

### Decisions
- **2026-04-29 `ec7be591`**: closed at 2 ns clock; manual io.tcl was needed because the auto IO placer clustered ports along one edge and choked routing in that region.
- **2026-05-13 area-opt**: shrunk die 250 → 165 (the 163-µm IO-pin track minimum + 2-µm headroom).  M5 pin pitch (0.048 µm) gives plenty of corner slack so no `__SKIP__` gap is required.

### Known issues / open questions
- None.

## nangate45

**Status**: finishing
**Last updated**: 2026-05-13 (commit `<pending>`)

### Configuration
- `DIE_AREA = 0 0 750 750` (~30% smaller than 900; with the `__SKIP__` gap, met6 pin pitch tolerates this)
- `TNS_END_PERCENT = 100`
- `end_margin = 15.0` µm in io.tcl (pins held away from corners)
- 10 `__SKIP__` slots between `hbm_narrow_out_rsp_i[0]` and `clk_i` on the left edge, plus 2 `__SKIP__` slots between each ctrl pin

### Decisions
- **2026-04-29 `ec7be591`**: same shape as asap7 — io.tcl carried over with platform-appropriate metal-layer references.
- **2026-05-13 area-opt**: shrunk die 900 → 750.  At 800 there was a single Metal Spacing DRC between `clk_i` and the adjacent `hbm_narrow_out_rsp_i[0]` (metal5 corner); at 750 the same site failed plus `clk_i`↔`rst_ni` started colliding too.  Inserting `__SKIP__` slots between the bus and ctrl pins AND between each ctrl pin closes the corner spacing.

### Known issues / open questions
- None.

## sky130hd

**Status**: finishing
**Last updated**: 2026-05-13 (commit `<pending>`)

### Configuration
- `DIE_AREA = 0 0 1600 1600` (11% smaller than 1800; required `__SKIP__` corner gap to reach this size)
- `TNS_END_PERCENT = 100`
- `edge_margin = 1.0` µm in io.tcl (pins inside the die-to-core gap, away from cell rows; avoids PSM-0069)
- 10 `__SKIP__` slots between `hbm_narrow_out_rsp_i[0]` and `clk_i` on the left edge

### Decisions
- **2026-05-08 `d7448e34`** (post-PR-99): `edge_margin = 5` had the bottom met2 pin shapes overlapping the first standard-cell row at y=5.44 µm, blocking the met2→met3→met4 via stack that connects the row's met1 followpin to the vertical met4 PDN stripes.  PSM reported the entire bottom row's VSS as electrically isolated.  Reducing `edge_margin` to 1 µm placed pins inside the die-to-core gap and cleared PSM-0069.
- **2026-05-13 area-opt**: dies 1500/1600/1700/1750 all produced 15-36 Metal Spacing DRC violations at the top-left clk_i corner.  None of PLACE_DENSITY, end_margin=15, or other knobs cleared it.  Inserting 10 `__SKIP__` slots between `hbm_narrow_out_rsp_i[0]` and `clk_i` on the left edge cleared the corner cleanly and unlocked 1600 (the previous practical floor was 1800).

### Known issues / open questions
- met2 pitch (0.46 µm) is 10× wider than asap7 M5, so the explicit pin placement has much less corner slack.  Further shrink below 1500 likely needs the `__SKIP__` mechanism extended to the other three corners as well.
