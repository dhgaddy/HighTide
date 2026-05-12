#!/usr/bin/env bash

set -euo pipefail

DIR="$(dirname $(readlink -f $0))"
cd "$DIR"

# Copy upstream RTL into gen/ tree
rm -rf gen
mkdir -p gen/rtl
cp -r repo/rtl/* gen/rtl/
