---
name: optimize-ppa
description: Optimize power, performance, and area (PPA) for a HighTide2 design. Maximize cell utilization and clock frequency while maintaining a clean flow (no DRC violations).
argument-hint: "<platform>/<design>"
---

# Optimize PPA for a Design

You are optimizing the PPA (power, performance, area) of the design at `designs/$0`. The goals are:
1. **Maximize utilization** — pack cells as tightly as possible to minimize die area
2. **Maximize clock frequency (Fmax)** — tighten the clock period to find the fastest achievable frequency
3. **Maintain a clean flow** — zero DRC violations, no routing failures

**Important:** HighTide is a benchmark suite — the RTL is a fixed input. Never suggest modifying the upstream Verilog/RTL. All optimizations must be scoped to flow parameters (config.mk), timing constraints (constraint.sdc), physical design files (io.tcl, pdn.tcl), and FakeRAM configuration.

## Step 1: Establish Baseline

First, gather the current metrics from the most recent build.

**Find the metrics report:**
```bash
# Bazel flow
cat bazel-bin/designs/$0/logs/*/base/6_report.json 2>/dev/null
# Make flow
cat logs/<platform>/<design>/base/6_report.json 2>/dev/null
```

If no completed build exists, run the flow first:
```bash
# Bazel
bazel build //designs/<platform>/<design>:<design>_final
# Make
./runorfs_ni.sh make DESIGN_CONFIG=./designs/<platform>/<design>/config.mk
```

**Record baseline metrics:**
- Die area, core area, instance area
- Cell utilization (%)
- WNS, TNS, Fmax
- Total power
- DRC error count
- Cell count, macro count
- **Total flow runtime** — record wall-clock time for the baseline build (check log timestamps or Bazel build time). This is a critical early-warning signal.

**Read the design configuration:**
- `designs/<platform>/<design>/config.mk`
- `designs/<platform>/<design>/constraint.sdc`
- `designs/<platform>/<design>/BUILD.bazel` (if it exists)
- `designs/<platform>/<design>/pdn.tcl` (if it exists)
- `designs/<platform>/<design>/io.tcl` (if it exists)

## Step 2: Maximize Utilization (Area Optimization)

The goal is to increase `CORE_UTILIZATION` as high as possible while maintaining a routable design with zero DRC violations.

### 2a. Check current utilization headroom

Compare the **target utilization** (from config.mk) to the **achieved utilization** (from the metrics report). If there is a large gap, the die is oversized.

Also check the placement density — if `PLACE_DENSITY` is much lower than the target utilization, placement may be too spread out.

### 2b. Increase utilization incrementally

Raise `CORE_UTILIZATION` in steps (e.g., +5% at a time). For each step:

1. Update `CORE_UTILIZATION` in config.mk (or `arguments` in BUILD.bazel)
2. Adjust `PLACE_DENSITY` to match — it should be slightly above the utilization fraction (e.g., if utilization is 60%, density ~0.65-0.70)
3. Run the flow and check for:
   - Placement overflow (placement cannot converge)
   - Routing congestion (DRC violations from congestion)
   - Timing degradation (WNS getting worse)
   - **Runtime blowup** (see section 2e below)

### 2c. Handle congestion at high utilization

As utilization increases, congestion will eventually become the bottleneck. Address congestion in this priority order (keep utilization high):

1. **IO pin placement** — Create or improve `io.tcl` to spread pins evenly across die edges. See `designs/asap7/gemmini/io.tcl` for reference. Set both `IO_CONSTRAINTS` and `FOOTPRINT_TCL` to the io.tcl path in config.mk.

2. **Macro halo** — If the design has FakeRAM macros, increase `MACRO_PLACE_HALO` (e.g., from `5 5` to `6 6` or `8 8`) to give the router clearance around macros.

3. **Pin spacing** — Add `PLACE_PINS_ARGS = -min_distance 30 -min_distance_in_tracks` to spread auto-placed pins.

4. **ABC area optimization** — Set `ABC_AREA = 1` to tell the synthesis tool to optimize for area, which reduces cell count and eases routing.

5. **Hierarchical synthesis** — For large designs, `SYNTH_HIERARCHICAL = 1` can help by keeping the hierarchy during synthesis, enabling better placement.

### 2e. Monitor runtime as an early-warning signal

A significant increase in flow runtime compared to the baseline is a strong indicator that the design is over-constrained — the tools are spending excessive time on repair_timing iterations, detailed routing retries, or placement optimization that cannot converge well.

**How to detect runtime blowup:**
- Compare wall-clock time to the baseline build. A run taking 2-3x longer than baseline is a warning; 5x+ means the configuration is likely unviable.
- Check per-stage runtimes by comparing log timestamps. The stages that blow up most are:
  - **Placement** (stage 3) — excessive time means placement density is too high
  - **CTS / repair_timing** (stage 4) — excessive time means timing constraints are too tight and the tool is doing many repair iterations
  - **Detailed routing** (stage 5) — excessive time means routing congestion is too high, causing many rip-up-and-retry cycles

**What to do when runtime blows up:**
- Do not wait for the run to finish — if a stage is already taking much longer than baseline, kill it and back off the most recent parameter change.
- If utilization increase caused the blowup, back off to the previous utilization value — that was likely the practical limit without other changes (io.tcl, pdn.tcl, etc.).
- If clock tightening caused the blowup, the previous clock period was near the achievable Fmax — back off and declare that as the result.
- A runtime blowup at one utilization level may be fixable with congestion mitigation (io.tcl, macro halo) before trying that utilization again.

### 2f. Generate images to diagnose congestion

When congestion blocks further utilization increases, generate heatmaps to identify specific problem areas (see Image Generation below):
- **Placement density heatmap** — find regions with excessive cell density
- **RUDY heatmap** — estimate routing demand before routing
- **Routing congestion heatmap** — find actual routing bottlenecks after routing

## Step 3: Maximize Clock Frequency (Performance Optimization)

The goal is to find the highest Fmax by tightening the clock period until timing violations appear, then backing off slightly.

### 3a. Analyze current timing

**Read the timing report:**
```bash
head -100 reports/<platform>/<design>/base/6_finish_setup.rpt 2>/dev/null
```

**Determine where timing margin exists:**
- If WNS is significantly positive (e.g., > 0.1ns), there is room to tighten the clock
- Identify the critical path — is it register-to-register or involves IO?

### 3b. Check for clock skew effects on IO paths

Clock tree insertion delay can cause misleading timing results when IO constraints assume ideal clocks.

1. **Find clock insertion delay:**
   ```bash
   grep -i "insertion\|skew\|latency" reports/<platform>/<design>/base/4_cts*.rpt 2>/dev/null
   grep -i "insertion\|skew\|latency" logs/<platform>/<design>/base/4_*.log 2>/dev/null
   ```

2. **Compare to IO delay budget**: IO delays are typically `clk_period * clk_io_pct`. If clock insertion delay is a significant fraction of this budget, IO paths have unrealistic constraints that will limit apparent Fmax.

3. **Separate IO timing from core timing**: For benchmarking, the core register-to-register Fmax is what matters. If IO paths are the bottleneck:
   - Increase `clk_io_pct` (e.g., 0.3 or 0.4) to give IO paths more slack
   - Or use `set_false_path` on IO ports to exclude them from timing analysis
   - Or set asymmetric input/output delays that account for insertion delay:
     ```tcl
     set_input_delay  [expr $clk_period * 0.3] -clock $clk_name $non_clock_inputs
     set_output_delay [expr $clk_period * 0.4] -clock $clk_name [all_outputs]
     ```
   - Add `set_clock_uncertainty` to model expected skew

### 3c. Tighten clock period

Binary search for the optimal clock period:

1. Start from the current `clk_period` in constraint.sdc
2. If WNS is positive, reduce `clk_period` by the WNS amount (minus a small margin)
3. Re-run the flow
4. If WNS is still positive, tighten further
5. If WNS is negative, back off — the previous period was close to optimal
6. Converge when WNS is near zero (within ~0.01-0.05ns for asap7, ~0.05-0.1ns for nangate45/sky130hd)

**Set `TNS_END_PERCENT = 100`** in config.mk to ensure the flow tries hard to close timing.

### 3d. Watch for runtime blowup during clock tightening

As the clock period gets tighter, the CTS and routing stages will spend increasingly more time on repair_timing iterations. If a run is taking significantly longer than the baseline (2-3x+), the clock target is likely too aggressive — kill it, back off to the previous period, and declare that as the achievable Fmax.

### 3e. Clock period guidance by platform

- **asap7 (7nm)**: 500-1000 ps typical; aggressive designs may reach 300-500 ps
- **nangate45 (45nm)**: 2-10 ns typical
- **sky130hd (130nm)**: 10-50 ns typical

## Step 4: Power Optimization

Power is generally a secondary concern for benchmarking, but some quick wins:

1. **Check for IR drop issues** — Generate an IR drop heatmap. If there are hotspots, create or adjust `pdn.tcl` to add power stripes (see `designs/asap7/gemmini/pdn.tcl`).

2. **ABC area optimization** (`ABC_AREA = 1`) reduces cell count, which also reduces dynamic power.

3. **Review power report** in the JSON metrics (`finish__power__total`). Power will naturally decrease as area decreases (higher utilization = smaller die = shorter wires = less capacitance).

## Step 5: Generate Layout Images

For visual diagnosis, generate images using OpenROAD's `save_image` command inside Docker with Xvfb (virtual framebuffer), since Docker has no X11 display.

**Extract the Docker image name:**
```bash
DOCKER_IMAGE=$(grep -oP 'image\s*=\s*"\K[^"]+' MODULE.bazel)
```

**Determine the ODB file path** for the stage to visualize:
- Placement: `results/<platform>/<design>/base/3_place.odb`
- Routing: `results/<platform>/<design>/base/5_route.odb`
- Final: `results/<platform>/<design>/base/6_final.odb`

For Bazel flow, ODB files are at: `bazel-bin/designs/$0/results/*/base/<stage>.odb`

### Run image generation in Docker

Write a Tcl script to a temp file, then execute inside Docker with Xvfb:

```bash
cat > /tmp/ht_save_image.tcl << 'TCLEOF'
read_db $::env(ODB_FILE)
# <heatmap setup commands go here — see variants below>
save_image -width 2048 $::env(OUTPUT_IMAGE)
TCLEOF

cd OpenROAD-flow-scripts
docker run --rm \
  -u $(id -u):$(id -g) \
  -v $(pwd)/flow:/OpenROAD-flow-scripts/flow \
  -v $(pwd)/..:/OpenROAD-flow-scripts/UCSC_ML_suite \
  -v /tmp:/tmp \
  -w /OpenROAD-flow-scripts/UCSC_ML_suite \
  -e ODB_FILE=<path-to-odb-relative-to-workdir> \
  -e OUTPUT_IMAGE=/tmp/design_image.webp \
  -e DISPLAY=:99 \
  ${DOCKER_IMAGE} \
  bash -c "Xvfb :99 -screen 0 2048x2048x24 &>/dev/null & sleep 1 && openroad -no_splash -gui /tmp/ht_save_image.tcl"
```

### Heatmap Tcl variants

**Placement density:**
```tcl
read_db $::env(ODB_FILE)
gui::save_display_controls
gui::set_display_controls "Heat Maps/Placement" visible true
gui::set_heatmap Placement rebuild 1
gui::set_heatmap Placement ShowLegend 1
save_image -width 2048 $::env(OUTPUT_IMAGE)
gui::restore_display_controls
```

**Routing congestion:**
```tcl
read_db $::env(ODB_FILE)
gui::save_display_controls
gui::set_display_controls "Heat Maps/Routing" visible true
gui::set_heatmap Routing rebuild 1
gui::set_heatmap Routing ShowLegend 1
save_image -width 2048 $::env(OUTPUT_IMAGE)
gui::restore_display_controls
```

**RUDY (routing demand estimation):**
```tcl
read_db $::env(ODB_FILE)
gui::save_display_controls
gui::set_display_controls "Heat Maps/RUDY" visible true
gui::set_heatmap RUDY rebuild 1
gui::set_heatmap RUDY ShowLegend 1
save_image -width 2048 $::env(OUTPUT_IMAGE)
gui::restore_display_controls
```

**IR drop:**
```tcl
read_db $::env(ODB_FILE)
gui::save_display_controls
gui::set_display_controls "Heat Maps/IR Drop" visible true
gui::set_heatmap IRDrop rebuild 1
gui::set_heatmap IRDrop ShowLegend 1
save_image -width 2048 $::env(OUTPUT_IMAGE)
gui::restore_display_controls
```

After generating images, use the Read tool to display them to the user and analyze what the image shows.

## Step 6: Iterate and Report

After each round of changes, re-run the flow and compare metrics:

**Make flow:**
```bash
./runorfs_ni.sh make DESIGN_CONFIG=./designs/<platform>/<design>/config.mk clean_all
./runorfs_ni.sh make DESIGN_CONFIG=./designs/<platform>/<design>/config.mk
```

**Bazel flow:**
```bash
bazel build //designs/<platform>/<design>:<design>_final
```

**Present results as a comparison table:**

```
| Metric       | Baseline | Current  | Change  |
|--------------|----------|----------|---------|
| Utilization  | 35.0%    | 55.0%    | +20%    |
| Die Area     | 12500    | 8200     | -34%    |
| Fmax (GHz)   | 1.25     | 1.42     | +14%    |
| WNS (ns)     | 0.05     | 0.01     | -0.04   |
| Power (mW)   | 45.2     | 38.7     | -14%    |
| DRC errors   | 0        | 0        | clean   |
```

Continue iterating until either:
- Further utilization increases cause unresolvable congestion/DRC
- Further clock tightening causes timing violations that cannot be closed
- The user is satisfied with the achieved PPA
