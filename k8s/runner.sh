#!/bin/bash
# Submit HighTide design builds to NRP Nautilus, throttled to N at a time.
#
# Discovers and filters designs the same way as ./k8s/run.sh, then maintains
# up to --max concurrent k8s Jobs by polling status and submitting the next
# pending design when a slot opens.  Submission is delegated to run.sh.
#
# Usage:
#   ./k8s/runner.sh [-n N] [--poll-secs SEC] [run.sh-flags...] [platform] [design]
#
# Examples:
#   ./k8s/runner.sh --branch main                       # all designs, 8 in flight (default)
#   ./k8s/runner.sh -n 2 --branch main asap7            # asap7 designs, 2 in flight
#   ./k8s/runner.sh --design lfsr                       # lfsr across all platforms
#
# Options:
#   -n, --max N         Max concurrent jobs (default: 8)
#   --poll-secs SEC     Polling interval in seconds (default: 120)
#   --branch BRANCH     Forwarded to run.sh (git branch to build)
#   --cpu NUM           Forwarded to run.sh (CPU request per job)
#   --mem SIZE          Forwarded to run.sh (memory request per job)
#   --upload-artifacts  Forwarded to run.sh (save bazel-bin to PVC)
#   --design DESIGN     Filter to a specific design across platforms
#   [platform] [design] Positional filters (same semantics as run.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="vlsida"

# Defaults
MAX_CONCURRENT=8
POLL_SECS=120
RUN_ARGS=()
FILTER_PLATFORM=""
FILTER_DESIGN=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--max)           MAX_CONCURRENT="$2"; shift 2 ;;
        --poll-secs)        POLL_SECS="$2"; shift 2 ;;
        --branch|--cpu|--mem) RUN_ARGS+=("$1" "$2"); shift 2 ;;
        --upload-artifacts) RUN_ARGS+=("$1"); shift ;;
        --design)           FILTER_DESIGN="$2"; shift 2 ;;
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

USER_LABEL=$(echo "$USER" | tr '[:upper:]' '[:lower:]')

# Discover designs (mirrors run.sh:discover_designs)
discover_designs() {
    for build_file in "$REPO_DIR"/designs/*/BUILD.bazel \
                      "$REPO_DIR"/designs/*/*/BUILD.bazel \
                      "$REPO_DIR"/designs/*/*/*/BUILD.bazel; do
        [[ -f "$build_file" ]] || continue
        grep -q 'hightide_design(' "$build_file" || continue

        local dir name
        dir=$(dirname "$build_file")
        name=$(grep -A1 'hightide_design(' "$build_file" | grep -oP 'name\s*=\s*"\K[^"]+')
        [[ -z "$name" ]] && continue

        local relpath="${dir#$REPO_DIR/designs/}"
        local platform="${relpath%%/*}"

        echo "$platform|$name|$relpath"
    done
}

# Build filtered queue
QUEUE=()
while IFS='|' read -r platform name relpath; do
    if [[ -n "$FILTER_PLATFORM" && "$platform" != "$FILTER_PLATFORM" ]]; then
        continue
    fi
    if [[ -n "$FILTER_DESIGN" ]]; then
        design_dir="${relpath#*/}"
        if [[ "$name" != "$FILTER_DESIGN" && "$design_dir" != *"$FILTER_DESIGN"* ]]; then
            continue
        fi
    fi
    QUEUE+=("$platform|$name|$relpath")
done < <(discover_designs | sort)

if [[ ${#QUEUE[@]} -eq 0 ]]; then
    echo "No designs matched the given filters."
    echo "  Platform: ${FILTER_PLATFORM:-<all>}"
    echo "  Design:   ${FILTER_DESIGN:-<all>}"
    exit 1
fi

echo "Designs to submit (${#QUEUE[@]}):"
for entry in "${QUEUE[@]}"; do
    IFS='|' read -r platform name _ <<< "$entry"
    echo "  $platform/$name"
done
echo ""
echo "Throttle: $MAX_CONCURRENT concurrent, poll every ${POLL_SECS}s"
echo ""

if [[ ${#QUEUE[@]} -gt 3 ]]; then
    read -r -p "Submit ${#QUEUE[@]} jobs to $NAMESPACE (throttled)? [y/N] " reply || reply=""
    if [[ ! "$reply" =~ ^[yY] ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Compute the k8s Job name run.sh will use, so we can track only our own.
job_name_for() {
    local platform="$1" relpath="$2"
    local leaf="${relpath##*/}"
    echo "${USER}-hightide-${platform}-${leaf}" \
        | tr '[:upper:]' '[:lower:]' | tr '_' '-' | cut -c1-63
}

# Tracking
TRACKED=()                # k8s job names we submitted
declare -A JOB_DESIGN     # job_name -> "platform/name" for status output
DONE_OK=0
DONE_FAIL=0

# Snapshot of finished tracked jobs we've already accounted for, so we
# don't double-count or re-detect them.
declare -A FINAL_STATE    # job_name -> "succ"|"fail"

# Returns lines: <jobname>|<succ>|<fail> for tracked jobs only.
poll_tracked_status() {
    [[ ${#TRACKED[@]} -eq 0 ]] && return 0

    # One kubectl call; filter to tracked jobs.
    local lines
    lines=$(kubectl get jobs -n "$NAMESPACE" -l "app=hightide,user=$USER_LABEL" \
        -o custom-columns='NAME:.metadata.name,S:.status.succeeded,F:.status.failed' \
        --no-headers 2>/dev/null || true)

    local n
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        n=$(awk '{print $1}' <<<"$line")
        local s f
        s=$(awk '{print $2}' <<<"$line")
        f=$(awk '{print $3}' <<<"$line")
        # Is this one of ours?
        for tj in "${TRACKED[@]}"; do
            if [[ "$tj" == "$n" ]]; then
                echo "$n|$s|$f"
                break
            fi
        done
    done <<<"$lines"
}

submit_next() {
    local entry="$1"
    IFS='|' read -r platform name relpath <<< "$entry"
    local job_name
    job_name=$(job_name_for "$platform" "$relpath")
    TRACKED+=("$job_name")
    JOB_DESIGN[$job_name]="$platform/$name"

    echo "[$(date +%H:%M:%S)] submit $platform/$name (job: $job_name)"
    if ! "$SCRIPT_DIR/run.sh" "${RUN_ARGS[@]}" "$platform" "$name" >/dev/null 2>&1; then
        echo "  WARN: run.sh exited non-zero for $platform/$name"
    fi
}

# Main loop
NEXT_IDX=0
TOTAL=${#QUEUE[@]}
TICK=0

while :; do
    # Read current status of tracked jobs
    active=0
    new_done_ok=0
    new_done_fail=0
    while IFS='|' read -r jn s f; do
        [[ -z "$jn" ]] && continue
        if [[ "$s" == "<none>" && "$f" == "<none>" ]]; then
            active=$((active + 1))
        elif [[ "$s" != "<none>" ]]; then
            if [[ -z "${FINAL_STATE[$jn]:-}" ]]; then
                FINAL_STATE[$jn]="succ"
                new_done_ok=$((new_done_ok + 1))
                echo "[$(date +%H:%M:%S)] DONE  ${JOB_DESIGN[$jn]:-$jn}"
            fi
        elif [[ "$f" != "<none>" ]]; then
            if [[ -z "${FINAL_STATE[$jn]:-}" ]]; then
                FINAL_STATE[$jn]="fail"
                new_done_fail=$((new_done_fail + 1))
                echo "[$(date +%H:%M:%S)] FAIL  ${JOB_DESIGN[$jn]:-$jn}"
            fi
        fi
    done < <(poll_tracked_status)
    DONE_OK=$((DONE_OK + new_done_ok))
    DONE_FAIL=$((DONE_FAIL + new_done_fail))

    # Submit while we have slack
    while [[ $active -lt $MAX_CONCURRENT && $NEXT_IDX -lt $TOTAL ]]; do
        submit_next "${QUEUE[$NEXT_IDX]}"
        NEXT_IDX=$((NEXT_IDX + 1))
        active=$((active + 1))
    done

    pending=$((TOTAL - NEXT_IDX))
    finished=$((DONE_OK + DONE_FAIL))

    # Exit when nothing left to submit and nothing in flight
    if [[ $pending -eq 0 && $active -eq 0 ]]; then
        echo
        echo "All ${TOTAL} job(s) finished: ${DONE_OK} succeeded, ${DONE_FAIL} failed."
        break
    fi

    # Periodic heartbeat (every tick)
    TICK=$((TICK + 1))
    echo "[$(date +%H:%M:%S)] tick=$TICK active=$active pending=$pending done=$finished (ok=$DONE_OK fail=$DONE_FAIL)"

    sleep "$POLL_SECS"
done

echo
echo "Final status:"
"$SCRIPT_DIR/run.sh" --status
