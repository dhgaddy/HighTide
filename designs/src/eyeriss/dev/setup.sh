#!/usr/bin/env bash
# Generate flat Verilog for the Eyeriss v2 ASIC top from the FPGA design.
#
# The upstream repo
# (https://github.com/BoooC/CNN-Accelerator-Based-on-Eyeriss-v2) targets a
# PYNQ-Z2 FPGA: its TOP_integration adds a Xilinx BRAM for the input feature
# map, a UART debug interface, and seven-segment display logic on top of the
# accelerator's TOP module. For ASIC we keep TOP only — the actual
# accelerator (Cluster_Group_array + GLB + routers + im2col + CSC encoders +
# pooling + quantizer + psum rearrange) — and drop the FPGA-only periphery.
#
# All Xilinx BRAM IPs (modules whose names start with IP_) are referenced by
# wrappers in the source but never defined, so they become blackboxes for
# yosys. We append macros.v with IP_* shims that instantiate bsg_fakeram-style
# 1r1w / 1rw SRAM macros so the ASIC flow has matching LEF/LIB to place.

set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

REPO_SRC=repo/FPGA_design/src
OUT_DIR=generated
mkdir -p "$OUT_DIR"

# Files to skip — FPGA-only top wrappers and human-machine interface.
EXCLUDE_DIRS=(
  "$REPO_SRC/UART"
  "$REPO_SRC/display"
  "$REPO_SRC/IO_processing"
)
EXCLUDE_FILES=(
  "$REPO_SRC/TOP/TOP_integration.v"
  "$REPO_SRC/TOP/TOP_integration_rom.v"
  "$REPO_SRC/TOP/TOP_integration_uart.v"
  "$REPO_SRC/TOP/TOP_interface.v"
  # CSC_encoderr_FIFO.v and CSC_switch_FIFO.v are byte-identical and both
  # define module CSC_switch_FIFO. Keep only one.
  "$REPO_SRC/CSC_encoder/CSC_encoderr_FIFO.v"
)

# Build the include/exclude args.
find_args=("$REPO_SRC" -type f -name '*.v')
for d in "${EXCLUDE_DIRS[@]}"; do
  find_args+=(-not -path "$d/*")
done
for f in "${EXCLUDE_FILES[@]}"; do
  find_args+=(-not -path "$f")
done

OUT_V="$OUT_DIR/eyeriss.v"
: > "$OUT_V"

# Concatenate the ASIC-relevant source files in stable lexical order.
while IFS= read -r f; do
  echo "// ===== $f =====" >> "$OUT_V"
  cat "$f" >> "$OUT_V"
  echo >> "$OUT_V"
done < <(find "${find_args[@]}" | sort)

# Upstream SCNN_shape_info_compiler.v has an empty `else if()` (a stub the
# authors never finished — see the README "most basic prototype" note). The
# branch has no body either; replacing the predicate with a constant-false
# expression keeps the synthesizable structure with no logic change.
sed -i 's/else if()/else if (1'\''b0)/g' "$OUT_V"

# Append fakeram wrapper shims that supply definitions for the IP_*_BRAM
# modules instantiated in the source. Each shim wraps a bsg_fakeram macro and
# matches the original Xilinx BRAM IP port names (clka/wea/addra/dina/douta
# for 1rw, or clka/wea/addra/dina + clkb/rstb/addrb/doutb for 1r1w).
cat macros_template.v >> "$OUT_V"

echo "Generated $OUT_V ($(wc -l < "$OUT_V") lines)" >&2
