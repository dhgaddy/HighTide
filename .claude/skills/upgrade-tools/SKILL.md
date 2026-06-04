---
name: upgrade-tools
description: Upgrade the bazel-orfs submodule (and the OpenROAD/OpenSTA/yosys it pins) to a newer commit, then validate every currently-passing design from smallest to largest, keeping QoR within ~5% and removing bug-workarounds whose upstream fix is now in the pin. Mirrors bazel-orfs's root-only MODULE.bazel overrides into HighTide's root, drops fixed-bug patches, and commits the tooling bump once plus one commit per design that re-passes. Use when bumping the EDA toolchain (not for adding designs or one-off bug fixes).
argument-hint: "[target-bazel-orfs-commit | 'latest']"
---

# Upgrade the EDA toolchain (bazel-orfs / OpenROAD / yosys)

HighTide layers on top of `bazel-orfs` (a git submodule at `./bazel-orfs`). Most tool
versions live in `bazel-orfs/MODULE.bazel`, but bzlmod only honors `*_override`,
`single_version_override`, and `register_toolchains` in the **root** module — so
HighTide's root `MODULE.bazel` **re-declares** them. Upgrading = bump the submodule, then
re-mirror those root-only overrides, drop workarounds whose bugs are now fixed upstream,
and prove each design still closes with acceptable QoR.

`$0` = target bazel-orfs commit (or `latest` = upstream `main` HEAD). Default: `latest`.

Constraints (unless the user says otherwise): **don't touch design RTL or SDC timing
constraints**; flow knobs (`CORE_UTILIZATION`, `PLACE_DENSITY`, `MACRO_PLACE_HALO`, repair
flags) are fair game. Scope = the (platform, design) pairs that reach `_final` **today**
(see CLAUDE.md "Reaching `_final`" lists) — don't try to fix pre-existing failures here.
All commits stay on the working branch.

## Step 1 — Survey the delta

```bash
cd bazel-orfs && git fetch origin && git log --oneline HEAD..origin/main | head
git show origin/main:MODULE.bazel        # target root-only overrides
git show origin/main:.bazelrc            # registry / flag changes
git show HEAD:MODULE.bazel               # current (pinned) for diff
```

Diff the two MODULE.bazel files. Note every change to: `archive_override`/`git_override`
pins (ORFS, OpenROAD — incl. `patch_cmds` that vendor `src/sta`, `third-party/abc`,
`third-party/slang-elab`), `single_version_override`s (sv-lang, scip, sed, soplex, …),
`bazel_dep` version bumps (yosys, abc, rules_python, …), the patches each override applies,
and any new module-extension blocks (`pycross.configure_environments`, the LLVM
`http_archive` xml-stub hack). HighTide's `.bazelrc` already `try-import`s
`bazel-orfs/.bazelrc`, so registry lines (e.g. the scip fork registry) come in
**automatically** with the submodule bump — verify, don't duplicate. Never touch
`.bazelrc.user` (it routes cache uploads to the local `bazel-remote` daemon; this host is
the cache).

## Step 2 — Check which workarounds are now fixed

For each row of CLAUDE.md's "Known OpenROAD / yosys-slang bug workarounds" table, check the
linked issue/PR and whether the fix commit is an ancestor of the **new** pin:

```bash
gh api repos/The-OpenROAD-Project/OpenROAD/issues/<N> --jq '{state,closed_at,title}'
# fix commit X in pin Y?  status "ahead"/"behind_by:0" ⇒ X is an ancestor of Y:
gh api repos/The-OpenROAD-Project/OpenROAD/compare/<fixsha>...<newpin> --jq '{status,ahead_by,behind_by}'
```

A closed issue + fix-in-pin makes that workaround a **removal candidate** (verified
per-design in Step 5, not blindly deleted). Map every workaround to its files:

```bash
grep -rnE 'SKIP_CTS_REPAIR_TIMING|SKIP_INCREMENTAL_REPAIR|SKIP_LAST_GASP|SETUP_MOVE_SEQUENCE|PRE_CTS_TCL|MACRO_PLACEMENT_TCL' designs/*/*/BUILD.bazel designs/*/*/*/BUILD.bazel
```

Patches the new pin already contains (e.g. an OpenROAD source patch merged upstream) are
dropped **globally** in Step 3.

## Step 3 — Bump + re-mirror (one initial commit)

1. `cd bazel-orfs && git checkout <target>` ; stage the submodule pointer in the superproject.
2. Rewrite root `MODULE.bazel` to mirror the new bazel-orfs root-only overrides. Keep
   HighTide-specific blocks: the yosys-slang plugin (`yosys_slang.bzl` /
   `//:yosys_share_with_slang`), `orfs.default(yosys_share=...)`, the LLVM + Python
   toolchains, and `register_toolchains`.
3. Fix `patches/` (symlinks into `bazel-orfs/patches/`; `*_override` patch labels must be
   root-repo `//patches:` labels): add new ones, drop renamed/removed ones, and delete any
   local patch the new pin made redundant.
4. `bazel build --nobuild //designs/asap7/lfsr:lfsr_synth` to resolve the graph. **Fix
   resolution errors iteratively** — bzlmod messages name the exact module. Known gotcha:
   the fork **sv-lang** pulls `boost.unordered@1.87.0` (old `compatibility_level 108700`)
   while OpenROAD pins all `boost.*` at `1.89.0.bcr.2` (level 0); MVS can't reconcile
   differing levels, so add
   `single_version_override(module_name="boost.unordered", version="1.89.0.bcr.2")`.
   (bazel-orfs doesn't carry this because its own overrides differ; HighTide as root must.)
5. Build `//designs/asap7/lfsr:lfsr_synth` then `:lfsr_gallery`. The first build recompiles
   yosys + the **whole OpenROAD source tree** from the new pin (thousands of actions, once;
   cached after). Risk: the yosys-slang plugin (pinned in `yosys_slang.bzl`) must compile
   against the new yosys — bump its commit if it won't.
6. Commit: `upgrade: bazel-orfs <sha> / OpenROAD <sha> (...)`. Include the `MODULE.bazel`,
   submodule pointer, `patches/`, and any dropped-patch deletions.

## Step 4 — Capture a QoR baseline

Before relying on new numbers, snapshot the old ones. The local `bazel-remote` cache is
often sparse, so use whatever's cached + the committed per-platform numbers in each
`designs/src/<design>/DECISIONS.md`:

```bash
REMOTE_CACHE=http://127.0.0.1:8080 ./tools/fetch_cache.sh --timeout 240 <plat> <design>
./tools/summary.sh > qor_baseline.txt    # WNS, Fmax, area, per-class cell counts
```

## Step 5 — Validate designs, smallest → largest (one commit per pass)

Order by size (cells / macro count / `CORE_UTILIZATION` — see CLAUDE.md platform table).
For each in-scope pair:

1. `bazel build //designs/<plat>/<design>:<design>_gallery` (local build populates the
   cache via `.bazelrc.user`). Heavy designs may be staged on k8s, but the committed run
   is local.
2. Read `bazel-bin/designs/<plat>/<design>/reports/<plat>/<design>/base/6_report.json` and
   compare to baseline with `tools/summary.sh`. Use the per-`class:*` cell counts (exclude
   fill/tap/antenna — see CLAUDE.md "Reporting cell counts"). Acceptable: WNS / area /
   power within ~5%, no new DRC.
3. Try removing this design's now-fixed workarounds (Step 2 map); rebuild; **keep the
   removal only if it still closes within ~5%**, else restore the knob.
4. Regression > 5% or non-finish: re-tune flow knobs only (never RTL/SDC). Escalate to the
   user only if knobs can't recover it.
5. Update `designs/src/<design>/DECISIONS.md` (per-platform: status, date+SHA, workarounds
   removed/kept, QoR delta) and CLAUDE.md's workaround table / "Reaching `_final`" lists.
6. Commit: `<design>: passes on bazel-orfs <sha> (QoR within X%)`.

## Step 6 — Finalize

Update CLAUDE.md's workaround table (delete fully-removed rows, note the new pin) and the
build-status lists. Confirm every in-scope pair has a green local build, a per-design
commit, and a refreshed DECISIONS.md.
