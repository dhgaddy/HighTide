# Adding a New Design

This guide covers adding a new open-source hardware design to the HighTide benchmark suite.

For a fully guided workflow, use the Claude Code skill: `/new-design <design-name> <upstream-repo-url>`

## Overview

Adding a design involves:
1. Adding the upstream repo as a git submodule
2. Creating a build script to generate Verilog from the source HDL
3. Creating platform-specific configuration (SDC, config.mk, BUILD.bazel)
4. Creating FakeRAM files if the design has embedded memories
5. Testing the build

## Directory Structure

A fully configured design looks like:

```
designs/
├── src/<design>/
│   ├── <design>.v              # Release RTL (pre-generated)
│   ├── verilog.mk              # Make-flow RTL selection
│   ├── BUILD.bazel             # Bazel RTL source definition
│   └── dev/
│       ├── repo/               # Git submodule (upstream source)
│       └── setup.sh            # Build script to generate Verilog
├── asap7/<design>/
│   ├── BUILD.bazel             # Bazel flow config
│   ├── config.mk               # Make flow config
│   ├── constraint.sdc          # Timing constraints
│   ├── pdn.tcl                 # (optional) Custom power delivery
│   ├── io.tcl                  # (optional) Custom pin placement
│   └── sram/                   # (if memories)
│       ├── lef/*.lef
│       └── lib/*.lib
├── nangate45/<design>/         # Same structure, different params
└── sky130hd/<design>/          # Same structure, different params
```

## Step-by-Step

### 1. Add the submodule

```bash
git submodule add <upstream-url> designs/src/<design>/dev/repo
```

### 2. Create the build script

`designs/src/<design>/dev/setup.sh` must convert the upstream HDL to plain Verilog. See existing examples:

| Source Language | Approach | Reference |
|----------------|----------|-----------|
| Pure Verilog | Direct (no conversion) | `designs/src/lfsr/dev/setup.sh` |
| SystemVerilog | **yosys-slang** (preferred) — synthesize SV directly | `designs/src/bp_processor/` |
| SystemVerilog | sv2v — convert to Verilog first | `designs/src/minimax/dev/setup.sh` |
| Chisel/Scala | JDK + sbt to generate Verilog | `designs/src/gemmini/dev/setup.sh` |
| LiteX/Python | Python venv + LiteX | `designs/src/liteeth/dev/setup.sh` |
| Veriloggen | Python venv + NNgen | `designs/src/cnn/dev/setup.sh` |

#### Using yosys-slang for SystemVerilog

For SystemVerilog designs, **yosys-slang is preferred over sv2v** because it handles parameter elaboration natively and avoids the sv2v conversion step. To use it:

1. The `setup.sh` parses the upstream file list and include paths (no Verilog conversion needed)
2. Set `"SYNTH_HDL_FRONTEND": "slang"` in the BUILD.bazel arguments
3. Pass include directories via `"VERILOG_INCLUDE_DIRS": "<space-separated paths>"`
4. Pass defines via `"VERILOG_DEFINES": "-D YOSYS"` (or other defines the design needs)

See `designs/src/bp_processor/defs.bzl` for a complete example:
```python
BP_COMMON_ARGS = {
    "SYNTH_HDL_FRONTEND": "slang",
    "VERILOG_DEFINES": "-D YOSYS",
    "VERILOG_INCLUDE_DIRS": BP_INCLUDE_DIRS_STR,
    "SYNTH_HIERARCHICAL": "1",
    ...
}
```

The `setup.sh` for bp_processor (`designs/src/bp_processor/dev/setup.sh`) shows how to parse an upstream `flist.vcs` file list into the format needed by Bazel — it extracts source files and include directories without any HDL conversion.

### 3. Create timing constraints

`designs/<platform>/<design>/constraint.sdc`:

```tcl
current_design <top_module>

set clk_name  core_clock
set clk_port_name clk
set clk_period <period>           # See platform guidance below
set clk_io_pct 0.2

set clk_port [get_ports $clk_port_name]
create_clock -name $clk_name -period $clk_period $clk_port

set non_clock_inputs [lsearch -inline -all -not -exact [all_inputs] $clk_port]
set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_name [all_outputs]
```

**Clock period guidance:**
- asap7: 500-1000 ps
- nangate45: 2-10 ns
- sky130hd: 10-50 ns

### 4. Create the Bazel build

`designs/<platform>/<design>/BUILD.bazel`:

```python
load("//:defs.bzl", "hightide_design")

hightide_design(
    name = "<design>",
    platform = "<platform>",
    verilog_files = ["//designs/src/<design>:rtl"],
    sources = {"SDC_FILE": [":constraint.sdc"]},
    arguments = {
        "CORE_UTILIZATION": "40",
        "TNS_END_PERCENT": "100",
    },
)
```

For designs with FakeRAM, add SRAM sources:
```python
    sources = {
        "SDC_FILE": [":constraint.sdc"],
        "ADDITIONAL_LEFS": ["//<parent>:sram_lefs"],
        "ADDITIONAL_LIBS": ["//<parent>:sram_libs"],
    },
    arguments = {
        "CORE_UTILIZATION": "40",
        "MACRO_PLACE_HALO": "5 5",
        "TNS_END_PERCENT": "100",
    },
```

### 5. Create FakeRAM (if needed)

If the design has large memories (typically >256 bits), create FakeRAM LEF/LIB files. Use existing files from the same platform as templates:
- Pin names must match the Verilog module interface exactly
- Metal layer names must match the platform
- See `designs/src/bp_processor/dev/gen_fakeram.py` for an automated generator

### 6. Test

```bash
bazel build //designs/<platform>/<design>:<design>_synth   # test synthesis first
bazel build //designs/<platform>/<design>:<design>_final   # full flow
```

If the build fails, use `/debug-design <platform>/<design>` to diagnose.

After a successful build, use `/optimize-ppa <platform>/<design>` to tune utilization and clock frequency.

## Porting to Additional Platforms

To add a design that already exists on one platform to another, use `/port-design <design> <source-platform> <target-platform>`. Key considerations:

- Scale clock period proportionally between platforms
- Create platform-specific FakeRAM files (different metal stacks)
- Adjust utilization — designs may need lower utilization on larger nodes due to different routing resource ratios
