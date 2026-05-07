# Manual placement of the four fakeram_w16_l32768 macros for nangate45 cnn.
#
# Same pair-and-flip layout as designs/asap7/cnn/macro_placement.tcl.
# Each macro is 998.26 x 1996.4 um (portrait, after regenerating with
# w = sqrt(area/2) in gen_fakeram_nangate45.py).  All 100 M4 pins live
# on the left edge of each macro, y = 1.4..140 (lower 7% of the
# 1996-um height).  Pairs M1<->M2 and M3<->M4 face each other across
# wide pin-fanout channels; M2/M3 have a small seam between them so
# their M4 obstructions don't clash.
#
# Pin sides after orientation (die x):
#   M1 (MY) -> right edge at  x=1049.26
#   M2 (R0) -> left  edge at  x=1224     <- 175 um channel between M1 and M2
#   M3 (MY) -> right edge at  x=3225.26  (5 um seam M2-M3)
#   M4 (R0) -> left  edge at  x=3400     <- 175 um channel between M3 and M4
#
# Core for nangate45 cnn at util=55: (1.14, 1.40) to (4501.10, 4501.00).

# Pair 1: M1 facing M2 (175 um channel)
place_macro -macro_name inst_ram_w16_l32768_id0_0/u_ram_w16_l32768_id0_0_mem \
            -location {51 2500} -orientation MY

place_macro -macro_name inst_ram_w16_l32768_id0_1/u_ram_w16_l32768_id0_1_mem \
            -location {1224 2500} -orientation R0

# 5 um seam between M2 (right edge x=2222.26) and M3 (left edge x=2227)
place_macro -macro_name inst_ram_w16_l32768_id1_0/u_ram_w16_l32768_id1_0_mem \
            -location {2227 2500} -orientation MY

# Pair 2: M3 facing M4 (175 um channel)
place_macro -macro_name inst_ram_w16_l32768_id1_1/u_ram_w16_l32768_id1_1_mem \
            -location {3400 2500} -orientation R0
