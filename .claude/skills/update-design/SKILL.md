---
name: update-design
description: Check for upstream updates to existing HighTide designs and tools, summarize what changed, apply updates, and keep the per-design DECISIONS.md (designs/src/<design>/DECISIONS.md) in sync — recording bug workarounds, manual macro/IO placement, timing-constraint choices, utilization tuning, and any other non-obvious decisions, with one section per technology. Use when a design needs to be refreshed, with no arguments to audit all designs for available updates, or with `--init-decisions <design>` to bootstrap a new DECISIONS.md from existing git history + BUILD.bazel + SDC.
argument-hint: "[design-name or 'all'] [platform]"
---

# Update an Existing Design

If `$ARGUMENTS` is empty or `all`, run the **Upstream Audit** first. Otherwise, you are updating the design `$0` on platform `$1` — determine what kind of update is needed by asking the user or inferring from context.

**Always** also keep `designs/src/$0/DECISIONS.md` in sync — see the **Decisions Document** section below for the file shape, where to record what, and the bootstrap workflow for designs that don't have one yet.

## Upstream Audit

Check all designs and their tool dependencies for upstream changes. Present a summary so the user can decide what's worth updating.

### 1. Audit design submodules

For each design submodule in `.gitmodules`, compare the pinned commit to upstream HEAD:

```bash
# For each submodule path (e.g., designs/src/minimax/dev/repo):
git -C <submodule-path> rev-parse HEAD          # our pinned commit
git -C <submodule-path> ls-remote origin HEAD    # upstream latest
```

If the submodule is not initialized, use `git ls-remote` with the URL from `.gitmodules` and compare against the commit recorded in the superproject:
```bash
git ls-submodule <submodule-path>                # pinned commit in superproject
git ls-remote <url> HEAD                         # upstream latest
```

For each submodule that has new commits upstream, summarize:
- **Design name** and upstream repo URL
- **Commits behind**: how many commits between pinned and upstream HEAD
- **Recency**: date of the most recent upstream commit
- **Extent of changes**: use `git log --oneline <pinned>..origin/HEAD` (or the GitHub API via `gh api`) to show a summary of what changed. Categorize as:
  - **Minor**: documentation, CI, test-only changes, cosmetic fixes
  - **Moderate**: bug fixes, small feature additions, dependency bumps
  - **Major**: new features, architectural changes, API/interface changes, new memory modules
- **Recommendation**: whether the changes are likely to affect generated RTL or just ancillary files

### 2. Audit tool dependencies in setup.sh files

For each design with a `setup.sh`, check pinned tool versions against latest:
- **pip packages pinned to git commits** (e.g., migen, litex, liteeth in `designs/src/liteeth/dev/setup.sh`): check if the pinned commit is behind the upstream default branch
- **pip packages pinned to versions** (e.g., `pyyaml==6.0.2`): check PyPI for newer versions
- **Tool binaries** (sv2v, JDK, sbt): note the pinned version and whether a newer release exists

Summarize each with the same minor/moderate/major classification.

### 3. Audit ORFS submodule

Check `OpenROAD-flow-scripts` for upstream updates:
```bash
git -C OpenROAD-flow-scripts log --oneline HEAD..origin/main | head -20
```
Summarize the nature of ORFS changes (new features, bug fixes, platform updates, etc.).

### 4. Present summary table

Format the results as a table:

```
| Design/Tool        | Pinned     | Upstream   | Behind | Last Activity | Severity | Recommendation     |
|--------------------|------------|------------|--------|---------------|----------|--------------------|
| minimax            | abc1234    | def5678    | 12     | 2026-02-15    | Moderate | Bug fixes, review  |
| liteeth            | ef5f9ee    | 1a2b3c4    | 45     | 2026-03-10    | Major    | New features       |
| verilog-lfsr       | 789abcd    | 789abcd    | 0      | 2025-01-03    | -        | Up to date         |
| litex (pip)        | a25eeec    | b36ff0d    | 8      | 2026-03-12    | Minor    | Docs only          |
| ORFS               | v3.0-...   | v3.1-...   | 200+   | 2026-03-14    | Major    | Platform updates   |
```

Let the user decide which updates to apply. Small changes that don't affect RTL generation (docs, tests, CI) are usually not worth updating for. Major changes that affect RTL output, fix synthesis bugs, or add new features are worth considering.

## Decisions Document

Every design has a long-form decisions log at `designs/src/<design>/DECISIONS.md` (one file per design — variants share it via sub-sections).  This is the place where non-obvious tuning choices, workaround rationale, and platform-specific gotchas live.  The file complements but **does not duplicate**:

- **CLAUDE.md "Known OpenROAD / yosys-slang bug workarounds" table** — the canonical bug index.  DECISIONS.md cross-links to specific rows there rather than restating the bug.
- **BUILD.bazel `arguments = { … }`** — the live config.  DECISIONS.md records *why* an argument has the value it does, not the value itself.
- **`constraint.sdc` comments** — the live constraints.  DECISIONS.md records *why* a clock period or `set_false_path` was chosen.

### When to record a decision

Update `designs/src/<design>/DECISIONS.md` whenever any of these change:

- A bug workaround lands in BUILD.bazel (`PRE_CTS_TCL`, `SKIP_*`, `SETUP_MOVE_SEQUENCE` trim, etc.) — link to the CLAUDE.md row.
- The clock period changes — record before/after Fmax and the period_min that motivated the change.
- A `macros.tcl`, `io.tcl`, `pdn.tcl`, or `*_pre_*.tcl` is added.
- Utilization, density addon, or macro halo gets a non-default value.
- A platform-specific FakeRAM tweak is needed.
- Synthesis is hierarchical / uses `SYNTH_HIERARCHICAL`, with a reason.
- A platform is marked "not yet finishing" (record what's been tried and what blocks closure).
- An optimization-PPA pass moves the QoR more than ~5% in any axis.

The other HighTide skills (`/debug-design`, `/optimize-ppa`, `/port-design`, `/track-bug`) should each append to this file when their work touches one of the above triggers.

### File shape

```markdown
# <design> Design Decisions

Per-platform notes on tuning, workarounds, and platform-specific
quirks for <design>.  See CLAUDE.md (root) for the canonical
upstream-bug index; this file cross-links to it.

## asap7

**Status**: closing | not finishing | failing-timing | partial
**Last updated**: 2026-05-08 (commit a1b2c3d)

### Configuration
- `CORE_UTILIZATION = N` — <one-line why this value>
- `PLACE_DENSITY_LB_ADDON = X` — <reason>
- Clock: `<N> ns` (Fmax `<X>` MHz) — <reason>
- Active workarounds: link to CLAUDE.md rows by error code

### Decisions
- **YYYY-MM-DD `<short-sha>`**: one-line summary of the decision and its motivation, with PR or issue reference where applicable.
- **YYYY-MM-DD `<short-sha>`**: …

### Known issues / open questions
- One bullet per known limitation, e.g. "DRC-clean but Fmax limited by macro→macro cross-die paths; manual macros.tcl might unlock further."

## nangate45

…

## sky130hd

…
```

For multi-variant designs (NVDLA, liteeth, bp_processor), each platform's section gets variant sub-sections:

```markdown
## sky130hd

### partition_a
…
### partition_c
**Status**: not finishing — GP overflow plateaus at 0.31, see CLAUDE.md.
…
```

### Bootstrap workflow (`--init-decisions <design>`)

If the file doesn't exist yet, build it from already-committed history rather than asking the user from scratch:

1. **Find the design's commits**:
   ```bash
   git log --oneline --reverse -- "designs/*/$design/" "designs/src/$design/"
   ```

2. **For each platform**, derive the live configuration:
   - Read `designs/<platform>/<design>/BUILD.bazel` → `arguments`, `sources`.
   - Read `designs/<platform>/<design>/constraint.sdc` → clock period, `set_false_path` lines, IO delay constants.
   - Note any `pdn.tcl` / `io.tcl` / `macros.tcl` / `*pre*.tcl` files that exist.

3. **Pull bug links from CLAUDE.md**: any row in the workarounds table whose "Affected designs" cell mentions this design becomes a "Active workarounds" bullet in the matching platform section, with the issue link copied verbatim.

4. **Pull historical decisions from git log**: scan commit messages on files in `designs/<platform>/<design>/` and `designs/src/<design>/`.  Promote commits that match these patterns to "Decisions" entries:
   - "Relax", "Tighten", "Bump", "Drop", "Switch", "Disable", "Enable" + clock/util/density/halo terms.
   - Anything tagged `Fix`, `Workaround`, `Skip`.
   - Initial port commits (first `Add … on <platform>` for each platform).

5. **Drop decisions older than 1 year** unless they're still load-bearing (e.g. the clock period chosen at port still in effect).  The doc is a working memory, not a changelog.

6. **Show the user the proposed file before writing**, especially when the inferred reasoning is uncertain — they may have context that didn't make it into commit messages.

### Updating an existing decisions file

Each invocation of `/update-design <design> <platform>` that touches the live config should also append (or replace) entries under that platform's **Decisions** list with the current commit short-sha.  Don't rewrite history — append a new dated bullet, and update the platform section's `**Last updated**` line.

If the only change is regenerating RTL from upstream with no flow-config impact, no DECISIONS.md update is needed (the upstream audit table is enough).

## Types of Updates

### A. Update upstream source (new RTL from upstream repo)

1. **Update the submodule to the desired commit:**
   ```bash
   cd designs/src/$0/dev/repo
   git fetch origin
   git checkout <new-commit-or-tag>
   cd /home/mrg/HighTide
   ```

2. **Check if `setup.sh` needs changes:**
   - Read `designs/src/$0/dev/setup.sh`
   - If the upstream build process changed (new dependencies, renamed files, different build commands), update `setup.sh` accordingly

3. **Regenerate RTL:**
   ```bash
   # Clean old dev artifacts
   make DESIGN_CONFIG=./designs/$1/$0/config.mk clean_design
   # Regenerate
   make DESIGN_CONFIG=./designs/$1/$0/config.mk dev
   ```

4. **Check for new or changed memories:**
   - Compare the new RTL against the old to identify any new memory modules
   - If new memories are found, create FakeRAM LEF/LIB files following the patterns in `designs/$1/$0/sram/` or other designs like NyuziProcessor/liteeth
   - Update `config.mk` ADDITIONAL_LEFS and ADDITIONAL_LIBS if new FakeRAM files were added

5. **Promote release RTL:**
   ```bash
   cp designs/src/$0/dev/generated/$0.v designs/src/$0/$0.v
   ```
   (Adjust the path based on where the design's `verilog.mk` expects release RTL)

6. **Check if `verilog.mk` needs updates:**
   - If new Verilog files were added or file names changed, update `designs/src/$0/verilog.mk`

7. **Test the flow:**
   ```bash
   make DESIGN_CONFIG=./designs/$1/$0/config.mk
   ```

### B. Update tool dependencies (JDK, sbt, sv2v, Python packages, etc.)

1. **Read current `setup.sh`:**
   - `designs/src/$0/dev/setup.sh`

2. **Update version numbers or URLs** as needed (e.g., JDK version, pip package commits, sbt version)

3. **Clean old tool artifacts:**
   ```bash
   # Remove cached tool installations and generated files
   rm -rf designs/src/$0/dev/generated
   rm -rf designs/src/$0/dev/.venv      # if Python-based
   rm -rf designs/src/$0/dev/sbt        # if sbt-based
   rm -rf designs/src/$0/dev/sv2v       # if sv2v-based
   ```

4. **Regenerate:**
   ```bash
   make DESIGN_CONFIG=./designs/$1/$0/config.mk dev
   ```

5. **Verify RTL matches or update release copy** if the generated Verilog changed.

### C. Tune flow parameters (timing, utilization, density)

1. **Read current config:**
   - `designs/$1/$0/config.mk`
   - `designs/$1/$0/constraint.sdc`
   - Check recent flow reports in `reports/$1/$0/base/` if available

2. **Congestion troubleshooting priority:**
   It is preferable to keep cell utilization high. If there are congestion problems, try these before lowering utilization:
   - First, fix IO pin placement — create or adjust `io.tcl` to spread pins and reduce congestion near IO (see `designs/asap7/gemmini/io.tcl` for reference). Set `IO_CONSTRAINTS` and `FOOTPRINT_TCL` in config.mk.
   - Second, adjust `MACRO_PLACE_HALO` — increase spacing around macros to give the router more room (e.g., `5 5` or `6 6`).
   - Third, try `PLACE_PINS_ARGS = -min_distance <N> -min_distance_in_tracks` to spread auto-placed pins.
   - Only as a last resort, lower `CORE_UTILIZATION` or `PLACE_DENSITY`.

3. **Common adjustments in `config.mk`:**
   - `CORE_UTILIZATION` — Prefer keeping this high; only lower as a last resort for congestion
   - `PLACE_DENSITY` — Affects routing congestion (0.6-0.8 typical)
   - `CORE_AREA` / `DIE_AREA` — For explicit die size control instead of utilization-based
   - `PLACE_DENSITY_LB_ADDON` — Additional placement density lower bound
   - `MACRO_PLACE_HALO` — Spacing around macros (increase if DRC errors or congestion near macros)
   - `ABC_AREA = 1` — Optimize for area in synthesis
   - `SYNTH_HIERARCHICAL = 1` — For large designs that need hierarchical synthesis

3. **Common adjustments in `constraint.sdc`:**
   - Clock period — Relax if timing violations, tighten if design can run faster
   - IO delay percentage (`clk_io_pct`) — Adjust input/output timing margin

4. **Test:**
   ```bash
   make DESIGN_CONFIG=./designs/$1/$0/config.mk clean_all
   make DESIGN_CONFIG=./designs/$1/$0/config.mk
   ```

### D. Add FakeRAM for newly identified memories

1. **Identify memory modules** in the design's Verilog that should be black-boxed:
   - Large register files, SRAMs, caches, deep FIFOs
   - Typically >32 entries or >256 total bits

2. **Create LEF and LIB files** for each memory:
   - Use naming convention: `fakeram_<width>x<depth>_<ports>.{lef,lib}`
   - Use existing FakeRAM files from the same platform as templates
   - Place in `designs/$1/$0/sram/lef/` and `designs/$1/$0/sram/lib/`

3. **Update `config.mk`** to reference the new FakeRAM files:
   ```makefile
   export ADDITIONAL_LEFS = $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lef/*.lef
   export ADDITIONAL_LIBS = $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lib/*.lib
   export GDS_ALLOW_EMPTY = fakeram*
   export MACRO_PLACE_HALO = 5 5
   ```

4. **Ensure `verilog.mk` does not include the memory module source** so synthesis instantiates the black-box macro instead.

### E. Port to a new platform

1. **Create the platform directory:**
   ```bash
   mkdir -p designs/<new-platform>/$0
   ```

2. **Copy and adapt from an existing platform:**
   - `config.mk` — Change PLATFORM, adjust utilization/density for the new technology
   - `constraint.sdc` — Adjust clock period for the technology node
   - `sram/` — Create platform-specific FakeRAM files if needed (different metal stacks and design rules per platform)

3. **Platform-specific clock period guidance:**
   - asap7 (7nm): 500-1000 ps
   - nangate45 (45nm): 2-10 ns
   - sky130hd (130nm): 10-50 ns

4. **Test the new platform:**
   ```bash
   make DESIGN_CONFIG=./designs/<new-platform>/$0/config.mk
   ```

## General Notes

- Use `./runorfs_ni.sh` prefix when running flows non-interactively (e.g., from Claude Code). The regular `runorfs.sh` uses `docker run -it` which requires an interactive terminal.
- Flow outputs go to `{logs,objects,reports,results}/$1/$0/base/`
- The flow resumes from the last completed stage in dev mode (checks for 1_synth.v, 2_floorplan.odb, etc.)
- Always `clean_all` before a full re-run if config.mk or constraint.sdc changed significantly.
