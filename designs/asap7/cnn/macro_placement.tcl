# Manual placement of the four fakeram_w16_l32768 macros for asap7 cnn.
#
# Each macro is 106 x 188 um with 100 M4 pins on its left edge,
# y = 5.6..104.4 (lower half).  Layout pairs macros M1<->M2 and
# M3<->M4 with their pin sides facing each other, so two wide pin-
# fanout channels concentrate the routing demand and the route-stage
# repair-buffer pass has room to legalise.
#
# M2-M3 seam needs a small gap (5 um) — when the macros touch flush
# their M4-edge obstructions clash and route reports Lef58EolKeepOut
# / Short violations.
#
# Pin sides after orientation (die x):
#   M1 (MY) -> right edge at x=107.5
#   M2 (R0) -> left  edge at x=127       <- 19.5 um channel between M1 and M2
#   M3 (MY) -> right edge at x=344       (5 um gap M2-M3)
#   M4 (R0) -> left  edge at x=363.5     <- 19.5 um channel between M3 and M4
#
# Margins: ~0.5 left, ~1.3 right (no pins face out there).

# Pair 1: M1 facing M2 (19.5 um channel)
place_macro -macro_name inst_ram_w16_l32768_id0_0/u_ram_w16_l32768_id0_0_mem \
            -location {1.5 282} -orientation MY

place_macro -macro_name inst_ram_w16_l32768_id0_1/u_ram_w16_l32768_id0_1_mem \
            -location {127 282} -orientation R0

# 5 um seam between M2 (right edge x=233) and M3 (left edge x=238)
place_macro -macro_name inst_ram_w16_l32768_id1_0/u_ram_w16_l32768_id1_0_mem \
            -location {238 282} -orientation MY

# Pair 2: M3 facing M4 (19.5 um channel)
place_macro -macro_name inst_ram_w16_l32768_id1_1/u_ram_w16_l32768_id1_1_mem \
            -location {363.5 282} -orientation R0
