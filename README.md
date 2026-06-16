# HighTide

A VLSI design benchmark suite that runs open-source hardware designs through the [OpenROAD](https://github.com/The-OpenROAD-Project/OpenROAD) RTL-to-GDSII flow on academic and open-source technology nodes (ASAP7 7nm, NanGate 45nm, SkyWater 130nm).

**New here?** See the **[Quick Start Guide](docs/quickstart.md)** to build your first design in 5 minutes. For the full, up-to-date list of designs and the platforms each one closes on, see the **[Design Catalog](docs/designs.md)**.

## How It Works

Each design's upstream source lives in a git submodule at `designs/src/<design>/dev/repo/`. A build script converts the source HDL (SystemVerilog, Chisel, LiteX, etc.) into plain Verilog, which is checked into the repo as the **release RTL** at `designs/src/<design>/`. The release RTL may include patches or modifications beyond simple conversion — for example, SRAM memories are replaced with FakeRAM black-box macros so the design can be synthesized without an SRAM compiler. This release RTL is what builds use by default — no submodule checkout or conversion tools needed.

To regenerate RTL from the upstream source (e.g., after updating the submodule to a newer commit):

```bash
bazel build --define update_rtl=true //designs/asap7/lfsr:lfsr_final
```

The release RTL is then run through the [OpenROAD-flow-scripts](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts) RTL-to-GDSII flow: synthesis (Yosys) → floorplan → placement → clock tree synthesis → routing → GDSII output. Each design has per-platform configuration (clock constraints, utilization targets, pin placement) tuned for the target technology node.

## Running a design in upstream ORFS (for OpenROAD researchers)

The Bazel (`bazel-orfs`) flow is HighTide's golden, supported entry
point. But if you want to experiment with **a custom OpenROAD build**,
**modified flow Tcl scripts**, or **added/changed flow steps**, plain
`OpenROAD-flow-scripts` (a single `config.mk` + the standard `Makefile`)
is the easier interface. Two tools bridge the gap.

### One command: `tools/run_orfs.sh`

```bash
# Fast, zero-setup: reuse the golden synthesized netlist + bazel openroad,
# full place-and-route:
tools/run_orfs.sh designs/asap7/lfsr

# Your own OpenROAD build, only through placement:
tools/run_orfs.sh --openroad ~/OpenROAD/build/src/openroad \
                  designs/asap7/lfsr floorplan place

# Re-synthesize from RTL in your own ORFS install (its yosys + slang):
tools/run_orfs.sh --resynth --flow-home ~/OpenROAD-flow-scripts designs/asap7/lfsr
```

It extracts the design's resolved `config.mk` and runs the standard ORFS
`Makefile`. There are two synthesis modes:

- **Default (reuse synth):** reuses the synthesized netlist bazel-orfs
  already produced (`results/.../1_synth.{odb,sdc}`) and runs only
  floorplan onward. Fast and zero-setup — **no yosys/slang needed** — and
  runs against the ORFS bazel-orfs already resolved. Best for iterating on
  placement, routing, or the OpenROAD binary (`--openroad` sets
  `OPENROAD_EXE`). The netlist already reflects your constraints/RTL *if*
  you rebuild through bazel; to re-synthesize entirely in plain ORFS, use
  `--resynth`.
- **`--resynth` (from RTL):** runs the *whole* flow including synthesis in
  your ORFS install, using its own yosys + yosys-slang. Honors changes to
  constraints, RTL, or the synthesis flow itself — but slower, and requires
  `--flow-home` pointing at a **built** OpenROAD-flow-scripts install (one
  whose `tools/install` has yosys; ORFS's slang support is built in).

To **edit flow scripts or steps**, point `--flow-home` at your own ORFS
checkout and edit `flow/scripts/*.tcl` there.

**QoR comparability:** HighTide's published numbers come from the bazel-orfs
build, which pins specific tool commits (bazel-orfs, OpenROAD, and the ORFS
commit `run_orfs.sh` prints). A `--resynth` run against a *different* ORFS /
yosys shifts the baseline, and some extracted `config.mk` workaround
variables (e.g. `SKIP_CTS_REPAIR_TIMING`, `SETUP_MOVE_SEQUENCE`, `write_sdc`
async-reset edits) may be unnecessary or stale — review them against your
ORFS.

### Just the config.mk: `tools/bazel_to_config_mk.sh`

To drive ORFS yourself, extract an ORFS-compatible `config.mk` (with
`--abs`, absolute paths that run from any directory):

```bash
tools/bazel_to_config_mk.sh --abs designs/asap7/lfsr /tmp/lfsr.config.mk
make -C OpenROAD-flow-scripts/flow DESIGN_CONFIG=/tmp/lfsr.config.mk
```

This costs no synthesis or place-and-route: it builds only each stage's
`<stage>.mk` config output group (cheap bazel *analysis*, seconds), unions
the `export VAR?=VALUE` lines, strips Bazel-internal vars, and adds the
cquery-resolved `VERILOG_FILES`. (`run_orfs.sh`'s default reuse-synth mode
additionally builds just the `_synth` stage to get the netlist; `--resynth`
re-synthesizes in your ORFS install and needs no bazel flow build at all.)

### Alternative: a custom OpenROAD inside bazel-orfs (binary swap only)

If you only need a different OpenROAD binary and want to keep bazel's
caching, override the `openroad` label instead of leaving bazel — per
design via `openroad = "//path/to:my_openroad"` on the
`hightide_design()`/`orfs_flow()` call, or globally in `MODULE.bazel`:

```starlark
orfs = use_extension("@bazel-orfs//:extension.bzl", "orfs_repositories")
orfs.default(openroad = "@my_openroad//:openroad")
```

This cannot modify flow Tcl scripts (`FLOW_HOME` is pinned) — use the
`config.mk` path above for flow-script or flow-step changes.

## Documentation

- **[Quick Start Guide](docs/quickstart.md)** — install, build, and view results
- **[Design Catalog](docs/designs.md)** — all designs, platforms, variants, and complexity
- **[Architecture](docs/architecture.md)** — build system, flow stages, RTL management, caching
- **[Adding Designs](docs/adding-designs.md)** — how to add a new design to the suite
- **[Kubernetes Builds](k8s/README.md)** — building at scale on NRP Nautilus
