# HighTide

A VLSI design benchmark suite that runs open-source hardware designs through the [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD) RTL-to-GDSII flow on academic and open-source technology nodes (ASAP7 7nm, NanGate 45nm, SkyWater 130nm).

## Quick Start

```bash
# Install Bazel
sudo apt install perl
sudo wget -O /usr/local/bin/bazel https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
sudo chmod +x /usr/local/bin/bazel

# Clone and build
git clone git@github.com:VLSIDA/HighTide.git
cd HighTide
bazel build //designs/asap7/lfsr:lfsr_final
```

Requires Linux and Docker. Bazel automatically fetches ORFS and tools. See the [Quick Start Guide](docs/quickstart.md) for details.

## Designs

| Design | Type | asap7 | nangate45 | sky130hd |
|--------|------|:-----:|:---------:|:--------:|
| lfsr | LFSR/PRBS generator | x | x | x |
| minimax | RISC-V RV32I core | x | x | x |
| liteeth | Ethernet MAC (6 variants) | x | x | x |
| NyuziProcessor | Multi-threaded GPGPU | x | x | |
| bp_processor | Black-Parrot RISC-V (2 variants) | x | x | |
| gemmini | ML systolic array | x | x | |
| cnn | CNN accelerator | x | x | |
| sha3 | SHA3 hash | x | x | |

See the [Design Catalog](docs/designs.md) for the full matrix including variants and complexity.

## Build Commands

```bash
# Single design, full flow
bazel build //designs/asap7/lfsr:lfsr_final

# Individual stages (synth, floorplan, place, cts, route, final)
bazel build //designs/asap7/lfsr:lfsr_synth

# All designs for a platform
bazel build //designs/asap7/...

# All designs, all platforms
bazel build //designs/...

# View build summary
./tools/summary.sh
```

## Fetch Pre-built Results

Baseline results for all designs are available from a remote cache:

```bash
./tools/fetch_cache.sh              # all designs
./tools/fetch_cache.sh asap7 lfsr   # specific design
```

## Documentation

- **[Quick Start Guide](docs/quickstart.md)** — build your first design in 5 minutes
- **[Design Catalog](docs/designs.md)** — all designs, platforms, and complexity
- **[Architecture](docs/architecture.md)** — how the build system, RTL management, and caching work
- **[Adding Designs](docs/adding-designs.md)** — how to add a new design to the suite
- **[Kubernetes Builds](k8s/README.md)** — building at scale on NRP Nautilus

## RTL Regeneration

Designs use pre-generated Verilog by default. To regenerate from upstream source:

```bash
bazel build --define update_rtl=true //designs/asap7/lfsr:lfsr_final
```

Some designs require additional tools (sv2v, JDK, Python) on PATH.

## Legacy Make Flow

The Make flow is still available for designs that have a `config.mk`:

```bash
./setup.sh                  # init ORFS submodule
./runorfs.sh                # launch Docker
make DESIGN_CONFIG=./designs/asap7/lfsr/config.mk
```
