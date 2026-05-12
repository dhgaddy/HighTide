#!/usr/bin/env python3
"""
Inline `$readmemh("xxx.init", mem)` calls into the generated litepcie_core.v.

Yosys is invoked from a sandbox directory that doesn't include the .init
file alongside the .v, so the readmemh call fails at synthesis time.
Since the LiteX-emitted .init only holds a short ASCII CSR-identifier
string (~45 bytes), we just rewrite it to a series of `mem[i] = 8'hXX;`
initial assignments — no runtime file IO needed.

Usage: inline_readmemh.py <generated.v> <generated_mem.init>
       (rewrites the .v file in place)
"""

import re
import sys
from pathlib import Path


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    verilog_path = Path(sys.argv[1])
    init_path    = Path(sys.argv[2])

    init_name = init_path.name
    values = [int(line.strip(), 16) for line in init_path.read_text().splitlines() if line.strip()]

    src = verilog_path.read_text()

    # Match e.g. `$readmemh("litepcie_core_mem.init", mem);` with arbitrary
    # whitespace.  Capture the mem-array name so we can emit per-cell inits.
    pat = re.compile(
        r'\$readmemh\s*\(\s*"' + re.escape(init_name) + r'"\s*,\s*(\w+)\s*\)\s*;'
    )

    def repl(m):
        mem = m.group(1)
        lines = [f'\t{mem}[{i}] = 8\'h{v:02x};' for i, v in enumerate(values)]
        return ("// inlined from " + init_name + " (LitePCIe CSR id string)\n"
                + "\n".join(lines))

    new_src, n = pat.subn(repl, src)
    if n == 0:
        sys.exit(f"readmemh({init_name}) not found in {verilog_path}")
    if n > 1:
        print(f"warning: inlined {n} readmemh sites", file=sys.stderr)

    verilog_path.write_text(new_src)
    print(f"Inlined {len(values)} bytes from {init_name} into {verilog_path}")


if __name__ == "__main__":
    main()
