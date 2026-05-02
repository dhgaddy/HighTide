#!/bin/bash
# Clear the local Bazel cache and bazel-bin outputs for specific designs.
#
# The remote cache (cache.hightide-benchmarks.dev) is content-addressed and
# self-evicting via LRU — there is no client-side way to wipe it.  To force
# a fresh build that overwrites cached results, rebuild with the flags shown
# at the end of this script's output.
#
# Usage:
#   ./tools/clear-cache.sh [platform] [design]   # clear a specific design
#   ./tools/clear-cache.sh [platform]             # clear all designs for a platform
#   ./tools/clear-cache.sh --design [design]      # clear a design across all platforms
#   ./tools/clear-cache.sh --all                  # clear all local caches
#
# Options:
#   --all      Clear the entire local cache (disk cache + bazel output base)
#   --dry-run  Show what would be cleared without doing it

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DISK_CACHE="${HOME}/.cache/bazel-disk-cache"

# Defaults
DRY_RUN=false
CLEAR_ALL=false
FILTER_PLATFORM=""
FILTER_DESIGN=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)      CLEAR_ALL=true; shift ;;
        --dry-run)  DRY_RUN=true; shift ;;
        --design)   FILTER_DESIGN="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,/^$/s/^# //p' "$0"
            exit 0
            ;;
        *)
            if [[ -z "$FILTER_PLATFORM" ]]; then
                FILTER_PLATFORM="$1"
            elif [[ -z "$FILTER_DESIGN" ]]; then
                FILTER_DESIGN="$1"
            else
                echo "ERROR: unexpected argument: $1" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ "$CLEAR_ALL" == true ]]; then
    echo "Clearing all local Bazel caches..."

    echo -n "  Local disk cache ($DISK_CACHE)... "
    if [[ "$DRY_RUN" == true ]]; then
        echo "would delete"
    else
        rm -rf "$DISK_CACHE"
        echo "cleared"
    fi

    echo -n "  Bazel output base... "
    if [[ "$DRY_RUN" == true ]]; then
        echo "would run bazel clean"
    else
        (cd "$REPO_DIR" && bazel clean 2>/dev/null) && echo "cleaned" || echo "skipped"
    fi

    exit 0
fi

# Discover designs (same logic as run.sh)
discover_designs() {
    for build_file in "$REPO_DIR"/designs/*/BUILD.bazel \
                      "$REPO_DIR"/designs/*/*/BUILD.bazel \
                      "$REPO_DIR"/designs/*/*/*/BUILD.bazel; do
        [[ -f "$build_file" ]] || continue
        grep -q 'hightide_design(' "$build_file" || continue

        local dir
        dir=$(dirname "$build_file")
        local name
        name=$(grep -A1 'hightide_design(' "$build_file" | grep -oP 'name\s*=\s*"\K[^"]+')
        [[ -z "$name" ]] && continue

        local relpath="${dir#$REPO_DIR/designs/}"
        local platform="${relpath%%/*}"
        local target="//designs/$relpath:${name}_final"

        echo "$platform|$name|$relpath|$target"
    done
}

# Collect matching designs
DESIGNS=()
while IFS='|' read -r platform name relpath target; do
    if [[ -n "$FILTER_PLATFORM" && "$platform" != "$FILTER_PLATFORM" ]]; then
        continue
    fi
    if [[ -n "$FILTER_DESIGN" ]]; then
        design_dir="${relpath#*/}"
        if [[ "$name" != "$FILTER_DESIGN" && "$design_dir" != *"$FILTER_DESIGN"* ]]; then
            continue
        fi
    fi
    DESIGNS+=("$platform|$name|$relpath|$target")
done < <(discover_designs | sort)

if [[ ${#DESIGNS[@]} -eq 0 ]]; then
    echo "No designs matched the given filters."
    echo "  Platform: ${FILTER_PLATFORM:-<all>}"
    echo "  Design:   ${FILTER_DESIGN:-<all>}"
    exit 1
fi

echo "Clearing local bazel-bin outputs for ${#DESIGNS[@]} design(s)..."
echo ""

for entry in "${DESIGNS[@]}"; do
    IFS='|' read -r platform name relpath target <<< "$entry"
    echo -n "  $platform/$name ... "

    local_dir="$REPO_DIR/bazel-bin/designs/$relpath"
    if [[ -d "$local_dir" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo -n "would delete $local_dir "
        else
            rm -rf "$local_dir"
            echo -n "local "
        fi
    fi

    echo "done"
done

echo ""
echo "Note: The remote cache is content-addressed and cannot be selectively"
echo "cleared by design name.  To force a fresh build that re-executes actions"
echo "and overwrites cached entries, rebuild with:"
echo ""
echo "  bazel build --noremote_accept_cached --remote_upload_local_results=true <target>"
echo ""
echo "(--remote_upload_local_results=true also requires the write credential in"
echo " ~/HighTide/.bazelrc.user; readers without it will only re-execute locally.)"
