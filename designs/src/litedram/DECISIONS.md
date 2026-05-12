# LiteDRAM Design Decisions

Per-platform notes for the `litedram` standalone DRAM controller benchmark. Generated from the upstream [enjoy-digital/litedram](https://github.com/enjoy-digital/litedram) Migen core. See `CLAUDE.md` (root) for the canonical upstream-bug index.

This is the first memory-controller design in the suite. One variant only — `SDR / GENSDRPHY / 16-bit DQ`, with AXI + Wishbone + native frontend ports.

## RTL configuration

`designs/src/litedram/litedram.yml` selects:

- **`memtype: SDR`** and **`sdram_phy: GENSDRPHY`** — vendor-agnostic Generic SDR PHY. The DRAM controller core is fully RTL; the PHY layer still instantiates four Lattice ECP5 primitives at the SDR I/O boundary (`FD1S3BX`, `OFS1P3BX`, `IFS1P3BX`, `TRELLIS_IO`). Synthesizable RTL stubs for those four primitives live in `designs/src/litedram/libraries/lattice/*.v`. ASIC time-of-flight modeling of the actual DDR PHYs (Xilinx S7/US, Lattice ECP5, Gowin) is out of scope — `gen.py` falls back to `LatticePlatform("LFE5U-45F-6BG381C", ...)` even in `GENSDRPHY` mode (see the `# FIXME: Allow other Vendors.` comment in `litedram/gen.py`), but the PHY itself is pure RTL.
- **`cpu: null`** — no CPU / no UART / no integrated ROM. We benchmark the controller core (bank machines, refresh FSM, AXI/Wishbone/native frontends, crossbar) without SoC scaffolding.
- **`user_ports`**: AXI + Wishbone + native, exercising the full frontend crossbar.
- **9 internal memories** all 16-deep × 25–54-bit (per-bank command FIFOs and AXI/Wishbone data buffers). Below the SRAM inference threshold — synthesizes as flop arrays on every platform. No FakeRAM needed.

## Patches applied to generated `litedram_core.v`

- **`patch/litedram_core.patch`**: change `sdram_dq` port from `input` to `inout`. LiteX's gen.py declares the bidirectional DQ bus as a plain `input` (Lattice-platform-style — the tristate buffer at the IOB drives it), but the generated module also instantiates 16 `TRELLIS_IO` cells that internally drive `B` (= `sdram_dq[i]`) when OE is low. With `input`, flat synthesis trips yosys' `check -assert` multi-driver test on all 16 DQ bits. Setting the port to `inout` is the cleanest fix — yosys' tristate inference takes over, and the synthesized OE-gated drivers no longer conflict with the external driver on the same wire.

## Active workarounds (per-platform)

- **`SYNTH_HIERARCHICAL = 1`** — required on every platform. With flat synth, abc inlines each `TRELLIS_IO` and the resulting INV cell (from the tristate optimization) collides with the `inout sdram_dq[*]` declaration. Hierarchical synth keeps each `TRELLIS_IO` as a module boundary so the multi-driver check sees only one driver per pin. Same approach as `liteeth_udp_raw_rgmii` for its `rgmii_mdio` MDIO pin.
- **`SKIP_INCREMENTAL_REPAIR = 1`** — required on asap7. The post-GRT `repair_timing` pass plateaus on 170 setup-violating endpoints (all `user_port_axi_0_*id[*]` AXI ID outputs and `user_rst`) — WNS stuck at −935 ps after 700+ iters at a 6 ns clock target, with the resizer making no per-iter progress. This is the RTL-bounded-endpoint pattern; same workaround as `snitch_cluster` (see CLAUDE.md workarounds table). Detail-route still does its own hold-repair; the final WNS shows up in the report.

## asap7

**Status**: setup-clean to GDS (PPA-tuned 2026-05-12)

| Util | Density | Clock (ps) | WNS (ps) | TNS (ps) | Setup viols | Hold viols | Die (µm²) | Fmax |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 45 | 0.55 | 25000 | **+2181** | **0** | **0** | 4295 | 7307 | 43.8 MHz |

**Focus: timing.** Iteration history (all with `SKIP_INCREMENTAL_REPAIR=1` because the post-GRT hold-fix trips ODB-1200 via `InsertBufferBeforeLoads`; neither dropping `split_load` from `SETUP_MOVE_SEQUENCE` nor setting `HOLD_SLACK_MARGIN` avoids the call site):

| Clock | Result | Notes |
|---:|---:|---|
| 6 ns | WNS −10328 ps, 2621 viols | initial — clock too tight, paths not buffered enough |
| 17 ns | WNS −7298 ps, 1243 viols | partial improvement |
| 25 ns | **WNS +2181 ps, 0 viols** | clean setup, accepting hold viols |

At 25 ns clock the worst routed delay (~22.8 ns achieved) fits comfortably. Hold-fix is skipped due to ODB-1200; detail route's own hold pass still trims the worst hold paths but 4295 endpoints remain — fixing them upstream needs the OpenROAD bug resolved.

Cell breakdown (excluding fill/tap/tie): 4393 sequential, 16486 multi_input_combinational, 1645 inverter, 766 timing_repair_buffer, 1 clock_buffer → 24397 stdcells total.

## nangate45

**Status**: area-tuned, timing closed (PPA sweep 2026-05-12)

| Util | Density | Clock (ns) | WNS (ns) | TNS (ns) | Setup viols | Die (µm²) | Fmax |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 90 | 0.92 | 12 | +6.87 | 0 | 0 | **45790** | 194.8 MHz |

**Focus: area.** Sweep from baseline util=45 (die 91077 µm²) → util=90 (die 45790 µm², **−49.7%**), all builds clean (0 viols, M2 congestion 73 % at util=90, well below the overflow wall). Intermediate landmarks:

| Util target | Achieved | Die (µm²) | M2 cong | Notes |
|---:|---:|---:|---:|---|
| 45 | 46.2 % | 91077 | 46 % | baseline (starter target) |
| 65 | 66.5 % | 63222 | 58 % | clean |
| 75 | 76.5 % | 54857 | 62 % | clean |
| 85 | 86.7 % | 48457 | 68 % | clean |
| **90** | **91.5 %** | **45790** | **73 %** | locked — comfortable margin to congestion wall |

util=90 still has +6.87 ns slack on the 12 ns clock — clock could be tightened separately for combined PPA, but per-task scope was area only. Cell breakdown post-sweep is essentially unchanged from baseline (denser packing, not different cell mix).

## sky130hd

**Status**: area-tuned, timing closed (PPA sweep 2026-05-12)

| Util | Density | Clock (ns) | WNS (ns) | TNS (ns) | Setup viols | Die (µm²) | Fmax |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 68 | 0.72 | 36 | +19.03 | 0 | 0 | **269065** | 58.9 MHz |

**Focus: area.** Baseline util=40 (die 456591 µm²) → util=68 (die 269065 µm², **−41.1%**). Intermediate landmarks:

| Util target | Achieved | Die (µm²) | M2 cong | Result |
|---:|---:|---:|---:|---|
| 40 | 46.4 % | 456591 | 33 % | baseline |
| 60 | 68.8 % | 304798 | 49 % | clean |
| **68** | **77.6 %** | **269065** | **57 %** | locked |
| 75 | — | — | 95 % overflow | **GRT-0116 fail** |

util=75 fails GRT congestion (M2 95 %, overflow 1994 tiles); util=68 is the practical ceiling without io.tcl / pdn.tcl tweaks. WNS still +19 ns of slack at util=68 — same combined-PPA opportunity as nangate45.

Cell breakdown: 4393 sequential, 6287 multi_input_combinational, 275 inverter, 842 timing_repair_buffer → 11797 stdcells total. Sky130hd's wider ANDs/NORs absorb more logic per cell than nangate45's library.

## Cross-platform notes

- The controller has a single clock domain (`clk` → `user_clk` is a buffered pass-through). The SDC declares `user_clk` as a generated clock with `-divide_by 1 -source clk` so the launch/capture edges line up; without that, OpenROAD treats `user_clk` as a separate primary clock and the AXI / Wishbone / native interfaces look async.
- The 16-bit SDR data bus + 13-bit address + bank + control signals total 75 ports / 534 port bits. That's a lot of I/O for a ~25k-cell design — placement at the higher utilization values is dominated by IO-pin placement and the surrounding repair_design buffering.
- `repair_timing` plateaus on `user_*` output paths because the launching FF is buried deep in the controller (multi-stage AXI ID FIFO) and the path runs cleanly to a top-level output — no hierarchy boundary for the resizer to insert into. Loosening `clk_io_pct` from 0.2 to a smaller value would help, but only marginally. The cleanest fix is a slower clock; the next-cleanest is `SKIP_INCREMENTAL_REPAIR`.
