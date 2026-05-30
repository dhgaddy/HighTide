---
name: new-design
description: Incorporate a new open-source hardware design into the HighTide benchmark suite. Use when adding a design that doesn't exist yet in the project.
argument-hint: "[design-name] [upstream-repo-url]"
---

# Incorporate a New Design

You are adding a new design called `$0` from upstream repository `$1` into the HighTide benchmark suite.

## Step-by-step Process

### 1. Understand the upstream design

- Clone or browse the upstream repo to understand:
  - What HDL it uses (Verilog, SystemVerilog, Chisel/Scala, LiteX/Python, etc.)
  - The top-level module name and its ports (especially clock, reset, data buses)
  - Whether it has substantial embedded memories (register files, FIFOs, caches, etc.)
  - Any build dependencies needed to generate Verilog (sv2v, sbt, Python venv, etc.)

### 2. Add the git submodule

```bash
git submodule add <UPSTREAM_URL> designs/src/$0/dev/repo
```

### 3. Create `designs/src/$0/dev/setup.sh`

This script must:
- `cd` to its own directory: `cd "$(dirname $(readlink -f $0))"`
- Install any required build tools locally if not present (sv2v, JDK, Python venv, etc.)
- Generate flat Verilog from the upstream source
- Place the output at a known location (e.g., `dev/generated/$0.v` or `dev/$0.v`)

The setup.sh must install all dependencies needed to convert the source HDL to plain Verilog. Follow existing patterns:
- **SystemVerilog designs**: Use either sv2v (see `designs/src/minimax/dev/setup.sh`) or yosys-slang. The setup.sh must build/install the chosen tool locally if not present.
- **Pure Verilog designs**: May just need file copying (see `designs/src/lfsr/dev/setup.sh`)
- **Chisel/Scala designs**: Install JDK + sbt locally, run sbt to generate Verilog (see `designs/src/gemmini/dev/setup.sh`)
- **LiteX/Python designs**: Create Python venv, pip install all dependencies, generate Verilog (see `designs/src/liteeth/dev/setup.sh`)
- **Veriloggen/Python designs**: Create Python venv, pip install dependencies including Veriloggen/NNgen, generate Verilog (see `designs/src/cnn/dev/setup.sh`)

### 4. Create `designs/src/$0/BUILD.bazel`

This file declares RTL filegroups and a `select()` alias that switches
between release and dev-generated Verilog. Follow this pattern (see
`designs/src/lfsr/BUILD.bazel` for the simplest reference):

```python
filegroup(
    name = "rtl_release",
    srcs = ["$0.v"],   # or multiple .v files
)

genrule(
    name = "rtl_dev_gen",
    srcs = [],
    outs = ["dev_$0.v"],
    local = True,
    cmd = """
        WORKSPACE_ROOT=$$(readlink -f $(location //:tools/update_rtl.sh) | sed 's|/tools/update_rtl.sh||')
        cd $$WORKSPACE_ROOT
        git submodule update --init designs/src/$0/dev/repo >&2
        bash designs/src/$0/dev/setup.sh >&2
        cp designs/src/$0/dev/generated/$0.v $(location dev_$0.v)
    """,
    tools = ["//:tools/update_rtl.sh"],
)

alias(
    name = "rtl",
    actual = select({
        "//:update_rtl": ":rtl_dev_gen",
        "//conditions:default": ":rtl_release",
    }),
    visibility = ["//visibility:public"],
)
```

Designs with many generated files typically wrap the genrule output in
a `filegroup` and glob over `dev/generated/**/*.v` — see
`designs/src/snitch_cluster/BUILD.bazel` or
`designs/src/bp_processor/BUILD.bazel` for richer examples.

### 5. Identify and create FakeRAM black-box memories

Analyze the design's Verilog for any substantial memory arrays. These include:
- Register files, SRAMs, caches, FIFOs with significant depth
- Any module that infers a large memory (typically >32 entries or >256 total bits)

For each memory found, create FakeRAM LEF and LIB files:

**Naming convention:** `fakeram_<width>x<depth>_<ports>.{lef,lib}`
- Ports: `1r1w` (1 read, 1 write), `2r1w` (2 read, 1 write), `1rw` (1 read/write), etc.

**LEF file structure** (see `designs/asap7/NyuziProcessor/sram/lef/` for examples):
- Define a MACRO with CLASS BLOCK
- SIZE should be estimated proportionally to the memory size (use existing FakeRAMs as reference for scaling)
- Include pins for: data input bus, data output bus, address bus(es), write enable, chip enable, clock
- Include VDD/VSS power pins
- Include OBS (obstruction) layers for M1-M4
- Pin placement: distribute signal pins across the macro edges on M3/M4 layers

**LIB file structure** (see `designs/asap7/NyuziProcessor/sram/lib/` for examples):
- Liberty format with timing/power tables
- Define pin groups matching the LEF: data, address, control, clock
- Include setup/hold constraints and clk-to-q delays
- Use placeholder timing values consistent with the technology node

**Place FakeRAM files at:** `designs/<platform>/$0/sram/lef/` and `designs/<platform>/$0/sram/lib/`

The same memory may need different LEF/LIB files per platform due to different metal layer stacks and design rules. Use existing FakeRAM files from the same platform as templates.

### 6. Create platform-specific design directories

For each target platform (start with one, typically asap7), create `designs/<platform>/$0/` with:

**`BUILD.bazel`** (required):
```python
load("//:defs.bzl", "hightide_design")

hightide_design(
    name = "$0",
    top = "$0",          # set if the top module name differs from name
    platform = "<platform>",
    verilog_files = ["//designs/src/$0:rtl"],
    sources = {
        "SDC_FILE": [":constraint.sdc"],
    },
    arguments = {
        "CORE_UTILIZATION": "40",
        "CORE_ASPECT_RATIO": "1.0",
        "CORE_MARGIN": "4",
        "PLACE_DENSITY": "0.7",
        "TNS_END_PERCENT": "100",
    },
)
```

If the design uses FakeRAM, add the LEF/LIB sources and bump halo:
```python
    sources = {
        "SDC_FILE": [":constraint.sdc"],
        "ADDITIONAL_LEFS": [":sram_lefs"],   # filegroup over sram/lef/*.lef
        "ADDITIONAL_LIBS": [":sram_libs"],
    },
    arguments = {
        ...
        "MACRO_PLACE_HALO": "5 5",
    },
```

(`GDS_ALLOW_EMPTY = fakeram.*` is set by `hightide_design()` by default.)

For large designs, consider:
```python
    arguments = {
        ...
        "SYNTH_HIERARCHICAL": "1",
        "ABC_AREA": "1",
    },
```

**`constraint.sdc`** (required):
```tcl
current_design $0

set clk_name  clock
set clk_port_name clk
set clk_period <appropriate_period_ns>
set clk_io_pct 0.2

set clk_port [get_ports $clk_port_name]
create_clock -name $clk_name -period $clk_period $clk_port

set non_clock_inputs [lsearch -inline -all -not -exact [all_inputs] $clk_port]
set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_name [all_outputs]
```

Adjust `clk_port_name` and `clk_period` based on the actual design. Check the top-level module ports for the clock signal name. For clock period:
- asap7: typically 500-1000 ps (0.5-1.0 ns)
- nangate45: typically 2-10 ns
- sky130hd: typically 10-50 ns

### 7. Optionally create pdn.tcl and io.tcl

Most designs work fine with platform defaults. These are needed in specific situations:

- **`pdn.tcl`** — Create a custom power delivery network when IR drop violations occur. Use `designs/asap7/gemmini/pdn.tcl` as a reference. This adds extra power stripes on higher metal layers to reduce IR drop.
- **`io.tcl`** — Create custom IO pin placement when the design has a large number of IOs or when there is routing congestion around the IO pins. Use `designs/asap7/gemmini/io.tcl` as a reference. This manually assigns pins to specific die edges and metal layers to spread them out.

**Congestion troubleshooting priority:** It is preferable to keep cell utilization high. If congestion occurs, try fixing IO placement first (`io.tcl`), then adjusting `MACRO_PLACE_HALO`, then `PLACE_PINS_ARGS = -min_distance <N> -min_distance_in_tracks`. Only lower `CORE_UTILIZATION` as a last resort.

### 8. Generate and check in release RTL

Run the dev RTL generator, then commit the result to the release location:
```bash
# Generate via dev mode (initializes submodule + runs setup.sh)
bazel build --define update_rtl=true //designs/src/$0:rtl

# Copy generated RTL out of the bazel-bin tree to the release location
cp bazel-bin/designs/src/$0/dev_$0.v designs/src/$0/$0.v
```

### 9. Test the flow

```bash
# Build with release RTL (default)
bazel build //designs/<platform>/$0:$0_final

# Build with dev RTL regenerated from the upstream submodule
bazel build --define update_rtl=true //designs/<platform>/$0:$0_final
```

For incremental work, build a single stage instead of the full flow:
```bash
bazel build //designs/<platform>/$0:$0_synth
bazel build //designs/<platform>/$0:$0_place
```

### 10. Port to additional platforms

Repeat step 6 for nangate45 and sky130hd as needed. Each platform needs its own:
- `BUILD.bazel` (adjust utilization/density for the technology)
- `constraint.sdc` (adjust clock period for the technology)
- `sram/` directory with platform-specific FakeRAM files (if applicable)

### 11. Create DECISIONS.md

Create `designs/src/$0/DECISIONS.md` with one `## <platform>` section per technology this design targets. Use `designs/src/gemmini/DECISIONS.md` as the canonical template (header + per-variant table + per-platform sections).

Each platform section should capture:
- **Status**: `finishing` or `not yet finishing`
- **Configuration**: a table of every non-default `BUILD.bazel` `arguments` knob, the SDC clock period, and which `pdn.tcl` / `io.tcl` / `pre_cts.tcl` files are wired in.
- **Decisions**: dated bullet list of the non-obvious calls made (why this utilization, why this SDC, what congestion / IR / timing surfaces you fought), with commit hashes.
- **Known issues / open questions**: active workarounds, anything pending.

For pre-existing designs that need a DECISIONS.md retroactively, the `update-design --init-decisions <design>` skill bootstraps a starter file from git history + BUILD.bazel + SDC.

**Do not** add the new design's narrative to `CLAUDE.md`. CLAUDE.md's "Build status" is a pure index of which (design, platform) pairs reach `_final`; per-design narrative belongs in DECISIONS.md. Update CLAUDE.md only to add the design to the Platforms table and to the appropriate status list (cached / local-only / not-finishing).
