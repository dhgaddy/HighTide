# Design Catalog

HighTide ports open-source hardware designs across three technology platforms using the OpenROAD RTL-to-GDSII flow.

## Platforms

| Platform | Node | Description |
|----------|------|-------------|
| **asap7** | 7nm | Academic predictive PDK from ASU |
| **nangate45** | 45nm | FreePDK with NanGate cell library |
| **sky130hd** | 130nm | Open-source SkyWater 130nm high-density |

## Design Matrix

| Design | Description | Language | asap7 | nangate45 | sky130hd |
|--------|-------------|----------|:-----:|:---------:|:--------:|
| **lfsr** | LFSR/PRBS generator | Verilog | x | x | x |
| **minimax** | RISC-V RV32I core | SystemVerilog (sv2v) | x | x | x |
| **liteeth** | Ethernet MAC (6 variants) | LiteX/Python | x | x | x |
| **NyuziProcessor** | Multi-threaded GPGPU | SystemVerilog (yosys-slang) | x | x | |
| **bp_processor** | Black-Parrot RISC-V (bp_uno, bp_quad) | SystemVerilog (yosys-slang) | x | x | |
| **gemmini** | ML systolic array accelerator | Chisel/Scala | x | x | |
| **cnn** | CNN accelerator | Veriloggen/NNgen/Python | x | x | |
| **sha3** | SHA3 hash engine | Verilog | x | x | |

### Liteeth Variants

The liteeth design has 6 configuration variants, each a different combination of protocol layer and PHY interface:

| Variant | Protocol | PHY |
|---------|----------|-----|
| `liteeth_udp_usp_gth_sgmii` | UDP | USP GTH SGMII |
| `liteeth_udp_raw_rgmii` | UDP raw | RGMII |
| `liteeth_udp_stream_rgmii` | UDP stream | RGMII |
| `liteeth_udp_stream_sgmii` | UDP stream | SGMII |
| `liteeth_mac_wb_mii` | MAC (Wishbone) | MII |
| `liteeth_mac_axi_mii` | MAC (AXI) | MII |

### Black-Parrot Variants

| Variant | Description |
|---------|-------------|
| `bp_uno` | Single-core BlackParrot |
| `bp_quad` | Quad-core BlackParrot |

## Design Complexity

Designs range from small (lfsr, ~200 cells) to large (gemmini, bp_quad with thousands of cells and memory macros). Designs with embedded memories use FakeRAM — placeholder LEF/LIB black-box macros that provide pin-accurate physical models without internal logic.

| Design | Approximate Size | Has FakeRAM | Hierarchical Synth |
|--------|-----------------|:-----------:|:-------------------:|
| lfsr | Small (~200 cells) | | |
| minimax | Small (~1K cells) | | |
| sha3 | Medium (~5K cells) | | |
| liteeth | Medium (~2-8K cells) | x | |
| NyuziProcessor | Large (~20K cells) | x | |
| cnn | Large (~15K cells) | x | |
| gemmini | Very large (~50K cells) | | |
| bp_uno | Large (~30K cells) | x | x |
| bp_quad | Very large (~100K+ cells) | x | x |

## Build Targets

Each design exposes Bazel targets for individual flow stages:

```
//designs/<platform>/<design>:<design>_synth       # Yosys synthesis
//designs/<platform>/<design>:<design>_floorplan   # Floorplan + IO + PDN
//designs/<platform>/<design>:<design>_place       # Global/detailed placement
//designs/<platform>/<design>:<design>_cts         # Clock tree synthesis
//designs/<platform>/<design>:<design>_route       # Global/detailed routing
//designs/<platform>/<design>:<design>_final       # Metal fill + GDSII
```

For multi-level designs (liteeth, bp_processor), the target path includes the variant:
```
//designs/asap7/liteeth/liteeth_mac_wb_mii:liteeth_mac_wb_mii_final
//designs/asap7/bp_processor/bp_quad:bp_quad_final
```
