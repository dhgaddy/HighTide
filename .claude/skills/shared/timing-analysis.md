# Timing Diagnosis Reference

Shared reference for diagnosing setup/hold failures. Used by `debug-design`
(when a flow stage fails or reports negative WNS) and `optimize-ppa` (when
clock tightening stalls). The goal is to decide *what kind* of timing
problem we have so the fix targets the right knob instead of the
shotgun: clock period? IO delay? skew? a wire-dominated path? a single
slow stage? a corner-specific failure?

## Inputs

Per-stage timing reports under `reports/<platform>/<design>/base/`:

| File | Use |
|------|-----|
| `6_finish_setup.rpt` | post-route setup paths (authoritative for final WNS) |
| `6_finish_hold.rpt` | post-route hold paths |
| `6_finish_clock_skew.rpt` | clock skew between launch/capture FFs |
| `6_finish_clock_min_period.rpt` | minimum achievable period (per clock) |
| `6_report.json` | JSON metrics (WNS, TNS, Fmax, power, area) |
| `4_cts.rpt` / `5_2_route.rpt` | intermediate snapshots when finish is degraded |

`reports/.../6_report.json` is the easiest entry point — its
`finish__timing__setup__ws`, `finish__timing__setup__tns`,
`finish__timing__fmax`, and `finish__clock__skew__worst_setup_*`
fields tell you which checks below to run first.

## Step-by-step diagnosis

Run the checks below in order; stop when one of them is clearly the
dominant problem.

### (a) Clock skew

Symptoms:
- `report_clock_skew` shows worst skew comparable to the slack deficit.
- Setup and hold violations on the *same* launch–capture pair (rare when
  skew is healthy).
- Hold-time violations clustered on short reg-to-reg paths.

Checks:
```bash
grep -A 30 "Clock skew" reports/<plat>/<des>/base/6_finish_clock_skew.rpt
jq '.finish__clock__skew__worst_setup_min, .finish__clock__skew__worst_setup_max,
    .finish__clock__skew__worst_hold_min,  .finish__clock__skew__worst_hold_max' \
    reports/<plat>/<des>/base/6_report.json
```

If the worst skew is a meaningful fraction of WNS (say > 30%), the
clock tree itself is the bottleneck. Likely causes:
- `CTS_BUF_LIST` doesn't include enough buffer strengths for the
  insertion delay required → adjust per-platform defaults are usually
  fine; only override in `BUILD.bazel` if you have a strong reason.
- Clock tree was forced into a corner of the die (look at the
  placement image — clock buffers crammed against macros).
- Bumping `MACRO_PLACE_HALO` and rerunning often fixes both skew and
  congestion at once.

### (b) Unreasonable clock period or IO delay

Symptoms:
- WNS is large and negative AND the design has no obvious congestion or
  macro hotspots.
- The critical path runs end-to-end through combinational logic with
  many stages.
- The path *starts* or *ends* at a top-level IO port.

Checks:
```bash
# Min achievable period per clock — the true Fmax target.
grep -A 5 "clock_period_min\|period_min" \
     reports/<plat>/<des>/base/6_finish_clock_min_period.rpt
jq '.finish__timing__fmax, .finish__timing__setup__ws' \
   reports/<plat>/<des>/base/6_report.json
```

If `clock_period_min` is well below the current `clk_period` in
`constraint.sdc`, the clock is over-constrained — relax it toward
`period_min + margin` (margin: ~50ps asap7, ~100ps nangate45/sky130hd).

If the worst path is from an `input` port or to an `output` port, the
problem is IO delay, not clock period:
- `clk_io_pct` in the SDC controls the input/output delay budget
  (typical 0.2–0.4). Raising it (0.5–0.8) shrinks the IO budget and is
  *more* aggressive; lowering it is what you want when IO paths dominate.
- Confirm against `set_clock_uncertainty` — large uncertainty also
  consumes the IO budget.

Real benchmark Fmax is reg-to-reg, so if IO paths dominate the
worst path, also report the worst *reg-to-reg* path separately:
```
report_checks -from [all_registers -clock_pins] \
              -to   [all_registers -data_pins] \
              -group_path_count 5
```

### (c) Wire vs. logic vs. macro delay

Symptoms: the path itself is the question — break it into segments.

Generate a detailed path dump (use the OpenROAD shell against the post-
route ODB, or read the existing report):
```
report_checks -path_delay min_max -format full_clock_expanded \
              -fields {slew cap input_pins nets fanout} \
              -group_path_count 1
```

Walk the path and bucket each delay:
- **Wire delay**: rows whose delay is attributed to a net (`net …`),
  driven by routing. Heavy wire delay → routing congestion, long net
  spans, or weak drivers. Fix in this order: lower utilization, add
  `IO_CONSTRAINTS`/`FOOTPRINT_TCL`, increase `MACRO_PLACE_HALO`, or
  add `set_load` on long capacitive loads.
- **Logic delay**: rows through std cells. Heavy logic delay → too
  many stages in one clock cycle (RTL-side, which we cannot change) or
  weak buffering. Set `ABC_AREA = 0` (perf-oriented synthesis), raise
  `TNS_END_PERCENT = 100`, or move to a faster cell variant via the
  library tier (asap7 R/SL/SLVT).
- **Macro delay**: rows where the cell is a FakeRAM (`fakeram_*`). If a
  single macro dominates, the macro's `.lib` access time IS the
  bottleneck — consider repartitioning (see
  `.claude/skills/shared/sram-repartition.md`) to a smaller, faster
  macro, or place the macro closer to its consumer in `io.tcl`/
  manual macro placement.

Rough heuristic: if any one bucket is > 60% of the total path delay,
that bucket is the lever. If they're balanced (~30/30/30), the design
is genuinely at its limit and only RTL changes (which we don't make in
HighTide) would help.

### (d) Single problematic stage

Symptoms: most of the path delay sits in one cell or one net.

Read the `full_clock_expanded` report and find the largest single delay
contribution. Common patterns:
- **One huge net**: a single net's delay > 30% of the path. Almost
  always a placement problem — driver and load are on opposite sides of
  the die. Check `placement.webp` for the cluster; consider an `io.tcl`
  / `macro_placement.tcl` constraint to colocate them.
- **One slow cell**: a single std cell delay > 30% of the path. Usually
  the synthesizer mapped it to a weak variant; bump `ABC_AREA = 0`
  and/or rerun.
- **One macro access**: a FakeRAM read/write that consumes most of the
  cycle. See (c) — repartition or move physically.

This is the most common "fix one thing and the design closes" pattern.
When you find a dominant stage, fixing it usually clears WNS entirely.

### (e) Multi-corner STA issue

Symptoms: WNS is fine at the typical corner but the flow still reports
violations; or hold passes only at the slow corner; or setup passes only
at the fast corner.

Checks: confirm which corners the flow ran with, and that all required
corners are constrained:
```
report_checks -path_delay min_max -corner <corner_name>
report_checks -scenes      # if multi-scene/multi-mode is configured
```

Look at:
- `STA_CORNERS` (default vs. overridden in BUILD.bazel) — is the failing
  corner even in the analyzed set?
- Slow / fast / typical liberty files — are all wired in via the
  platform PDK?
- Derate values (`set_timing_derate`) on the failing corner.

For HighTide, single-corner failure is rare and usually means a
constraint is corner-specific (e.g., `set_clock_uncertainty` that's too
tight for the slow corner). Common fix: relax the constraint that's
corner-specific, or add a corner-specific override. See
`.claude/skills/sdc-sta/SKILL.md` for the multi-corner SDC primitives.

### (f) None of the above

If (a)–(e) don't fit, the failure is something else. Sanity checks
before declaring "RTL limit":
- **Constraint typos**: `report_checks -unconstrained` and `check_setup`
  surface ports with missing `set_input_delay`/`set_output_delay`. A
  forgotten constraint can make a path "infinitely fast" or
  "infinitely slow" depending on direction.
- **Stale ODB**: rerun the report against the *current* ODB, not a
  cached one from an earlier iteration.
- **Hold paths driving setup choices**: if you tightened the clock to
  fix hold, you may have created a setup problem. Treat them separately.
- **CTS-0105, ODB-1200, MPL-0040**: known OpenROAD bugs documented in
  `CLAUDE.md`'s known-bug table — check it before chasing the symptom.

Report your conclusion in this shape:
```
Dominant issue: <(a)–(f)>
Evidence:       <one or two numeric facts: e.g., "skew 95ps vs WNS 110ps">
Recommended fix: <one or two flow-parameter or SDC changes>
```

Keep the report short and numeric. If multiple buckets contribute
(say 50/40/10), say so — and address the larger lever first.
