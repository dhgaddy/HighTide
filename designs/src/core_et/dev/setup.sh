#!/usr/bin/env bash
# Prepare CORE-ET (Erbium) RTL for yosys-slang synthesis.
#
# The upstream submodule (openhwgroup/core-et, branch erbium) was written for
# VCS-style single-compilation-unit synthesis.  yosys-slang processes each
# source file as an independent compilation unit by default, which causes two
# classes of failures:
#
#   1. Duplicate SV interface definitions — tbox_types.vh instantiates SV
#      interfaces via ENQIO_IF/VALID_IF macros at file scope; every source
#      file that transitively includes it creates the same global interface,
#      causing "duplicate definition" errors in slang.
#
#   2. Missing macro definitions — ~100 lib files rely on preprocessor macros
#      (RST_EN_FF, EN_FF, etc.) being set up by an earlier file in the same
#      compilation unit; they fail in per-file mode.
#
# Fix strategy:
#   • Apply patches/synthesis.patch to the submodule to fix the lib-file
#     includes, add ifndef guards to fp_types.vh and tbox_types.vh, and strip
#     the interface instantiation calls from tbox_types.vh.
#   • Create rtl/inc/tbox_ifs.sv as a dedicated source file that instantiates
#     the TBOX SV interfaces exactly once.
#   • Use SYNTH_SLANG_ARGS="--single-unit" in the platform BUILD.bazel so
#     all files share one preprocessor context (matching the VCS model).
#
# Usage:
#   bash designs/src/core_et/dev/setup.sh
#
# Run from the erbium workspace root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR/repo"
PATCHES_DIR="$SCRIPT_DIR/patches"

if [ ! -e "$REPO_DIR/.git" ]; then
    echo "Submodule not initialised; run: git submodule update --init designs/src/core_et/dev/repo"
    exit 1
fi

cd "$REPO_DIR"

# Reset any previously applied patches so this script is idempotent.
git checkout -- .

# Apply the synthesis compatibility patch.
git apply "$PATCHES_DIR/synthesis.patch"

# Create tbox_ifs.sv — the single compilation unit that instantiates TBOX SV
# interfaces.  Kept out of the patch so the intent is self-documenting here.
cat > rtl/inc/tbox_ifs.sv <<'EOF'
// SV interface instantiations for the TBOX subsystem.
// Separated from tbox_types.vh so that interfaces are compiled exactly once
// (as a source file in the RTL glob) rather than being re-instantiated each
// time tbox_types.vh is `include'd by a different compilation unit.
`include "soc_defines.vh"
`include "fp_types.vh"
`include "tbox_types.vh"

localparam IMG_INFO_TABLE_WIDTH = $bits(imageInformationTableEntry_t);
localparam VADDR_MEM_WIDTH = $bits(imageInformationVaddressEntry_t);

`ENQIO_IF(sample_request_if, sample_request_t)
`ENQIO_IF(addressInTableOutIO_if, addressInTableOutIO_t)
`ENQIO_IF(addressOutIO_if, addressOutIO_t)
`ENQIO_IF(futureTagsDataIO_if, futureTagsDataIO_t)
`ENQIO_IF(decompressL2IO_if, decompressL2IO_t)
`ENQIO_IF(imageInformationL2Req_if, logic [PA_SIZE_TBOX-1:0])
`VALID_IF(imageInformationL2Rep_if, logic [MEM_ENTRY_SZ-1:0])
`ENQIO_IF(imageInformationRdRep_if, logic [IMG_INFO_TABLE_WIDTH+ENTRY_IDX_SZ-1:0])
`ENQIO_IF(l2ReorderFifo_req_if, l2ReorderFifo_req_t)
`VALID_IF(l2ReorderFifo_rep_if, l2ReorderFifo_rep_t)
`ENQIO_IF(virtualAddressL2IO_if, virtualAddressL2IO_t)
`ENQIO_IF(futureTagsVirtualAddressIO_if, futureTagsVirtualAddressIO_t)
`VALID_IF(imageInformationVAddrIO_if, imageInformationVAddrIO_t)
`VALID_IF(addressInIO_if, addressInIO_t)
`ENQIO_IF(cacheDataL2IO_if, logic [TEX_L1_DATA_SZ-1:0])
`ENQIO_IF(tmuxInIO_if, tmuxInIO_t)
`ENQIO_IF(tmuxOutIO_if, tmuxOutIO_t)
`VALID_IF(addressAckOut_if, addressAckOut_t)
`ENQIO_IF(pixelAccumOutIO_if, pixelAccumOutIO_t)
`ENQIO_IF(blenderOutIO_if, blenderOutIO_t)
EOF

echo "setup.sh complete — submodule patched for synthesis."
