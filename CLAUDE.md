# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HighTide is a VLSI design benchmark suite built on OpenROAD-flow-scripts (ORFS). It ports open-source hardware designs to asap7/sky130hd/nangate45 technologies using the OpenROAD RTL-to-GDSII flow, serving as a benchmark suite for ML projects.

## Setup

There are two build flows: the original **Make flow** (Docker-based) and the newer **Bazel flow** (native).

### Make Flow Setup

```bash
./setup.sh            # Init ORFS submodule, create symlinks (scripts/, util/, platforms/)
./runorfs.sh           # Launch Docker container with OpenROAD tools
```

### Bazel Flow Setup

Requires an Ubuntu machine with:
- [Bazelisk](https://github.com/bazelbuild/bazelisk) (or Bazel 7.6.1+)
- Docker (for bazel-orfs tool extraction from ORFS image)

No additional setup needed — Bazel fetches ORFS and bazel-orfs automatically via `MODULE.bazel`.

## Build Commands

### Bazel Flow (recommended)

```bash
# Build the full RTL-to-GDS flow for one design
bazel build //designs/asap7/lfsr:lfsr_final

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

Note: `hightide_design()` exposes only the per-stage `orfs_flow` targets (`_synth` … `_final`) plus `_generate_abstract` / `_generate_metadata`. There is no aggregate `:<design>` target — use `:<design>_final` for the full flow.

### Make Flow (legacy)

```bash
# Run full flow for a design (default: asap7/lfsr)
make DESIGN_CONFIG=./designs/<platform>/<design>/config.mk

# Run via Docker non-interactively (use this instead of runorfs.sh which has -it)
./runorfs_ni.sh make DESIGN_CONFIG=./designs/<platform>/<design>/config.mk

# Run with dev RTL generation from source repos
make DESIGN_CONFIG=./designs/<platform>/<design>/config.mk update-rtl

# Individual ORFS flow stages
make DESIGN_CONFIG=... do-synth       # Yosys synthesis
make DESIGN_CONFIG=... do-floorplan   # Floorplan + IO + PDN
make DESIGN_CONFIG=... do-place       # Global/detailed placement
make DESIGN_CONFIG=... do-cts         # Clock tree synthesis
make DESIGN_CONFIG=... do-route       # Global/detailed routing
make DESIGN_CONFIG=... do-finish      # Metal fill + GDSII

# Cleanup
make DESIGN_CONFIG=... clean_design   # Remove dev-generated sources
make DESIGN_CONFIG=... clean_all      # Full cleanup
```

## Architecture

### Key Relationships (Make Flow)

- `Makefile` includes ORFS flow via `-include OpenROAD-flow-scripts/flow/Makefile`
- `settings.mk` overrides ORFS output paths to organize results by `<platform>/<design>/<variant>/`
- Symlinks (`scripts/`, `util/`, `platforms/`) point into the ORFS submodule
- `runorfs.sh` wraps Docker execution with proper mounts and OpenROAD image tags

### Key Relationships (Bazel Flow)

- **`MODULE.bazel`** — Declares dependencies on `bazel-orfs` (via `git_override`) and configures the ORFS Docker image for tool extraction
- **`defs.bzl`** — `hightide_design()` macro wrapping `orfs_flow()` with common defaults (`GDS_ALLOW_EMPTY`, platform-to-PDK mapping)
- **`BUILD.bazel`** (root) — Defines `//:update_rtl` config setting and the `merge_yosys_share` target that bundles the yosys-slang plugin
- Each design has a `BUILD.bazel` calling `hightide_design()` with parameters mirroring its `config.mk`
- RTL sources at `designs/src/<design>/BUILD.bazel` use `select()` to switch between release and dev RTL

### Design Configuration

Each design lives at `designs/<platform>/<design>/` and contains:
- **`config.mk`** — (Make flow) Sets DESIGN_NAME, PLATFORM, VERILOG_FILES, SDC_FILE, utilization/density params. Includes `verilog.mk` from the source directory for RTL file selection.
- **`BUILD.bazel`** — (Bazel flow) Calls `hightide_design()` with equivalent parameters: verilog_files, sources (SDC, LEFs, LIBs), arguments (utilization, density, etc.)
- **`constraint.sdc`** — Clock definitions and timing constraints (shared by both flows)
- **`pdn.tcl`** (optional) — Power delivery network configuration (layer stripes, pitches)
- **`io.tcl`** (optional) — Pin placement constraints

### RTL Source Management (`designs/src/`)

Design sources are git submodules under `designs/src/<design>/dev/repo/`.

**Make flow:** The `update-rtl` make target:
1. Initializes the submodule
2. Runs `designs/src/<design>/dev/setup.sh` to generate Verilog
3. Resumes the ORFS flow from the last completed stage

Each design's `verilog.mk` selects between dev-generated RTL (when `.dev-run-*` flag exists) and pre-generated release RTL.

**Bazel flow:** Each `designs/src/<design>/BUILD.bazel` defines:
- `rtl_release` filegroup — pre-generated Verilog files
- `rtl_dev_gen` genrule — runs setup.sh/sv2v to generate from source
- `rtl` alias — uses `select({"//:update_rtl": ..., "//conditions:default": ...})` to pick

Dev mode requires: `git submodule update --init designs/src/<design>/dev/repo` before `bazel build --define update_rtl=true`.

### Platforms

| Platform | Node | Designs |
|----------|------|---------|
| asap7 | 7nm academic | coralnpu, gemmini, lfsr, minimax, sha3, vortex, liteeth (6 variants), NVDLA (partitions a/c/m/o/p), bp_processor (bp_uno, bp_quad), cnn, floonoc, NyuziProcessor, snitch_cluster |
| nangate45 | 45nm | coralnpu, gemmini, lfsr, minimax, NyuziProcessor, sha3, liteeth (6 variants), bp_processor (bp_uno, bp_quad), cnn |
| sky130hd | 130nm open | gemmini, lfsr, minimax, sha3, liteeth (mac_axi_mii, mac_wb_mii, udp_stream_rgmii, udp_usp_gth_sgmii), cnn, liteeth (udp_raw_rgmii, udp_stream_sgmii) |

#### Build status (as of 2026-04-26)

Designs reaching `_final` (cached on remote build cache):
- **asap7**: coralnpu, gemmini, lfsr, minimax, sha3, vortex, all 6 liteeth variants, NVDLA partitions a/m/o
- **nangate45**: coralnpu, gemmini, lfsr, minimax, NyuziProcessor, sha3, all 6 liteeth variants
- **sky130hd**: gemmini, lfsr, minimax, sha3, liteeth mac_axi_mii / mac_wb_mii / udp_stream_rgmii / udp_usp_gth_sgmii

Not yet finishing (not cached):
- **asap7**: cnn, floonoc, NyuziProcessor, snitch_cluster, bp_processor (bp_uno, bp_quad), NVDLA partitions c, p
- **nangate45**: cnn, bp_processor (bp_uno, bp_quad)
- **sky130hd**: cnn, liteeth udp_raw_rgmii, liteeth udp_stream_sgmii

Use `tools/fetch_cache.sh` to pull cached `_final` results from the remote cache; designs marked NOT CACHED there are the not-yet-finishing set above.

### Output Directories

**Make flow:** Build artifacts go to `{logs,objects,reports,results}/<platform>/<design>/<variant>/`. Key outputs:
- `results/.../6_final.gds` — Final GDSII layout
- `reports/.../` — QoR reports per stage

**Bazel flow:** Build artifacts go to `bazel-bin/designs/<platform>/<design>/`. Key outputs:
- `results/<platform>/<design>/base/6_final.{odb,v,sdc,spef}` — Final ODB and netlist (and `6_final.gds` when `GDS_ALLOW_EMPTY` is not suppressing GDS write)
- `results/<platform>/<design>/base/<N>_<stage>.{odb,sdc,...}` — Per-stage outputs (1_synth, 2_floorplan, 3_place, 4_cts, 5_1_grt, 5_2_route, 6_final)
- `reports/<platform>/<design>/base/` — QoR and OpenROAD-generated `.webp.png` heatmaps/placement images written by ORFS's own report stage
- `logs/<platform>/<design>/base/` — Per-stage logs

### FakeRAM

Designs with embedded memories use FakeRAM (LEF-only, no GDS). Controlled by `GDS_ALLOW_EMPTY := fakeram.*` in settings.mk (Make flow) and set as a default in `defs.bzl` (Bazel flow).

SRAM LEF/LIB files are organized per-platform:
- `designs/<platform>/NyuziProcessor/sram/{lef,lib}/` — NyuziProcessor memories
- `designs/<platform>/liteeth/sram/{lef,lib}/` — liteeth variant memories (shared across variants)
- `designs/asap7/bp_processor/sram/{lef,lib}/` — bp_processor memories
- `designs/src/cnn/fakeram_*.{lef,lib}` — CNN asap7 memories (shared with src dir)
- `designs/{nangate45,sky130hd}/cnn/sram/{lef,lib}/` — CNN per-platform synthetic FakeRAMs (regenerable via `designs/src/cnn/dev/gen_fakeram_{nangate45,sky130hd}.py`)

## Shared Machine

- This is a shared multi-user machine. When checking process status (e.g., `ps aux | grep openroad`), always filter to the current user's processes or check for bazel sandbox paths (`external/bazel-orfs`) to avoid confusing other users' builds with ours.

## Bazel Cache

- **NEVER** run `bazel clean --expunge` or delete the entire disk cache (`~/.cache/bazel-disk-cache`). Synthesis takes hours and clearing the cache forces a full rebuild of all designs.
- To invalidate a single design's cached results, use targeted approaches:
  - Change an argument in the design's BUILD.bazel (forces re-run of affected stages)
  - Use `bazel build --strategy=<target>=local` to bypass cache for one target
- The remote cache (`--remote_cache` in `.bazelrc`) is shared and read-only by default. Never delete or corrupt it.
- If you suspect a stale cache, verify by checking the process count in bazel output: `N processwrapper-sandbox` means N actions actually ran; `N internal` means cached.
