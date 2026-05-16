#!/bin/bash

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <YML_FILE>" >&2
    exit 1
fi

YML_FILE="$1"
LITEPCI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Generating LitePCIe core from $YML_FILE..."

cd "$LITEPCI_DIR/dev"
source "$LITEPCI_DIR/dev/.venv/bin/activate"

# Always start from a clean build so memory init files don't accumulate.
[ -d build ] && rm -rf build

python3 "$LITEPCI_DIR/dev/repo/litepcie/gen.py" "$YML_FILE"

# Inline the LiteX CSR identifier `$readmemh` into the verilog so yosys
# doesn't need to track the .init file at flow time.  The init file holds
# the ASCII identifier string LitePCIeCore reports through CSR — small and
# constant per config.
python3 "$LITEPCI_DIR/dev/inline_readmemh.py" \
    build/gateware/litepcie_core.v \
    build/gateware/litepcie_core_mem.init

# Promote the generated core verilog and regenerate the pcie_us blackbox stub
# (port list / widths depend on the PHY variant chosen in the YAML).
cp build/gateware/litepcie_core.v "$LITEPCI_DIR/litepcie_core.v"
python3 "$LITEPCI_DIR/dev/gen_phy_stub.py" \
    build/gateware/litepcie_core.v \
    --module pcie_us \
    --out "$LITEPCI_DIR/pcie_us_stub.v"

# OpenROAD's synth_odb needs a LEF master for the pcie_us blackbox on every
# platform.  Regenerate the per-platform placeholder LEF/LIB pair into the
# committed phy/ trees so the build does not depend on dev tooling at flow
# time (mirrors how sram/ LEFs are committed).
REPO_ROOT="$(cd "$LITEPCI_DIR/../../.." && pwd)"
for PLAT in asap7 nangate45 sky130hd; do
    PHY_DIR="$REPO_ROOT/designs/$PLAT/litepci/phy"
    mkdir -p "$PHY_DIR/lef" "$PHY_DIR/lib"
    python3 "$LITEPCI_DIR/dev/gen_phy_lef.py" \
        "$LITEPCI_DIR/pcie_us_stub.v" \
        --module pcie_us --platform "$PLAT" \
        --out-lef "$PHY_DIR/lef/pcie_us.lef" \
        --out-lib "$PHY_DIR/lib/pcie_us.lib"
done

# Archive the full build tree (csr.json, xdc, mem.init, …) for traceability.
ARCHIVE_DIR="$LITEPCI_DIR/dev/build_archive/litepcie_core_${TIMESTAMP}"
mkdir -p "$ARCHIVE_DIR"
cp -r build/* "$ARCHIVE_DIR/"

rm -rf build
echo "Done. Verilog at $LITEPCI_DIR/litepcie_core.v"
