---
name: track-bug
description: Document a newly-found upstream tool bug (OpenROAD, yosys-slang, sv2v, ORFS, bazel-orfs, …) in CLAUDE.md's "Known OpenROAD / yosys-slang bug workarounds" table. Searches the relevant repo for matching GitHub issues, captures the workaround, and updates the env-var subsection if a new flag is used. Use when a bug shows up in tool output, NOT for design issues (broken constraints, congestion, etc.).
argument-hint: "[tool] [error-code-or-short-description]"
---

# Track an Upstream Tool Bug

The user just hit (or fixed a workaround for) a bug in an upstream tool — OpenROAD, yosys, yosys-slang, sv2v, ORFS, bazel-orfs, KLayout, qt-bazel, etc.  Capture it in `CLAUDE.md`'s **"Known OpenROAD / yosys-slang bug workarounds"** table (around line 177), with a link to the upstream GitHub issue and the workaround that lives in this repo.

The user may have given you the tool name (`$0`) and/or an error code or short description (`$1`).  Fill in whatever's missing by reading the conversation, recent build logs, and recent commits.

**Important — what counts as a tool bug**

✅ In scope (track these):
- Stage failures with an error code that points at tool internals (`MPL-0040`, `CTS-0105`, `ODB-1200`, `DPL-0036`, `GUI-0076`, …).
- Output that is silently wrong (yosys-slang's phantom drivers, sv2v emitting incorrect Verilog, klayout misreading layer maps).
- Flow pathologies that aren't a bug per se but where the only mitigation is a tool flag (`SKIP_INCREMENTAL_REPAIR` for repair_timing non-convergence).
- Tool crashes / segfaults / Tcl errors during a stage script.

❌ Out of scope (don't track here — they belong in /debug-design or /optimize-ppa instead):
- Designs that miss timing because the constraint is too aggressive.
- Designs that overflow placement because utilization is too high.
- Missing FakeRAM LEFs, wrong include paths, etc. — these are HighTide-side configuration mistakes.

## Step 1: Confirm the bug is in scope and gather facts

Ask the user (or read from context) for:

| Field | Where to look |
|---|---|
| **Tool** | Which binary printed the error: `openroad`, `yosys`, `yosys-slang` (an `external/+yosys_slang+yosys-slang/...` path is the giveaway), `sv2v`, `make`, `klayout`, `bazel`, etc. |
| **Error code or short symptom** | Tool log, e.g. `[ERROR ODB-1200]`, `[ERROR CTS-0105]`, `Tcl: invalid command name`, `slang: assertion failed: ...`. If there's no code, write a 1-line description. |
| **Affected designs** | Which `<platform>/<design>` builds hit it.  Use `./tools/summary.sh` to confirm "incomplete builds" lines. |
| **Stage** | Which ORFS stage the failure happens in (`synth`, `floorplan`, `place`, `cts`, `grt`, `route`, `final`). |
| **Reproduces consistently?** | If yes, useful for a minimal upstream repro later. |

If the user invoked the skill with bare arguments (e.g. `/track-bug openroad ODB-1200`), use them as the starting hint and search the conversation/logs for the rest.

## Step 2: Search the upstream repo for matching issues

Use `gh` to search the issue tracker.  The mapping from tool to repo:

| Tool | GitHub repo |
|---|---|
| OpenROAD (binary, Tcl scripts shipped with it) | `The-OpenROAD-Project/OpenROAD` |
| yosys (BCR-built core) | `YosysHQ/yosys` |
| yosys-slang | `povik/yosys-slang` |
| sv2v | `zachjs/sv2v` |
| ORFS (flow scripts, Makefile) | `The-OpenROAD-Project/OpenROAD-flow-scripts` |
| bazel-orfs (Bazel rules) | `The-OpenROAD-Project/bazel-orfs` |
| KLayout / klayout-bazel | `KLayout/klayout` (mock klayout in bazel-orfs is mock_klayout.bzl) |
| qt-bazel | `The-OpenROAD-Project/qt_bazel_prebuilts` |

Search command (replace `<repo>` and `<query>`):

```bash
gh search issues --repo <repo> --state all --limit 10 "<query>"
gh issue list --repo <repo> --state open --limit 5 --search "<query>"
```

Try multiple queries:
- The exact error code (`ODB-1200`, `MPL-0040`).
- A distinctive substring of the error message.
- The Tcl command or function name that throws.

Show the user the candidate matches and confirm which (if any) is the right one.  If there are multiple plausible matches, prefer the *open* issue most recently active.

If **no upstream issue exists**, flag this and offer to help draft one in Step 5.

## Step 3: Identify the workaround

The user typically already has a fix in mind or has applied one.  Capture:

- **What** the workaround changes (a config knob, a `PRE_<stage>_TCL` script, a vendored patch, a bumped commit pin).
- **Where** it lives (which file path).
- **First commit** that landed it.  Look it up:
  ```bash
  git log --oneline -- <path-to-fix>
  ```
  Use the **first** sha that introduced the workaround in this repo, not the most recent edit.

Common workaround patterns to recognize:

- **`PRE_<stage>_TCL`** Tcl injection — e.g. resetting `dbSourceType` before CTS for CTS-0105.
- **Skip flag** — `SKIP_CTS_REPAIR_TIMING`, `SKIP_INCREMENTAL_REPAIR`, `SKIP_LAST_GASP` (already documented in the env-var subsection).
- **Move-sequence trim** — drop a misbehaving move from `SETUP_MOVE_SEQUENCE` (e.g. removing `split_load` to dodge ODB-1200).
- **Manual macro placement** — `macros.tcl` to bypass MPL-0040.
- **Vendored patch / pin bump** — pinning a known-good commit of the offending tool.
- **`GDS_ALLOW_EMPTY`** glob — accept empty GDS for FakeRAM blocks.
- **Util/density loosening** — only count this as a *workaround* if the loose value is non-obvious and tied to a specific tool failure, not a tuning choice.

## Step 4: Add a row to CLAUDE.md

Open `CLAUDE.md`, find the table that begins with `| Bug | Affected designs | Workaround | First commit | Issue |`, and append a new row in the same format.  Keep cells terse — the table is meant to be scannable.

Row template:

```
| **<error code / short label>** — <one-sentence description of the bug, including what tool prints it and what state it leaves the flow in> | <platform>/<design list> | <one-line workaround description, naming the env var or file used> | `<8-char first-commit sha>` | [<repo-shortname>#<num>](<full url>) |
```

If there is **no upstream issue**, put `None` (or `None — <reason>`, e.g. `None (ORFS layering issue; no upstream issue filed yet)`) in the Issue column rather than leaving it blank.

If the workaround uses a new env var or `PRE_*_TCL` slot that isn't already mentioned in the **"Useful ORFS env vars for these workarounds"** subsection just below the table, add a bullet there too with a one-line description.

If the workaround uses an existing env var, do **not** re-document it — just reference it by name in the row.

## Step 5: (Optional) Help file an upstream issue

If Step 2 found no matching issue and the bug is reproducible, offer to help draft one.  A good upstream issue contains:

1. **Tool version** — for OpenROAD, the commit sha pinned in our `MODULE.bazel` (`grep openroad MODULE.bazel` or read `bazel-orfs/MODULE.bazel`).  For yosys / yosys-slang, the BCR version + the `yosys-slang.bzl` commit.
2. **Minimal repro** — ideally a small RTL + SDC the maintainer can run standalone.  HighTide RTL is usually too large; offer to extract the offending module.
3. **Full error log** — the relevant stage's `.log` file, copied verbatim.
4. **What the user expected**.

Don't auto-create the issue — surface the draft text and let the user post it via `gh issue create` themselves.  Update the CLAUDE.md row's Issue column to point at the new issue once filed.

## Step 6: Confirm

Show the user the diff of the CLAUDE.md change (and the env-var bullet if added) before saving, so they can adjust wording.  Once accepted, leave it for them to commit — don't auto-commit.

---

## Examples

### Example 1: User invokes with explicit args

```
/track-bug openroad CTS-0105
```

Recognize: tool = OpenROAD, error code = CTS-0105.  Skim the conversation for which design tripped it; if not obvious, ask.  Search `The-OpenROAD-Project/OpenROAD` for "CTS-0105" → find the open issue.  Identify the workaround the user just landed (likely a `PRE_CTS_TCL` script).  Add a row.

### Example 2: User invokes bare

```
/track-bug
```

Read the conversation: a recent build error showed `[ERROR ODB-1200] InsertBufferBeforeLoads ...` during `cts.tcl`'s repair_timing.  That's an OpenROAD ODB error inside a CTS-time pass.  Search OpenROAD repo for "ODB-1200 InsertBufferBeforeLoads" → no hit; search "InsertBufferBeforeLoads stale" → find an open issue.  Workaround the user just landed: drop `split_load` from `SETUP_MOVE_SEQUENCE`.  Add a row, optionally update the env-var bullet for `SETUP_MOVE_SEQUENCE` (already there in this case).

### Example 3: New env var introduced

User adds a `SKIP_GLOBAL_PLACE_TIMING_DRIVEN = 1` flag (hypothetical).  Beyond adding the table row, also add a bullet under **"Useful ORFS env vars for these workarounds"**:

```
- **`SKIP_GLOBAL_PLACE_TIMING_DRIVEN = 1`** — skip the timing-driven inner pass during global placement.  Use when GP repair_timing chases all nets on macro-heavy designs.
```
