# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HighTide is a VLSI design benchmark suite built on OpenROAD-flow-scripts (ORFS). It ports open-source hardware designs to asap7/sky130hd/nangate45 technologies using the OpenROAD RTL-to-GDSII flow, serving as a benchmark suite for ML projects.

## Setup

Requires an Ubuntu machine with [Bazelisk](https://github.com/bazelbuild/bazelisk) (or Bazel 7.6.1+). No additional setup needed — Bazel fetches everything via `MODULE.bazel` and the pinned `bazel-orfs` submodule.

## Build Commands

```bash
# Build the full RTL-to-GDS flow for one design (through the gallery
# render — caches the layout PNG too, so update-results is a pure fetch)
bazel build //designs/asap7/lfsr:lfsr_gallery

# Build a design across all available platforms
bazel build //designs/asap7/minimax:minimax_final \
            //designs/nangate45/minimax:minimax_final \
            //designs/sky130hd/minimax:minimax_final

# Build all designs for a platform
bazel build //designs/asap7/...

# Build all designs across all platforms
bazel build //designs/...

# Build with dev RTL generation (requires submodule init + tools)
bazel build --define update_rtl=true //designs/asap7/lfsr:lfsr_final

# Build individual stages (target suffixes: _synth, _floorplan, _place, _cts, _grt, _route, _final)
bazel build //designs/asap7/lfsr:lfsr_synth
bazel build //designs/asap7/lfsr:lfsr_place
```

Note: `hightide_design()` exposes the per-stage `orfs_flow` targets (`_synth` … `_final`), `_generate_abstract` / `_generate_metadata`, and `_<design>_gallery` (renders the layout PNG; `src = :<design>_final`). There is no aggregate `:<design>` target. **Build `:<design>_gallery` for sweeps** — it runs the whole flow *and* renders+caches the gallery image, so `update-results` (and k8s/run.sh, which now targets `_gallery`) becomes a pure cache fetch with no per-design local re-render. Use `:<design>_final` only when you explicitly don't want the image.

## Architecture

### Key Relationships

- **`MODULE.bazel`** — Declares dependencies on `bazel-orfs` (via `git_override`) and configures the ORFS Docker image for tool extraction
- **`defs.bzl`** — `hightide_design()` macro wrapping `orfs_flow()` with common defaults (`GDS_ALLOW_EMPTY`, platform-to-PDK mapping)
- **`BUILD.bazel`** (root) — Defines `//:update_rtl` config setting and the `merge_yosys_share` target that bundles the yosys-slang plugin
- Each design has a `BUILD.bazel` calling `hightide_design()` with its parameters (utilization, density, SRAMs, etc.)
- RTL sources at `designs/src/<design>/BUILD.bazel` use `select()` to switch between release and dev RTL

### Design Configuration

Each design lives at `designs/<platform>/<design>/` and contains:
- **`BUILD.bazel`** — Calls `hightide_design()` with verilog_files, sources (SDC, LEFs, LIBs), arguments (utilization, density, etc.)
- **`constraint.sdc`** — Clock definitions and timing constraints
- **`pdn.tcl`** (optional) — Power delivery network configuration (layer stripes, pitches)
- **`io.tcl`** (optional) — Pin placement constraints

### RTL Source Management (`designs/src/`)

Design sources are git submodules under `designs/src/<design>/dev/repo/`.

Each `designs/src/<design>/BUILD.bazel` defines:
- `rtl_release` filegroup — pre-generated Verilog files
- `rtl_dev_gen` genrule — runs setup.sh/sv2v to generate from source
- `rtl` alias — uses `select({"//:update_rtl": ..., "//conditions:default": ...})` to pick

Dev mode requires: `git submodule update --init designs/src/<design>/dev/repo` before `bazel build --define update_rtl=true`.

### Platforms

| Platform | Node | Designs |
|----------|------|---------|
| asap7 | 7nm academic | coralnpu, gemmini, lfsr, litedram, minimax, sha3, vortex, liteeth_udp_usp_gth_sgmii, NVDLA (partitions a/c/m/o/p), bp_processor (bp_uno, bp_quad), cnn, floonoc, NyuziProcessor, snitch_cluster |
| nangate45 | 45nm | coralnpu, gemmini, lfsr, litedram, minimax, NyuziProcessor, sha3, liteeth_udp_usp_gth_sgmii, bp_processor (bp_uno, bp_quad), cnn |
| sky130hd | 130nm open | gemmini, lfsr, litedram, minimax, sha3, liteeth_udp_usp_gth_sgmii, cnn |

#### Build status (as of 2026-05-11)

Designs reaching `_final` (cached on remote build cache):
- **asap7**: coralnpu, gemmini, lfsr, litedram, minimax, sha3, vortex, liteeth_udp_usp_gth_sgmii, NVDLA partitions a/m/o
- **nangate45**: coralnpu, gemmini, lfsr, litedram, minimax, NyuziProcessor, sha3, liteeth_udp_usp_gth_sgmii
- **sky130hd**: gemmini, lfsr, litedram, minimax, sha3, liteeth_udp_usp_gth_sgmii, NVDLA partitions a/m/o/p

Newly finishing after the wd_in-fix recovery (verified locally, 2026-05-16):
- **sky130hd**: `cnn` (fixed-grid `macro_placement.tcl` + `PLACE_DENSITY=0.20` + halo 300 — full GDS, 0 route DRC)
- **nangate45**: `cnn`; **asap7/nangate45**: NVDLA `partition_c` (local sweep `6_final`)

Not yet finishing (not cached):
- **asap7**: floonoc, snitch_cluster, bp_processor (bp_uno, bp_quad), NVDLA partition p
- **nangate45**: bp_processor (bp_uno, bp_quad)
- **sky130hd**: NVDLA partition c — global-placement plateau (~18 h on `3_place`, the documented GP overflow plateau); needs the same manual-grid `macro_placement.tcl` treatment cnn-sky130hd just got

`sky130hd/NVDLA/partition_c` global placement plateaus at overflow ~0.31 (target 0.10) — 84 macros at sky130hd's coarse pitches create local density hot spots near macro pin clusters that the placer can't smooth out. Loosening `CORE_UTILIZATION` / `PLACE_DENSITY_LB_ADDON` / `MACRO_PLACE_HALO` to match working partitions doesn't fix it. Likely needs a manual `macros.tcl` to spread the 84 SRAMs into a regular grid.

Use `tools/fetch_cache.sh` to pull cached `_final` results from the remote cache; designs marked NOT CACHED there are the not-yet-finishing set above.

### Output Directories

Build artifacts go to `bazel-bin/designs/<platform>/<design>/`. Key outputs:
- `results/<platform>/<design>/base/6_final.{odb,v,sdc,spef}` — Final ODB and netlist (and `6_final.gds` when `GDS_ALLOW_EMPTY` is not suppressing GDS write)
- `results/<platform>/<design>/base/<N>_<stage>.{odb,sdc,...}` — Per-stage outputs (1_synth, 2_floorplan, 3_place, 4_cts, 5_1_grt, 5_2_route, 6_final)
- `reports/<platform>/<design>/base/` — QoR and OpenROAD-generated `.webp.png` heatmaps/placement images written by ORFS's own report stage
- `logs/<platform>/<design>/base/` — Per-stage logs

### FakeRAM

Designs with embedded memories use FakeRAM (LEF-only, no GDS). Controlled by `GDS_ALLOW_EMPTY = fakeram.*` set as a default in `defs.bzl`.

Every design's LEF/LIB is generated by `tools/bsg_fakeram` (VLSIDA fork — `https://github.com/VLSIDA/bsg_fakeram`, branch `asap7-area-calib-v2`). The fork carries local patches on top of upstream BSG: per-bit `write_granularity` end-to-end, calibrated asap7 area (`2.5×` periphery overhead + dynamic column mux for ~1.5:1 aspect, bitcell from Clark et al. 2016), the same analytical path for sky130hd (1.07×1.74 µm bitcell from OpenRAM), and the **`wd_in` LEF pin-direction fix (`c83ecb4`)**. nangate45 still uses CACTI directly. The fork README acknowledges both BSG and ABKGroup's FakeRAM2.0 as upstream sources.

> **`wd_in` LEF bug (fixed `c83ecb4`, submodule bumped in HighTide `044c02b9`):** before `c83ecb4`, `generate_lef.py` set the pin `DIRECTION` by physical die side, not pin function, so the upper half of every write-data bus (`*_wd_in[ceil(W/2)..W-1]`) was emitted as `DIRECTION OUTPUT` while Liberty correctly said `input`. yosys (uses Liberty) synthesized correctly, but OpenROAD PnR (uses LEF) shorted half of every write-data bus into one giant net → unroutable GRT-0116 congestion (first caught on cnn-sky130hd, net with 1964 iterms / 512 bogus drivers). Pre-existing since fork commit `0e1b3c00` (Oct 2025). **Any LEF generated before `c83ecb4` is electrically invalid** — regenerate via `tools/regenerate_sram.sh` and verify `grep 'DIRECTION OUTPUT' -B1` shows no `*_wd_in` pins.

Generation flow:
1. **One JSON cfg per (design, platform)** lives at `designs/src/<design>/dev/generated/fakeram_<platform>.cfg`. Lists the macro `srams` array with width / depth / banks / `no_wmask` / port spec.
2. **`tools/regenerate_sram.sh <design> <platform>`** runs `bsg_fakeram/scripts/run.py` on that cfg, then copies the resulting `.lef`/`.lib` into `designs/<platform>/<design>/sram/{lef,lib}/`. The intermediate `dev/generated/sram/<platform>/` tree is gitignored.
3. **`tools/diff_sram_size.sh <design> <platform>`** emits a markdown diff of new vs `git HEAD` sizes (area %, aspect ratios, flag on >25% area or >2× aspect change) for pre-commit review.
4. **`tools/reconstruct_cfg_from_lef.py <design> <platform>`** — for designs whose cfg was lost or drifted (Section B: `coralnpu`, `vortex`, `NyuziProcessor` had no usable cfg / stale names). Derives a standard-path cfg from the *committed* LEF macro set (the ground truth for what the RTL instantiates): width from `wd_in` pin count, depth from the macro-name dims disambiguated by width (handles both `WIDTHxDEPTH` and `DEPTHxWIDTH` naming and non-power-of-2 depths like `16x52`), ports from the name suffix, `write_granularity` from wmask/width.

Committed LEF/LIB lives at `designs/<platform>/<design>/sram/{lef,lib}/` for every design.

Sub-CACTI-sized memories: a few designs need sizes below CACTI's reach (very narrow words, depth ≤ 16, or under ~1 Kb). Those don't get LEF/LIB; instead a small behavioural Verilog stub is added to the RTL filegroup and yosys synthesises the array as flip-flops. Two scripts emit these stubs:
- `designs/src/NVDLA/dev/gen_ff_rams.py` → `dev/generated/sram_ff/fakeram_*_1r1w.v` for `(6,128)`, `(9,80)`, `(66,8)`, `(64,16)`, `(256,16)`, `(272,16)`. Included in the NVDLA `:rtl` filegroup.
- `designs/src/bp_processor/dev/gen_macros_v.py` → `designs/{asap7,nangate45}/bp_processor/macros.v`. Wraps `bsg_mem_1rw_sync_synth` / `bsg_mem_1rw_sync_mask_write_bit_synth`; sizes not in `LARGE_CONFIGS` (currently 32x66 and 8x174) fall through to a register-array branch.
- `designs/src/vortex/dev/VX_dp_ram_REPLACE.sv` — the 6 vortex macros bsg_fakeram cannot size on **all** target platforms (`192x16`/`193x16`/`85x16`/`87x16` depth 16 below nangate45 CACTI range; `560x4`/`654x4` depth 4 exceed asap7 analytical pin-routing) have their `g_fakeram` branches removed so those `(DATAW,SIZE)` configs fall through to the stub's existing behavioral reg-array path (FF on all 3 platforms — the stub is shared RTL). Hard macros kept: `128x64`/`21x256`/`21x64` (dp), `32x1024`/`512x64`/`128x256` (sp).

## Reporting cell counts

When reporting or comparing cell counts across designs or platforms, **exclude fill cells, tap cells, and antenna cells**. They are physical-only / manufacturing-rule cells, not part of the design's logic. Their counts vary wildly across platforms (sky130hd uses ~17× more tap cells than nangate45 due to a stricter max-tap-distance rule, and lower `CORE_UTILIZATION` inflates filler counts proportionally), so including them obscures real differences.

Use the per-class fields in `6_report.json` (e.g. `class:sequential_cell`, `class:multi_input_combinational_cell`, `class:inverter`, `class:clock_buffer`, `class:timing_repair_buffer`) — not the top-level `instance__count` — when comparing designs.

## Known OpenROAD / yosys-slang bug workarounds

Designs in this repo carry workarounds for upstream tool bugs. Update this table whenever a new workaround lands, and remove rows once the upstream bug is fixed and the workaround can be reverted.

| Bug | Affected designs | Workaround | First commit | Issue |
|-----|------------------|------------|--------------|-------|
| **bsg_fakeram `wd_in` LEF direction** — `generate_lef.py` set pin `DIRECTION` by physical die side, not function, so the upper half of every write-data bus was `OUTPUT` in LEF while Liberty said `input`; OpenROAD PnR shorted half of each `wd_in` bus → unroutable GRT-0116 (cnn-sky130hd net: 1964 iterms / 512 bogus drivers) | every fakeram design's pre-`c83ecb4` LEF (Section A + B); all prior `_final` passes invalid | Fork fix `c83ecb4` (submodule bumped `044c02b9`); regenerate all macros via `tools/regenerate_sram.sh` / `tools/reconstruct_cfg_from_lef.py`; vortex's 6 unsizable macros → FF-fallback | `c83ecb4` / `044c02b9` | Pre-existing in fork since `0e1b3c00` (Oct 2025); fixed in VLSIDA/bsg_fakeram |
| **CTS-0105** false skip — yosys hierarchical synthesis output port buffers arrive in ODB with `dbSourceType::TIMING` instead of `NETLIST`; CTS skips them as pre-existing clock buffers and leaves the clock net unbuffered | asap7 NyuziProcessor; asap7/nangate45/sky130hd `bp_quad`, `bp_uno` | `PRE_CTS_TCL` script resets affected buffers' `dbSourceType` from `TIMING` → `NETLIST` before CTS runs | `81b0ed4b` | [OpenROAD#10177](https://github.com/The-OpenROAD-Project/OpenROAD/issues/10177) |
| **MPL-0040** — `rtl_macro_placer` annealing failure on certain macro clusters | asap7 `bp_quad` (pipe_fma cluster), asap7 `cnn` | Hand-place fakeram macros in left-edge columns at FIRM status via `macros.tcl` so RTLMP only sees pre-placed macros; for cnn also drop `CORE_UTILIZATION` 65→60 | `09542e19` | [OpenROAD#9985](https://github.com/The-OpenROAD-Project/OpenROAD/issues/9985) |
| **ODB-1200** in `repair_timing` — `InsertBufferBeforeLoads` iterates a stale load list and aborts the flow with `Load pin '...' is not connected to net '...'`. Triggered by the resizer's `SplitLoadMove` step in CTS-time repair_timing | asap7 `liteeth_udp_usp_gth_sgmii`; sky130hd `NyuziProcessor`; asap7 `NyuziProcessor` (surfaced post-wd_in-fix); asap7 `bp_quad`; asap7 `gemmini` | Most designs: `SKIP_CTS_REPAIR_TIMING = 1` (skips the whole repair pass; route still does its own hold-repair). Gemmini + asap7 `NyuziProcessor`: drop `split_load` from `SETUP_MOVE_SEQUENCE` (`"unbuffer,sizeup,swap,buffer,clone"`) — keeps the rest of repair_timing working (preferred over the full skip) | `87829fdb` | [HighTide#75](https://github.com/VLSIDA/HighTide/issues/75) |
| **DPL-0036** in CTS-internal `detailed_placement` — `cts.tcl` builds its own `dpl_args` ignoring `DETAIL_PLACEMENT_ARGS`, so CTS-inserted leaf clock buffers can land too far from a legal stdcell row | asap7 `snitch_cluster` | `PRE_CTS_TCL` wraps `detailed_placement` to inject `-max_displacement {2000 400}` for the CTS call | `0af20020` | None (ORFS layering issue; no upstream issue filed yet) |
| **yosys-slang** phantom 1'x drivers on interface-array modport ports — extra driver wins at `opt_clean`, real driver silently dropped | asap7 `vortex` | Bumped `yosys-slang` 4e53d77 → eabdfd1 (vendored via `MODULE.bazel`) | `cb488bea` | [yosys-slang#304](https://github.com/povik/yosys-slang/issues/304) |
| **`repair_timing` non-convergence** — repair loop spends iterations on the same RTL-bounded endpoint without making progress. Not a bug per se, but a flow pathology when the clock target is too tight for the design | asap7 `snitch_cluster`, asap7 `litedram` | `SKIP_INCREMENTAL_REPAIR = 1` to skip post-GRT `repair_timing` | `39ca8670` | None |
| **LiteX GENSDRPHY `input sdram_dq`** — `litedram/gen.py` declares the bidirectional SDR DQ bus as a plain `input` port (Lattice-platform convention; the tristate buffer lives at the IOB), but the same module instantiates 16 `TRELLIS_IO` cells that internally drive the port via OE-gated logic. yosys' `check -assert -mapped` sees the conflict and aborts synth on all 3 platforms | asap7/nangate45/sky130hd `litedram` | Patch `litedram_core.v` to make `sdram_dq` an `inout` port (`patch/litedram_core.patch`). Combined with `SYNTH_HIERARCHICAL = 1` so abc keeps each `TRELLIS_IO` as a hierarchy boundary | (this PR) | None (LiteX `gen.py:870` carries a `# FIXME: Allow other Vendors.` note) |

### Useful ORFS env vars for these workarounds

- **`PRE_CTS_TCL`** / **`PRE_GRT_TCL`** / etc — point at a Tcl script that runs before the named stage. Used for the CTS-0105 reset and DPL-0036 displacement injection.
- **`SETUP_MOVE_SEQUENCE`** — comma-separated list of moves passed to `repair_timing -sequence`. Default sequence is `unbuffer,sizeup,swap,buffer,clone,split_load`. Drop `split_load` to dodge ODB-1200 while keeping the rest of repair_timing active.
- **`SKIP_CTS_REPAIR_TIMING = 1`** — skip the entire `repair_timing_helper` call inside `cts.tcl`. Heavier hammer than dropping a single move; route's own hold-repair still runs.
- **`SKIP_INCREMENTAL_REPAIR = 1`** — skip post-GRT `repair_timing`. Use when the loop never converges (RTL-bounded critical paths).
- **`SKIP_LAST_GASP = 1`** — skip the final repair_timing pass.

These go into `arguments = { ... }` of `hightide_design()`.

## Shared Machine

- This is a shared multi-user machine. When checking process status (e.g., `ps aux | grep openroad`), always filter to the current user's processes or check for bazel sandbox paths (`external/bazel-orfs`) to avoid confusing other users' builds with ours.

## Bazel Cache

- **NEVER** run `bazel clean --expunge` or delete the entire disk cache (`~/.cache/bazel-disk-cache`). Synthesis takes hours and clearing the cache forces a full rebuild of all designs.
- To invalidate a single design's cached results, use targeted approaches:
  - Change an argument in the design's BUILD.bazel (forces re-run of affected stages)
  - Use `bazel build --strategy=<target>=local` to bypass cache for one target
- The remote cache (`--remote_cache` in `.bazelrc`) is shared and read-only by default. Never delete or corrupt it.
- If you suspect a stale cache, verify by checking the process count in bazel output: `N processwrapper-sandbox` means N actions actually ran; `N internal` means cached.

### Cloudflare 100 MB upload limit — build the biggest designs locally

The remote cache is self-hosted `bazel-remote` fronted by a **Cloudflare Tunnel** whose free tier caps request bodies at **100 MB**. ORFS emits multi-100-MB stage ODBs (`2_floorplan.odb`, `3_place.odb`) for the largest designs; even with `--remote_cache_compression` (zstd) the very biggest still exceed the ceiling, so their `_final` results **fail to upload and never get cached remotely** — every k8s run rebuilds them from scratch and re-fails the upload. Build these locally instead so they at least populate the local `~/.cache/bazel-disk-cache`:

- **`bp_quad`** (asap7, nangate45) — biggest design (560 macros, 64–160 Gi RAM, 14 h+); k8s-hostile.
- **`NVDLA/partition_c`** (asap7, nangate45, sky130hd) — the named offender in `.bazelrc`. The other NVDLA partitions (a/m/o/p) stay under the ceiling with zstd and run fine on k8s.
- **`cnn`** (nangate45, sky130hd) — 65 macros each.

Everything else — including NVDLA partitions a/m/o/p and the smaller recovery designs (ternip, bp_uno, liteeth, litepci, coralnpu, vortex, NyuziProcessor, cnn-asap7) — stays on k8s via `./k8s/run.sh --branch fakeram <platform> <design>`.

**Keep this list current:** *remove* a design once all its cache objects are confirmed < 100 MB (it can go back to k8s); *add* a design the moment it fails to upload on k8s (the bazel log shows a cache-upload error / `413` / size-limit on a stage ODB). The list is a live record of which designs currently bust the Cloudflare ceiling, not a fixed set.
