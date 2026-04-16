---
name: debug-design
description: Analyze and debug a failing HighTide2 design. Diagnose synthesis problems, memory inference issues, congestion, timing violations, and placement/routing failures. Can generate layout images for visual diagnosis.
argument-hint: "<platform>/<design> [stage] [issue-description]"
---

# Debug a Failing Design

You are debugging the design at `designs/$0`. The user may have specified a stage (`$1`) and/or an issue description (`$2`). If the stage or issue is not provided, determine them by examining build artifacts and logs.

**Important:** HighTide is a benchmark suite — the RTL is a fixed input. Never suggest modifying the upstream Verilog/RTL. All fixes must be scoped to flow parameters (config.mk), timing constraints (constraint.sdc), physical design files (io.tcl, pdn.tcl), and FakeRAM configuration.

## Step 1: Locate Build Artifacts

Check for artifacts in three locations, in order of preference:

### 1a. Local Bazel artifacts

```bash
ls bazel-bin/designs/$0/results/*/base/*.odb 2>/dev/null
ls bazel-bin/designs/$0/logs/*/base/*.log 2>/dev/null
ls bazel-bin/designs/$0/logs/*/base/6_report.json 2>/dev/null
```

### 1b. Previously fetched artifacts

Artifacts downloaded from the Nautilus PVC are stored at `artifacts/<platform>/<design>/`:
```bash
ls artifacts/$0/results/*/base/*.odb 2>/dev/null
ls artifacts/$0/logs/*/base/*.log 2>/dev/null
ls artifacts/$0/logs/*/base/6_report.json 2>/dev/null
```

### 1c. Fetch from Nautilus PVC

If no local artifacts exist, the design may have been built on the Nautilus NRP cluster (via `./k8s/run.sh --upload-artifacts`). Fetch the artifacts:

```bash
./tools/fetch_artifacts.sh --keep <platform> <design>
```

This downloads results, reports, and logs from the `hightide-artifacts` PVC to `artifacts/<platform>/<design>/`. Use `--keep` to preserve the remote copy for other users. Without `--keep`, remote artifacts are deleted after fetch.

Other fetch options:
```bash
./tools/fetch_artifacts.sh --keep <platform>          # all designs for a platform
./tools/fetch_artifacts.sh --keep                     # all designs, all platforms
./tools/fetch_artifacts.sh --keep --design <design>   # one design, all platforms
```

### 1d. Determine build status

Identify the **last completed stage** (1_synth, 2_floorplan, 3_place, 4_cts, 5_route, 6_final) and the **first failed stage** by checking which .odb files exist. Check whichever artifact location has the files (bazel-bin or artifacts directory).

**Artifact path convention:** Throughout this skill, paths like `logs/<platform>/<design>/base/` refer to whichever artifact location has the files. Check in order: `bazel-bin/designs/$0/`, then `artifacts/$0/`. Use the one that exists.

## Step 2: Read the Design Configuration

Read these files to understand the design setup:
- `designs/<platform>/<design>/config.mk` — flow parameters
- `designs/<platform>/<design>/constraint.sdc` — timing constraints
- `designs/<platform>/<design>/BUILD.bazel` — Bazel flow config (if it exists)
- `designs/<platform>/<design>/pdn.tcl` — power delivery (if it exists)
- `designs/<platform>/<design>/io.tcl` — pin placement (if it exists)
- `designs/src/<design>/verilog.mk` — which Verilog files are used

## Step 3: Analyze by Failure Type

Based on the failed stage and symptoms, follow the appropriate diagnosis path below.

---

### A. Synthesis Failures (Stage 1)

**Read the synthesis log** (check bazel-bin or artifacts directory, whichever has the files):
```bash
tail -200 bazel-bin/designs/$0/logs/*/base/1_1_yosys.log 2>/dev/null
tail -200 artifacts/$0/logs/*/base/1_1_yosys.log 2>/dev/null
```

**Common synthesis issues:**

1. **Missing modules / unresolved references**: Check that all Verilog files are listed in `verilog.mk` or `BUILD.bazel`. Search the RTL for the missing module name.

2. **Incorrectly synthesized memories**: Yosys may infer memories as flip-flops instead of using FakeRAM macros.
   - Check the synth log for `Creating memory...` or `$mem` cells
   - Search for large register arrays: `grep -i "mem\|ram\|reg.*\[" <synth-log>`
   - If memories are being flattened into flops, the design needs FakeRAM black-box macros:
     - FakeRAM LEF/LIB files must exist in `designs/<platform>/<design>/sram/`
     - `ADDITIONAL_LEFS` and `ADDITIONAL_LIBS` must be set in config.mk
     - The Verilog module interfaces must match the FakeRAM macro pin names
     - `SYNTH_MEMORY_MAX_BITS` may need adjustment to prevent Yosys from synthesizing large memories
   - A suspiciously high cell count is a strong indicator memories were flattened

3. **SystemVerilog not supported**: Yosys has limited SV support. The design may need sv2v conversion. Check `designs/src/<design>/dev/setup.sh`.

4. **Synthesis timeout / excessive runtime**: Consider `SYNTH_HIERARCHICAL = 1` and `ABC_AREA = 1` in config.mk.

---

### B. Floorplan Failures (Stage 2)

**Read the floorplan log:**
```bash
tail -200 logs/<platform>/<design>/base/2_*.log
```

**Common floorplan issues:**

1. **Macro placement failures (MPL-0040 or similar)**: The macro placer cannot find valid placements.
   - Increase `MACRO_PLACE_HALO` (e.g., `6 6` or `8 8`)
   - Lower `CORE_UTILIZATION` or increase die area — macros + std cells may not fit
   - Consider explicit `DIE_AREA` and `CORE_AREA` instead of utilization-based sizing

2. **PDN failures**: Power grid cannot be constructed.
   - Check if `pdn.tcl` exists and metal layer names match the platform (M1-M7 for asap7, met1-met5 for sky130hd)

3. **IO placement failures**: Too many pins for the die perimeter — increase die area or create a manual `io.tcl`.

**Generate a floorplan image** to visualize macro placement and die area (see Step 4).

---

### C. Placement Failures (Stage 3)

**Read the placement log:**
```bash
tail -200 logs/<platform>/<design>/base/3_*.log
```

**Common placement issues:**

1. **Placement overflow / cannot place**: Die too small or utilization too high.
   - Check reported utilization vs target
   - Lower `PLACE_DENSITY` (try 0.5-0.65)

2. **Congestion hotspots**: Router estimates show high congestion during placement.
   - Look for "Congestion" warnings in the log
   - Generate a placement density and RUDY heatmap (see Step 4)
   - Follow the congestion fix priority in `.claude/skills/shared/congestion-analysis.md`

---

### D. CTS Failures (Stage 4)

**Read the CTS log:**
```bash
tail -200 logs/<platform>/<design>/base/4_*.log
```

**Common CTS issues:**
1. **Clock tree cannot meet skew targets**: Check the clock definitions in `constraint.sdc`
2. **Missing clock port**: Verify `clk_port_name` in the SDC matches the actual design port name

---

### E. Routing Failures (Stage 5)

**Read the routing log:**
```bash
tail -200 logs/<platform>/<design>/base/5_*.log
```

**Common routing issues:**

1. **DRC violations**:
   ```bash
   head -100 reports/<platform>/<design>/base/5_route_drc.rpt 2>/dev/null
   ```

2. **Congestion-driven routing failures**: Too many routing resources consumed.
   - Check the GRT congestion report for per-layer overflow counts (see `.claude/skills/shared/congestion-analysis.md`):
     ```bash
     grep -A 15 "Final congestion report" logs/*/base/5_1_grt.log 2>/dev/null
     ```
   - Non-zero overflow on any layer means congestion-driven failures
   - Generate a routing congestion heatmap (see Step 4) for spatial diagnosis
   - Follow the congestion fix priority in `.claude/skills/shared/congestion-analysis.md`

3. **Antenna violations**: Check antenna report if available

---

### F. Timing Violations (Any Stage)

Timing analysis should cover setup slack, hold slack, clock skew, and IO constraint realism. Since the RTL is fixed, the goal is to find the best achievable Fmax by tuning constraints and flow parameters.

**Read timing reports:**
```bash
# Setup timing (critical for Fmax)
head -100 reports/<platform>/<design>/base/6_finish_setup.rpt 2>/dev/null

# Hold timing
head -100 reports/<platform>/<design>/base/6_finish_hold.rpt 2>/dev/null

# JSON metrics summary
cat logs/<platform>/<design>/base/6_report.json 2>/dev/null
```

**Key metrics to extract and present:**
- **WNS** (worst negative slack) — negative means violation
- **TNS** (total negative slack) — sum of all violating paths
- **Fmax** — maximum achievable frequency
- **`report_clock_min_period`** — look for this in the finish report; it gives the true minimum achievable clock period directly, which is more reliable than computing it from WNS
- **Top 5 worst paths**: start point, end point, path delay breakdown

**Important: utilization and clock period are coupled.** Tighter clock constraints cause synthesis to produce more cells (more buffering, complex gate decompositions), which increases the effective utilization. A design that fits at 80% util with a relaxed clock may overflow at 80% with an aggressive clock. When diagnosing timing, also check if the cell count and instance area increased compared to a relaxed-clock build.

**Clock skew analysis:**

Clock tree insertion delay can cause timing violations when IO constraints assume ideal clocks. Check for this:

1. **Read the clock tree report** to find insertion delay:
   ```bash
   grep -i "insertion\|skew\|latency" reports/<platform>/<design>/base/4_cts*.rpt 2>/dev/null
   grep -i "insertion\|skew\|latency" logs/<platform>/<design>/base/4_*.log 2>/dev/null
   ```

2. **Compare insertion delay to IO constraints**: In the SDC, IO delays are typically set as a fraction of the clock period (`clk_io_pct`). If the clock tree insertion delay is significant compared to `clk_period * clk_io_pct`, the IO paths will have unrealistic timing targets.

   For example, if `clk_period = 1.0ns` and `clk_io_pct = 0.2`, the IO delay budget is 0.2ns. If clock insertion delay is 0.15ns, that leaves almost no margin for actual IO path logic.

3. **Check if failing paths are IO paths**: Look at the worst timing paths in the setup report. If they are input-to-register or register-to-output paths (not register-to-register), the IO constraints are likely the problem, not the core logic.

4. **Fixes for clock-skew-related IO timing:**
   - Increase `clk_io_pct` to account for clock tree insertion delay (e.g., 0.3 or 0.4)
   - Use `set_clock_uncertainty` in the SDC to model expected skew
   - Set different input/output delays that account for insertion delay:
     ```tcl
     # Instead of using clk_io_pct for both:
     set_input_delay  [expr $clk_period * 0.3] -clock $clk_name $non_clock_inputs
     set_output_delay [expr $clk_period * 0.4] -clock $clk_name [all_outputs]
     ```
   - For benchmarking purposes, if external IO timing is not meaningful, relax IO constraints significantly or use `set_false_path` on IO ports to focus on core register-to-register Fmax

**Common timing fixes:**
1. **Relax clock period** in `constraint.sdc` to find the achievable Fmax for this design/platform combination
2. **Adjust IO constraints** as described above if clock skew is causing false IO violations
3. **Set `TNS_END_PERCENT = 100`** in config.mk to prioritize timing closure
4. **Hold violations** are usually fixed automatically by the flow; if persistent, check for clock tree issues

---

### G. Final Stage / DRC (Stage 6)

**Read the finish log and DRC report:**
```bash
tail -100 logs/<platform>/<design>/base/6_*.log
head -50 reports/<platform>/<design>/base/6_finish_drc.rpt 2>/dev/null
```

**Check the summary metrics:**
```bash
./tools/summary.sh            # Bazel flow
# Or manually parse 6_report.json
```

---

## Step 4: Generate Layout Images

For visual diagnosis of floorplan, placement, congestion, and power routing problems, generate images using OpenROAD's `save_image` command.

See `.claude/skills/shared/image-generation.md` for the full Docker/Xvfb setup, Tcl scripts, and heatmap variants (routing congestion, placement density, RUDY, IR drop).

---

## Step 5: Recommend Fixes

Based on the diagnosis, recommend specific changes. Always explain **what** to change, **why**, and provide the exact file edits. Remember: never suggest RTL modifications — the Verilog is a fixed benchmark input.

**Congestion fix priority** — see `.claude/skills/shared/congestion-analysis.md`

**Timing fix priority:**
1. Check if the clock period target is realistic for the platform and design complexity
2. Check if failing paths are IO-constrained — if so, adjust `clk_io_pct` or IO delays to account for clock tree insertion delay
3. Add `set_clock_uncertainty` to model expected skew
4. Set `TNS_END_PERCENT = 100` in config.mk
5. Relax clock period to find the true achievable Fmax

**Memory fix priority:**
1. Identify which memories need FakeRAM black-boxing
2. Create FakeRAM LEF/LIB files (use existing designs on the same platform as templates)
3. Update config.mk with `ADDITIONAL_LEFS` / `ADDITIONAL_LIBS`

## Step 6: Test the Fix

After applying changes, re-run the flow:

**Make flow:**
```bash
./runorfs_ni.sh make DESIGN_CONFIG=./designs/<platform>/<design>/config.mk clean_all
./runorfs_ni.sh make DESIGN_CONFIG=./designs/<platform>/<design>/config.mk
```

**Bazel flow:**
```bash
bazel build //designs/<platform>/<design>:<design>_final
```

Compare metrics before and after (WNS, TNS, Fmax, DRC count, cell count) to verify the fix improved the situation.

Once the design is passing cleanly, suggest that the user run `/optimize-ppa` to maximize utilization and clock frequency.
