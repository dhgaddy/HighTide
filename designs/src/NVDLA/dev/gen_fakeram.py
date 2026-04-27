#!/usr/bin/env python3
"""Generate FakeRAM LEF/LIB files for NVDLA SRAM macros (1r1w, no mask).

NVDLA's existing asap7 fakeram_<W>x<D>_1r1w macros use a separate read and
write port interface (w0_clk/ce/we/addr/wd_in, r0_clk/ce/addr/rd_out) plus
VDD/VSS power pins. cacti can't size the smallest configurations
(<~1KB), so this generator computes geometry directly from the pin count
and a platform-specific area-per-bit estimate, mirroring what
bp_processor/dev/gen_fakeram.py does for that design.

Usage:
    python3 gen_fakeram.py --platform nangate45 <sram_dir>
"""
import argparse
import math
import os
import sys

# (width, depth) pairs used by NVDLA partitions a/c/o/p (partition_m has none).
SRAM_SIZES = [
    (4, 256),
    (6, 128),
    (7, 256),
    (8, 256),
    (9, 80),
    (11, 128),
    (14, 80),
    (15, 80),
    (16, 160),
    (18, 128),
    (22, 60),
    (32, 128),
    (64, 16),
    (64, 256),
    (65, 160),
    (66, 8),
    (66, 64),
    (66, 80),
    (256, 16),
    (272, 16),
]

# supply_track_offset / supply_track_pitch describe the routing grid of the
# supply layer (horizontal tracks). VDD/VSS rail centers are placed on these
# tracks so DRT doesn't reject pin shapes as offgrid.
PLATFORM_PARAMS = {
    "asap7": {
        "pin_w": 0.024,
        "pin_pitch": 0.144,
        "snap_w": 0.054,
        "snap_h": 0.270,
        "area_per_bit": 0.5,
        "min_area": 100,
        "pin_layer": "M4",
        "supply_layer": "M4",
        "supply_track_offset": 0.024,
        "supply_track_pitch": 0.048,
        "obs_layers": ["M1", "M2", "M3"],
        "nom_voltage": 0.7,
        "op_cond_name": "tt_1.0_25.0",
    },
    "nangate45": {
        "pin_w": 0.140,
        "pin_pitch": 0.280,
        "snap_w": 0.190,
        "snap_h": 1.400,
        "area_per_bit": 3.8,
        "min_area": 800,
        "pin_layer": "metal3",
        "supply_layer": "metal4",
        "supply_track_offset": 0.070,
        "supply_track_pitch": 0.280,
        "obs_layers": ["metal1", "metal2", "metal3"],
        "nom_voltage": 1.1,
        "op_cond_name": "tt_1.0_25.0",
    },
    "sky130hd": {
        # Signal pin RECT spans (0, y) -> (pin_w, y + pin_w). pin_w must
        # be wide enough to overlap met3's first vertical track at x=0.34
        # (so set 0.5, covers x=0..0.5). pin_pitch matches met4's track
        # pitch so each pin's Y extent always covers a met4 track,
        # allowing DRT to stack a met3-met4 via.
        "pin_w": 0.500,
        "pin_pitch": 0.920,
        # Supply rails run VERTICAL on met4 (perpendicular to met4's
        # horizontal preferred direction). The platform's macro_grid_1
        # connects met4-met5 with vertical met5 stripes; perpendicular
        # met4 macro rails meet them at clean crossings with proper M4
        # enclosure. Width 1.2 / pitch ~14.7 mirrors the working
        # liteeth fakeram on this platform.
        "supply_direction": "vertical",
        "supply_rail_w": 1.200,
        "supply_track_offset": 8.360,
        "supply_track_pitch": 7.360,
        "snap_w": 0.460,
        "snap_h": 2.720,
        "area_per_bit": 10.0,
        "min_area": 1000,
        "pin_layer": "met3",
        "supply_layer": "met4",
        "obs_layers": ["met1", "met2", "met3"],
        "nom_voltage": 1.8,
        "op_cond_name": "tt_1.0_25.0",
    },
}


def fakeram_name(width, depth):
    return f"fakeram_{width}x{depth}_1r1w"


def gen_lef(name, width, depth, outdir, platform):
    addr_bits = max(1, math.ceil(math.log2(depth))) if depth > 1 else 1
    p = PLATFORM_PARAMS[platform]

    bits = width * depth
    area = max(bits * p["area_per_bit"], p["min_area"])
    h = math.sqrt(area / 2.0)
    w = area / h
    w = math.ceil(w / p["snap_w"]) * p["snap_w"]
    h = math.ceil(h / p["snap_h"]) * p["snap_h"]

    # 2 ports * (data + addr) + clk/ce/we per port = 2*W + 2*A + 5 signal pins
    total_pins = 2 * width + 2 * addr_bits + 5
    min_h = p["pin_pitch"] * (total_pins + 4)
    if h < min_h:
        h = math.ceil(min_h / p["snap_h"]) * p["snap_h"]

    lines = [
        "VERSION 5.7 ;",
        'BUSBITCHARS "[]" ;',
        f"MACRO {name}",
        f"  FOREIGN {name} 0 0 ;",
        "  SYMMETRY X Y R90 ;",
        f"  SIZE {w:.3f} BY {h:.3f} ;",
        "  CLASS BLOCK ;",
    ]

    y = p["pin_pitch"]

    def add_pin(pname, direction):
        nonlocal y
        lines.extend([
            f"  PIN {pname}",
            f"    DIRECTION {direction} ;",
            "    USE SIGNAL ;",
            "    SHAPE ABUTMENT ;",
            "    PORT",
            f"      LAYER {p['pin_layer']} ;",
            f"      RECT 0.000 {y:.3f} {p['pin_w']:.3f} {y + p['pin_w']:.3f} ;",
            "    END",
            f"  END {pname}",
        ])
        y += p["pin_pitch"]

    # Write port
    for i in range(width):
        add_pin(f"w0_wd_in[{i}]", "INPUT")
    for i in range(addr_bits):
        add_pin(f"w0_addr_in[{i}]", "INPUT")
    add_pin("w0_clk", "INPUT")
    add_pin("w0_ce_in", "INPUT")
    add_pin("w0_we_in", "INPUT")
    # Read port
    for i in range(width):
        add_pin(f"r0_rd_out[{i}]", "OUTPUT")
    for i in range(addr_bits):
        add_pin(f"r0_addr_in[{i}]", "INPUT")
    add_pin("r0_clk", "INPUT")
    add_pin("r0_ce_in", "INPUT")

    # VDD / VSS supply rails on the supply layer, snapped to that layer's
    # routing track grid. Two orientations supported:
    #   "horizontal" — rails run along the layer's preferred direction
    #     (full-width thin strips stacked in Y). Works for asap7/nangate45.
    #   "vertical" — rails run perpendicular to the preferred direction
    #     (full-height thin strips spaced in X). Required for sky130hd:
    #     the platform's met5 stripes that connect via macro_grid_1 are
    #     vertical, so met4 macro rails must be vertical too to give the
    #     M4-M5 via a perpendicular crossing with proper enclosure.
    track_off = p["supply_track_offset"]
    track_pitch = p["supply_track_pitch"]
    rail_w = p.get("supply_rail_w", p["pin_w"])
    direction = p.get("supply_direction", "horizontal")
    span_axis = h if direction == "horizontal" else w
    track_centers = []
    n = 0
    while True:
        c = track_off + n * track_pitch
        if c + rail_w / 2 > span_axis:
            break
        if c - rail_w / 2 >= 0:
            track_centers.append(c)
        n += 1
    vdd_centers = track_centers[0::2]
    vss_centers = track_centers[1::2]

    def add_supply(net, use, centers):
        lines.extend([
            f"  PIN {net}",
            f"    DIRECTION INOUT ;",
            f"    USE {use} ;",
            "    PORT",
            f"      LAYER {p['supply_layer']} ;",
        ])
        for c in sorted(centers):
            if direction == "horizontal":
                x0, x1 = p["snap_w"], w - p["snap_w"]
                y0, y1 = c - rail_w / 2, c + rail_w / 2
            else:  # vertical
                x0, x1 = c - rail_w / 2, c + rail_w / 2
                y0, y1 = p["snap_h"], h - p["snap_h"]
            lines.append(f"      RECT {x0:.3f} {y0:.3f} {x1:.3f} {y1:.3f} ;")
        lines.extend([
            "    END",
            f"  END {net}",
        ])

    add_supply("VDD", "POWER", vdd_centers)
    add_supply("VSS", "GROUND", vss_centers)

    lines.append("  OBS")
    for layer in p["obs_layers"]:
        lines.extend([
            f"    LAYER {layer} ;",
            f"      RECT 0.000 0.000 {w:.3f} {h:.3f} ;",
        ])
    lines.extend([
        "  END",
        f"END {name}",
        "END LIBRARY",
    ])

    path = os.path.join(outdir, "lef", f"{name}.lef")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    return w, h


def gen_lib(name, width, depth, outdir, w_um, h_um, platform):
    addr_bits = max(1, math.ceil(math.log2(depth))) if depth > 1 else 1
    area = w_um * h_um
    p = PLATFORM_PARAMS[platform]
    voltage = p["nom_voltage"]
    op_cond = p["op_cond_name"]

    L = []
    L.append(f"library({name}) {{")
    L.append("    technology (cmos);")
    L.append("    delay_model : table_lookup;")
    L.append("    revision : 1.0;")
    L.append('    date : "2026-01-01 00:00:00Z";')
    L.append('    comment : "SRAM";')
    L.append('    time_unit : "1ns";')
    L.append('    voltage_unit : "1V";')
    L.append('    current_unit : "1uA";')
    L.append('    leakage_power_unit : "1uW";')
    L.append("    nom_process : 1;")
    L.append("    nom_temperature : 25.000;")
    L.append(f"    nom_voltage : {voltage};")
    L.append("    capacitive_load_unit (1,pf);")
    L.append('    pulling_resistance_unit : "1kohm";')
    L.append(f"    operating_conditions({op_cond}) {{")
    L.append("        process : 1;")
    L.append("        temperature : 25.000;")
    L.append(f"        voltage : {voltage};")
    L.append("        tree_type : balanced_tree;")
    L.append("    }")
    L.append("    default_cell_leakage_power : 0;")
    L.append("    default_fanout_load : 1;")
    L.append("    default_inout_pin_cap : 0.0;")
    L.append("    default_input_pin_cap : 0.0;")
    L.append("    default_output_pin_cap : 0.0;")
    L.append("    default_max_transition : 0.227;")
    L.append(f"    default_operating_conditions : {op_cond};")
    L.append("    default_leakage_power_density : 0.0;")
    L.append("    slew_derate_from_library : 1.000;")
    L.append("    slew_lower_threshold_pct_fall : 20.000;")
    L.append("    slew_upper_threshold_pct_fall : 80.000;")
    L.append("    slew_lower_threshold_pct_rise : 20.000;")
    L.append("    slew_upper_threshold_pct_rise : 80.000;")
    L.append("    input_threshold_pct_fall : 50.000;")
    L.append("    input_threshold_pct_rise : 50.000;")
    L.append("    output_threshold_pct_fall : 50.000;")
    L.append("    output_threshold_pct_rise : 50.000;")
    L.append(f"    lu_table_template({name}_delay) {{")
    L.append("        variable_1 : input_net_transition;")
    L.append("        variable_2 : total_output_net_capacitance;")
    L.append('            index_1 ("1000, 1001");')
    L.append('            index_2 ("1000, 1001");')
    L.append("    }")
    L.append(f"    lu_table_template({name}_slew) {{")
    L.append("        variable_1 : total_output_net_capacitance;")
    L.append('            index_1 ("1000, 1001");')
    L.append("    }")
    L.append(f"    lu_table_template({name}_constraint) {{")
    L.append("        variable_1 : related_pin_transition;")
    L.append("        variable_2 : constrained_pin_transition;")
    L.append('            index_1 ("1000, 1001");')
    L.append('            index_2 ("1000, 1001");')
    L.append("    }")
    L.append("    library_features(report_delay_calculation);")
    L.append(f"    type ({name}_DATA) {{")
    L.append("        base_type : array; data_type : bit;")
    L.append(f"        bit_width : {width}; bit_from : {width-1}; bit_to : 0; downto : true;")
    L.append("    }")
    L.append(f"    type ({name}_ADDR) {{")
    L.append("        base_type : array; data_type : bit;")
    L.append(f"        bit_width : {addr_bits}; bit_from : {addr_bits-1}; bit_to : 0; downto : true;")
    L.append("    }")
    L.append(f"    cell({name}) {{")
    L.append(f"        area : {area:.3f};")
    L.append("        interface_timing : true;")
    L.append("        dont_use : true;")
    L.append("        dont_touch : true;")

    def constraint_block(pin_name, direction, related_clk, cap="0.0035", bus_type=None, extra_lines=None):
        b = []
        if bus_type:
            b.append(f"        bus({pin_name}) {{")
            b.append(f"            bus_type : {bus_type};")
        else:
            b.append(f"        pin({pin_name}) {{")
        b.append(f"            direction : {direction};")
        if direction == "input":
            b.append(f"            capacitance : {cap};")
        if extra_lines:
            b.extend(extra_lines)
        b.extend([
            "            timing() {",
            f'                related_pin : "{related_clk}";',
            "                timing_type : setup_rising;",
            f"                rise_constraint({name}_constraint) {{",
            '                    index_1 ("0.010, 0.100"); index_2 ("0.010, 0.100");',
            '                    values("0.050, 0.050", "0.050, 0.050");',
            "                }",
            f"                fall_constraint({name}_constraint) {{",
            '                    index_1 ("0.010, 0.100"); index_2 ("0.010, 0.100");',
            '                    values("0.050, 0.050", "0.050, 0.050");',
            "                }",
            "            }",
            "            timing() {",
            f'                related_pin : "{related_clk}";',
            "                timing_type : hold_rising;",
            f"                rise_constraint({name}_constraint) {{",
            '                    index_1 ("0.010, 0.100"); index_2 ("0.010, 0.100");',
            '                    values("0.005, 0.005", "0.005, 0.005");',
            "                }",
            f"                fall_constraint({name}_constraint) {{",
            '                    index_1 ("0.010, 0.100"); index_2 ("0.010, 0.100");',
            '                    values("0.005, 0.005", "0.005, 0.005");',
            "                }",
            "            }",
            "        }",
        ])
        return b

    # Write port
    L.append('        pin(w0_clk) { direction : input; capacitance : 0.0214; clock : true; }')
    L.extend(constraint_block("w0_ce_in", "input", "w0_clk"))
    L.extend(constraint_block("w0_we_in", "input", "w0_clk"))
    L.extend(constraint_block("w0_addr_in", "input", "w0_clk", bus_type=f"{name}_ADDR"))
    L.extend(constraint_block(
        "w0_wd_in", "input", "w0_clk", bus_type=f"{name}_DATA",
        extra_lines=['            memory_write() { address : w0_addr_in; clocked_on : "w0_clk"; }'],
    ))

    # Read port
    L.append('        pin(r0_clk) { direction : input; capacitance : 0.0214; clock : true; }')
    L.extend(constraint_block("r0_ce_in", "input", "r0_clk"))
    L.extend(constraint_block("r0_addr_in", "input", "r0_clk", bus_type=f"{name}_ADDR"))

    L.extend([
        f"        bus(r0_rd_out) {{",
        f"            bus_type : {name}_DATA;",
        "            direction : output;",
        "            max_capacitance : 0.500;",
        "            memory_read() { address : r0_addr_in; }",
        "            timing() {",
        '                related_pin : "r0_clk";',
        "                timing_type : rising_edge;",
        "                timing_sense : non_unate;",
        f"                cell_rise({name}_delay) {{",
        '                    index_1 ("0.010, 0.100"); index_2 ("0.0005, 0.500");',
        '                    values("0.200, 0.800", "0.250, 0.850");',
        "                }",
        f"                cell_fall({name}_delay) {{",
        '                    index_1 ("0.010, 0.100"); index_2 ("0.0005, 0.500");',
        '                    values("0.200, 0.800", "0.250, 0.850");',
        "                }",
        f"                rise_transition({name}_slew) {{",
        '                    index_1 ("0.0005, 0.500"); values("0.015, 0.300");',
        "                }",
        f"                fall_transition({name}_slew) {{",
        '                    index_1 ("0.0005, 0.500"); values("0.015, 0.300");',
        "                }",
        "            }",
        "        }",
        "    }",
        "}",
    ])

    path = os.path.join(outdir, "lib", f"{name}.lib")
    with open(path, "w") as f:
        f.write("\n".join(L) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--platform", choices=list(PLATFORM_PARAMS), default="nangate45")
    ap.add_argument("sram_dir")
    args = ap.parse_args()

    os.makedirs(os.path.join(args.sram_dir, "lef"), exist_ok=True)
    os.makedirs(os.path.join(args.sram_dir, "lib"), exist_ok=True)

    print(f"Generating {len(SRAM_SIZES)} NVDLA FakeRAM macros for {args.platform}:")
    for width, depth in SRAM_SIZES:
        name = fakeram_name(width, depth)
        w, h = gen_lef(name, width, depth, args.sram_dir, args.platform)
        gen_lib(name, width, depth, args.sram_dir, w, h, args.platform)
        print(f"  {name}  {w:.3f} x {h:.3f} um")


if __name__ == "__main__":
    main()
