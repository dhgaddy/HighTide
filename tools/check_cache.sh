#!/bin/bash
# Check which designs have build results available locally.
# Checks bazel-bin for completed stages without triggering any builds.
#
# Usage: ./tools/check_cache.sh [platform]
#   e.g.: ./tools/check_cache.sh asap7
#         ./tools/check_cache.sh          (all platforms)

BIN_DIR="bazel-bin"
PLATFORM="${1:-*}"

if [ ! -d "$BIN_DIR" ]; then
    echo "No bazel-bin found. Run 'bazel build //designs/...' first."
    exit 1
fi

printf "%-12s %-35s %-15s %s\n" "Platform" "Design" "Status" "Last Stage"
printf "%s\n" "$(printf '=%.0s' {1..75})"

for build_file in designs/${PLATFORM}/*/BUILD.bazel designs/${PLATFORM}/*/*/BUILD.bazel; do
    [ -f "$build_file" ] || continue
    grep -q "hightide_design" "$build_file" || continue

    dir=$(dirname "$build_file")
    design=$(grep -A1 'hightide_design(' "$build_file" | grep -oP 'name\s*=\s*"\K[^"]+')
    [ -z "$design" ] && continue

    platform=$(echo "$dir" | cut -d/ -f2)

    # Search for results under the Bazel output dir for this package
    results=$(find "$BIN_DIR/$dir" -path "*/results/*/base/1_synth.odb" -not -path "*.runfiles*" 2>/dev/null | head -1)

    if [ -n "$results" ]; then
        results_dir=$(dirname "$results")

        if [ -f "$results_dir/6_final.odb" ]; then
            printf "%-12s %-35s %-15s %s\n" "$platform" "$design" "COMPLETE" "6_final"
        else
            last=$(ls "$results_dir"/*.odb 2>/dev/null | sort -V | tail -1 | xargs -r basename 2>/dev/null | sed 's/\.odb//')
            printf "%-12s %-35s %-15s %s\n" "$platform" "$design" "PARTIAL" "${last:--}"
        fi
    else
        printf "%-12s %-35s %-15s %s\n" "$platform" "$design" "NOT BUILT" "-"
    fi
done
