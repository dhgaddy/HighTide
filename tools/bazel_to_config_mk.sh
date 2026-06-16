#!/usr/bin/env bash
#
# Extract an ORFS-compatible config.mk for a HighTide design from the
# bazel-orfs flow's generated artifacts.
#
# Each flow stage exposes its resolved config as a `<stage>.mk` bazel
# output group, written by a cheap analysis-phase action. This script
# builds ONLY those config output groups — so it costs no synthesis or
# place-and-route, just bazel analysis (seconds) — then unions the
# `export VAR?=VALUE` lines across stages (different stages contribute
# different vars: floorplan → CORE_UTILIZATION, final → GDS_ALLOW_EMPTY,
# etc.), drops the Bazel-internal ones, adds the cquery-resolved
# VERILOG_FILES (the one var the .mk files omit), and emits a config.mk
# you can feed to upstream OpenROAD-flow-scripts (`make DESIGN_CONFIG=...`).
#
# Usage:
#   tools/bazel_to_config_mk.sh [--abs] <design-dir-or-label> [output-file]
#
# Options:
#   --abs   Emit absolute paths (rooted at the repo) for the path-bearing
#           vars (VERILOG_FILES, SDC_FILE, ADDITIONAL_LEFS/LIBS/GDS,
#           PDN_TCL, IO_CONSTRAINTS, FOOTPRINT_TCL, MACRO_PLACEMENT_TCL,
#           VERILOG_INCLUDE_DIRS) so the config.mk runs from any CWD and
#           against any ORFS clone. Default keeps workspace-relative paths.
#
# Examples:
#   tools/bazel_to_config_mk.sh designs/asap7/lfsr
#   tools/bazel_to_config_mk.sh --abs designs/asap7/lfsr   ./lfsr.config.mk
#   tools/bazel_to_config_mk.sh //designs/asap7/lfsr:lfsr   ./lfsr.config.mk
#   tools/bazel_to_config_mk.sh designs/asap7/liteeth/liteeth_mac_axi_mii
#
# Caveats:
# - Without --abs, VERILOG_FILES / SDC_FILE paths are workspace-relative;
#   run upstream ORFS Make from the HighTide repo root (or use --abs).
# - For designs that synthesize from dev-generated RTL (genrules), the
#   resolved paths point into bazel-out/. Use --define update_rtl=true
#   before extraction if you want fresh generated sources, or rely on
#   the committed release RTL by extracting without that flag (default).
# - PLATFORM_DIR is intentionally stripped — let ORFS Make derive it
#   from $(FLOW_HOME)/platforms/$(PLATFORM).

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
    [ -f "$(git rev-parse --show-toplevel)/bazel-orfs/MODULE.bazel" ] && return
    cat >&2 <<'EOF'
ERROR: the bazel-orfs submodule is not initialized.
HighTide's Bazel build needs it (the patches/ files are symlinks into it).
Run, from the repo root:
  git submodule update --init bazel-orfs
EOF
    exit 1
}

abs=0
positional=()
while [ $# -gt 0 ]; do
    case "$1" in
        --abs)      abs=1; shift ;;
        -h|--help)  usage ;;
        --)         shift; while [ $# -gt 0 ]; do positional+=("$1"); shift; done ;;
        -*)         echo "ERROR: unknown option: $1" >&2; usage ;;
        *)          positional+=("$1"); shift ;;
    esac
done

[ "${#positional[@]}" -ge 1 ] && [ "${#positional[@]}" -le 2 ] || usage

input=${positional[0]}
output=${positional[1]:-}

repo_root=$(git rev-parse --show-toplevel)

# --- Normalize the input to package + target name -------------------
case "$input" in
    //*:*)        # //designs/asap7/lfsr:lfsr
        label=${input#//}
        pkg=${label%:*}
        name=${label##*:}
        ;;
    //*)          # //designs/asap7/lfsr  (no :target → derive from BUILD.bazel)
        pkg=${input#//}
        name=""
        ;;
    *)            # designs/asap7/lfsr  (or with trailing /)
        pkg=${input%/}
        name=""
        ;;
esac

build_file="${pkg}/BUILD.bazel"
[ -f "$build_file" ] || {
    echo "ERROR: no $build_file" >&2
    exit 1
}

# If no target was supplied, read the name from the hightide_design()
# (or orfs_flow()) call in BUILD.bazel — first quoted value after `name =`.
if [ -z "$name" ]; then
    name=$(awk -F'"' '
        /hightide_design\(|orfs_flow\(/   { in_call = 1 }
        in_call && /name[[:space:]]*=/    { print $2; exit }
    ' "$build_file")
    [ -n "$name" ] || {
        echo "ERROR: could not find name = \"...\" in $build_file" >&2
        exit 1
    }
fi

# --- Extract config from the per-stage config files (NO flow build) -------
# Each stage exposes its resolved config as the <stage>.mk output group,
# written by a cheap analysis-phase action — so building just these groups
# costs no synthesis or place-and-route (they complete as "internal"
# actions in seconds). VERILOG_FILES is the one resolved variable the
# <stage>.mk files omit; pull it from the synth target's verilog_files
# attr via cquery (analysis only, no build).
stages=(synth floorplan place cts grt route final)
targets=()
for s in "${stages[@]}"; do targets+=("//${pkg}:${name}_${s}"); done
config_groups=1_synth.mk,2_floorplan.mk,3_place.mk,4_cts.mk,5_1_grt.mk,5_2_route.mk,6_final.mk

require_bazel
require_bazel_orfs
echo "Extracting config of //${pkg}:${name} (config only, no flow build) ..." >&2
bazel build "${targets[@]}" --output_groups="$config_groups" >&2

verilog_files=$(bazel cquery --output=files \
    "labels(verilog_files, //${pkg}:${name}_synth)" 2>/dev/null | tr '\n' ' ')

# --- Locate the result dir + collect the per-stage config .mk files -------
results_root="bazel-bin/${pkg}/results"
[ -d "$results_root" ] || {
    echo "ERROR: $results_root missing after build" >&2
    exit 1
}

# Stage configs are <N>_<stage>.mk; skip the *.args.mk / *.short.mk / args.mk
# helper configs.
mapfile -t mks < <(find "$results_root" -type f -name '*.mk' \
    ! -name '*.args.mk' ! -name '*.short.mk' ! -name 'args.mk' 2>/dev/null | sort)
[ "${#mks[@]}" -gt 0 ] || {
    echo "ERROR: no per-stage *.mk under $results_root" >&2
    exit 1
}

# --- Filter + union -------------------------------------------------
# Drop Bazel-internal vars that ORFS Make computes itself or doesn't want.
SKIP_VARS='^(WORK_HOME|FLOW_VARIANT|LEC_CHECK|GENERATE_ARTIFACTS_ON_FAILURE|PLATFORM_DIR)$'

emit() {
    cat <<EOF
# Generated by tools/bazel_to_config_mk.sh from BUILD.bazel.
# Source : //${pkg}:${name}
# Reproduce:
#   bazel build //${pkg}:${name}_final
#   tools/bazel_to_config_mk.sh ${pkg}
#
# Run upstream ORFS from the HighTide repo root, e.g.:
#   make -C OpenROAD-flow-scripts/flow DESIGN_CONFIG=\$(pwd)/${pkg}/config.mk

EOF

    # `export VAR?=VALUE` → keep the first occurrence of each VAR.
    # The per-stage .mk files omit VERILOG_FILES; inject the cquery-resolved
    # list so the union is complete. With --abs, prefix each repo-relative
    # token of the path-bearing vars with the repo root (runs from any CWD).
    {
        grep -h '^export ' "${mks[@]}"
        [ -n "$verilog_files" ] && printf 'export VERILOG_FILES?=%s\n' "${verilog_files% }"
    } \
        | awk -v skip="$SKIP_VARS" -v abs="$abs" -v root="$repo_root" '
            # Vars whose value is one or more file/dir paths.
            function is_pathvar(k) {
                return (k ~ /^(VERILOG_FILES|SDC_FILE|ADDITIONAL_LEFS|ADDITIONAL_LIBS|ADDITIONAL_GDS|IO_CONSTRAINTS|FOOTPRINT_TCL|MACRO_PLACEMENT_TCL|VERILOG_INCLUDE_DIRS|PDN_TCL)$/) || (k ~ /_TCL$/)
            }
            {
                pos = index($0, "?=")
                if (pos == 0) next
                lhs = substr($0, 1, pos + 1)   # includes "?="
                val = substr($0, pos + 2)
                key = lhs
                sub(/^export /, "", key)
                sub(/\?=$/, "", key)
                sub(/[[:space:]]+$/, "", key)
                if (key ~ skip)   next
                if (seen[key]++)  next

                if (abs == "1" && is_pathvar(key)) {
                    n = split(val, toks, /[[:space:]]+/)
                    out = ""
                    for (i = 1; i <= n; i++) {
                        t = toks[i]
                        if (t == "") continue
                        # Absolutize relative paths; leave abs paths and
                        # make/flag tokens (-, $) untouched.
                        if (t !~ /^\// && t !~ /^-/ && t !~ /^\$/)
                            t = root "/" t
                        out = (out == "" ? t : out " " t)
                    }
                    val = out
                }
                print lhs val
            }' \
        | sort
}

if [ -z "$output" ]; then
    emit
else
    emit > "$output"
    echo "Wrote $output" >&2
fi
