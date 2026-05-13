# Hand-placed array layout for the 10 banked SRAMs.
#
# Each functional group is grouped into a 2D array of MY-R0 pairs with
# the signal pin edges facing each other across a dedicated pin
# channel (cnn-style — see designs/asap7/cnn/macro_placement.tcl).
# Vertical seams between paired rows get an ~8 um gap so M4-edge
# obstructions of adjacent macros don't clash and trip Lef58EolKeepOut.
#
# importvector (16 × 1024) is implemented as flip-flops — only 16 entries.
#
# Sized for CORE_UTILIZATION=45 (die ~382 um, core ~380 um) with
# MACRO_PLACE_HALO=4:
#
#     +--------------- 380 ---------------+
#     |                                   |
#     |  [Group B]                        |
#     |  exportvector                     |
#     |  2 × 512×16                       |
#     |  196 × 45                         |
#     |  @(20, 260)                       |
#     |                                   |
#     |  [Group A] vector_registers       |
#     |  8 × 512×16                       |
#     |  196 × 205                        |
#     |  @(20, 20)                        |
#     |                                   |
#     +-----------------------------------+
#
# fakeram7_512x16: 90.558 × 45.360 µm   (vector_registers, exportvector)

#======================================================================
# Group A — vector_registers, 8 × fakeram7_512x16 in 2 × 4 array
#======================================================================
# Pair: MY (left col) + R0 (right col), 15 µm pin channel between them.
#   col_left  x: [20.0, 110.558]    (MY, pins on physical right facing channel)
#   channel   x: [110.558, 125.558] (15 µm wide pin channel)
#   col_right x: [125.558, 216.116] (R0, pins on physical left facing channel)
# Rows stacked vertically with 8 µm seams.
#   row 0 y: [20.000,  65.360]
#   row 1 y: [73.360, 118.720]
#   row 2 y: [126.720, 172.080]
#   row 3 y: [180.080, 225.440]

# row 0
place_macro -macro_name {vector_registers.pipelined_mem.gen_sram.gen_bank\[0\].sram} \
            -location {20.0 20.0} -orientation MY
place_macro -macro_name {vector_registers.pipelined_mem.gen_sram.gen_bank\[1\].sram} \
            -location {125.558 20.0} -orientation R0
# row 1
place_macro -macro_name {vector_registers.pipelined_mem.gen_sram.gen_bank\[2\].sram} \
            -location {20.0 73.36} -orientation MY
place_macro -macro_name {vector_registers.pipelined_mem.gen_sram.gen_bank\[3\].sram} \
            -location {125.558 73.36} -orientation R0
# row 2
place_macro -macro_name {vector_registers.pipelined_mem.gen_sram.gen_bank\[4\].sram} \
            -location {20.0 126.72} -orientation MY
place_macro -macro_name {vector_registers.pipelined_mem.gen_sram.gen_bank\[5\].sram} \
            -location {125.558 126.72} -orientation R0
# row 3
place_macro -macro_name {vector_registers.pipelined_mem.gen_sram.gen_bank\[6\].sram} \
            -location {20.0 180.08} -orientation MY
place_macro -macro_name {vector_registers.pipelined_mem.gen_sram.gen_bank\[7\].sram} \
            -location {125.558 180.08} -orientation R0

#======================================================================
# Group B — exportvector, 2 × fakeram7_512x16 (1 pair)
#======================================================================
# Same pair geometry as Group A; placed above Group A with a 35 µm
# stdcell channel between Group A top (225.44) and Group B bottom (260).
place_macro -macro_name {tmatmul.exportvector.gen_sram.gen_bank\[0\].sram} \
            -location {20.0 260.0} -orientation MY
place_macro -macro_name {tmatmul.exportvector.gen_sram.gen_bank\[1\].sram} \
            -location {125.558 260.0} -orientation R0

