#!/usr/bin/env python3
"""
Generate nangate45-compatible FakeRAM LEF/LIB files for CNN SRAM memories.

The CNN design uses dual-port read-write memories (rw0/rw1 interface) generated
by OpenFakeRAM for asap7. This script generates equivalent LEF/LIB files
targeted at the nangate45 platform.

Usage: python3 gen_fakeram_nangate45.py <output_sram_dir>

Generates LEF/LIB files in <output_sram_dir>/lef/ and <output_sram_dir>/lib/.
"""
import math
import os
import sys

# CNN memory configurations: (name, width, depth)
# These match the existing fakeram Verilog modules in designs/src/cnn/
CNN_CONFIGS = [
    ("fakeram_w16_l512",   16, 512),
    ("fakeram_w16_l8192",  16, 8192),
    ("fakeram_w16_l32768", 16, 32768),
    ("fakeram_w64_l256",   64, 256),
]

# nangate45 grid constants
PIN_W = 0.140
PIN_PITCH = 1.400
SNAP_W = 0.190
SNAP_H = 1.400
AREA_PER_BIT = 3.8
MIN_AREA = 800
PIN_LAYER = "metal3"
OBS_LAYERS = ["metal1", "metal2", "metal3", "metal4"]
NOM_VOLTAGE = 1.1
OP_COND = "tt_1.0_25.0"


def gen_lef(name, width, depth, outdir):
    addr_bits = max(1, math.ceil(math.log2(depth))) if depth > 1 else 1

    # Estimate macro size
    bits = width * depth
    area = max(bits * AREA_PER_BIT, MIN_AREA)
    h = math.sqrt(area / 2.0)
    w = area / h
    w = math.ceil(w / SNAP_W) * SNAP_W
    h = math.ceil(h / SNAP_H) * SNAP_H

    # Dual-port pins: rw0 + rw1, each has: clk, ce_in, we_in, addr_in[N], wd_in[W], rd_out[W]
    total_pins = 2 * (3 + addr_bits + width * 2)
    min_h = PIN_PITCH * (total_pins + 4)
    if h < min_h:
        h = math.ceil(min_h / SNAP_H) * SNAP_H

    lines = [
        "VERSION 5.7 ;",
        'BUSBITCHARS "[]" ;',
        f"MACRO {name}",
        f"  FOREIGN {name} 0 0 ;",
        "  SYMMETRY X Y R90 ;",
        f"  SIZE {w:.3f} BY {h:.3f} ;",
        "  CLASS BLOCK ;",
    ]

    y_pos = PIN_PITCH

    def add_pin(pname, direction):
        nonlocal y_pos
        lines.extend([
            f"  PIN {pname}",
            f"    DIRECTION {direction} ;",
            "    USE SIGNAL ;",
            "    SHAPE ABUTMENT ;",
            "    PORT",
            f"      LAYER {PIN_LAYER} ;",
            f"      RECT 0.000 {y_pos:.3f} {PIN_W:.3f} {y_pos + PIN_W:.3f} ;",
            "    END",
            f"  END {pname}",
        ])
        y_pos += PIN_PITCH

    # Port rw0
    add_pin("rw0_clk", "INPUT")
    add_pin("rw0_ce_in", "INPUT")
    add_pin("rw0_we_in", "INPUT")
    for i in range(addr_bits):
        add_pin(f"rw0_addr_in[{i}]", "INPUT")
    for i in range(width):
        add_pin(f"rw0_wd_in[{i}]", "INPUT")
    for i in range(width):
        add_pin(f"rw0_rd_out[{i}]", "OUTPUT")

    # Port rw1
    add_pin("rw1_clk", "INPUT")
    add_pin("rw1_ce_in", "INPUT")
    add_pin("rw1_we_in", "INPUT")
    for i in range(addr_bits):
        add_pin(f"rw1_addr_in[{i}]", "INPUT")
    for i in range(width):
        add_pin(f"rw1_wd_in[{i}]", "INPUT")
    for i in range(width):
        add_pin(f"rw1_rd_out[{i}]", "OUTPUT")

    lines.append("  OBS")
    for layer in OBS_LAYERS:
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


def gen_lib(name, width, depth, outdir, w_um, h_um):
    addr_bits = max(1, math.ceil(math.log2(depth))) if depth > 1 else 1
    area = w_um * h_um

    lines = [
        f"library({name}) {{",
        "    technology (cmos);",
        "    delay_model : table_lookup;",
        "    revision : 1.0;",
        '    date : "2025-01-01 00:00:00Z";',
        '    comment : "SRAM";',
        '    time_unit : "1ns";',
        '    voltage_unit : "1V";',
        '    current_unit : "1uA";',
        '    leakage_power_unit : "1uW";',
        "    nom_process : 1;",
        "    nom_temperature : 25.000;",
        f"    nom_voltage : {NOM_VOLTAGE};",
        '    capacitive_load_unit (1,pf);',
        '    pulling_resistance_unit : "1kohm";',
        f"    operating_conditions({OP_COND}) {{",
        "        process : 1;",
        "        temperature : 25.000;",
        f"        voltage : {NOM_VOLTAGE};",
        "        tree_type : balanced_tree;",
        "    }",
        "    default_cell_leakage_power : 0;",
        "    default_fanout_load : 1;",
        "    default_inout_pin_cap : 0.0;",
        "    default_input_pin_cap : 0.0;",
        "    default_output_pin_cap : 0.0;",
        "    default_max_transition : 0.227;",
        f"    default_operating_conditions : {OP_COND};",
        "    default_leakage_power_density : 0.0;",
        "    slew_derate_from_library : 1.000;",
        "    slew_lower_threshold_pct_fall : 20.000;",
        "    slew_upper_threshold_pct_fall : 80.000;",
        "    slew_lower_threshold_pct_rise : 20.000;",
        "    slew_upper_threshold_pct_rise : 80.000;",
        "    input_threshold_pct_fall : 50.000;",
        "    input_threshold_pct_rise : 50.000;",
        "    output_threshold_pct_fall : 50.000;",
        "    output_threshold_pct_rise : 50.000;",
        f"    lu_table_template({name}_delay) {{",
        "        variable_1 : input_net_transition;",
        "        variable_2 : total_output_net_capacitance;",
        '            index_1 ("1000, 1001");',
        '            index_2 ("1000, 1001");',
        "    }",
        f"    lu_table_template({name}_slew) {{",
        "        variable_1 : total_output_net_capacitance;",
        '            index_1 ("1000, 1001");',
        "    }",
        f"    lu_table_template({name}_constraint) {{",
        "        variable_1 : related_pin_transition;",
        "        variable_2 : constrained_pin_transition;",
        '            index_1 ("1000, 1001");',
        '            index_2 ("1000, 1001");',
        "    }",
        "    library_features(report_delay_calculation);",
        f"    type ({name}_DATA) {{",
        "        base_type : array; data_type : bit;",
        f"        bit_width : {width}; bit_from : {width-1}; bit_to : 0; downto : true;",
        "    }",
        f"    type ({name}_ADDR) {{",
        "        base_type : array; data_type : bit;",
        f"        bit_width : {addr_bits}; bit_from : {addr_bits-1}; bit_to : 0; downto : true;",
        "    }",
        f"    cell({name}) {{",
        f"        area : {area:.3f};",
        "        interface_timing : true;",
        "        dont_use : true;",
        "        dont_touch : true;",
    ]

    def add_port_pins(prefix):
        """Add LIB pin definitions for one read-write port (rw0 or rw1)."""
        lines.append(f"        pin({prefix}_clk) {{ direction : input; capacitance : 0.0214; clock : true; }}")

        def constraint_block(pin_name, direction, cap="0.0035", bus_type=None, extra=""):
            block = []
            if bus_type:
                block.append(f"        bus({pin_name}) {{")
                block.append(f"            bus_type : {bus_type};")
            else:
                block.append(f"        pin({pin_name}) {{")
            block.append(f"            direction : {direction};")
            if direction == "input":
                block.append(f"            capacitance : {cap};")
            if extra:
                block.append(extra)
            block.extend([
                "            timing() {",
                f'                related_pin : "{prefix}_clk";',
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
                f'                related_pin : "{prefix}_clk";',
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
            return block

        lines.extend(constraint_block(f"{prefix}_ce_in", "input"))
        lines.extend(constraint_block(f"{prefix}_we_in", "input"))
        lines.extend(constraint_block(f"{prefix}_addr_in", "input", bus_type=f"{name}_ADDR"))
        lines.extend(constraint_block(f"{prefix}_wd_in", "input", bus_type=f"{name}_DATA",
                                      extra=f'            memory_write() {{ address : {prefix}_addr_in; clocked_on : "{prefix}_clk"; }}'))

        lines.extend([
            f"        bus({prefix}_rd_out) {{",
            f"            bus_type : {name}_DATA;",
            "            direction : output;",
            "            max_capacitance : 0.500;",
            f"            memory_read() {{ address : {prefix}_addr_in; }}",
            "            timing() {",
            f'                related_pin : "{prefix}_clk";',
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
        ])

    add_port_pins("rw0")
    add_port_pins("rw1")

    lines.extend([
        "    }",
        "}",
    ])

    path = os.path.join(outdir, "lib", f"{name}.lib")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <output_sram_dir>")
        sys.exit(1)

    outdir = sys.argv[1]
    os.makedirs(os.path.join(outdir, "lef"), exist_ok=True)
    os.makedirs(os.path.join(outdir, "lib"), exist_ok=True)

    print(f"Generating nangate45 FakeRAM files for {len(CNN_CONFIGS)} CNN memory configs:")
    for cnn_name, width, depth in CNN_CONFIGS:
        bits = width * depth
        print(f"  {cnn_name} ({bits} bits)")
        w, h = gen_lef(cnn_name, width, depth, outdir)
        gen_lib(cnn_name, width, depth, outdir, w, h)


if __name__ == "__main__":
    main()
