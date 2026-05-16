#!/usr/bin/env bash
#
# Regenerate the committed RTL under dev/rtl/ (ternip core) and dev/bsg/
# (BaseJump STL subset) from the dev/repo and dev/basejump_stl submodules.
#
# The build (designs/src/ternip/BUILD.bazel) reads the committed copies so
# it does NOT depend on submodule init — k8s job clones only init
# bazel-orfs. Run this only when bumping the upstream submodules:
#
#   git submodule update --init designs/src/ternip/dev/repo \
#                                designs/src/ternip/dev/basejump_stl
#   designs/src/ternip/dev/setup.sh
#   git add designs/src/ternip/dev/rtl designs/src/ternip/dev/bsg
#
# BUILD.bazel's _TERNIP_FILES / _BSG_FILES are the single source of truth
# for which files are needed; this script parses them out so the two never
# drift.
set -euo pipefail
DIR="$(dirname "$(readlink -f "$0")")"
SRC="$(dirname "$DIR")"          # designs/src/ternip
cd "$SRC"

[ -f dev/repo/rtl/ternip_pkg.sv ] || {
  echo "dev/repo submodule not initialized; run: git submodule update --init designs/src/ternip/dev/repo" >&2
  exit 1
}
[ -f dev/basejump_stl/bsg_misc/bsg_defines.sv ] || {
  echo "dev/basejump_stl submodule not initialized; run: git submodule update --init designs/src/ternip/dev/basejump_stl" >&2
  exit 1
}

# Pull the file lists straight out of BUILD.bazel so this script and the
# build can never disagree about the required set.
list() {  # $1 = bazel list name (without leading underscore)
  awk -v marker="_${1} = [" '
    index($0, marker) {grab=1; next}
    grab && index($0, "]") {exit}
    grab && index($0, "\"") {gsub(/[",]/,""); gsub(/^[ \t]+/,""); if ($0 != "") print $0}
  ' BUILD.bazel
}

rm -rf dev/rtl dev/bsg
while read -r f; do
  [ -n "$f" ] || continue
  mkdir -p "dev/rtl/$(dirname "$f")"
  cp "dev/repo/rtl/$f" "dev/rtl/$f"
done < <(list TERNIP_FILES)

# Include headers referenced by the core (e.g. ternip_readmem_path.svh).
find dev/repo/rtl -name '*.svh' -print0 | while IFS= read -r -d '' h; do
  rel="${h#dev/repo/rtl/}"
  mkdir -p "dev/rtl/$(dirname "$rel")"
  cp "$h" "dev/rtl/$rel"
done

while read -r f; do
  [ -n "$f" ] || continue
  mkdir -p "dev/bsg/$(dirname "$f")"
  cp "dev/basejump_stl/$f" "dev/bsg/$f"
done < <(list BSG_FILES)

echo "Regenerated: $(find dev/rtl -type f | wc -l) files in dev/rtl, $(find dev/bsg -type f | wc -l) in dev/bsg"
