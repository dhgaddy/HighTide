#!/usr/bin/env python3
"""Generate a fixed-grid MACRO_PLACEMENT_TCL from an ODB macro dump.

Design-agnostic version of the cnn-sky130hd grid fix. sky130hd's coarse
routing pitch + fakeram macros that put all signal pins on their bottom
(met2) edge means RTLMP's pin-edge-blind, mixed-orientation clustering
collides adjacent macros' met2 escape lanes -> localized capacity:0
overflow that no knob tuning clears. The fix: force every macro to R0
(pins uniformly south) on a regular grid with a routing channel below
every row, so each macro's pin edge always faces clear routing space.
Macros are set FIRM so the rtl_macro_placer ORFS runs *after* sourcing
MACRO_PLACEMENT_TCL leaves them alone.

With --alternate, rows alternate R0 (pins south) / MX (pins north).
Inter-row channels are then either "cold" (R0 top → MX bottom: both pin-
free boundaries) or "hot" (MX top → R0 bottom: pins on both sides).
Use --cold-chan / --hot-chan to size each independently so hot channels
get enough room for pin-escape routing from both boundaries.

With --aside MASTER [MASTER ...], those master types are removed from the
main grid and placed instead in the left side corridor (between the core
left edge and the centred grid), vertically centred in the die, oriented
R0.  Requires --center.  Useful for outlier-sized macros that would
otherwise sit alone in a partial top row with limited space above them.

Input: a dump produced by tools/dump_macros.tcl, lines of the form
  MACRO <inst> | <master> | <orient> | x y | WxH | status
plus one  CORE_UM x0 y0 x1 y1  line.  W/H come straight from the dump so
no LEF parsing or per-design size table is needed.

Usage:
  gen_macro_grid.py <dump.txt> <out.tcl> [--margin M] [--gap-x GX]
                     [--chan CH] [--per-row N] [--center] [--numeric-sort]
                     [--alternate] [--cold-chan CC] [--hot-chan HC]
                     [--aside MASTER ...]
"""
import argparse
import re
import sys


def load(path):
    core = None
    macros = []  # (inst, master, w, h)
    for line in open(path):
        if line.startswith("CORE_UM"):
            _, x0, y0, x1, y1 = line.split()
            core = (float(x0), float(y0), float(x1), float(y1))
        elif line.startswith("MACRO"):
            parts = [p.strip() for p in line[5:].split("|")]
            inst, master = parts[0], parts[1]
            w, h = (float(v) for v in parts[4].split("x"))
            macros.append((inst, master, w, h))
    if core is None:
        sys.exit("dump has no CORE_UM line")
    return core, macros


def _natural_key(s):
    """Natural-sort key: split on runs of digits so 'bank9' < 'bank10'."""
    return [int(t) if t.isdigit() else t for t in re.split(r'(\d+)', s)]


def pack_rows(macros, x0, x_limit, gap_x, per_row_override=None,
              numeric_sort=False, aside_masters=None):
    """Group like-sized macros into left-aligned rows, largest area first."""
    aside_masters = set(aside_masters or [])
    by_master = {}
    for m in macros:
        if m[1] not in aside_masters:
            by_master.setdefault(m[1], []).append(m)
    order = sorted(by_master, key=lambda k: by_master[k][0][2] * by_master[k][0][3],
                   reverse=True)
    rows = []
    for master in order:
        group = by_master[master]
        if numeric_sort:
            group = sorted(group, key=lambda m: _natural_key(m[0]))
        w = group[0][2]
        if per_row_override is not None:
            per_row = per_row_override
        else:
            per_row = max(1, int((x_limit - x0 + gap_x) // (w + gap_x)))
        for i in range(0, len(group), per_row):
            rows.append(group[i:i + per_row])
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dump")
    ap.add_argument("out")
    ap.add_argument("--margin", type=float, default=50.0,
                    help="left/right margin from core edge (um). Ignored when "
                         "--center is set.")
    ap.add_argument("--gap-x", type=float, default=300.0)
    ap.add_argument("--chan", type=float, default=500.0,
                    help="routing channel below each row (um)")
    ap.add_argument("--per-row", type=int, default=None,
                    help="macros per row for the primary (largest) master; "
                         "default: fill available width")
    ap.add_argument("--center", action="store_true",
                    help="horizontally centre the macro grid in the core, "
                         "leaving equal free-routing corridors on both sides")
    ap.add_argument("--numeric-sort", action="store_true",
                    help="sort instance names numerically (natural sort) "
                         "instead of lexicographically within each master group")
    ap.add_argument("--alternate", action="store_true",
                    help="alternate R0/MX orientations between rows (even rows R0, "
                         "odd rows MX). Produces cold channels (R0-top→MX-bottom, "
                         "no pins on either boundary) and hot channels "
                         "(MX-top→R0-bottom, pins on both sides).")
    ap.add_argument("--cold-chan", type=float, default=None,
                    help="channel height (um) for cold inter-row boundaries "
                         "(R0→MX: both pin-free). Defaults to --chan.")
    ap.add_argument("--hot-chan", type=float, default=None,
                    help="channel height (um) for hot inter-row boundaries "
                         "(MX→R0: pins on both sides). Defaults to --chan.")
    ap.add_argument("--aside", nargs="+", default=[],
                    help="master name(s) to place in the left side corridor "
                         "rather than in the main grid rows (requires --center). "
                         "Each aside macro is centred horizontally in the left "
                         "corridor and stacked vertically, centred in the die.")
    args = ap.parse_args()

    (cx0, cy0, cx1, cy1), macros = load(args.dump)

    # Determine per-row count from the primary (largest) master so we can
    # compute the centred x_start before calling pack_rows.
    if args.per_row is not None:
        per_row = args.per_row
    else:
        # Use full-width default: compute from the largest master's width.
        largest_w = max(m[2] for m in macros)
        x0_tmp = cx0 + args.margin
        x_limit_tmp = cx1 - args.margin
        per_row = max(1, int((x_limit_tmp - x0_tmp + args.gap_x)
                             // (largest_w + args.gap_x)))

    if args.aside and not args.center:
        sys.exit("--aside requires --center (need a defined left corridor)")

    aside_macros = [m for m in macros if m[1] in args.aside]
    if args.aside and not aside_macros:
        sys.exit(f"--aside masters not found in dump: {args.aside}")

    if args.center:
        # Centre the widest-row group in the core (excluding aside masters).
        grid_macros = [m for m in macros if m[1] not in args.aside]
        largest_w = max(m[2] for m in grid_macros) if grid_macros else 0
        grid_width = per_row * largest_w + (per_row - 1) * args.gap_x
        core_w = cx1 - cx0
        x0 = cx0 + (core_w - grid_width) / 2
    else:
        x0 = cx0 + args.margin

    x_limit = cx1 - args.margin  # only used when per_row_override is None
    rows = pack_rows(macros, x0, x_limit, args.gap_x,
                     per_row_override=args.per_row,
                     numeric_sort=args.numeric_sort,
                     aside_masters=args.aside)

    cold_chan = args.cold_chan if args.cold_chan is not None else args.chan
    hot_chan = args.hot_chan if args.hot_chan is not None else args.chan

    orient_note = ("alternating R0/MX" if args.alternate
                   else "every macro R0 (pins uniformly south)")
    out = [
        "# AUTO-GENERATED by tools/gen_macro_grid.py",
        f"# Fixed grid: {orient_note}, a routing",
        "# channel below every row so each macro's met2 pin edge faces",
        "# clear space. Macros FIRM so the post-source rtl_macro_placer",
        "# leaves them alone. See the script header for the rationale.",
        "",
    ]
    # Start one channel up so row 0's pin edge also faces a channel.
    y = cy0 + args.chan
    for i, row in enumerate(rows):
        orient = "MX" if (args.alternate and i % 2 == 1) else "R0"
        rh = max(m[3] for m in row)
        x = x0
        for inst, master, w, h in row:
            out.append(
                f"place_macro -macro_name {{{inst}}} "
                f"-location {{{x:.3f} {y:.3f}}} -orientation {orient}")
            x += w + args.gap_x
        # Channel type after this row:
        #   even row (R0) → next odd row (MX): cold (both boundaries pin-free)
        #   odd row (MX)  → next even row (R0): hot  (both boundaries have pins)
        if args.alternate:
            chan = cold_chan if i % 2 == 0 else hot_chan
        else:
            chan = args.chan
        y += rh + chan

    top = y
    if top >= cy1 - args.margin:
        sys.exit(f"grid overflows core: top={top:.1f} >= {cy1 - args.margin:.1f}"
                 f" (loosen --gap-x / --chan or widen the die)")

    # Place aside macros in the left side corridor, stacked and centred.
    if aside_macros:
        left_corridor_w = x0 - cx0
        total_aside_h = sum(m[3] for m in aside_macros) + args.chan * (len(aside_macros) - 1)
        aside_y = cy0 + ((cy1 - cy0) - total_aside_h) / 2
        out.append("")
        out.append("# aside macros — left side corridor, vertically centred")
        for inst, master, w, h in aside_macros:
            aside_x = cx0 + (left_corridor_w - w) / 2
            out.append(
                f"place_macro -macro_name {{{inst}}} "
                f"-location {{{aside_x:.3f} {aside_y:.3f}}} -orientation R0")
            aside_y += h + args.chan

    out += ["", "set _blk [ord::get_db_block]", "foreach _m {"]
    out += [f"  {{{m[0]}}}" for m in macros]
    out += ["} {", "  set _i [$_blk findInst $_m]",
            "  if {$_i ne \"NULL\" && $_i ne \"\"} { $_i setPlacementStatus FIRM }",
            "}", ""]

    with open(args.out, "w") as f:
        f.write("\n".join(out) + "\n")
    print(f"wrote {args.out}: {len(macros)} macros, {len(rows)} rows, "
          f"grid_top={top:.1f}um, core_y1={cy1:.1f}um")


if __name__ == "__main__":
    main()
