---
name: improve-skills
description: Review past experiences from debugging, optimization, porting, and design work, then update existing HighTide skills or propose new ones. Use after completing a session that revealed new patterns, workarounds, or failure modes.
argument-hint: "[optional: skill-name to focus on, or 'all' to audit everything]"
---

# Improve Skills from Experience

Review recent work and update the HighTide skills to capture new knowledge. This prevents the team from rediscovering the same solutions.

## Step 1: Gather Recent Experience

### 1a. Check conversation context

Review the current conversation for any of these signals:
- A debugging session that uncovered a non-obvious root cause
- An optimization that found a new technique or parameter interaction
- A porting effort that revealed platform-specific gotchas
- A build failure with a fix that isn't documented in any skill
- A workflow change (new tools, scripts, infrastructure) that skills reference incorrectly

### 1b. Check recent git history for skill-relevant changes

```bash
git log --oneline -20
git log --oneline -20 -- tools/ k8s/ defs.bzl MODULE.bazel Makefile settings.mk
git log --oneline -20 -- designs/
```

Look for:
- New scripts or tools that skills should reference
- Changed infrastructure (Docker image, Bazel config, K8s setup)
- New designs or platforms added
- Config parameter changes that worked well (or didn't)

### 1c. Check memory for feedback and project context

Read the memory index at the project memory path for any feedback or project memories that should be reflected in skills.

### 1d. Mine per-design DECISIONS.md files

Each design records non-obvious choices in `designs/src/<design>/DECISIONS.md`
(bug workarounds, manual macro/IO placement, timing-constraint choices,
utilization tuning, etc., with one section per technology). Aggregate these
into patterns:

```bash
# All decision files with their headings and workaround/issue lines
for f in designs/src/*/DECISIONS.md; do
    echo "=== $f ==="
    grep -E '^#|^- |Workaround:|Issue:|OpenROAD #|yosys-slang #' "$f"
done
```

Look for:
- **Same workaround in multiple designs** — promote to a skill bullet (in `debug-design`, `port-design`, or `optimize-ppa` as appropriate). If the same env var, macro-halo bump, or SDC pattern shows up in 2+ DECISIONS files, it is general knowledge, not design-specific.
- **Same upstream bug referenced** — confirm it is in `CLAUDE.md`'s "Known OpenROAD / yosys-slang bug workarounds" table; if not, hand off to the `track-bug` skill or add it directly.
- **Decisions that contradict skill guidance** — either the skill is wrong, or the design is doing something the skill should explicitly warn about.

### 1e. Cross-reference with OpenROAD upstream issues

DECISIONS.md, CLAUDE.md, and commit messages often reference OpenROAD GitHub
issues by number (e.g. `OpenROAD #1234`) or by tool category (`ODB-1200`,
`CTS-0105`, `MPL-0040`, `PSM-0069`, `GRT-…`, `RSZ-…`). For each issue
referenced more than once across the repo, check its current state:

```bash
# Collect upstream-bug references and rank by frequency
{
    grep -rohE 'OpenROAD[ -]#[0-9]+|ODB-[0-9]+|CTS-[0-9]+|GRT-[0-9]+|MPL-[0-9]+|PSM-[0-9]+|RSZ-[0-9]+' \
        designs/src/*/DECISIONS.md CLAUDE.md 2>/dev/null
    git log --pretty=%B -200 | grep -oE 'OpenROAD[ -]#[0-9]+|ODB-[0-9]+|CTS-[0-9]+|GRT-[0-9]+|MPL-[0-9]+|PSM-[0-9]+|RSZ-[0-9]+'
} | sort | uniq -c | sort -rn

# For frequently-referenced upstream issues, check current state:
gh issue view <num> --repo The-OpenROAD-Project/OpenROAD --json state,title,closedAt
```

Update skills when:
- **An upstream issue is now closed/fixed**: the workaround in DECISIONS.md, CLAUDE.md, or skills can be removed (or marked "no longer needed as of OpenROAD vX.Y") — but verify in a real build before deleting the workaround.
- **A pattern emerges** (e.g., several designs hit MPL-* or CTS-* issues at high utilization): add an early-warning bullet to the relevant skill (`debug-design`, `optimize-ppa`, `port-design`) so future runs spot the symptom sooner.
- **An issue applies broadly** but is only documented in one DECISIONS.md: lift it into `CLAUDE.md`'s known-bug table so all designs benefit.

Use the `track-bug` skill for the mechanics of recording a newly-found
upstream bug; this step is the *discovery* phase that feeds it.

## Step 2: Audit Existing Skills

Read each skill and check for these problems:

### Staleness
- **Outdated paths**: Do file paths, script names, or directory structures still match reality?
- **Removed tools**: Does the skill reference scripts or flows that no longer exist (e.g., the old Make/Docker ORFS flow, removed before 2026-05)?
- **Stale design lists**: Does find-designs or CLAUDE.md list the current set of designs and platforms?
- **Changed infrastructure**: Do K8s, Docker, or Bazel references match the current setup?

### Missing knowledge
- **Undocumented failure modes**: Are there failure patterns we've encountered that no skill covers?
- **Missing diagnostic techniques**: Are there useful commands or metrics we use that aren't in the skills (e.g., GRT congestion report, `report_clock_min_period`)?
- **Parameter interactions**: Are there coupled parameters (like utilization vs. clock period) that skills treat as independent?

### Duplication
- **Repeated content**: Is the same guidance copy-pasted across skills? Extract to `.claude/skills/shared/` and reference it.
- **Overlapping scope**: Do two skills cover the same topic with slightly different (possibly inconsistent) advice?

### Completeness
- **Missing skills**: Is there a common workflow or task that isn't covered by any skill?
- **Missing platforms/designs**: Has the design or platform list grown without updating the skills?

## Step 3: Apply Updates

For each issue found:

### Update an existing skill
1. Read the skill file
2. Make the specific edit (fix the path, add the missing technique, update the list)
3. If extracting shared content, put it in `.claude/skills/shared/<topic>.md` and replace inline content with a reference

### Propose a new skill
If the experience reveals a workflow that's substantially different from existing skills (not just a subsection), propose it to the user before creating. Explain:
- What the skill would cover
- Why it doesn't fit in an existing skill
- What the trigger/description would be

### Update shared references
If the change affects content in `.claude/skills/shared/`, update it there once — all referencing skills benefit automatically.

## Step 4: Verify Consistency

After making changes, do a quick cross-check:
- Grep for any remaining references to removed/renamed paths
- Check that shared files referenced by skills actually exist
- Verify the design/platform lists match `designs/*/BUILD.bazel`

```bash
# Check for broken shared references
grep -r "shared/" .claude/skills/*/SKILL.md | grep -oP 'shared/[^)]+' | sort -u | while read ref; do
  [[ -f ".claude/skills/$ref" ]] || echo "MISSING: $ref"
done

# Check design list currency
find designs -name BUILD.bazel -path "*/designs/*/*" -not -path "*/src/*" | \
  sed 's|designs/||;s|/BUILD.bazel||' | sort
```

## Step 5: Report Changes

Present a summary to the user:
- Which skills were updated and why
- Any new skills proposed
- Any shared content extracted or updated
- Whether the changes should be committed

## Guidelines

- **Don't over-generalize from a single incident.** If a workaround was needed for one specific design, note it as a design-specific tip rather than changing the general workflow.
- **Preserve what works.** Don't rewrite a skill that's working well just because it could be structured differently.
- **Keep skills focused.** A skill should have one clear trigger condition. If it's becoming a "do everything" document, split it.
- **Date-stamp volatile information.** If adding a note about a specific OpenROAD bug or workaround, include the issue number so it can be removed when fixed upstream.
