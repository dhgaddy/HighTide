# liteeth Design Decisions

Per-platform notes for the `liteeth_udp_usp_gth_sgmii` design — the LiteEth Ethernet stack (LiteX/Python) configured with a UDP endpoint over the Xilinx UltraScale+ GTH-SerDes SGMII PHY.

This is the most complex liteeth variant: UDP streaming protocol + a high-speed serial PHY whose Xilinx UltraScale+ GTH transceiver brings in the most logic, and the one that exercises the most OpenROAD corner cases. It is the sole liteeth design kept in HighTide as of 2026-05-12 — the other five variants (`mac_axi_mii`, `mac_wb_mii`, `udp_raw_rgmii`, `udp_stream_rgmii`, `udp_stream_sgmii`) were removed when the suite was simplified.

| Variant | Protocol | PHY |
|---|---|---|
| `liteeth_udp_usp_gth_sgmii` | UDP | Xilinx UltraScale+ GTH SGMII |

FakeRAM macros live at `designs/<platform>/liteeth/sram/{lef,lib}/`.

## Active workarounds

- **ODB-1200** in CTS-time `repair_timing` affects **asap7**.  Fixed via `SKIP_CTS_REPAIR_TIMING = 1` (skip the entire repair pass; route's own hold-repair still runs).  See [HighTide#75](https://github.com/VLSIDA/HighTide/issues/75).

## asap7

**Status**: finishing
**Last updated**: `8ec5a224` (2026-05-11 PPA area sweep)

### Configuration

| Util | Density | Halo | Clock (ps) | Notes |
|---:|---:|---:|---:|---|
| 50 | 0.55 | — | 1000 | `SKIP_CTS_REPAIR_TIMING=1` (ODB-1200); area-tuned 2026-05-11 |

### Decisions
- **2026-04-30 `c8d96617`**: hit ODB-1200 in CTS repair_timing once the OpenROAD pin moved from `5f1bd87f` to `578be38a` (HighTide #103). Same bug class that previously affected `liteeth_udp_stream_sgmii` (PR #76). Added `SKIP_CTS_REPAIR_TIMING=1`.
- **2026-05-11 PPA area sweep**: UTIL 35→50 / DENSITY 0.30→0.55. Die area 41,896 → 29,439 µm² (**−30 %**). UTIL=55 fails MPL-0003 (macros + default halo cannot tile in the smaller core).

## nangate45

**Status**: finishing
**Last updated**: `8ec5a224` (2026-05-11 PPA area sweep)

### Configuration

| Util | Density | Halo | Clock (ns) | Notes |
|---:|---:|---:|---:|---|
| 60 | 0.65 | — | 10 | `SYNTH_HIERARCHICAL=1`; area-tuned 2026-05-11 |

### Decisions
- nangate45 closes without the ODB-1200 workaround that asap7 needs — the bug is sensitive to the specific resizer-state interaction triggered by asap7's smaller cells.
- **2026-05-11 PPA area sweep**: UTIL 45→60 / DENSITY 0.40→0.65. Die area 746,271 → 560,103 µm² (**−25 %**). This was the headline single-variant win on nangate45.

## sky130hd

**Status**: finishing
**Last updated**: `8ec5a224` (2026-05-11 PPA area sweep)

### Configuration

| Util | Density | Halo | Clock (ns) | Notes |
|---:|---:|---:|---:|---|
| 52 | 0.57 | 30 30 | 10 | area-tuned 2026-05-11 |

### Decisions
- sky130hd halo is 30×30 — large enough to keep std cells out of the macro shadow given sky130hd's wide cells.
- ODB-1200 doesn't trigger on sky130hd, same as nangate45.
- **2026-05-11 PPA area sweep**: UTIL 50→52 / DENSITY 0.40→0.57. Die area 3,864,920 → 3,716,410 µm² (−4 %). The baseline at UTIL=50 already had 50 max-slew + 4 max-cap DRV violations; UTIL=52 improves both (46/0). UTIL=55 fails global-route congestion.
