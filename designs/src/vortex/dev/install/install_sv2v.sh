#!/usr/bin/env bash
# Optional helper: install a local sv2v binary under designs/src/vortex/dev/
# for users who want to flatten Vortex SystemVerilog to plain Verilog.
#
# Vortex's primary synthesis path (both Make and Bazel flows) uses yosys-slang
# directly on the SV tree and does NOT require sv2v. This script exists for
# alternate workflows (e.g., Vivado targets).
#
# Downloads a prebuilt sv2v binary from upstream releases to avoid a Haskell
# toolchain dependency. Adapted from the pattern used by NyuziProcessor, which
# builds sv2v from source.

set -euo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEV_DIR="$(cd -- "$DIR/.." && pwd)"

SV2V_VERSION="${SV2V_VERSION:-v0.0.13}"
SV2V_ZIP="sv2v-Linux.zip"
SV2V_URL="https://github.com/zachjs/sv2v/releases/download/${SV2V_VERSION}/${SV2V_ZIP}"

if [ -x "$DEV_DIR/sv2v" ]; then
    echo "sv2v already present at $DEV_DIR/sv2v"
    exit 0
fi

echo "Downloading sv2v $SV2V_VERSION from $SV2V_URL"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

curl -sSL -o "$TMP/$SV2V_ZIP" "$SV2V_URL"
unzip -q -o "$TMP/$SV2V_ZIP" -d "$TMP/extract"
install -m 0755 "$TMP/extract/sv2v-Linux/sv2v" "$DEV_DIR/sv2v"

echo "Installed sv2v at $DEV_DIR/sv2v"
