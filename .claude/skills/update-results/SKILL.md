---
name: update-results
description: Refresh webpage/results.html, webpage/index.html (Design Portfolio platform badges), webpage/gallery.html, and webpage/figures/ to reflect each (platform, design) pair's latest cached build. Detects stale rows by comparing a per-row data-commit attribute to the design's most recent commit, refetches the cached 6_report.json via tools/fetch_cache.sh, regenerates the gallery image at <design>_<platform>_<sha>.png, deletes the previous versioned image, and rewrites the table between RESULTS_START / RESULTS_END markers. Also handles the one-time migration from canonical filenames (cnn_asap7.png) to commit-versioned ones. Use after a build sweep lands new artifacts in the remote cache.
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

Look for canonical filenames (no SHA component) in **both** the full-resolution PNGs and the JPEG thumbnails — they migrate together so `<img src=…>` and `<a href=…>` always reference the same SHA.  Either may predate this skill and need a one-time rename to the versioned convention:

```bash
# full-res PNGs
ls "$WT"/figures/*.png 2>/dev/null \
    | grep -vE '_[0-9a-f]{7,}\.png$' \
    | grep -vE '/(HighTideFLOW|lighthouse|final_placement_)'   # exclude infra figures, not per-design

# JPEG thumbnails
ls "$WT"/figures/thumbs/*.jpg 2>/dev/null \
    | grep -vE '_[0-9a-f]{7,}\.jpg$'
```

Anything that comes back is on the canonical-name convention.  For each, decode `<design>_<platform>` from the filename, compute the design's current SHA (Step 4 below), then:

```bash
git mv "$WT"/figures/<design>_<platform>.png \
       "$WT"/figures/<design>_<platform>_<sha>.png
git mv "$WT"/figures/thumbs/<design>_<platform>.jpg \
       "$WT"/figures/thumbs/<design>_<platform>_<sha>.jpg
```

Use `git mv` so the rename history is preserved.  Both renames must use the *same* SHA for a given (design, platform) — if either side already has a versioned name, use that SHA for the other side rather than recomputing.

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

# Copy versioned full-res image, delete the previous one.
new_img="$WT/figures/${leaf}_${platform}_${sha}.png"
old_img=$(ls "$WT"/figures/${leaf}_${platform}_*.png 2>/dev/null | grep -v "_${sha}.png$" | head -1)
cp "bazel-bin/designs/$design_dir/${leaf}_gallery.png" "$new_img"
[[ -n "$old_img" ]] && git -C "$WT" rm -f "$old_img"
git -C "$WT" add "$new_img"

# Generate the versioned thumbnail, delete the previous one.
python3 tools/gallery/make_thumbnails.py "$WT/figures"   # rebuilds thumbs/ for any new PNG
new_thumb="$WT/figures/thumbs/${leaf}_${platform}_${sha}.jpg"
old_thumb=$(ls "$WT"/figures/thumbs/${leaf}_${platform}_*.jpg "$WT"/figures/thumbs/${leaf}_${platform}.jpg 2>/dev/null | grep -v "_${sha}.jpg$" | head -1)
[[ -n "$old_thumb" ]] && git -C "$WT" rm -f "$old_thumb"
git -C "$WT" add "$new_thumb"
```

Capture QoR from the JSON using the same metric keys `tools/summary.sh` reads:
- `finish__design__die__area`
- `finish__design__core__area`
- `finish__design__instance__area__stdcell`
- `finish__design__instance__utilization` (× 100 for %)
- `finish__design__instance__count__stdcell`
- `finish__design__instance__count__macros`
- `finish__design__io`
- `finish__timing__setup__ws` (WNS)
- `finish__timing__setup__tns` (TNS)
- `finish__timing__fmax` (÷ 1e9 for GHz)
- `finish__power__total` (× 1000 for mW)
- `finish__flow__errors__count` (DRCs)

Format with the same precision as `tools/summary.sh:53-84` (areas / cells / counts: 1 decimal; timing / fmax: 2 decimals; power: 3 decimals; util: 1 decimal).

## Step 6: Rewrite the table between markers

Find `<!-- RESULTS_START -->` and `<!-- RESULTS_END -->` in `webpage/results.html`.  Replace everything between them with one `<tr>` per (platform, design) in `(platform, design)` sort order:

```html
<tr data-design="cnn" data-platform="asap7" data-commit="a1b2c3d">
  <td><span class="platform-badge badge-asap7">asap7</span></td>
  <td>cnn</td>
  <td>360000.0</td>
  <td>336166.0</td>
  <td>23936.7</td>
  <td>40.1</td>
  <td>212257</td>
  <td>65</td>
  <td>367</td>
  <td>-44.30</td>
  <td>-149.87</td>
  <td>0.96</td>
  <td>456.091</td>
  <td>0</td>
  <td><a href="https://github.com/VLSIDA/HighTide/commit/a1b2c3d">a1b2c3d</a></td>
</tr>
```

The first time the skill runs the table needs a new `<th>Commit</th>` column at the right end of the `<thead>` row — add it once, idempotent.

If a (platform, design) is currently NOT CACHED (Step 5 skipped it), preserve any existing row in the table (don't drop the design from the page just because the user's local cache is empty).  Use `<!-- skipped: not cached on YYYY-MM-DD -->` as a comment marker to make stale-data sources visible.

## Step 7: Update gallery.html thumbnails

`webpage/gallery.html` references the same images.  Both reference families need to point at the versioned names from Step 5:

- `<a class="thumb-link" href="figures/<design>_<platform>_<sha>.png">` — full-res click target
- `<img src="figures/thumbs/<design>_<platform>_<sha>.jpg">` — visible thumbnail

The full-res `href` and the thumbnail `src` MUST share the same SHA — they describe the same routed view; mismatched SHAs means the user clicks a thumb of one build and lands on a different build's full image.

Same migration rule applies on first run for both the `.png` and `.jpg` references.

### Thumbnail order within each design card

For a card whose family has multiple thumbnails (NVDLA partitions a/c/m/o/p, LiteEth's 6 PHY/bus variants, etc.), order the `<a class="thumb-link">` entries by **(platform, variant)** — platform first, then variant alphabetically within each platform.  Platform sequence is always asap7 → nangate45 → sky130hd to match the badge ordering everywhere else.

Concretely: emit all asap7 thumbs (sorted by variant), then all nangate45 thumbs, then all sky130hd thumbs.  This produces a clean per-platform row in the auto-fill grid (~6 cells across) for cards like LiteEth, and matches the existing NVDLA ordering.

For cards with one thumb per platform (CoralNPU, Vortex, Gemmini, etc.), the variant secondary sort is a no-op — just preserve asap7 → nangate45 → sky130hd order.

## Step 8: Update the Design Portfolio platform badges in index.html

`webpage/index.html` has a "Design Portfolio" table (`<section id="designs">`) where each row's last column is a list of `<span class="platform-badge badge-<platform>">…</span>` tags.  Those badges must reflect which platforms each design *actually* reaches `_final` on, derived from the same per-(platform, design) sweep used above.

### Display-name → design-family mapping

Index rows use display names; the sweep produces leaf names.  Map them like this (rows not in the sweep are left untouched):

| Display name      | Design family (any variant qualifies)                |
|-------------------|------------------------------------------------------|
| BlackParrot       | bp_uno, bp_quad                                      |
| Gemmini           | gemmini                                              |
| SHA3              | sha3                                                 |
| CNN               | cnn                                                  |
| NyuziProcessor    | NyuziProcessor                                       |
| Minimax           | minimax                                              |
| LiteEth           | liteeth_* (any of the 6 variants)                    |
| CoralNPU          | coralnpu                                             |
| NVDLA             | partition_a … partition_p (any of the 5 partitions)  |
| FlooNoC           | floonoc                                              |
| Snitch Cluster    | snitch_cluster                                       |
| Vortex            | vortex                                               |

For a family design, a platform badge appears if **any** family member has a cached `_final` for that platform.  This matches how the gallery card aggregates variants on a single design entry.

### Update procedure

For each `<tr>` whose `<td><strong>…</strong></td>` matches a row in the table above:

1. Compute the active-platforms set for that family from the Step 5 results: `{platform : ∃ design ∈ family with cached _final on platform}`.
2. Re-emit the badge `<td>` with one `<span class="platform-badge badge-<platform>">…</span>` per active platform, ordered asap7 → nangate45 → sky130hd, indented to match the surrounding HTML.
3. If the active set is empty, leave the row's badges as-is and emit `<!-- skipped: no cached _final on YYYY-MM-DD -->` next to the badges so a future sweep can re-evaluate.
4. Don't touch any other column (description, language) — those are hand-curated and have no machine-readable source of truth.

This step is idempotent: running the skill twice in a row produces no diff if the cache state hasn't changed.

## Step 9: Show the diff and stop

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
> Updated index.html design portfolio: 12 rows, 3 platform badges added (cnn nangate45, gemmini sky130hd, sha3 sky130hd), 1 removed (floonoc nangate45 → cache cold).
> Diff:
>     index.html   |  18 +++++++++--------
>     results.html | 412 ++++++++++++++++++++++++++++++++++++++++++--------------
>     gallery.html |  84 +++++-----
>     figures/     | 38 deletions, 38 creations (renames)
> Run `git -C /home/mrg/HighTide/webpage diff` to review, then commit + push.
```
