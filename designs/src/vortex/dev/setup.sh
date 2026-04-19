#!/usr/bin/env bash
# Vortex dev-mode setup: copies upstream hw/rtl/ from the pinned submodule into
# dev/gen/rtl/, then overlays local *_REPLACE.sv stubs (FakeRAM-aware RAM
# primitives). Run this before `bazel build --define update_rtl=true
# //designs/asap7/vortex/...` or `make update-rtl`.

set -euo pipefail

DEV_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$DEV_DIR/repo"
OUT_DIR="$DEV_DIR/gen/rtl"

if [ ! -d "$REPO_DIR/hw/rtl" ]; then
    echo "Error: vortex submodule not initialized at $REPO_DIR." >&2
    echo "Run: git submodule update --init designs/src/vortex/dev/repo" >&2
    exit 1
fi

echo "Copying $REPO_DIR/hw/rtl/ → $OUT_DIR/"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
cp -r "$REPO_DIR/hw/rtl/." "$OUT_DIR/"

# DPI headers live under hw/dpi/ upstream but are `included with no subdir
# prefix by VX_platform.vh — copy next to the RTL so the include path works.
if [ -f "$REPO_DIR/hw/dpi/float_dpi.vh" ]; then
    cp "$REPO_DIR/hw/dpi/float_dpi.vh" "$OUT_DIR/"
fi
if [ -f "$REPO_DIR/hw/dpi/util_dpi.vh" ]; then
    cp "$REPO_DIR/hw/dpi/util_dpi.vh" "$OUT_DIR/"
fi

# Overlay FakeRAM-aware RAM primitives. These stubs switch to instantiating
# the fakeram_* macros once SIZE/DATAW exceed a threshold, matching the LEF/LIB
# shipped under designs/asap7/vortex/sram/.
echo "Overlaying REPLACE stubs for VX_dp_ram.sv, VX_sp_ram.sv"
cp "$DEV_DIR/VX_dp_ram_REPLACE.sv" "$OUT_DIR/libs/VX_dp_ram.sv"
cp "$DEV_DIR/VX_sp_ram_REPLACE.sv" "$OUT_DIR/libs/VX_sp_ram.sv"

echo "Done. Generated SV tree at $OUT_DIR"
