# Repartition FakeRAM macros (split or merge banks)

> **⚠ Apply per-platform, not universally.**  FakeRAM geometry is platform-specific.  A split that helps on `sky130hd` will often regress area on `asap7` (and vice-versa for merging).  Only change the FakeRAM set used by the **one platform** that's failing or plateauing.  Each platform's `BUILD.bazel` references its own `sram_lefs_<variant>` / `sram_libs_<variant>` filegroups under `designs/<platform>/<design>/sram/`, and **only those should change**.  Do **not** propagate the change to other platforms unless they show the same symptoms independently.

For macro-heavy designs, the **geometry** of the FakeRAM banks is a tuning lever that's often more powerful than placement density.  There's a real trade-off:

| Direction | Effect on memory area | Effect on placement / routing |
|---|---|---|
| **Combine** many narrow banks into fewer wider/deeper ones | **Denser** memory (less perimeter wasted on per-macro overhead, fewer access ports needed at the boundary) | **Harder to place** — fewer larger blockages make floorplanning fragile, easier to create routing channels too narrow for stdcells around them.  Especially painful on sky130hd's coarse pitches. |
| **Split** wide banks into many narrower ones | **Less dense** memory (more perimeter, more pin clusters per bit) | **Easier to place** — small blockages distribute around the die; stdcells can flow between them.  Often unlocks higher overall `CORE_UTILIZATION` despite the macros themselves being less dense. |

## When to reach for this

This is a heavy-weight knob — only consider it once the lighter ones (`PLACE_DENSITY`, `MACRO_PLACE_HALO`, `io.tcl`, `pdn.tcl`) have been exhausted.  Signals that geometry is the right axis:

- **Debug context (`/debug-design`):** the design stops finishing because global placement overflow plateaus around 0.2–0.4 — local density hot spots near macro pin clusters that no global parameter can smooth out (`sky130hd/NVDLA/partition_c` was the canonical example).  Placement legalization fails, or detailed routing dies in regions next to macros.
- **Optimize context (`/optimize-ppa`):** Step 2 plateaus before timing converges — the design has plenty of die area unused but `CORE_UTILIZATION` cannot rise because routing congestion near macros is the binding constraint.  Std-cell utilization is noticeably below the global `CORE_UTILIZATION` target.
- **Platform-asymmetric closure:** the design closes on `asap7` / `nangate45` but stalls on `sky130hd` solely because the same macro geometry creates routing bottlenecks at the coarser pitch.

## Direction by platform

- **sky130hd**: usually benefits from **splitting** — coarse routing pitches make tall narrow FakeRAM pin clusters easier to route through.
- **asap7**: usually benefits from **merging** — fine pitches absorb dense per-macro pin overhead, so fewer larger macros win on area.
- **nangate45**: usually fine in either direction — the platform's middle ground in pitch makes either choice viable, so prefer the geometry that worked on the other two platforms.

## Procedure

This is a structural change to the FakeRAM LEF/LIB set, not a knob in `BUILD.bazel`:

1. **Identify the candidate macros** from the floorplan placement image (see `.claude/skills/shared/image-generation.md`) and from the per-class instance counts in `6_report.json` / `6_finish.rpt`.
2. **Decide direction** (split / merge / re-shape) based on the table above and the platform pattern.
3. **Generate the new FakeRAM** at the target geometry via `/generate-sram` (the skill wraps `bsg_fakeram`).  Place the new LEF/LIB at the platform's `designs/<platform>/<design>/sram/{lef,lib}/` location and update `BUILD.bazel`'s `sram_lefs_*` / `sram_libs_*` filegroups.
4. **Wrapper Verilog**, not RTL changes.  HighTide's design RTL is fixed; if the new geometry doesn't match the original macro interface verbatim, the change goes in a HighTide-side **wrapper** under `designs/src/<design>/` (a SystemVerilog module that exposes the original interface and instantiates the new geometry internally).  Wrappers are not "design RTL" — they're glue, same category as `pdn.tcl` / `io.tcl`.
5. **Rebuild and compare** on the same axes — die area, std-cell utilization, slack, runtime.  If the change regressed Fmax or made closure marginal, revert.

## Record in DECISIONS.md afterwards

The change is structural — log it in `designs/src/<design>/DECISIONS.md` under **only the platform you changed**:

- The old vs new geometry (e.g., "8 × `fakeram_64x16` → 2 × `fakeram_64x64`")
- Why the change was made (which symptom it was addressing on this platform)
- The PPA delta vs the prior commit (die area, util, Fmax, power)
- Wrapper module path if one was added
- An explicit note that the geometry is **platform-specific** and the other platforms' sections are unchanged.

## Last resort: shrink the memory itself

> **STOP — ask the user before doing this.**  Repartitioning preserves total memory capacity; *shrinking* changes the design's character — it's no longer the same benchmark.  HighTide designs are meant to be representative workloads, and silently halving an SRAM under a benchmark name misleads downstream PPA comparisons.

If geometry alone can't make the design closable on a given platform (sky130hd is the typical offender), reducing the memory **capacity** is a possible escape hatch.  Examples: dropping a 64×256 cache down to 64×128, or replacing a 4-bank scratchpad with 2 banks at the same width.

When you reach this point:

1. **Pause and ask the user explicitly.**  Phrase the question with the trade-off — "this would shrink design X's <name> memory from `<old>` to `<new>`, which means the design no longer matches its original spec.  OK to proceed, or should we mark this (platform, design) as 'not finishing' instead?"
2. **Only proceed with explicit approval.**  A user agreeing to a repartition is not approval to shrink.
3. **Scope to one platform**, same as repartitioning.
4. **Record it loudly in DECISIONS.md** — use a `### ⚠ Reduced memory` subsection under the platform's section, naming the old vs new size, the user-approval commit reference, and the implication for benchmark comparability.
5. **Reflect it on the results page** — the row should make the reduction visible (e.g. a note in the Design cell, or a follow-up `webpage` change).  Don't let the table imply this is the original design.
