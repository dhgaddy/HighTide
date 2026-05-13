#!/usr/bin/env python3
"""
Generate platform-compatible FakeRAM LEF/LIB files for CORE-ET SRAM memories.

CORE-ET has six custom SRAM macros with bespoke interfaces:
  1. icache_data_ram         512 x 144   1RW
  2. icache_tag_data_array   128 x 27    1W + 2R
  3. icache_lru_state_array  128 x 16    1W + 1R
  4. dcache_128x32_1r1w_lram 128 x 32    1W + 1R
  5. vpu_64x32_3r2w_vpurf     64 x 32    2W + 3R
  6. vpu_tensorc_rf_buffer_array  16 x 32  1W + 1R

Usage:
    python3 gen_fakeram.py nangate45 <output_sram_dir>
    python3 gen_fakeram.py sky130hd  <output_sram_dir>
"""
import math
import os
import sys


# ── platform constants ────────────────────────────────────────────────────────

PLATFORMS = {
    "nangate45": {
        "pin_w":       0.140,
        "pin_pitch":   1.400,
        "snap_w":      0.190,
        "snap_h":      1.400,
        "area_per_bit": 3.8,
        "min_area":    800,
        "pin_layer":   "metal3",
        "obs_layers":  ["metal1", "metal2", "metal3", "metal4"],
        "nom_voltage": 1.1,
        "op_cond":     "tt_1.0_25.0",
    },
    "sky130hd": {
        "pin_w":       0.300,
        "pin_pitch":   2.720,
        "snap_w":      0.460,
        "snap_h":      2.720,
        "area_per_bit": 4.0,
        "min_area":    800,
        "pin_layer":   "met3",
        "obs_layers":  ["li1", "met1", "met2", "met3", "met4"],
        "nom_voltage": 1.8,
        "op_cond":     "tt_1.0_25.0",
    },
}


# ── memory configurations ─────────────────────────────────────────────────────

# Each config is (name, spec_fn) where spec_fn() returns a (pins, depth, width)
# tuple:  pins  = ordered list of (pin_name, direction) tuples (no VSS/VDD)
#         depth = number of words (for area estimate)
#         width = bits per word  (for area estimate)

def _pins_1rw(addr_bits, data_bits):
    """1 read/write port: clk, ce, we, addr[], din[], dout[]."""
    pins = [("clk", "INPUT"), ("ce", "INPUT"), ("we", "INPUT")]
    for i in range(addr_bits):
        pins.append((f"addr[{i}]", "INPUT"))
    for i in range(data_bits):
        pins.append((f"din[{i}]", "INPUT"))
    for i in range(data_bits):
        pins.append((f"dout[{i}]", "OUTPUT"))
    return pins


def _pins_1w2r(addr_bits, data_bits):
    """1 write + 2 read ports."""
    pins = [
        ("clk",         "INPUT"),
        ("wr_enable",   "INPUT"),
        ("rd_enable_a", "INPUT"),
        ("rd_enable_b", "INPUT"),
    ]
    for i in range(addr_bits):
        pins.append((f"wr_addr[{i}]", "INPUT"))
    for i in range(data_bits):
        pins.append((f"wr_data[{i}]", "INPUT"))
    for i in range(addr_bits):
        pins.append((f"rd_addr_a[{i}]", "INPUT"))
    for i in range(addr_bits):
        pins.append((f"rd_addr_b[{i}]", "INPUT"))
    for i in range(data_bits):
        pins.append((f"rd_data_a[{i}]", "OUTPUT"))
    for i in range(data_bits):
        pins.append((f"rd_data_b[{i}]", "OUTPUT"))
    return pins


def _pins_1w1r(addr_bits, data_bits):
    """1 write + 1 read port."""
    pins = [
        ("clk",        "INPUT"),
        ("wr_enable",  "INPUT"),
        ("rd_enable",  "INPUT"),
    ]
    for i in range(addr_bits):
        pins.append((f"wr_addr[{i}]", "INPUT"))
    for i in range(data_bits):
        pins.append((f"wr_data[{i}]", "INPUT"))
    for i in range(addr_bits):
        pins.append((f"rd_addr[{i}]", "INPUT"))
    for i in range(data_bits):
        pins.append((f"rd_data[{i}]", "OUTPUT"))
    return pins


def _pins_2w3r(addr_bits, data_bits):
    """2 write + 3 read ports (vpu_64x32_3r2w_vpurf)."""
    pins = [("clk", "INPUT")]
    for wp in range(2):
        pins.append((f"wr_enable{wp}", "INPUT"))
        for i in range(addr_bits):
            pins.append((f"wr_addr{wp}[{i}]", "INPUT"))
        for i in range(data_bits):
            pins.append((f"wr_data{wp}[{i}]", "INPUT"))
    for rp in range(3):
        pins.append((f"rd_enable{rp}", "INPUT"))
        for i in range(addr_bits):
            pins.append((f"rd_addr{rp}[{i}]", "INPUT"))
        for i in range(data_bits):
            pins.append((f"rd_data{rp}[{i}]", "OUTPUT"))
    return pins


MEMORIES = [
    # (name, depth, width, pins_list)
    (
        "icache_data_ram",
        512, 144,
        _pins_1rw(9, 144),
    ),
    (
        "icache_tag_data_array",
        128, 27,
        _pins_1w2r(7, 27),
    ),
    (
        "icache_lru_state_array",
        128, 16,
        _pins_1w1r(7, 16),
    ),
    (
        "dcache_128x32_1r1w_lram",
        128, 32,
        _pins_1w1r(7, 32),
    ),
    (
        "vpu_64x32_3r2w_vpurf",
        64, 32,
        _pins_2w3r(6, 32),
    ),
    (
        "vpu_tensorc_rf_buffer_array",
        16, 32,
        _pins_1w1r(4, 32),
    ),
]


# ── LEF generator ─────────────────────────────────────────────────────────────

def gen_lef(name, depth, width, signal_pins, outdir, P):
    bits = depth * width
    area = max(bits * P["area_per_bit"], P["min_area"])
    w = math.sqrt(area / 2.0)
    h = area / w
    w = math.ceil(w / P["snap_w"]) * P["snap_w"]
    h = math.ceil(h / P["snap_h"]) * P["snap_h"]

    pin_w     = P["pin_w"]
    pin_pitch = P["pin_pitch"]
    pin_layer = P["pin_layer"]

    # Enough height for all signal pins + VDD + VSS + margin
    min_h = pin_pitch * (len(signal_pins) + 4)
    if h < min_h:
        h = math.ceil(min_h / P["snap_h"]) * P["snap_h"]

    lines = [
        "VERSION 5.7 ;",
        'BUSBITCHARS "[]" ;',
        f"MACRO {name}",
        f"  FOREIGN {name} 0 0 ;",
        "  SYMMETRY X Y R90 ;",
        f"  SIZE {w:.3f} BY {h:.3f} ;",
        "  CLASS BLOCK ;",
    ]

    y = pin_pitch

    def add_pin(pname, direction, use="SIGNAL"):
        nonlocal y
        lines.extend([
            f"  PIN {pname}",
            f"    DIRECTION {direction} ;",
            f"    USE {use} ;",
            "    SHAPE ABUTMENT ;",
            "    PORT",
            f"      LAYER {pin_layer} ;",
            f"      RECT 0.000 {y:.3f} {pin_w:.3f} {y + pin_w:.3f} ;",
            "    END",
            f"  END {pname}",
        ])
        y += pin_pitch

    for pname, direction in signal_pins:
        add_pin(pname, direction)

    # Power rails span the full width on the pin layer
    for pname, direction, use in [("VSS", "INOUT", "GROUND"), ("VDD", "INOUT", "POWER")]:
        lines += [
            f"  PIN {pname}",
            f"    DIRECTION {direction} ;",
            f"    USE {use} ;",
            "    SHAPE ABUTMENT ;",
            "    PORT",
            f"      LAYER {pin_layer} ;",
            f"      RECT 0.000 {y:.3f} {w:.3f} {y + pin_w:.3f} ;",
            "    END",
            f"  END {pname}",
        ]
        y += pin_pitch

    lines.append("  OBS")
    for layer in P["obs_layers"]:
        lines += [
            f"    LAYER {layer} ;",
            f"      RECT 0.000 0.000 {w:.3f} {h:.3f} ;",
        ]
    lines += ["  END", f"END {name}", "END LIBRARY"]

    path = os.path.join(outdir, "lef", f"{name}.lef")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    return w, h


# ── LIB generator ─────────────────────────────────────────────────────────────

def gen_lib(name, depth, width, signal_pins, outdir, P, w_um, h_um):
    area = w_um * h_um
    nom_v = P["nom_voltage"]
    op    = P["op_cond"]

    input_pins  = [p for p, d in signal_pins if d == "INPUT"]
    output_pins = [p for p, d in signal_pins if d == "OUTPUT"]

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
        '    pulling_resistance_unit : "1kohm";',
        '    capacitive_load_unit (1,pf);',
        f"    nom_process : 1.0;",
        f"    nom_temperature : 25.0;",
        f"    nom_voltage : {nom_v};",
        f"    operating_conditions({op}) {{",
        "        process : 1.0;",
        "        temperature : 25.0;",
        f"        voltage : {nom_v};",
        "        tree_type : balanced_tree;",
        "    }",
        f"    default_operating_conditions : {op};",
        f"    lu_table_template({name}_delay) {{",
        '        variable_1 : input_net_transition;',
        '        variable_2 : total_output_net_capacitance;',
        '        index_1 ("0.010, 0.100");',
        '        index_2 ("0.0005, 0.500");',
        "    }",
        f"    lu_table_template({name}_slew) {{",
        '        variable_1 : total_output_net_capacitance;',
        '        index_1 ("0.0005, 0.500");',
        "    }",
        f"    cell({name}) {{",
        f"        area : {area:.3f};",
        '        interface_timing : true;',
        "        pg_pin(VDD) { voltage_name : VDD; pg_type : primary_power; }",
        "        pg_pin(VSS) { voltage_name : VSS; pg_type : primary_ground; }",
    ]

    # Clock pin
    if any(p == "clk" for p, _ in signal_pins):
        lines += [
            "        pin(clk) {",
            "            direction : input;",
            "            capacitance : 0.020;",
            "            clock : true;",
            "        }",
        ]

    # Generic input pins (non-clock)
    for pname in input_pins:
        if pname == "clk":
            continue
        lines += [
            f"        pin({pname}) {{",
            "            direction : input;",
            "            capacitance : 0.005;",
            "            timing() {",
            '                related_pin : "clk";',
            "                timing_type : setup_rising;",
            '                rise_constraint(scalar) { values("0.100"); }',
            '                fall_constraint(scalar) { values("0.100"); }',
            "            }",
            "            timing() {",
            '                related_pin : "clk";',
            "                timing_type : hold_rising;",
            '                rise_constraint(scalar) { values("0.050"); }',
            '                fall_constraint(scalar) { values("0.050"); }',
            "            }",
            "        }",
        ]

    # Output pins
    for pname in output_pins:
        lines += [
            f"        pin({pname}) {{",
            "            direction : output;",
            "            max_capacitance : 0.500;",
            "            timing() {",
            '                related_pin : "clk";',
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
        ]

    lines += ["    }", "}"]

    path = os.path.join(outdir, "lib", f"{name}.lib")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) != 3 or sys.argv[1] not in PLATFORMS:
        print(f"Usage: {sys.argv[0]} {{nangate45|sky130hd}} <output_sram_dir>")
        sys.exit(1)

    platform = sys.argv[1]
    outdir   = sys.argv[2]
    P        = PLATFORMS[platform]

    os.makedirs(os.path.join(outdir, "lef"), exist_ok=True)
    os.makedirs(os.path.join(outdir, "lib"), exist_ok=True)

    print(f"Generating {platform} FakeRAM files for CORE-ET ({len(MEMORIES)} memories):")
    for name, depth, width, pins in MEMORIES:
        bits = depth * width
        print(f"  {name} ({depth}x{width} = {bits} bits)")
        w, h = gen_lef(name, depth, width, pins, outdir, P)
        gen_lib(name, depth, width, pins, outdir, P, w, h)
    print("Done.")


if __name__ == "__main__":
    main()
