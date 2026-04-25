#!/bin/bash
# Quickly compare every git submodule's pinned commit to its upstream HEAD
# using the GitHub REST API.  No cloning or fetching — works on a cold
# checkout in seconds.
#
# Outputs:
#   - Markdown table to stdout (always)
#   - NDJSON of actionable items to $AUDIT_OUT (default: audit_upstream_items.ndjson)
#     one line per submodule whose pinned commit is behind upstream
#
# Requires: gh (authenticated via GH_TOKEN or gh auth login), jq.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_DIR"

OUT_JSON="${AUDIT_OUT:-audit_upstream_items.ndjson}"
: > "$OUT_JSON"

# Snapshot all existing audit issues (open and closed) so we can attach
# their numbers to each actionable item.  One API call total.
EXISTING_ISSUES=$(gh issue list --label upstream-update --state all --limit 200 \
                    --json number,state,title 2>/dev/null || echo '[]')

# Collect submodule names from .gitmodules
mapfile -t NAMES < <(
    git config -f .gitmodules --get-regexp '^submodule\..*\.path$' \
    | sed -E 's/^submodule\.(.*)\.path .*/\1/'
)

printf '| %-50s | %-8s | %-8s | %6s | %-11s | %-11s | %10s |\n' \
    "Submodule" "Pinned" "Upstream" "Behind" "Pinned" "Upstream" "Days stale"
printf '|%s|%s|%s|%s|%s|%s|%s|\n' \
    "$(printf -- '-%.0s' {1..52})" \
    "$(printf -- '-%.0s' {1..10})" \
    "$(printf -- '-%.0s' {1..10})" \
    "$(printf -- '-%.0s' {1..8})" \
    "$(printf -- '-%.0s' {1..13})" \
    "$(printf -- '-%.0s' {1..13})" \
    "$(printf -- '-%.0s' {1..12})"

for name in "${NAMES[@]}"; do
    path=$(git config -f .gitmodules "submodule.${name}.path")
    url=$(git config -f .gitmodules "submodule.${name}.url")
    branch=$(git config -f .gitmodules "submodule.${name}.branch" 2>/dev/null || true)

    if ! [[ "$url" =~ github\.com[:/]([^/]+)/([^/]+) ]]; then
        printf '| `%-48s` | %-8s | %-8s | %6s | %-11s | %-11s | %10s |\n' \
            "$path" "-" "non-github" "-" "-" "-" "-"
        continue
    fi
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]%.git}"
    repo="${repo%/}"

    pinned_sha=$(git ls-tree HEAD "$path" 2>/dev/null | awk '{print $3}')
    if [[ -z "$pinned_sha" ]]; then
        printf '| `%-48s` | %-8s | %-8s | %6s | %-11s | %-11s | %10s |\n' \
            "$path" "unknown" "-" "-" "-" "-" "-"
        continue
    fi
    pinned_short="${pinned_sha:0:7}"

    # Tracked branch: explicit in .gitmodules, or the repo's default
    if [[ -z "$branch" ]]; then
        branch=$(gh api "repos/$owner/$repo" --jq '.default_branch' 2>/dev/null || echo "HEAD")
    fi

    pinned_date=$(gh api "repos/$owner/$repo/commits/$pinned_sha" --jq '.commit.author.date // empty' 2>/dev/null | cut -c1-10)
    upstream_sha=$(gh api "repos/$owner/$repo/commits/$branch" --jq '.sha // empty' 2>/dev/null)
    upstream_date=$(gh api "repos/$owner/$repo/commits/$branch" --jq '.commit.author.date // empty' 2>/dev/null | cut -c1-10)
    upstream_short="${upstream_sha:0:7}"

    if [[ -z "$upstream_sha" ]]; then
        printf '| `%-48s` | %-8s | %-8s | %6s | %-11s | %-11s | %10s |\n' \
            "$path" "$pinned_short" "api-error" "-" "${pinned_date:--}" "-" "-"
        continue
    fi

    if [[ "$pinned_sha" == "$upstream_sha" ]]; then
        behind=0
    else
        behind=$(gh api "repos/$owner/$repo/compare/${pinned_sha}...${upstream_sha}" --jq '.ahead_by // "?"' 2>/dev/null || echo "?")
    fi

    days_stale="-"
    if [[ -n "${pinned_date:-}" && -n "${upstream_date:-}" ]]; then
        p_epoch=$(date -d "$pinned_date" +%s 2>/dev/null || echo "")
        u_epoch=$(date -d "$upstream_date" +%s 2>/dev/null || echo "")
        if [[ -n "$p_epoch" && -n "$u_epoch" ]]; then
            days_stale=$(( (u_epoch - p_epoch) / 86400 ))
        fi
    fi

    printf '| `%-48s` | %-8s | %-8s | %6s | %-11s | %-11s | %10s |\n' \
        "$path" "$pinned_short" "$upstream_short" "$behind" \
        "${pinned_date:--}" "${upstream_date:--}" "$days_stale"

    if [[ "$behind" != "0" && "$behind" != "?" ]]; then
        title="Upstream update available: $path"
        existing=$(jq -c --arg t "$title" 'map(select(.title == $t)) | first // null' <<<"$EXISTING_ISSUES")
        existing_number=$(jq -r 'if . == null then "" else .number end' <<<"$existing")
        existing_state=$(jq -r 'if . == null then "" else .state end' <<<"$existing")

        jq -cn \
            --arg path "$path" --arg owner "$owner" --arg repo "$repo" \
            --arg branch "$branch" \
            --arg pinned "$pinned_sha" --arg upstream "$upstream_sha" \
            --argjson behind "$behind" \
            --arg pinned_date "${pinned_date:-}" --arg upstream_date "${upstream_date:-}" \
            --arg days_stale "$days_stale" \
            --arg existing_issue "$existing_number" \
            --arg existing_state "$existing_state" \
            '{path:$path, owner:$owner, repo:$repo, branch:$branch,
              pinned:$pinned, upstream:$upstream, behind:$behind,
              pinned_date:$pinned_date, upstream_date:$upstream_date,
              days_stale:$days_stale,
              existing_issue:$existing_issue,
              existing_state:$existing_state}' >> "$OUT_JSON"
    fi
done

echo ""
n_items=$(wc -l < "$OUT_JSON" 2>/dev/null | awk '{print $1}')
echo "Actionable items (behind > 0): ${n_items:-0}"
echo "Details written to: $OUT_JSON"
