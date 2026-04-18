---
name: improve-skills
description: Review past experiences from debugging, optimization, porting, and design work, then update existing HighTide2 skills or propose new ones. Use after completing a session that revealed new patterns, workarounds, or failure modes.
argument-hint: "[optional: skill-name to focus on, or 'all' to audit everything]"
---

# Improve Skills from Experience

Review recent work and update the HighTide2 skills to capture new knowledge. This prevents the team from rediscovering the same solutions.

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

## Step 2: Audit Existing Skills

Read each skill and check for these problems:

### Staleness
- **Outdated paths**: Do file paths, script names, or directory structures still match reality?
- **Removed tools**: Does the skill reference scripts or flows that no longer exist (e.g., Make flow if fully deprecated)?
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
