# Congestion Analysis Reference

Shared reference for analyzing routing congestion. Used by debug-design and optimize-ppa skills.

## Reading the GRT congestion report

The global router (GRT) produces a per-layer congestion summary. This is the most reliable numeric indicator of routing health:

```bash
grep -A 15 "Final congestion report" logs/*/base/5_1_grt.log 2>/dev/null
```

Example output:
```
Layer         Resource        Demand        Usage (%)    Max H / Max V / Total Overflow
---------------------------------------------------------------------------------------
M1                   0             0            0.00%             0 /  0 /  0
M2                1244           214           17.20%             0 /  0 /  0
M3                1582           207           13.08%             0 /  0 /  0
...
Total             6811           474            6.96%             0 /  0 /  0
```

**Key metrics:**
- **Total Overflow = 0** means routing succeeded without congestion violations
- **Usage %** above ~70-80% on any single layer is a warning sign
- **Max H / Max V overflow > 0** means the router had to rip-up and retry in that region

## Congestion fix priority

When congestion blocks further progress, try fixes in this order (prefer keeping utilization high):

1. **IO pin placement** — Create or improve `io.tcl` to spread pins evenly across die edges. See `designs/asap7/gemmini/io.tcl` for reference. Set both `IO_CONSTRAINTS` and `FOOTPRINT_TCL` to the io.tcl path in config.mk.

2. **Macro halo** — If the design has FakeRAM macros, increase `MACRO_PLACE_HALO` (e.g., from `5 5` to `6 6` or `8 8`) to give the router clearance around macros.

3. **Pin spacing** — Add `PLACE_PINS_ARGS = -min_distance 30 -min_distance_in_tracks` to spread auto-placed pins.

4. **ABC area optimization** — Set `ABC_AREA = 1` in config.mk to reduce cell count.

5. **Lower utilization** — Only as a last resort. Reduce `CORE_UTILIZATION` by 5% increments.

## Using congestion metrics in optimization

When increasing utilization, check the GRT overflow after each iteration. A design that has zero overflow at 70% util but non-zero overflow at 75% has hit the congestion wall — apply the fixes above before pushing utilization further.

## Visual diagnosis

For spatial congestion analysis, generate heatmap images. See `.claude/skills/shared/image-generation.md` for the Tcl scripts and Docker commands. The most useful heatmaps for congestion are:
- **Routing congestion** — actual congestion after routing
- **RUDY** — routing demand estimation (faster, available before detailed routing)
- **Placement density** — cell density hotspots that correlate with congestion
