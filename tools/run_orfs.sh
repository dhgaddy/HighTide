#!/usr/bin/env bash
#
# Run a HighTide design in upstream OpenROAD-flow-scripts (plain ORFS),
# so OpenROAD researchers can experiment with a custom OpenROAD binary,
# modified flow Tcl scripts, or added/changed flow steps — without
# leaving HighTide's golden bazel-orfs configuration behind.
#
# It (1) extracts the design's resolved ORFS config.mk via
# tools/bazel_to_config_mk.sh --abs, (2) reuses the golden synthesized
# netlist bazel-orfs already produced (results/.../1_synth.{odb,sdc}) so
# no yosys / yosys-slang plugin is needed and the P&R starting point is
# identical to HighTide's published QoR, and (3) runs the standard ORFS
# Makefile from floorplan onward against the OpenROAD binary and flow
# you choose.
#
# Usage:
#   tools/run_orfs.sh [options] <design-dir-or-label> [make-target...]
#
# Options:
#   --flow-home DIR  ORFS checkout to run (its `flow/` dir or the dir
#                    itself). Default: the exact ORFS bazel-orfs resolved
#                    (read-only) — i.e. HighTide's golden flow. To edit
#                    flow scripts, clone ORFS at the commit printed below,
#                    edit flow/scripts/*.tcl, and pass --flow-home <clone>.
#   --openroad BIN   openroad executable (sets OPENROAD_EXE). Default: the
#                    bazel-built @openroad//:openroad. Point this at your
#                    own build to test a custom OpenROAD.
#   --work-dir DIR   Run/output directory (becomes ORFS WORK_HOME).
#                    Default: <repo>/.run_orfs/<platform>/<design>.
#   --config FILE    Use this config.mk instead of extracting one.
#   --no-build       Don't (re)build in bazel; assume stages + config exist.
#   -h, --help       Print this help and exit.
#
# make-target defaults to: floorplan place cts route finish
#
# Examples:
#   # Out-of-box: golden flow + bazel openroad, full P&R.
#   tools/run_orfs.sh designs/asap7/lfsr
#   # My OpenROAD build, only through placement.
#   tools/run_orfs.sh --openroad ~/OpenROAD/build/src/openroad \
#                     designs/asap7/lfsr floorplan place
#   # My modified ORFS flow scripts.
#   tools/run_orfs.sh --flow-home ~/OpenROAD-flow-scripts designs/sky130hd/eyeriss
#
# Note: synthesis is reused from the golden bazel build, not re-run here
# (that keeps every design buildable without the yosys-slang toolchain and
# holds the netlist fixed). To re-synthesize, use the bazel flow.

set -euo pipefail

usage() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 1
}

flow_home=""
openroad=""
work_dir=""
config=""
no_build=0
positional=()

while [ $# -gt 0 ]; do
    case "$1" in
        --flow-home) flow_home=$2; shift 2 ;;
        --openroad)  openroad=$2;  shift 2 ;;
        --work-dir)  work_dir=$2;  shift 2 ;;
        --config)    config=$2;    shift 2 ;;
        --no-build)  no_build=1;   shift ;;
        -h|--help)   usage ;;
        --)          shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
        -*)          echo "ERROR: unknown option: $1" >&2; usage ;;
        *)           positional+=("$1"); shift ;;
    esac
done

[ "${#positional[@]}" -ge 1 ] || usage
input=${positional[0]}
targets=("${positional[@]:1}")
[ "${#targets[@]}" -gt 0 ] || targets=(floorplan place cts route finish)

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

# --- Normalize the design input to a bazel package (designs/<plat>/<d>) ---
case "$input" in
    //*:*) pkg=${input#//}; pkg=${pkg%:*} ;;
    //*)   pkg=${input#//} ;;
    *)     pkg=${input%/} ;;
esac
[ -f "$pkg/BUILD.bazel" ] || { echo "ERROR: no $pkg/BUILD.bazel" >&2; exit 1; }

# Design target base name (first quoted value after `name =` in the
# hightide_design()/orfs_flow() call).
name=$(awk -F'"' '
    /hightide_design\(|orfs_flow\(/ { in_call = 1 }
    in_call && /name[[:space:]]*=/  { print $2; exit }' "$pkg/BUILD.bazel")
[ -n "$name" ] || { echo "ERROR: could not find name in $pkg/BUILD.bazel" >&2; exit 1; }

# --- Build stages + extract config.mk (cached after first run) ------------
if [ -z "$work_dir" ]; then
    # platform = first path component under designs/; leaf = last.
    rel=${pkg#designs/}
    work_dir="$repo_root/.run_orfs/${rel%%/*}/${rel##*/}"
fi
mkdir -p "$work_dir"

if [ -z "$config" ]; then
    config="$work_dir/config.mk"
    echo ">> Extracting config.mk -> $config" >&2
    tools/bazel_to_config_mk.sh --abs "$pkg" "$config"
elif [ "$no_build" = 0 ]; then
    echo ">> Building all stages of //$pkg (for the synth netlist) ..." >&2
    stage_targets=()
    for s in synth floorplan place cts grt route final; do
        stage_targets+=("//$pkg:${name}_$s")
    done
    bazel build "${stage_targets[@]}" >&2
fi
config=$(realpath "$config")

# --- Locate the golden synthesized netlist from the bazel build -----------
results_root="bazel-bin/$pkg/results"
synth_odb=$(find "$results_root" -name '1_synth.odb' -type f 2>/dev/null | head -1)
[ -n "$synth_odb" ] || {
    echo "ERROR: no 1_synth.odb under $results_root — did the bazel build run?" >&2
    exit 1
}
synth_dir=$(dirname "$synth_odb")
# results/<platform>/<design>/<variant>/1_synth.odb
relres=${synth_odb#*/results/}
IFS=/ read -r platform design variant _ <<<"$relres"

# --- Resolve the ORFS flow dir (FLOW_HOME) --------------------------------
if [ -z "$flow_home" ]; then
    ob=$(bazel info output_base 2>/dev/null)
    flow_home="$ob/external/orfs+"
fi
if   [ -f "$flow_home/flow/Makefile" ]; then flow_dir="$flow_home/flow"
elif [ -f "$flow_home/Makefile" ];      then flow_dir="$flow_home"
else echo "ERROR: no ORFS Makefile under --flow-home $flow_home" >&2; exit 1
fi
orfs_commit=$(grep -oP 'OpenROAD-flow-scripts-\K[0-9a-f]{40}' MODULE.bazel | head -1)

# --- Resolve the OpenROAD (+ matching sta) binary -------------------------
opensta=""
if [ -z "$openroad" ]; then
    echo ">> Resolving bazel-built openroad ..." >&2
    bazel build @openroad//:openroad >&2
    openroad=$(realpath "$(bazel cquery --output=files @openroad//:openroad 2>/dev/null | head -1)")
    if bazel cquery @openroad//src/sta:opensta >/dev/null 2>&1; then
        bazel build @openroad//src/sta:opensta >&2 || true
        opensta=$(realpath "$(bazel cquery --output=files @openroad//src/sta:opensta 2>/dev/null | head -1)" 2>/dev/null || true)
    fi
fi
[ -x "$openroad" ] || { echo "ERROR: openroad not executable: $openroad" >&2; exit 1; }

# --- Seed WORK_HOME with the golden synth artifacts so synth is skipped ---
# Copy every 1_* / mem* artifact bazel produced (the whole yosys chain:
# *.rtlil, 1_2_yosys.{v,sdc}, 1_synth.{odb,sdc}, mem*.json) so upstream
# Make sees the synth prerequisites present, then touch them in dependency
# order — newer than the (old, committed) RTL/LEF/LIB sources — so Make
# treats synthesis as up-to-date and never invokes yosys.
work_results="$work_dir/results/$platform/$design/$variant"
mkdir -p "$work_results"
chmod -R u+w "$work_results" 2>/dev/null || true
cp -f --no-preserve=mode "$synth_dir"/1_* "$work_results"/ 2>/dev/null || true
cp -f --no-preserve=mode "$synth_dir"/mem*.json "$work_results"/ 2>/dev/null || true

# clock_period.txt is a yosys prerequisite Make would otherwise regenerate
# (then rebuild the netlist). Its content is irrelevant once synth is
# skipped — create it only if bazel didn't emit one.
[ -f "$work_results/clock_period.txt" ] || echo 0 > "$work_results/clock_period.txt"

# Anchor slightly in the past so the ordered touches stay <= now (avoids
# Make's "modification time in the future" warning) yet newer than the
# day-old committed sources.
base=$(( $(date +%s) - 60 ))
i=0
for f in clock_period.txt 1_1_yosys_canonicalize.rtlil 1_2_yosys.sdc \
         1_2_yosys.v 1_synth.odb 1_synth.sdc; do
    [ -e "$work_results/$f" ] && touch -d "@$((base + i * 2))" "$work_results/$f"
    i=$((i + 1))
done

# --- Run upstream ORFS ----------------------------------------------------
cat >&2 <<EOF
>> Running upstream ORFS
   design     : $platform / $design
   flow_home  : $flow_dir
   (golden ORFS commit bazel resolves: $orfs_commit — clone this to edit flow scripts)
   openroad   : $openroad
   work_home  : $work_dir
   targets    : ${targets[*]}
EOF

exec make -C "$flow_dir" \
    DESIGN_CONFIG="$config" \
    WORK_HOME="$work_dir" \
    FLOW_HOME="$flow_dir" \
    OPENROAD_EXE="$openroad" \
    ${opensta:+OPENSTA_EXE="$opensta"} \
    "${targets[@]}"
