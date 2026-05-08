#!/bin/bash
# Generates a summary table of all completed Bazel ORFS builds.
# Usage: ./tools/summary.sh [bazel-bin path]

set -e

BIN_DIR="${1:-bazel-bin}"

if [ ! -d "$BIN_DIR" ]; then
    echo "Error: $BIN_DIR not found. Run 'bazel build //designs/...' first." >&2
    exit 1
fi

# Print commit version
COMMIT=$(git -C "$(dirname "$0")/.." rev-parse --short HEAD 2>/dev/null || echo "unknown")
echo "HighTide commit: $COMMIT"
echo ""

# Header
printf "%-12s %-25s %10s %10s %10s %8s %8s %6s %6s %7s %5s %5s %10s %8s %12s %12s %12s\n" \
    "Platform" "Design" "Die Area" "Core Area" "Inst Area" "Util%" "Cells" "Seq" "Comb" "BufInv" "Macr" "IOs" "Slack(ps)" "Skew(ps)" "Fmax(GHz)" "Pwr(mW)" "ClkPwr(mW)"
printf "%s\n" "$(printf '=%.0s' {1..180})"

# Find all 6_report.json files (indicates a completed final stage)
# Deduplicate by platform/design since multiple targets may share the same output
find "$BIN_DIR/designs" -path "*/logs/*/base/6_report.json" -not -path "*.runfiles*" 2>/dev/null | sort -u | while read -r json; do
    # Extract platform/design from the logs path inside the output
    # Path: .../logs/<platform>/<design>/base/6_report.json
    logs_rel="${json##*/logs/}"
    platform="${logs_rel%%/*}"
    logs_rel="${logs_rel#*/}"
    design="${logs_rel%%/*}"

    # Parse metrics from 6_report.json using grep+sed (no jq dependency)
    get_metric() {
        grep -o "\"$1\":[^,}]*" "$json" 2>/dev/null | head -1 | sed 's/.*://' | tr -d ' "'
    }

    die_area=$(get_metric "finish__design__die__area")
    core_area=$(get_metric "finish__design__core__area")
    inst_area=$(get_metric "finish__design__instance__area__stdcell")
    util=$(get_metric "finish__design__instance__utilization")
    slack=$(get_metric "finish__timing__setup__ws")
    skew=$(get_metric "finish__clock__skew__setup")
    seq=$(get_metric "finish__design__instance__count__class:sequential_cell")
    comb=$(get_metric "finish__design__instance__count__class:multi_input_combinational_cell")
    inv=$(get_metric "finish__design__instance__count__class:inverter")
    clk_buf=$(get_metric "finish__design__instance__count__class:clock_buffer")
    clk_inv=$(get_metric "finish__design__instance__count__class:clock_inverter")
    trep_buf=$(get_metric "finish__design__instance__count__class:timing_repair_buffer")
    trep_inv=$(get_metric "finish__design__instance__count__class:timing_repair_inverter")
    buf_inv=$((${inv:-0} + ${clk_buf:-0} + ${clk_inv:-0} + ${trep_buf:-0} + ${trep_inv:-0}))
    # Total cells = sequential + combinational + buf/inv.  Excludes
    # tap, tie, fill, antenna, and macro — we want the count of "real"
    # logic-doing instances, not infrastructure cells.
    cells=$((${seq:-0} + ${comb:-0} + ${buf_inv:-0}))
    macros=$(get_metric "finish__design__instance__count__class:macro")
    [[ -z "$macros" ]] && macros=$(get_metric "finish__design__instance__count__macros")
    ios=$(get_metric "finish__design__io")
    fmax=$(get_metric "finish__timing__fmax")
    power=$(get_metric "finish__power__total")

    # Clock-power lives only in 6_finish.rpt's report_power "Group" table
    # (not in 6_report.json).  Pull the 5th whitespace field of the "Clock"
    # row — internal/switching/leakage/total in Watts.  Scope to the
    # report_power section so we don't grab the "Clock <name>" lines from
    # the clock-skew section earlier in the file.
    rpt="${json/logs/reports}"
    rpt="${rpt/6_report.json/6_finish.rpt}"
    clk_power=$(awk '/report_power/{f=1} f && /^Clock +[0-9]/{print $2+$3+$4; exit}' "$rpt" 2>/dev/null)

    # Format utilization as percentage
    if [ -n "$util" ]; then
        util=$(awk "BEGIN {printf \"%.1f\", $util * 100}")
    fi

    # Format areas to 1 decimal
    if [ -n "$die_area" ]; then
        die_area=$(awk "BEGIN {printf \"%.1f\", $die_area}")
    fi
    if [ -n "$core_area" ]; then
        core_area=$(awk "BEGIN {printf \"%.1f\", $core_area}")
    fi
    if [ -n "$inst_area" ]; then
        inst_area=$(awk "BEGIN {printf \"%.1f\", $inst_area}")
    fi

    # Format timing/skew to 2 decimals in picoseconds (signed; positive
    # slack is good).  asap7 Liberty uses ps; nangate45 / sky130hd use
    # ns — multiply by 1000 to land everything on a common ps axis.
    case "$platform" in
        asap7) time_scale=1 ;;
        *)     time_scale=1000 ;;
    esac
    if [ -n "$slack" ]; then
        slack=$(awk "BEGIN {printf \"%.2f\", $slack * $time_scale}")
    fi
    if [ -n "$skew" ]; then
        skew=$(awk "BEGIN {printf \"%.2f\", $skew * $time_scale}")
    fi

    # Format fmax to GHz with 2 decimals
    if [ -n "$fmax" ]; then
        fmax=$(awk "BEGIN {printf \"%.2f\", $fmax / 1e9}")
    fi

    # Format power to mW with 3 decimals
    if [ -n "$power" ]; then
        power=$(awk "BEGIN {printf \"%.3f\", $power * 1000}")
    fi
    if [ -n "$clk_power" ]; then
        clk_power=$(awk "BEGIN {printf \"%.3f\", $clk_power * 1000}")
    fi

    printf "%-12s %-25s %10s %10s %10s %8s %8s %6s %6s %7s %5s %5s %10s %8s %12s %12s %12s\n" \
        "${platform:-?}" "${design:-?}" \
        "${die_area:--}" "${core_area:--}" "${inst_area:--}" "${util:--}" \
        "${cells:--}" "${seq:--}" "${comb:--}" "${buf_inv:--}" "${macros:--}" "${ios:--}" \
        "${slack:--}" "${skew:--}" "${fmax:--}" "${power:--}" "${clk_power:--}"
done

# Show designs that failed (have synth but no final report)
echo ""
echo "Incomplete builds:"
find "$BIN_DIR/designs" -path "*/results/*/1_synth.odb" -not -path "*.runfiles*" 2>/dev/null | sort -u | while read -r synth; do
    dir=$(dirname "$synth")
    if [ ! -f "${dir}/6_final.gds" ] && [ ! -f "${dir}/6_final.odb" ]; then
        # Parse from the inner results subtree so per-variant names
        # (e.g. liteeth_mac_axi_mii) are preserved instead of collapsing
        # to the parent dir (liteeth).  Mirrors the success loop above.
        rel="${synth##*/results/}"
        platform="${rel%%/*}"
        rel="${rel#*/}"
        design="${rel%%/*}"
        # Find which stage completed last
        last_stage=$(ls "$dir"/*.odb 2>/dev/null | sort | tail -1 | grep -oP '\d+_\w+' | head -1)
        echo "  ${platform}/${design} — stopped at ${last_stage:-synth}"
    fi
done
