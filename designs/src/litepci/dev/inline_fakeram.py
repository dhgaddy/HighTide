#!/usr/bin/env python3
"""
Rewrite LiteX-emitted inferred memory blocks in litepcie_core.v into
explicit `fakeram_1rw1r_<W>w<D>d_sram` instantiations.

The standalone litepcie generator emits each memory as a `reg [W-1:0]
<name>[0:D-1];` register array with companion `_dat0` / `_dat1` registers
and 2 sync-write / sync-or-async-read `always @(posedge clk)` blocks.
That pattern relies on yosys's memory inference to produce a real
SRAM, but yosys-slang only blackboxes — without an explicit fakeram
instance the design either synthesizes ~1 Mb of flop array (huge) or
gets collapsed by `SYNTH_MOCK_LARGE_MEMORIES` (loses register-to-
register paths in STA).

This patcher is the litepci analog of liteeth's hand-written
`patch/*.patch`, but driven from the source generator output: each
memory is parsed, classified by W×D, and replaced when above
`THRESHOLD_BITS` with a fakeram instance whose 5 supported geometries
are committed under each platform's `litepci/sram/`.  Sub-threshold
memories stay as register arrays (yosys-slang infers them to flops).

Caveat: 4 of the descriptor-table memories (storage_5/7/11/13) declare
Port 1 as `Read: Async` in the LiteX header.  The fakeram only offers
a sync read port, so the rewrite adds one cycle of latency on those
read paths.  For benchmarking this is harmless; for functional
verification it isn't.  See `designs/src/litepci/DECISIONS.md`.
"""

import argparse
import re
import sys
from pathlib import Path


# Memories at least this large get mapped to FakeRAM.  Smaller stay as
# register arrays — yosys-slang will synthesize them to flops.  Matches
# the per-platform `SYNTH_MEMORY_MAX_BITS` default of 4096.
THRESHOLD_BITS = 4096

# (width, depth) → fakeram module name.  All five geometries listed here
# must have a matching LEF/LIB committed under
# `designs/<platform>/litepci/sram/`.  If you add a new memory shape
# below the threshold, also add it to bsg_fakeram configs and regenerate.
FAKERAM = {
    ( 92,  256): "fakeram_1rw1r_92w256d_sram",
    (130,  128): "fakeram_1rw1r_130w128d_sram",
    (130,  512): "fakeram_1rw1r_130w512d_sram",
    (130, 1024): "fakeram_1rw1r_130w1024d_sram",
    (230,  128): "fakeram_1rw1r_230w128d_sram",
}


# Regexes for parsing one memory block.  The block layout is:
#
#   // Memory <name>: <D>-words x <W>-bit
#   //---...
#   // Port 0 | Read: <Sync> | Write: <Sync> | Mode: <X>
#   // Port 1 | Read: <Sync|Async> | Write: ---- |
#   reg [<W-1>:0] <name>[0:<D-1>];
#   reg [<W-1>:0] <name>_dat0;
#   [reg [<W-1>:0] <name>_dat1;]                              <- if Port 1 sync
#   always @(posedge <wrclk>) begin
#       if (<sig>_wrport_we)
#           <name>[<sig>_wrport_adr] <= <sig>_wrport_dat_w;
#       <name>_dat0 <= <name>[<sig>_wrport_adr];
#   end
#   always @(posedge <rdclk>) begin
#       [if (<sig>_rdport_re)]                                <- optional gate
#       [<name>_dat1 <= <name>[<sig>_rdport_adr];]            <- if Port 1 sync
#   end
#   assign <sig>_wrport_dat_r = <name>_dat0;
#   assign <sig>_rdport_dat_r = (<name>_dat1 OR <name>[<sig>_rdport_adr]);

HEADER_RE = re.compile(
    r"^// Memory (\w+): (\d+)-words x (\d+)-bit\s*$",
    re.MULTILINE,
)

# Inside a block, pick out the wrport signal prefix and the wr/rd clocks.
WR_ALWAYS_RE = re.compile(
    r"always @\(posedge (\w+)\) begin\s*\n"
    r"\s*if \((\w+)_wrport_we\)\s*\n"
    r"\s*\w+\[\2_wrport_adr\] <= \2_wrport_dat_w;\s*\n"
    r"\s*\w+_dat0 <= \w+\[\2_wrport_adr\];\s*\n"
    r"\s*end"
)
# Sync read always: same wrport prefix is reused for the rd async path's name
# (LiteX uses one prefix per memory), so capture from the second always block.
RD_ALWAYS_SYNC_RE = re.compile(
    r"always @\(posedge (\w+)\) begin\s*\n"
    r"(?:\s*if \((\w+_rdport_re)\)\s*\n)?"
    r"\s*\w+_dat1 <= \w+\[(\w+)_rdport_adr\];\s*\n"
    r"\s*end"
)
# Empty read always (async-read memories drop the body):
RD_ALWAYS_EMPTY_RE = re.compile(
    r"always @\(posedge (\w+)\) begin\s*\n\s*end"
)
WRPORT_DAT_R_RE = re.compile(r"assign (\w+)_wrport_dat_r = \w+_dat0;")
RDPORT_DAT_R_RE = re.compile(r"assign (\w+)_rdport_dat_r = (.*?);")


def find_block_end(src: str, start: int) -> int:
    """Return the offset just past the closing `assign <sig>_rdport_dat_r` line."""
    m = RDPORT_DAT_R_RE.search(src, start)
    if not m:
        raise RuntimeError(f"could not find rdport_dat_r assignment after offset {start}")
    return m.end()


def patch_block(name: str, depth: int, width: int, body: str) -> str:
    """Replace one memory block body with a fakeram instantiation."""
    wr = WR_ALWAYS_RE.search(body)
    if not wr:
        raise RuntimeError(f"no recognized write-port always block in {name}")
    wrclk     = wr.group(1)
    wrport_sig = wr.group(2)  # signal prefix on wrport_we / wrport_adr / wrport_dat_w

    # Read port: try sync first, then fall back to async (empty always + assign
    # rdport_dat_r = <name>[<sig>_rdport_adr]).
    rd_sync = RD_ALWAYS_SYNC_RE.search(body, wr.end())
    if rd_sync:
        rdclk      = rd_sync.group(1)
        rdport_re  = rd_sync.group(2)        # may be None
        rdport_sig = rd_sync.group(3)
    else:
        rd_empty = RD_ALWAYS_EMPTY_RE.search(body, wr.end())
        if not rd_empty:
            raise RuntimeError(f"no recognized read-port always block in {name}")
        rdclk      = rd_empty.group(1)
        rdport_re  = None
        # Async-read memories don't have a _dat1 reg or sync assignment; the
        # rdport signal is the same prefix as wrport (LiteX uses one).
        rdport_sig = wrport_sig

    rdport_dat_r = RDPORT_DAT_R_RE.search(body, wr.end())
    if not rdport_dat_r:
        raise RuntimeError(f"no rdport_dat_r assign in {name}")
    rdport_sig = rdport_dat_r.group(1)  # canonical: drive prefix from the assign

    module = FAKERAM[(width, depth)]
    inst   = f"u_{name}_{module}"

    # Sync-read with re becomes ce_in(rdport_re); async-read or no-re becomes
    # ce_in(1'b1).  Either way the consumer sees a registered output one
    # cycle after the address — same as the sync write port, and the same
    # one-cycle bump async-read consumers will need to absorb.
    rd_ce = f"{rdport_sig}_rdport_re" if rdport_re else "1'b1"

    return f"""// Patched: {depth}×{width} → {module} ({inst})
wire [{width - 1}:0] {name}_dat0;
wire [{width - 1}:0] {name}_dat1;
(* keep *) {module} {inst} (
    .rw0_clk    ({wrclk}),
    .rw0_ce_in  (1'b1),
    .rw0_we_in  ({wrport_sig}_wrport_we),
    .rw0_addr_in({wrport_sig}_wrport_adr),
    .rw0_wd_in  ({wrport_sig}_wrport_dat_w),
    .rw0_rd_out ({name}_dat0),
    .r0_clk     ({rdclk}),
    .r0_ce_in   ({rd_ce}),
    .r0_addr_in ({rdport_sig}_rdport_adr),
    .r0_rd_out  ({name}_dat1)
);
assign {wrport_sig}_wrport_dat_r = {name}_dat0;
assign {rdport_sig}_rdport_dat_r = {name}_dat1;
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("verilog", help="litepcie_core.v to patch in place")
    args = ap.parse_args()

    path = Path(args.verilog)
    src  = path.read_text()

    # Find every memory header, decide whether to map, do replacement
    # right-to-left so byte offsets stay stable across edits.
    headers = list(HEADER_RE.finditer(src))
    patches = []
    skipped = []
    for h in headers:
        name  = h.group(1)
        depth = int(h.group(2))
        width = int(h.group(3))
        bits  = width * depth
        if bits < THRESHOLD_BITS:
            skipped.append((name, depth, width, bits, "< threshold"))
            continue
        if (width, depth) not in FAKERAM:
            skipped.append((name, depth, width, bits, "no matching fakeram"))
            continue
        # Block runs from header start to end of the rdport_dat_r assign.
        block_start = h.start()
        block_end   = find_block_end(src, h.end())
        body        = src[block_start:block_end]
        replacement = patch_block(name, depth, width, body)
        patches.append((block_start, block_end, name, replacement))

    for start, end, name, repl in reversed(patches):
        src = src[:start] + repl + src[end:]

    path.write_text(src)

    for name, depth, width, bits, why in skipped:
        print(f"  skip {name:<12} {depth:>5} × {width:>4} ({bits:>7} bits)  — {why}",
              file=sys.stderr)
    for _, _, name, _ in patches:
        print(f"  map  {name}", file=sys.stderr)
    print(f"Patched {len(patches)} memories into fakeram instances; "
          f"{len(skipped)} left as flop arrays.", file=sys.stderr)


if __name__ == "__main__":
    main()
