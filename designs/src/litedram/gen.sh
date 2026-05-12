#!/bin/bash
#
# Regenerate litedram_core.v from designs/src/litedram/litedram.yml using the
# upstream enjoy-digital/litedram standalone generator. Called by the
# rtl_dev_gen genrule in BUILD.bazel when `--define update_rtl=true`.
#
# Args:
#   $1  YAML config path (absolute)
#   $2  Path to the litedram src dir (the parent of dev/) (absolute)
#   $3  Output basename (e.g. "litedram") — copy build output to
#       $2/<basename>_core.v

set -e

YML_FILE="$1"
LITEDRAM_DIR="$2"
DESIGN_NAME="$3"

if [[ -z "$YML_FILE" || -z "$LITEDRAM_DIR" || -z "$DESIGN_NAME" ]]; then
    echo "Usage: gen.sh <yml> <litedram_dir> <design_name>" >&2
    exit 1
fi

echo "Generating litedram core for $DESIGN_NAME from $YML_FILE"

cd "$LITEDRAM_DIR/dev"
source "$LITEDRAM_DIR/dev/.venv/bin/activate"

# Clean prior build so leftover files can't sneak in.
[ -d "$LITEDRAM_DIR/dev/build" ] && rm -rf "$LITEDRAM_DIR/dev/build"

python3 "$LITEDRAM_DIR/dev/repo/litedram/gen.py" "$YML_FILE"

cp "$LITEDRAM_DIR/dev/build/gateware/litedram_core.v" \
   "$LITEDRAM_DIR/${DESIGN_NAME}_core.v"

# Archive build/ for reproducibility/debugging — paralleling liteeth/gen.sh.
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_DIR="$LITEDRAM_DIR/dev/${DESIGN_NAME}_build_${TIMESTAMP}"
mkdir -p "$ARCHIVE_DIR"
cp -r "$LITEDRAM_DIR/dev/build/"* "$ARCHIVE_DIR/"

rm -rf "$LITEDRAM_DIR/dev/build"

echo "Generated $LITEDRAM_DIR/${DESIGN_NAME}_core.v"
