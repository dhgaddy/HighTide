---
name: update-results
description: Refresh webpage/results.html and webpage/figures/ to reflect each (platform, design) pair's latest cached build. Detects stale rows by comparing a per-row data-commit attribute to the design's most recent commit, refetches the cached 6_report.json via tools/fetch_cache.sh, regenerates the gallery image at <design>_<platform>_<sha>.png, deletes the previous versioned image, and rewrites the table between RESULTS_START / RESULTS_END markers. Also handles the one-time migration from canonical filenames (cnn_asap7.png) to commit-versioned ones. Use after a build sweep lands new artifacts in the remote cache.
argument-hint: "[platform] [design]"
---

# Update results.html and gallery figures

Keeps `webpage/results.html` and `webpage/figures/` in sync with each design's latest cached `6_report.json`.  Each row pins a **commit SHA** (the most recent commit touching that design's BUILD/SDC/RTL); the gallery image is named with the same SHA so the row and image cannot drift.  Old image files are deleted as new versions land.

The user may have given a `[platform]` and/or `[design]` filter (`$0` / `$1`) — use the same matching semantics as `k8s/run.sh` (positional, with `--design` for design-only).  No filter = sweep everything.

**Operates on the `webpage` git worktree**, not whichever branch the user is currently on.  Find it with `git worktree list | awk '$3=="[webpage]"{print $1}'`.

## Step 1: Locate the webpage worktree and check it's clean

```bash
WT=$(git worktree list | awk '$3=="[webpage]"{print $1}')
test -n "$WT" || die "no webpage worktree found; create one with 'git worktree add ../webpage webpage'"
git -C "$WT" status --short
```

If the worktree has uncommitted changes (other than the ones you're about to make), warn the user and ask whether to proceed — don't blindly add to a dirty tree.

If `webpage` is behind `origin/webpage`, fast-forward it before doing any work:

```bash
git -C "$WT" pull --ff-only
```

## Step 2: Detect first-time migration

Look for canonical filenames (no SHA component).  These predate this skill and need a one-time rename to the new convention:

```bash
ls "$WT"/figures/*.png 2>/dev/null \
    | grep -vE '_[0-9a-f]{7,}\.png$' \
    | grep -vE '/(HighTideFLOW|lighthouse|final_placement_)'   # exclude infra figures, not per-design
```

Anything that comes back is on the canonical-name convention.  For each, decode `<design>_<platform>` from the filename, compute the design's current SHA (Step 4 below), then:

```bash
git mv "$WT"/figures/<design>_<platform>.png \
       "$WT"/figures/<design>_<platform>_<sha>.png
```

Use `git mv` so the rename history is preserved.

After all migrations, the existing single `<tr>` in results.html (currently a hardcoded lfsr row) should be replaced with a freshly-generated row in Step 6.  Don't try to migrate the row in place — just regenerate it.

## Step 3: Determine the design list

```bash
bazel query '//designs/...' 2>/dev/null \
    | awk -F: '/_final$/ { sub(":.*", "", $0); print $0 }' \
    | sort -u
```

That yields entries like `//designs/asap7/cnn`.  Strip the prefix to get `<platform>/<design-path>`.  Apply `[platform]` / `[design]` filters if provided.

For each, derive:
- `platform` (first segment)
- `design_dir` (full path under `designs/`)
- `leaf` (last segment of `design_dir`)
- `bazel_target = //designs/<design_dir>:<leaf>_final`
- `gallery_target = //designs/<design_dir>:<leaf>_gallery`
- `report_path = bazel-bin/designs/<design_dir>/logs/<platform>/<top>/base/6_report.json` — `<top>` is whatever the design's `top` is, usually `<leaf>` but not always (e.g. lfsr's top is `lfsr_prbs_gen`).  Read it from `bazel query --output=build //designs/<design_dir>:<leaf>_final` if uncertain, or just glob `logs/<platform>/*/base/6_report.json`.

## Step 4: Compute the design SHA

For each (platform, design):

```bash
sha=$(git log -1 --format=%h -- \
    "designs/$design_dir/" \
    "designs/src/$leaf/" 2>/dev/null)
```

7 chars (default `%h`), matching GitHub's commit-link convention.  If the design has no `designs/src/<leaf>/` (no per-design RTL submodule, e.g. lfsr's RTL is in `designs/src/lfsr/` but for designs whose RTL lives elsewhere, just drop the second arg).

## Step 5: Refresh stale designs

Parse `webpage/results.html` for existing rows.  Each row is keyed by `data-design` + `data-platform`; its current commit is `data-commit`.  A row is **stale** if `data-commit` ≠ the SHA from Step 4, or the row is missing entirely.

For each stale (platform, design):

```bash
# Pull the cached JSON.  No local build — if cache miss, log + skip.
./tools/fetch_cache.sh "$platform" "$leaf" || { echo "WARN: $platform/$leaf NOT CACHED, skipping"; continue; }

# Build only this design's gallery target.
bazel build "$gallery_target"

# Copy versioned image, delete the previous one.
new_img="$WT/figures/${leaf}_${platform}_${sha}.png"
old_img=$(ls "$WT"/figures/${leaf}_${platform}_*.png 2>/dev/null | grep -v "_${sha}.png$" | head -1)
cp "bazel-bin/designs/$design_dir/${leaf}_gallery.png" "$new_img"
[[ -n "$old_img" ]] && git -C "$WT" rm -f "$old_img"
git -C "$WT" add "$new_img"
```

Capture QoR from the JSON using the same metric keys `tools/summary.sh` reads:

**Areas / utilization:**
- `finish__design__die__area`
- `finish__design__core__area`
- `finish__design__instance__area__stdcell`
- `finish__design__instance__utilization` (× 100 for %)

**Cell-class breakdown** (the table replaces the old single "Cells" column with three: Sequential / Combinational / Buf-Inv):
- `finish__design__instance__count__class:sequential_cell` → **Sequential**
- `finish__design__instance__count__class:multi_input_combinational_cell` → **Combinational** (does not include buf/inv)
- Sum these for **Buf/Inv**:
  - `finish__design__instance__count__class:inverter`
  - `finish__design__instance__count__class:clock_buffer`
  - `finish__design__instance__count__class:clock_inverter`
  - `finish__design__instance__count__class:timing_repair_buffer`
  - `finish__design__instance__count__class:timing_repair_inverter`
- `finish__design__instance__count__class:macro` (fall back to `finish__design__instance__count__macros` if not present)
- `finish__design__io`

**Timing — convert all platforms to picoseconds.**  asap7 Liberty uses ps natively; nangate45 / sky130hd use ns, so multiply their values by 1000:
- `finish__timing__setup__ws` → **Slack** (signed; positive is good)
- `finish__clock__skew__setup` → **Skew**
- `finish__timing__fmax` (÷ 1e9 for GHz)

**Power:**
- `finish__power__total` (× 1000 for mW)
- **Clock power is not in the JSON** — parse it from `reports/<platform>/<design>/base/6_finish.rpt`.  Find the `report_power` section, then the `Clock` row; sum its 2nd / 3rd / 4th whitespace fields (Internal + Switching + Leakage Watts) and multiply by 1000 for mW.

**Removed columns**: TNS (always 0 for closing designs; redundant with Slack) and DRCs (always 0 in this benchmark suite).

Format with the same precision as `tools/summary.sh` (areas / counts: 1 decimal or integer; timing / fmax: 2 decimals; power: 3 decimals; util: 1 decimal).

## Step 6: Rewrite the table between markers

Find `<!-- RESULTS_START -->` and `<!-- RESULTS_END -->` in `webpage/results.html`.  Replace everything between them with one `<tr>` per (platform, design) in `(platform, design)` sort order:

```html
<tr data-design="cnn" data-platform="asap7" data-commit="a1b2c3d">
  <td><span class="platform-badge badge-asap7">asap7</span></td>
  <td>cnn</td>
  <td>360000.0</td>            <!-- Die Area μm² -->
  <td>336166.0</td>            <!-- Core Area μm² -->
  <td>23936.7</td>             <!-- Inst Area μm² -->
  <td>40.1</td>                <!-- Util % -->
  <td>28507</td>               <!-- Sequential -->
  <td>106616</td>              <!-- Combinational -->
  <td>36463</td>               <!-- Buf/Inv -->
  <td>65</td>                  <!-- Macros -->
  <td>367</td>                 <!-- IOs -->
  <td>-44.30</td>              <!-- Slack ps -->
  <td>118.16</td>              <!-- Skew ps -->
  <td>0.96</td>                <!-- Fmax GHz -->
  <td>456.091</td>             <!-- Power mW -->
  <td>47.501</td>              <!-- Clk Power mW -->
  <td><a href="https://github.com/VLSIDA/HighTide/commit/a1b2c3d">a1b2c3d</a></td>
</tr>
```

Column order in `<thead>` (17 columns total): Platform, Design, Die Area, Core Area, Inst Area, Util%, Sequential, Combinational, Buf/Inv, Macros, IOs, Slack ps, Skew ps, Fmax GHz, Power mW, Clk Power mW, Commit.  Keep `data-col` indices on the `<th>` matching the column position so the JS sort/filter logic stays in sync.

The "Total Cells" filter input in the page sums columns 6+7+8 (Sequential + Combinational + Buf/Inv).

If a (platform, design) is currently NOT CACHED (Step 5 skipped it), preserve any existing row in the table (don't drop the design from the page just because the user's local cache is empty).  Use `<!-- skipped: not cached on YYYY-MM-DD -->` as a comment marker to make stale-data sources visible.

## Step 7: Update gallery.html thumbnails

`webpage/gallery.html` references the same images.  Replace its `<img src="figures/<old>.png">` references to point at the new versioned filenames.  Same migration rule applies on first run.

## Step 8: Show the diff and stop

```bash
git -C "$WT" status --short
git -C "$WT" diff --stat
git -C "$WT" diff figures/ -- ':(exclude)*.png' | head   # text-only diff for HTML
```

Surface the change set to the user, list any designs that were skipped because the cache was cold, and stop.  Don't `git commit` or `git push` — leave that to the user.

## Worked example

```
/update-results
```

(No filter, so sweep everything.)

```
> Locating webpage worktree at /home/mrg/HighTide/webpage … clean (origin/webpage @ 1d9ccec4).
> Migration check: 38 canonical-name PNGs found, renaming to <design>_<platform>_<sha>.png …
>   figures/cnn_asap7.png        → cnn_asap7_a1b2c3d.png
>   figures/coralnpu_asap7.png   → coralnpu_asap7_e4f5g6h.png
>   …
> Sweep: 56 (platform, design) pairs.
>   asap7/cnn         a1b2c3d  STALE (table commit was canonical-only)
>     ./tools/fetch_cache.sh asap7 cnn → cached
>     bazel build //designs/asap7/cnn:cnn_gallery → 0.4s, cache hit
>     wrote figures/cnn_asap7_a1b2c3d.png (replaces cnn_asap7.png)
>   sky130hd/NVDLA/partition_c   stale  NOT CACHED → skipped
>   …
> Rewrote results.html (56 rows, 1 skipped → preserved as comment).
> Rewrote gallery.html (38 image references updated).
> Diff:
>     results.html | 412 ++++++++++++++++++++++++++++++++++++++++++--------------
>     gallery.html |  84 +++++-----
>     figures/     | 38 deletions, 38 creations (renames)
> Run `git -C /home/mrg/HighTide/webpage diff` to review, then commit + push.
```
