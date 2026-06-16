#!/usr/bin/env bash
#
# Run a HighTide design in upstream OpenROAD-flow-scripts (plain ORFS),
# so OpenROAD researchers can experiment with a custom OpenROAD binary,
# modified flow Tcl scripts, added/changed flow steps, or different
# constraints — without leaving HighTide's golden bazel-orfs config.
#
# It extracts the design's resolved ORFS config.mk (via
# tools/bazel_to_config_mk.sh --abs) and runs the standard ORFS Makefile.
#
# Two synthesis modes:
#
#   default (reuse synth):  reuses the synthesized netlist bazel-orfs already
#       produced (results/.../1_synth.{odb,sdc}) and runs only floorplan
#       onward. Fast and zero-setup — no yosys/slang needed — and works
#       against the ORFS bazel-orfs already resolved. Best for iterating on
#       placement / routing / the OpenROAD binary. (The netlist is rebuilt by
#       bazel whenever constraints/RTL change, but only if you go through the
#       bazel build; to re-synthesize entirely in plain ORFS, use --resynth.)
#
#   --resynth (from RTL):  runs the *whole* flow including synthesis in your
#       ORFS install, using its own yosys + yosys-slang. Honors changes to
#       constraints, RTL, or the synthesis flow itself — but slower, and
#       requires --flow-home pointing at a built OpenROAD-flow-scripts install
#       (one whose tools/install has yosys; ORFS's slang support is built in).
#
# Usage:
#   tools/run_orfs.sh [options] <design-dir-or-label> [make-target...]
#
# Options:
#   --resynth        Run synthesis from RTL in your ORFS install (default:
#                    reuse the bazel-synthesized netlist). Needs --flow-home.
#   --flow-home DIR  ORFS checkout to run (its `flow/` dir or the root).
#                    Default (reuse mode): the ORFS bazel-orfs resolved.
#                    Required with --resynth: a built install with yosys+slang.
#   --openroad BIN   openroad executable (sets OPENROAD_EXE). Point this at
#                    your own build to test a custom OpenROAD. Default: the
#                    bazel-built @openroad//:openroad (reuse mode) or your
#                    ORFS install's own openroad (with --resynth).
#   --work-dir DIR   Run/output directory (becomes ORFS WORK_HOME).
#                    Default: <repo>/.run_orfs/<platform>/<design>.
#   --config FILE    Use this config.mk instead of extracting one.
#   --no-build       Don't (re)build in bazel; assume stages + config exist.
#   -h, --help       Print this help and exit.
#
# make-target default: "floorplan place cts route finish"
#                      (--resynth: "synth floorplan place cts route finish")
#
# Examples:
#   # Fast, zero-setup: reuse golden synth + bazel openroad, full P&R:
#   tools/run_orfs.sh designs/asap7/lfsr
#   # Your custom OpenROAD build, only through placement:
#   tools/run_orfs.sh --openroad ~/OpenROAD/build/src/openroad \
#                     designs/asap7/lfsr floorplan place
#   # Re-synthesize from RTL in your ORFS install (its yosys+slang):
#   tools/run_orfs.sh --resynth --flow-home ~/OpenROAD-flow-scripts designs/asap7/lfsr
#
# QoR comparability: HighTide's published numbers come from the bazel-orfs
# build. A --resynth run reproduces them only if your ORFS install's yosys /
# openroad match the commits bazel-orfs pins (printed below); otherwise the
# baseline shifts and some config.mk workaround vars may be stale.

set -euo pipefail

usage() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 1
}

require_bazel() {
    command -v bazel >/dev/null 2>&1 && return
    cat >&2 <<'EOF'
ERROR: 'bazel' is not installed or not on PATH.
HighTide resolves each design's configuration with Bazel (via Bazelisk).
Install Bazelisk (recommended — it auto-fetches the pinned Bazel version):
  Linux x86_64:
    sudo curl -fsSL -o /usr/local/bin/bazel \
      https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64
    sudo chmod +x /usr/local/bin/bazel
  npm:  npm install -g @bazelbuild/bazelisk
  go:   go install github.com/bazelbuild/bazelisk@latest
More:   https://github.com/bazelbuild/bazelisk
EOF
    exit 1
}

# The Bazel build (and the patches/ symlinks it references) need the
# bazel-orfs submodule checked out — otherwise bazel fails deep in repo
# fetch with a cryptic "Cannot find patch file" error.
require_bazel_orfs() {
    [ -f "$repo_root/bazel-orfs/MODULE.bazel" ] && return
    cat >&2 <<'EOF'
ERROR: the bazel-orfs submodule is not initialized.
HighTide's Bazel build needs it (the patches/ files are symlinks into it).
Run, from the repo root:
  git submodule update --init bazel-orfs
EOF
    exit 1
}

flow_home=""
openroad=""
work_dir=""
config=""
no_build=0
resynth=0
positional=()

while [ $# -gt 0 ]; do
    case "$1" in
        --resynth)   resynth=1;    shift ;;
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
if [ "${#targets[@]}" -eq 0 ]; then
    if [ "$resynth" = 1 ]; then
        targets=(synth floorplan place cts route finish)
    else
        targets=(floorplan place cts route finish)
    fi
fi

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

# --- Resolve the ORFS flow dir (FLOW_HOME) --------------------------------
user_flow_home=0
if [ -n "$flow_home" ]; then
    user_flow_home=1
elif [ "$resynth" = 0 ]; then
    # Default (reuse) path: the ORFS bazel-orfs already resolved (no
    # tools/install needed — synth is skipped, openroad comes from bazel).
    ob=$(bazel info output_base 2>/dev/null)
    flow_home="$ob/external/orfs+"
else
    echo "ERROR: --resynth needs a built OpenROAD-flow-scripts install." >&2
    echo "       Pass --flow-home <ORFS> (its tools/install must have yosys+slang)," >&2
    echo "       or drop --resynth to reuse the bazel-synthesized netlist." >&2
    exit 1
fi
if   [ -f "$flow_home/flow/Makefile" ]; then flow_dir="$flow_home/flow"
elif [ -f "$flow_home/Makefile" ];      then flow_dir="$flow_home"
else echo "ERROR: no ORFS Makefile under --flow-home $flow_home" >&2; exit 1
fi
orfs_commit=$(grep -oP 'OpenROAD-flow-scripts-\K[0-9a-f]{40}' MODULE.bazel | head -1)

# Soft check: --resynth needs a yosys somewhere (install dir or PATH).
if [ "$resynth" = 1 ] \
   && [ ! -x "$flow_dir/../tools/install/yosys/bin/yosys" ] \
   && ! command -v yosys >/dev/null 2>&1; then
    echo "WARNING: no yosys found at $flow_dir/../tools/install or on PATH;" >&2
    echo "         synthesis will fail unless your ORFS install provides one." >&2
fi

# --- Build stages + extract config.mk (cached after first run) ------------
if [ -z "$work_dir" ]; then
    rel=${pkg#designs/}
    work_dir="$repo_root/.run_orfs/${rel%%/*}/${rel##*/}"
fi
mkdir -p "$work_dir"

if [ -z "$config" ]; then
    config="$work_dir/config.mk"
    echo ">> Extracting config.mk -> $config" >&2
    tools/bazel_to_config_mk.sh --abs "$pkg" "$config"
fi
config=$(realpath "$config")

# Reuse mode needs the bazel-synthesized netlist (config extraction above is
# config-only and does NOT build it). Build just the synth stage — not the
# whole flow. --resynth re-synthesizes in plain ORFS, so it needs nothing.
if [ "$resynth" = 0 ] && [ "$no_build" = 0 ]; then
    require_bazel; require_bazel_orfs
    echo ">> Building synth netlist //$pkg:${name}_synth ..." >&2
    bazel build "//$pkg:${name}_synth" >&2
fi

# --- Resolve OpenROAD (+ matching sta) ------------------------------------
# Override OPENROAD_EXE/OPENSTA_EXE only when the tools wouldn't otherwise
# resolve: a user-supplied --openroad, or the bazel-resolved ORFS default
# (which has no tools/install). A user-supplied ORFS install uses its own.
openroad_exe="$openroad"
opensta_exe=""
if [ -z "$openroad_exe" ] && [ "$user_flow_home" = 0 ]; then
    require_bazel; require_bazel_orfs
    echo ">> Resolving bazel-built openroad ..." >&2
    bazel build @openroad//:openroad >&2
    openroad_exe=$(realpath "$(bazel cquery --output=files @openroad//:openroad 2>/dev/null | head -1)")
    if bazel cquery @openroad//src/sta:opensta >/dev/null 2>&1; then
        bazel build @openroad//src/sta:opensta >&2 || true
        opensta_exe=$(realpath "$(bazel cquery --output=files @openroad//src/sta:opensta 2>/dev/null | head -1)" 2>/dev/null || true)
    fi
fi
[ -z "$openroad_exe" ] || [ -x "$openroad_exe" ] || {
    echo "ERROR: openroad not executable: $openroad_exe" >&2; exit 1; }

# --- Reuse-synth (default): seed WORK_HOME with the golden netlist --------
if [ "$resynth" = 0 ]; then
    results_root="bazel-bin/$pkg/results"
    synth_odb=$(find "$results_root" -name '1_synth.odb' -type f 2>/dev/null | head -1)
    [ -n "$synth_odb" ] || {
        echo "ERROR: no 1_synth.odb under $results_root — did the bazel build run?" >&2
        exit 1
    }
    synth_dir=$(dirname "$synth_odb")
    relres=${synth_odb#*/results/}      # <platform>/<design>/<variant>/1_synth.odb
    IFS=/ read -r platform design variant _ <<<"$relres"

    # Copy every 1_* / mem* artifact (the whole yosys chain) so upstream Make
    # sees the synth prerequisites present, then touch them in dependency
    # order — newer than the (old, committed) sources — so Make treats
    # synthesis as up-to-date and never invokes yosys.
    work_results="$work_dir/results/$platform/$design/$variant"
    mkdir -p "$work_results"
    chmod -R u+w "$work_results" 2>/dev/null || true
    cp -f --no-preserve=mode "$synth_dir"/1_* "$work_results"/ 2>/dev/null || true
    cp -f --no-preserve=mode "$synth_dir"/mem*.json "$work_results"/ 2>/dev/null || true
    [ -f "$work_results/clock_period.txt" ] || echo 0 > "$work_results/clock_period.txt"

    base=$(( $(date +%s) - 60 ))
    i=0
    for f in clock_period.txt 1_1_yosys_canonicalize.rtlil 1_2_yosys.sdc \
             1_2_yosys.v 1_synth.odb 1_synth.sdc; do
        [ -e "$work_results/$f" ] && touch -d "@$((base + i * 2))" "$work_results/$f"
        i=$((i + 1))
    done
else
    platform=${pkg#designs/}; platform=${platform%%/*}
    design=$(awk -F'?=' '/^export DESIGN_NAME\?=/{print $2; exit}' "$config")
fi

# --- Run upstream ORFS ----------------------------------------------------
mode=$([ "$resynth" = 1 ] && echo "from RTL (incl. synthesis)" || echo "reuse synth (floorplan onward)")
cat >&2 <<EOF
>> Running upstream ORFS
   design     : $platform / ${design:-$name}
   mode       : $mode
   flow_home  : $flow_dir
   (golden ORFS commit bazel resolves: $orfs_commit)
   openroad   : ${openroad_exe:-<ORFS install default>}
   work_home  : $work_dir
   targets    : ${targets[*]}
EOF

exec make -C "$flow_dir" \
    DESIGN_CONFIG="$config" \
    WORK_HOME="$work_dir" \
    FLOW_HOME="$flow_dir" \
    ${openroad_exe:+OPENROAD_EXE="$openroad_exe"} \
    ${opensta_exe:+OPENSTA_EXE="$opensta_exe"} \
    "${targets[@]}"
