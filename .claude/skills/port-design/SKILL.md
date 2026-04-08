---
name: port-design
description: Port an existing HighTide2 design from one technology platform to another (e.g., asap7 to nangate45 or sky130hd). Use when a design exists for one platform and needs to be added to another.
argument-hint: "[design-name] [source-platform] [target-platform]"
---

# Port a Design to a New Platform

You are porting the design `$0` from `$1` to `$2`.

## Prerequisites

Before starting, verify:
- The design exists at `designs/$1/$0/` with a working config.mk and BUILD.bazel
- The RTL source exists at `designs/src/$0/` (shared across platforms)

## Step-by-step Process

### 1. Analyze the source design

Read the source platform's configuration to understand:
- `designs/$1/$0/config.mk` — all ORFS parameters
- `designs/$1/$0/BUILD.bazel` — Bazel flow configuration
- `designs/$1/$0/constraint.sdc` — clock period and port names
- Whether it has FakeRAM memories (ADDITIONAL_LEFS/ADDITIONAL_LIBS)
- Whether it has custom pdn.tcl or io.tcl
- Whether it uses a macros.v wrapper (for designs that remap memory instantiations)
- Whether it's a multi-variant design with subdirectories

Also study existing designs on the target platform to understand conventions:
- Read 2-3 existing `designs/$2/*/config.mk` and `BUILD.bazel` files
- Note the metal layer names and parameter conventions

### 2. Calibrate scaling ratios from existing cross-platform designs

Compare designs that already exist on both platforms to determine scaling factors. Read the constraint.sdc and config.mk for each shared design on both `$1` and `$2`.

**Clock period scaling:** For each design on both platforms, compute the ratio `target_period / source_period`. Average these ratios to get a clock scaling factor. Be mindful of unit differences (asap7 uses picoseconds, nangate45/sky130hd use nanoseconds).

**Area scaling:** For designs using explicit `DIE_AREA`/`CORE_AREA`, compute the ratio of die areas between platforms. For designs using `CORE_UTILIZATION`, note that utilization percentages are generally kept similar across platforms.

Apply these empirically-derived ratios when creating the new design's SDC and floorplan parameters.

### 3. Platform-specific constants reference

| Parameter | asap7 (7nm) | nangate45 (45nm) | sky130hd (130nm) |
|-----------|-------------|------------------|------------------|
| Clock period units | picoseconds | nanoseconds | nanoseconds |
| Nominal voltage | 0.7V | 1.1V | 1.8V |
| Metal layer names | M1-M9 | metal1-metal10 | met1-met5 |
| FakeRAM pin layer | M4 | metal3 | met3 |
| FakeRAM OBS layers | M1, M2, M3 | metal1-metal4 | met1-met3 |
| Site snap (w x h) | 0.054 x 0.270 | 0.190 x 1.400 | 0.460 x 2.720 |
| Pin width | 0.024 | 0.140 | 0.170 |
| Pin pitch | 0.144 | 1.400 | 2.720 |
| Area per bit (FakeRAM) | 0.5 | 3.8 | 10.0 |

### 4. Create the target platform design directory

```bash
mkdir -p designs/$2/$0
```

For multi-variant designs, mirror the source directory structure.

### 5. Create constraint.sdc

Scale the clock period using the ratio derived in step 2. Keep the same clock name, port name, and IO percentage.

Use the standard SDC template matching the target platform's conventions (ns-based periods, `[expr $clk_period * $clk_io_pct]` for IO delays).

**Important:** asap7 SDC files sometimes use fixed input/output delays (e.g., `set_input_delay 10`). For other platforms, use the `[expr $clk_period * $clk_io_pct]` pattern instead.

### 6. Create config.mk

Copy the source config.mk and modify:
- Change `PLATFORM` to `$2`
- Keep the same `DESIGN_NAME` and synthesis parameters (`SYNTH_HIERARCHICAL`, `ABC_AREA`, `TNS_END_PERCENT`)
- Scale `CORE_UTILIZATION` down for larger technology nodes. Designs with high routing demand (wide combinational datapaths like sha3) may need significantly lower utilization on nangate45/sky130hd than on asap7 because the routing resources per unit area are different. Calibrate using existing cross-platform designs. As a rule of thumb, reduce utilization by ~30-35% from asap7 to nangate45 (e.g., 70% → 45%).
- Prefer `PLACE_DENSITY_LB_ADDON` over fixed `PLACE_DENSITY` — it adapts better to different die sizes
- If the source uses `DIE_AREA`/`CORE_AREA` (explicit dimensions), scale them using the area ratio from step 2, or switch to `CORE_UTILIZATION` to let ORFS auto-size
- Update `ADDITIONAL_LEFS`/`ADDITIONAL_LIBS` paths to point to `$2` platform directory
- Scale `MACRO_PLACE_HALO` proportionally to technology node (e.g., if asap7 uses `6 6`, nangate45 might use `40 40` based on the ratio seen in existing designs)

### 7. Create BUILD.bazel

Follow the pattern from existing designs on the target platform. Key changes:
- Set `platform = "$2"`
- Update SRAM LEF/LIB references to point to the new platform's sram/ directory
- Keep the same RTL source references (`//designs/src/$0:rtl`)

For designs with memories, create a parent BUILD.bazel with filegroups:
```python
package(default_visibility = ["//designs/$2/$0:__subpackages__"])

filegroup(name = "sram_lefs", srcs = glob(["sram/lef/*.lef"]))
filegroup(name = "sram_libs", srcs = glob(["sram/lib/*.lib"]))
```

**Bazel PDK availability:** Not all platforms have Bazel PDK targets defined in bazel-orfs. The PDK list is in `docker.BUILD.bazel` within the bazel-orfs repo. If the target platform is not in that list, the Bazel flow will fail with "no such target" for the platform's config.mk. To add a new platform to the Bazel flow:
1. Check bazel-orfs's `docker.BUILD.bazel` for the current PDK list
2. If the target platform is missing, add it to the `for pdk in [...]` loop in `docker.BUILD.bazel` upstream in bazel-orfs
3. Until that's merged, create the design files anyway (config.mk, BUILD.bazel, constraint.sdc) — the Make flow will work, and the Bazel flow will work once the PDK is added upstream

### 8. Generate FakeRAM files (if design has memories)

Designs with embedded memories need platform-specific FakeRAM LEF and LIB files. The FakeRAM LEF/LIB are placeholder black boxes — exact timing is not critical. What matters is:
1. Pin names match the Verilog module interface exactly
2. Metal layer names are correct for the target platform
3. The macro is large enough to fit all pins
4. Voltage in the LIB matches the platform

Check if the design already has a FakeRAM generator script in `designs/src/$0/dev/`. If so, check whether it supports a `--platform` flag for the target platform. If not, either extend it or create a new generator.

The generator should use the platform-specific constants from the table in step 3 (metal layer names, pin dimensions, voltage, area scaling). See `designs/src/bp_processor/dev/gen_fakeram.py` for an example of a platform-aware generator with a `PLATFORM_PARAMS` dict.

Place generated files at:
```
designs/$2/$0/sram/lef/fakeram_*.lef
designs/$2/$0/sram/lib/fakeram_*.lib
```

If the design uses a macros.v wrapper, generate or copy that too — the Verilog content is platform-independent (same FakeRAM module names).

### 9. Port pdn.tcl (if applicable)

If the source design has a custom pdn.tcl, the ported design will likely need one too — the same design characteristics (macro density, power distribution needs) that motivated a custom PDN on the source platform apply on the target.

Port the pdn.tcl by:
- Translating metal layer names to the target platform (see table in step 3)
- Scaling stripe widths and pitches proportionally using the area scaling ratio from step 2
- Updating the top-level pin layer to match the target platform's metal stack
- Checking that macro grid halo values are scaled appropriately

Without a ported pdn.tcl, the design will likely have IR drop issues in the final analysis.

### 10. Port io.tcl (if applicable)

If the source design has a custom io.tcl, the ported design will likely need one too — the same pin count and routing congestion concerns apply regardless of technology.

Port the io.tcl by:
- Scaling all coordinates using the area scaling ratio from step 2 (die dimensions change with technology)
- Translating metal layer names to the target platform
- Adjusting pin spacing to respect the target platform's routing pitch

If coordinate scaling is impractical (e.g., the source uses procedural placement with many hardcoded values), consider rewriting the io.tcl using `set_io_pin_constraint` with region-based placement instead of exact coordinates.

### 11. Test the build

```bash
# Bazel flow
bazel build //designs/$2/$0:$0_synth    # Test synthesis first
bazel build //designs/$2/$0:$0_final    # Full flow

# Make flow
make DESIGN_CONFIG=./designs/$2/$0/config.mk
```

If synthesis fails, check:
- FakeRAM module names match between Verilog and LEF/LIB
- Clock port name in SDC matches the actual top-level port
- VERILOG_FILES paths are correct

If placement/routing fails, try:
- Lowering `CORE_UTILIZATION` (e.g., from 49 to 40)
- Increasing `MACRO_PLACE_HALO`
- Adding `PLACE_DENSITY_LB_ADDON`

### 12. Verify generated files

After a successful build, check:
- `reports/$2/$0/*/` for QoR reports
- No DRC violations in the final report
- Timing meets the target clock period (some slack is expected for initial ports)
