# FakeRAM Repartitioning (Split / Merge Macro Banks)

For macro-heavy designs, **FakeRAM geometry** is often a more powerful tuning lever than placement density.  Splitting wide banks into more numerous narrow ones makes placement easier (at the cost of memory density); combining narrow banks into wider/deeper ones is denser but harder to place.  Reach for this when standard knobs plateau and the bottleneck is the macros themselves, not the std cells.

> ⚠ **Apply per-platform, not universally.**  Each platform's `BUILD.bazel` references its own `sram_lefs_<variant>` / `sram_libs_<variant>` filegroup, and the right geometry differs across `asap7` / `nangate45` / `sky130hd`.  Change only the failing platform's set.  A repartitioning that unblocks `sky130hd` will almost always regress `asap7` if applied there.

## The trade-off

| Direction | Effect on memory area | Effect on placement / routing |
|---|---|---|
| **Combine** many narrow banks into fewer wider/deeper ones | **Denser** memory (less perimeter wasted on per-macro overhead, fewer access ports at the boundary) | **Harder to place** — fewer larger blockages make floorplanning fragile, easier to create routing channels too narrow for stdcells around them.  Especially painful on sky130hd's coarse pitches. |
| **Split** wide banks into many narrower ones | **Less dense** memory (more perimeter, more pin clusters per bit) | **Easier to place** — small blockages distribute around the die; stdcells flow between them.  Often unlocks higher overall `CORE_UTILIZATION` despite the macros themselves being less dense. |

## When to reach for this

- **Debug context (`/debug-design`)** — the design fails to finish on one platform.  Common symptoms:
  - **Floorplan stage:** MPL-0040 macro-placement failures that resist halo/utilization tuning.
  - **Placement stage:** global-placement overflow plateaus around 0.2–0.4 regardless of `PLACE_DENSITY` / `CORE_UTILIZATION`.  Local-density hot spots near macro pin clusters that no global parameter smooths out.
- **Optimize context (`/optimize-ppa`)** — Step 2 plateaus before timing converges and std-cell utilization is noticeably below `CORE_UTILIZATION` — i.e., the routability bottleneck is the macros, not the std cells.
- **Platform-asymmetric closure** — a design that finishes on `asap7`/`nangate45` but stalls on `sky130hd` solely because the same macro geometry creates routing bottlenecks at the coarser pitch.

## Direction by platform

Defaults that tend to work, but always verify before/after:

- **sky130hd** → usually **split**.  Coarse metal pitches make wide banks routing-hostile.
- **asap7** → usually **merge**.  Fine pitches let dense banks place cleanly; the area win is worth it.
- **nangate45** → middle ground; let the symptom decide.

## Procedure

This is a structural change to the FakeRAM LEF/LIB set, not a knob in `BUILD.bazel`.

1. **Identify the candidate macros** from the floorplan placement image and from `6_finish.rpt`'s instance counts.  Note which banks dominate the area and where they cluster on the die.
2. **Decide direction** (split / merge / re-shape) based on the table above and the platform default.
3. **Generate the new FakeRAM** at the target geometry via `/generate-sram` (wraps `bsg_fakeram`).  Place the new LEF/LIB under `designs/<platform>/<design>/sram/{lef,lib}/` for **only the affected platform**, and update **only that platform's** `BUILD.bazel` `sram_lefs_*` / `sram_libs_*` filegroups.
4. **Wrapper Verilog is allowed; RTL changes are not.**  HighTide's RTL is fixed.  If the new geometry doesn't match the original macro interface verbatim, add a HighTide-side **wrapper** under `designs/src/<design>/` (a SystemVerilog module exposing the original interface and instantiating the new geometry internally).  Wrappers are glue, same category as `pdn.tcl` / `io.tcl` — not "design RTL".
5. **Rebuild and compare on the same axes** — die area, std-cell utilization, slack, runtime — **and verify other platforms didn't regress** (since the unaffected platforms' `sram_lefs_*` filegroups are unchanged, their builds should be cache-hits).  If the change regressed Fmax or made closure marginal on the target platform, revert.

## DECISIONS.md entry

Record in `designs/src/<design>/DECISIONS.md`, scoped to **only the changed platform's section**:

```markdown
### <platform> — FakeRAM repartitioning

- **Old → new geometry:** 8 × `fakeram_64x16` → 2 × `fakeram_64x64`  (or similar)
- **Why:** which axis was the change trying to improve (closure, area, Fmax)
- **PPA delta vs prior commit:** WNS x → y ps, area x → y µm², util x → y%
- **Wrapper module:** `designs/src/<design>/wrappers/<name>.sv` if one was added
- **Other platforms:** confirmed cache-hits / unchanged (or note any regressions)
```

Do **not** record this change in other platforms' sections — they were not modified.

## Last resort: shrink the memory

> **STOP — ask the user before doing this.**  Repartitioning preserves total memory capacity; *shrinking* changes the design's character — it is no longer the same benchmark.  This is a change of kind, not degree.

If repartitioning in both directions fails to unblock closure on the target platform, the remaining lever is to **reduce the memory size** (fewer entries, narrower words, or drop a memory entirely).  This is acceptable only as a last resort and only with explicit user approval.

1. **Pause and ask the user.**  Describe what you tried (split, merge, halo/util/density sweep) and what failed.  Propose a specific reduction (e.g., "shrink the L1 from 16KB → 4KB on sky130hd only") and the expected delta.  Wait for explicit approval before proceeding.
2. **Scope the reduction to one platform.**  Use the same per-platform `sram_lefs_*` / `sram_libs_*` mechanism — do not touch other platforms' filegroups.
3. **Wrapper Verilog tie-offs.**  If the smaller memory exposes a different address range, the wrapper must tie off / decode the missing bits — RTL is still fixed.
4. **Record loudly in DECISIONS.md.**  Use a dedicated subsection so future readers immediately see this is a reduced-capacity build, not the canonical benchmark:

   ```markdown
   ### ⚠ <platform> — Reduced memory (not canonical benchmark)

   - **Approved by user on YYYY-MM-DD** after split/merge repartitioning failed to close.
   - **Reduction:** 16KB → 4KB L1 data cache (entries 1024 → 256, word width unchanged)
   - **Rationale:** sky130hd routing congestion at coarse pitch; full-size memory exceeded routing resources regardless of bank geometry.
   - **Other platforms:** unchanged at full 16KB.
   ```
5. **Make the reduction visible on the results page.**  If this design appears in `webpage/results.html` or the summary table, ensure the reduced-memory build is marked so consumers don't compare reduced numbers against full-capacity numbers from other platforms.
