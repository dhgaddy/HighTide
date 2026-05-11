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
| `liteeth_mac_axi_mii` | 40 | 0.4 | 2 2 | 610 | Smallest variant |
| `liteeth_mac_wb_mii` | 30 | 0.4 | 5 5 | 1000 | Wishbone bus is wider |
| `liteeth_udp_raw_rgmii` | 35 | 0.3 | 5 5 | 590 | `SYNTH_HIERARCHICAL=1` |
| `liteeth_udp_stream_rgmii` | 35 | 0.5 | 5 5 | 700 | |
| `liteeth_udp_stream_sgmii` | 40 | 0.3 | 5 5 | 1000 | `SKIP_CTS_REPAIR_TIMING=1` (ODB-1200) |
| `liteeth_udp_usp_gth_sgmii` | 35 | 0.3 | — | 1000 | `SKIP_CTS_REPAIR_TIMING=1` (ODB-1200) |

### Decisions
- **2026-04-24 `87829fdb`**: `liteeth_udp_stream_sgmii` hit ODB-1200 in CTS repair_timing; added `SKIP_CTS_REPAIR_TIMING=1`.
- **2026-04-30 `c8d96617`**: `liteeth_udp_usp_gth_sgmii` hit the same ODB-1200; same workaround applied.

## nangate45

**Status**: all 6 variants finishing
**Last updated**: 2026-03-19 (commit `518c6e03`)

### Per-variant configuration

| Variant | Util | Density | Halo | Clock (ns) | Notes |
|---|---:|---:|---:|---:|---|
| `liteeth_mac_axi_mii` | (default) | 0.4 | 30 30 | (default ~10) | |
| `liteeth_mac_wb_mii` | (default) | 0.35 | 30 30 | (default) | |
| `liteeth_udp_raw_rgmii` | 35 | 0.6 | — | 10 | `SYNTH_HIERARCHICAL=1` |
| `liteeth_udp_stream_rgmii` | 45 | 0.7 | — | 10 | `SYNTH_HIERARCHICAL=1` — packs tightest of all variants |
| `liteeth_udp_stream_sgmii` | 60 | 0.85 | — | 10 | `SYNTH_HIERARCHICAL=1` — densest variant on nangate45; ODB-1200 doesn't trigger here, no CTS skip needed |
| `liteeth_udp_usp_gth_sgmii` | 45 | 0.4 | — | 10 | `SYNTH_HIERARCHICAL=1` |

### Decisions
- nangate45 closes the SGMII variants without the ODB-1200 workaround that asap7 needs — the bug is sensitive to the specific resizer-state interaction triggered by asap7's smaller cells.

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
