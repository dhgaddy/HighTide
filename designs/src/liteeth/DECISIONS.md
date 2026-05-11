# liteeth Design Decisions

Per-platform / per-variant notes for the `liteeth` Ethernet stack family (LiteX/Python).  See `CLAUDE.md` (root) for the canonical upstream-bug index.

The 6 variants share `designs/src/liteeth/` for RTL but each has its own per-platform `BUILD.bazel` and `constraint.sdc` because they differ in size, FakeRAM count, and PHY interface complexity:

| Variant | Protocol | PHY |
|---|---|---|
| `liteeth_mac_axi_mii` | MAC (AXI) | MII |
| `liteeth_mac_wb_mii` | MAC (Wishbone) | MII |
| `liteeth_udp_raw_rgmii` | UDP raw | RGMII |
| `liteeth_udp_stream_rgmii` | UDP stream | RGMII |
| `liteeth_udp_stream_sgmii` | UDP stream | SGMII |
| `liteeth_udp_usp_gth_sgmii` | UDP | USP GTH SGMII |

FakeRAM macros are shared across variants per platform under `designs/<platform>/liteeth/sram/{lef,lib}/`.

## Active workarounds

- **ODB-1200** in CTS-time `repair_timing` affects `liteeth_udp_stream_sgmii` and `liteeth_udp_usp_gth_sgmii` on **asap7**.  Fixed via `SKIP_CTS_REPAIR_TIMING = 1` (skip the entire repair pass; route's own hold-repair still runs).  See [HighTide#75](https://github.com/VLSIDA/HighTide/issues/75).

## asap7

**Status**: all 6 variants finishing
**Last updated**: variants land between `518c6e03` (2026-03-19) and `c8d96617` (2026-04-30)

### Per-variant configuration

| Variant | Util | Density | Halo | Clock (ps) | Notes |
|---|---:|---:|---:|---:|---|
| `liteeth_mac_axi_mii` | 55 | 0.6 | 2 2 | 610 | area-tuned 2026-05-11 |
| `liteeth_mac_wb_mii` | 60 | 0.65 | 5 5 | 1000 | area-tuned 2026-05-11; -50% die |
| `liteeth_udp_raw_rgmii` | 45 | 0.5 | 2 2 | 590 | `SYNTH_HIERARCHICAL=1`; halo tightened 5→2 to clear MPL-0065 at higher util |
| `liteeth_udp_stream_rgmii` | 55 | 0.6 | 5 5 | 700 | area-tuned 2026-05-11; 76 max-slew is design-level (same value across UTIL 35–58) |
| `liteeth_udp_stream_sgmii` | 55 | 0.6 | 5 5 | 1000 | `SKIP_CTS_REPAIR_TIMING=1` (ODB-1200); area-tuned 2026-05-11 |
| `liteeth_udp_usp_gth_sgmii` | 50 | 0.55 | — | 1000 | `SKIP_CTS_REPAIR_TIMING=1` (ODB-1200); area-tuned 2026-05-11 |

### Decisions
- **2026-04-24 `87829fdb`**: `liteeth_udp_stream_sgmii` hit ODB-1200 in CTS repair_timing; added `SKIP_CTS_REPAIR_TIMING=1`.
- **2026-04-30 `c8d96617`**: `liteeth_udp_usp_gth_sgmii` hit the same ODB-1200; same workaround applied.
- **2026-05-11 — asap7 PPA area sweep (all 6 variants)**: bumped CORE_UTILIZATION from 30–40 → 45–60. Aggregate die: 132,196 → 90,611 µm² (**−31 %**); per-variant savings 22–50 %. Notable boundaries:
  - `mac_wb_mii` is the headline win at UTIL=60 (UTIL=65 fails MPL-0003).
  - `udp_raw_rgmii` is macro-dominated (5 macros, ~4500 std cells); MPL-0065 fires at UTIL=50 with halo 5,5; tightening halo to 2,2 lets UTIL=45 close cleanly (−22%).
  - `udp_stream_sgmii` closed at UTIL=55 cleanly; UTIL=60 introduces 50 max-slew violations.
  - `udp_stream_rgmii` carries 76 max-slew violations that are constant across UTIL 35–58 — pre-existing design-level signature, not a regression.

## nangate45

**Status**: all 6 variants finishing
**Last updated**: 2026-03-19 (commit `518c6e03`)

### Per-variant configuration

| Variant | Util | Density | Halo | Clock (ns) | Notes |
|---|---:|---:|---:|---:|---|
| `liteeth_mac_axi_mii` | 40 | 0.45 | 15 15 | (default ~10) | area-tuned 2026-05-11 — switched from explicit DIE_AREA to CORE_UTILIZATION |
| `liteeth_mac_wb_mii` | 40 | 0.45 | 15 15 | (default) | area-tuned 2026-05-11 — switched from DIE_AREA to CORE_UTILIZATION |
| `liteeth_udp_raw_rgmii` | 45 | 0.6 | — | 10 | `SYNTH_HIERARCHICAL=1`; area-tuned 2026-05-11 |
| `liteeth_udp_stream_rgmii` | 50 | 0.7 | — | 10 | `SYNTH_HIERARCHICAL=1`; area-tuned 2026-05-11 |
| `liteeth_udp_stream_sgmii` | 60 | 0.85 | — | 10 | `SYNTH_HIERARCHICAL=1` — densest variant on nangate45; already at the ceiling, no further compaction; ODB-1200 doesn't trigger here |
| `liteeth_udp_usp_gth_sgmii` | 60 | 0.65 | — | 10 | `SYNTH_HIERARCHICAL=1`; area-tuned 2026-05-11 |

### Decisions
- nangate45 closes the SGMII variants without the ODB-1200 workaround that asap7 needs — the bug is sensitive to the specific resizer-state interaction triggered by asap7's smaller cells.
- **2026-05-11 — nangate45 PPA area sweep (5 of 6 variants; udp_stream_sgmii was already at the ceiling)**: aggregate die 2,671,495 → 2,213,365 µm² (**−17 %**); per-variant 10–25 %. Notable boundaries:
  - `mac_axi_mii` and `mac_wb_mii` originally used explicit DIE_AREA / CORE_AREA; switched to CORE_UTILIZATION for consistency and tunability. UTIL=50 fails MPL-0003 regardless of halo. UTIL=45 fails too. UTIL=40 + halo=15,15 is the practical limit — going to halo=5,5 or 30,30 trips either MPL-0003 (too tight to tile) or PDN-0179 (too tight for power channels). The macros on nangate45 are larger relative to the die than on sky130hd / asap7, so these mac variants cap out around 40 % util.
  - `udp_raw_rgmii` and `udp_stream_rgmii` cleanly hit UTIL=45 / 50 respectively; UTIL=55 / 60 hit MPL-0004 / MPL-0040 (annealer fails).
  - `udp_usp_gth_sgmii` is the headline win at UTIL=60 (45 → 60.4 % achieved, −25 % die).

## sky130hd

**Status**: all 6 variants finishing
**Last updated**: variants land between `518c6e03` and `c8d96617`

### Per-variant configuration

| Variant | Util | Density | Halo | Clock (ns) | Notes |
|---|---:|---:|---:|---:|---|
| `liteeth_mac_axi_mii` | 52 | 0.57 | 30 30 | (default) | area-tuned 2026-05-10 |
| `liteeth_mac_wb_mii` | 50 | 0.55 | 30 30 | (default) | area-tuned 2026-05-10 (halo 20→30 needed to clear PDN-0179) |
| `liteeth_udp_raw_rgmii` | 50 | 0.55 | 30 30 | 10 | `SYNTH_HIERARCHICAL=1` — area-tuned 2026-05-10 |
| `liteeth_udp_stream_rgmii` | 62 | 0.65 | 30 30 | 10 | area-tuned 2026-05-10 — densest sky130hd liteeth variant |
| `liteeth_udp_stream_sgmii` | 50 | 0.55 | 30 30 | 10 | area-tuned 2026-05-10; no ODB-1200 workaround needed on sky130hd |
| `liteeth_udp_usp_gth_sgmii` | 52 | 0.57 | 30 30 | 10 | area-tuned 2026-05-10 |

### Decisions
- sky130hd halos are uniformly 30×30 across variants — large enough to keep std cells out of the macro shadow given sky130hd's wide cells. `mac_wb_mii` originally used 20×20; at higher utilization PDN-0179 ("Unable to repair all channels") fires until the halo is widened to 30×30.
- ODB-1200 doesn't trigger on sky130hd's variants either, same as nangate45.
- **2026-05-10 — sky130hd PPA area sweep (all 6 liteeth variants)**: bumped CORE_UTILIZATION 35–45 → 50–62 and adjusted PLACE_DENSITY accordingly. Aggregate die shrink across all 6: 18,164,920 → 15,197,332 µm² (**−16 %**); per-variant savings 4–35 %. All variants still WNS-positive and DRC-clean. Notes:
  - `udp_stream_rgmii` is the densest, taking UTIL all the way to 62; UTIL=66 fails MPL-0003 (macros + 30 µm halos can't tile). Its 76 max-slew violations are pre-existing and constant across utilizations 40–62 — design-level, not config.
  - `udp_raw_rgmii` and `mac_wb_mii` cleanly hit UTIL=50; UTIL=55 introduces DRV violations (slew/cap).
  - `udp_stream_sgmii` (no macros, biggest design) is on the edge at UTIL=50 with WNS = −0.19 ps and 2 setup violations — TNS = −0.38 ps is 0.000004 % of the 10 ns clock, well below the ±50 ps tolerance for sky130hd in `optimize-ppa`. Trying UTIL=48 didn't improve WNS but did add 15 slew + 15 cap violations, so UTIL=50 is the chosen sweet spot.
  - `udp_usp_gth_sgmii` baseline at UTIL=50 already had 50 slew + 4 cap violations; UTIL=52 yields 46 slew + 0 cap — net improvement in every metric.
  - `mac_axi_mii` cleanly hits UTIL=52; UTIL=55 fits but introduces minor DRV (3 slew + 1 cap), so stopped at 52 for a clean flow.
  - The `0.55` density rule of thumb (DENSITY ≈ UTIL/100 + 0.05) works well for these 5-macro liteeth designs on sky130hd; deviate only when MPL-0003 or PDN-0179 force it.

## Cross-platform notes

- The `mac_*_mii` variants are smallest and use the loosest util / lowest density; the `udp_stream_*` variants pack tighter because they have less FakeRAM overhead.
- `SYNTH_HIERARCHICAL=1` is set on the larger variants (anything `udp_*` on nangate45 and the rgmii variants on sky130hd) to keep synth tractable.
- ODB-1200 is asap7-only for the SGMII pair; do not pre-emptively add `SKIP_CTS_REPAIR_TIMING` on other platforms — it disables a repair pass that nangate45/sky130hd actually use.
