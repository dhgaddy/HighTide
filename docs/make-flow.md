# Legacy Make Flow

The original HighTide build flow uses GNU Make and Docker. It is still functional but the **Bazel flow is recommended** for new work — see the [Quick Start Guide](quickstart.md).

## Setup

```bash
# Clone the repo
git clone git@github.com:VLSIDA/HighTide.git
cd HighTide

# Initialize the ORFS submodule and create symlinks
./setup.sh
```

This clones OpenROAD-flow-scripts as a submodule and creates symlinks (`scripts/`, `util/`, `platforms/`) pointing into it.

## Running a Build

Launch the Docker container, then run Make inside it:

```bash
# Interactive (with terminal)
./runorfs.sh
make DESIGN_CONFIG=./designs/asap7/lfsr/config.mk

# Non-interactive (for scripting / CI)
./runorfs_ni.sh make DESIGN_CONFIG=./designs/asap7/lfsr/config.mk
```

The Docker image tag is extracted from `MODULE.bazel` to stay in sync with the Bazel flow.

## Individual Stages

```bash
make DESIGN_CONFIG=./designs/asap7/lfsr/config.mk do-synth       # Yosys synthesis
make DESIGN_CONFIG=./designs/asap7/lfsr/config.mk do-floorplan   # Floorplan + IO + PDN
make DESIGN_CONFIG=./designs/asap7/lfsr/config.mk do-place       # Global/detailed placement
make DESIGN_CONFIG=./designs/asap7/lfsr/config.mk do-cts         # Clock tree synthesis
make DESIGN_CONFIG=./designs/asap7/lfsr/config.mk do-route       # Global/detailed routing
make DESIGN_CONFIG=./designs/asap7/lfsr/config.mk do-finish      # Metal fill + GDSII
```

## Output Directories

Build artifacts are organized by platform, design, and variant:

```
logs/<platform>/<design>/base/       # Per-stage log files
objects/<platform>/<design>/base/    # Intermediate objects
reports/<platform>/<design>/base/    # QoR reports (timing, area, DRC)
results/<platform>/<design>/base/    # ODB and GDS files per stage
```

This layout is controlled by `settings.mk`, which overrides ORFS defaults.

## RTL Regeneration

To regenerate Verilog from the upstream source repository:

```bash
make DESIGN_CONFIG=./designs/asap7/lfsr/config.mk update-rtl
```

This initializes the git submodule, runs the design's `setup.sh` to generate Verilog, then resumes the flow from the last completed stage.

## Cleanup

```bash
# Remove dev-generated sources
make DESIGN_CONFIG=./designs/asap7/lfsr/config.mk clean_design

# Full cleanup (sources + build artifacts)
make DESIGN_CONFIG=./designs/asap7/lfsr/config.mk clean_all
```

## Design Configuration

Each design's Make-flow configuration is in `designs/<platform>/<design>/config.mk`. This file sets:

- `DESIGN_NAME`, `PLATFORM` — design identity
- `VERILOG_FILES` — RTL sources (via `-include verilog.mk`)
- `SDC_FILE` — timing constraints
- `CORE_UTILIZATION`, `PLACE_DENSITY` — physical design parameters
- `ADDITIONAL_LEFS`, `ADDITIONAL_LIBS` — FakeRAM files (if applicable)
- `PDN_TCL`, `IO_CONSTRAINTS`, `FOOTPRINT_TCL` — custom physical design scripts

The config.mk parameters mirror those in the Bazel BUILD.bazel files. Both are kept in sync so either flow can be used.

## Differences from Bazel Flow

| Aspect | Make Flow | Bazel Flow |
|--------|-----------|------------|
| Dependencies | Manual (`./setup.sh` + Docker) | Automatic (Bazel fetches everything) |
| Caching | None (rebuild from scratch) | Remote + local Bazel cache |
| Parallelism | One design at a time | Multiple designs in parallel |
| Tool extraction | Docker container at runtime | OCI layer extraction at build time |
| K8s support | No | Yes (`k8s/run.sh`) |
| Config file | `config.mk` | `BUILD.bazel` |
