#!/usr/bin/env python3
"""
Generate a placeholder LEF + LIB for the Xilinx PCIe hard-IP blackbox
(`pcie_us` / `pcie_s7`) instantiated by litepcie's `gen.py`.

OpenROAD's synth_odb step needs a LEF master for every blackbox in the
netlist; this script extracts the port list (names + widths) from the
auto-generated stub Verilog (gen_phy_stub.py output) and lays the pins
out on a fixed-size hard macro.  The dimensions are a rough guess —
real Xilinx UltraScale+ PCIe Gen3 x4 hard IP sits around 0.5 mm² in
16 nm, so we pick 200 µm × 200 µm here as a placeholder.

Usage: gen_phy_lef.py <stub.v> --platform asap7 --out-lef <lef> --out-lib <lib>

The companion .lib is similarly a stub: each input is a non-timing
input pin, each output drives a constant.  It exists only to satisfy
OpenSTA's linkage; the block itself is treated as off-chip in
practice (no GDS body).
"""

import argparse
import re
import sys
from pathlib import Path


# Per-platform LEF parameters chosen so generated pin centers land on the
# platform's M4 (or equivalent) track grid.  The track offsets/pitches come
# from each platform's openRoad/make_tracks.tcl (or pin pitches reported in
# the BSG FakeRAM configs).  See gen_phy_lef.py header for context.
#
#   pin_layer:   horizontal-routing pin layer to use for IO pins
#   pin_w_um:    pin width along the y-direction (height of the pin RECT)
#   pin_ext_um:  how far the pin extends into the macro along x
#   track_off_um, track_pitch_um:  y-track grid for `pin_layer`
#   pin_stride:  number of tracks between consecutive bit-pins
#   size_um:     macro outline (snapped to grid_um)
#   grid_um:     manufacturing grid
PLATFORMS = {
    # asap7: M4 routes horizontal → pins on left/right edges land on horizontal
    # tracks at y = 0.012 + N*0.048.  Pin stride 2 (pitch 0.096) needs ~62 µm
    # for the 651-per-edge pin column; 80 µm is the smallest tested size that
    # still leaves the resizer comfortable room around the macro.
    "asap7": {
        "size_um":     (80.0, 80.0),
        "pin_layer":   "M4",
        "pin_w_um":    0.024,
        "pin_ext_um":  0.072,
        "track_off_um":   0.012,
        "track_pitch_um": 0.048,
        "pin_stride":  2,
        "grid_um":     0.001,
    },
    # nangate45: metal4 is VERTICAL → use metal3 (horizontal) for L/R edge pins.
    # metal3 track grid from make_tracks.tcl: y_offset 0.07, y_pitch 0.19.
    # Stride 2 (pitch 0.38) gives the access-point algorithm room between pins;
    # stride 1 hit DRT-0419 warnings and a non-converging repair_timing loop.
    "nangate45": {
        "size_um":     (280.0, 280.0),
        "pin_layer":   "metal3",
        "pin_w_um":    0.07,
        "pin_ext_um":  0.38,
        "track_off_um":   0.07,
        "track_pitch_um": 0.19,
        "pin_stride":  2,
        "grid_um":     0.005,
    },
    # sky130hd: met4 is VERTICAL → use met3 (horizontal).
    # met3 track grid: y_offset 0.34, y_pitch 0.68.  Stride 1 produced
    # `DRT-0073 No access point for pcie_us/...` because pitch = track pitch
    # left no via-drop room; stride 2 needs 885 µm per edge for 651 pins so
    # the macro must be ≥ 900 µm tall.
    "sky130hd": {
        "size_um":     (1000.0, 1000.0),
        "pin_layer":   "met3",
        "pin_w_um":    0.30,
        "pin_ext_um":  0.68,
        "track_off_um":   0.34,
        "track_pitch_um": 0.68,
        "pin_stride":  2,
        "grid_um":     0.005,
    },
}


def parse_stub_ports(stub_v: Path):
    """Yield (direction, name, width) for every port in the (* blackbox *) stub."""
    text = stub_v.read_text()
    # Match e.g. `input  [7:0] foo,` or `output bar);`
    port_re = re.compile(
        r"^\s*(input|output)\s*(?:\[(\d+):(\d+)\])?\s+(\w+)\s*[,)]",
        re.MULTILINE,
    )
    for d, hi, lo, name in port_re.findall(text):
        w = (int(hi) - int(lo) + 1) if hi else 1
        yield d, name, w


def snap(v, grid):
    return round(v / grid) * grid


def emit_lef(module, ports, params) -> str:
    sx, sy = params["size_um"]
    layer  = params["pin_layer"]
    pw     = params["pin_w_um"]
    pe     = params["pin_ext_um"]
    grid   = params["grid_um"]
    t_off  = params["track_off_um"]
    t_p    = params["track_pitch_um"]
    stride = params["pin_stride"]
    pitch  = t_p * stride  # y-distance between consecutive bit-pins

    # Flatten the (name, dir) port list into bit-level pins.
    bit_pins = []
    for d, name, w in ports:
        if w == 1:
            bit_pins.append((d, name))
        else:
            for i in range(w):
                bit_pins.append((d, f"{name}[{i}]"))

    # Distribute bit-pins evenly around the left/right edges; reserve top/bottom
    # for power.  Half on the left (any direction), half on the right.
    n = len(bit_pins)
    half = (n + 1) // 2
    left  = bit_pins[:half]
    right = bit_pins[half:]

    # Tracks available on each edge between pitch-margin top and bottom.
    margin    = 2 * pitch
    usable    = sy - 2 * margin
    n_tracks  = int(usable // pitch)
    if max(len(left), len(right)) > n_tracks:
        sys.exit(f"macro too small: {n_tracks} tracks per edge < "
                 f"{max(len(left), len(right))} pins per edge")

    lines = []
    lines.append("VERSION 5.7 ;")
    lines.append('BUSBITCHARS "[]" ;')
    lines.append(f"MACRO {module}")
    lines.append("  CLASS BLOCK ;")
    lines.append(f"  FOREIGN {module} 0 0 ;")
    lines.append("  SYMMETRY X Y R90 ;")
    lines.append(f"  SIZE {snap(sx, grid):.3f} BY {snap(sy, grid):.3f} ;")

    def emit_pin(direction, full_name, x0, y_center):
        # Snap pin center to nearest track, then build a width=pw RECT around it.
        nearest_k = round((y_center - t_off) / t_p)
        yc        = t_off + nearest_k * t_p
        y0        = snap(yc - pw / 2, grid)
        y1        = snap(yc + pw / 2, grid)
        x0s       = snap(x0, grid)
        x1s       = snap(x0 + pe, grid)
        lines.append(f"  PIN {full_name}")
        lines.append(f"    DIRECTION {'INPUT' if direction == 'input' else 'OUTPUT'} ;")
        lines.append("    USE SIGNAL ;")
        lines.append("    PORT")
        lines.append(f"      LAYER {layer} ;")
        lines.append(f"      RECT {x0s:.3f} {y0:.3f} {x1s:.3f} {y1:.3f} ;")
        lines.append("    END")
        lines.append(f"  END {full_name}")

    def emit_edge(pins_list, edge_x):
        # Place pin i at y = margin + i*pitch (one pin per `stride` tracks).
        for i, (d, n) in enumerate(pins_list):
            y = margin + i * pitch
            emit_pin(d, n, edge_x, y)

    emit_edge(left,  0.0)
    emit_edge(right, sx - pe)

    lines.append(f"END {module}")
    lines.append("")
    lines.append("END LIBRARY")
    return "\n".join(lines) + "\n"


def emit_lib(module, ports) -> str:
    """Stub liberty: every input is direction=input, every output drives 0."""
    lines = []
    lines.append(f"library({module}_lib) {{")
    lines.append("  technology(cmos);")
    lines.append("  delay_model : table_lookup;")
    lines.append("  time_unit : \"1ns\";")
    lines.append("  voltage_unit : \"1V\";")
    lines.append("  current_unit : \"1mA\";")
    lines.append("  pulling_resistance_unit : \"1kohm\";")
    lines.append("  capacitive_load_unit (1.0, pf);")
    lines.append("  default_max_transition : 1.0;")
    lines.append("  default_input_pin_cap : 0.001;")
    lines.append("  default_output_pin_cap : 0.0;")
    lines.append(f"  cell({module}) {{")
    lines.append("    interface_timing : true;")
    lines.append("    dont_use : true;")
    lines.append("    dont_touch : true;")
    lines.append("    is_macro_cell : true;")
    for d, name, w in ports:
        if w == 1:
            lines.append(f"    pin({name}) {{")
            lines.append(f"      direction : {d};")
            if d == "input":
                lines.append("      capacitance : 0.001;")
            else:
                lines.append("      function : \"0\";")
            lines.append("    }")
        else:
            lines.append(f"    bus({name}) {{")
            lines.append("      bus_type : bus_type_default;")
            lines.append(f"      direction : {d};")
            for i in range(w):
                lines.append(f"      pin({name}[{i}]) {{")
                lines.append(f"        direction : {d};")
                if d == "input":
                    lines.append("        capacitance : 0.001;")
                else:
                    lines.append("        function : \"0\";")
                lines.append("      }")
            lines.append("    }")
    lines.append("  }")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("stub_v")
    ap.add_argument("--module", default="pcie_us")
    ap.add_argument("--platform", required=True, choices=list(PLATFORMS))
    ap.add_argument("--out-lef", required=True)
    ap.add_argument("--out-lib", required=True)
    # Bus widths in liberty must match a default bus_type; emit a tiny header
    # for it so OpenSTA accepts buses without a project-wide definition.
    args = ap.parse_args()

    params = PLATFORMS[args.platform]
    ports = list(parse_stub_ports(Path(args.stub_v)))
    if not ports:
        sys.exit("no ports found in stub")

    Path(args.out_lef).write_text(emit_lef(args.module, ports, params))
    # Prepend a bus_type definition to the lib so the bus() blocks parse.
    bus_widths = sorted({w for _, _, w in ports if w > 1})
    lib_body = emit_lib(args.module, ports)
    # Inject bus_type definitions before the first cell().
    bus_defs = []
    for w in bus_widths:
        bus_defs.append("  type(bus_type_default) {")
        bus_defs.append("    base_type : array;")
        bus_defs.append("    data_type : bit;")
        bus_defs.append(f"    bit_width : {w};")
        bus_defs.append(f"    bit_from  : {w - 1};")
        bus_defs.append("    bit_to    : 0;")
        bus_defs.append("    downto    : true;")
        bus_defs.append("  }")
    if bus_defs:
        # Pop in a single definition (max width); per-bus mismatches would
        # need richer types but ORFS only inspects names, not widths.
        max_w = max(bus_widths)
        bus_defs = [
            "  type(bus_type_default) {",
            "    base_type : array;",
            "    data_type : bit;",
            f"    bit_width : {max_w};",
            f"    bit_from  : {max_w - 1};",
            "    bit_to    : 0;",
            "    downto    : true;",
            "  }",
        ]
        lib_body = lib_body.replace(
            f"  cell({args.module})",
            "\n".join(bus_defs) + f"\n  cell({args.module})",
            1,
        )
    Path(args.out_lib).write_text(lib_body)
    print(f"Wrote {args.out_lef} and {args.out_lib} ({len(ports)} ports, "
          f"{sum(w for _, _, w in ports)} bit-pins)")


if __name__ == "__main__":
    main()
