# Manual placement of the four fakeram_w16_l32768 macros for asap7 cnn.
#
# RTLMP's default behaviour packs them into a 2x2 block, leaving most
# of the bottom half of the die unused. Pinning them in a 4x1 row
# along the top edge frees the lower ~280 µm of die height for the
# remaining 62 small fakerams + 2 medium + 1 odd, plus all standard
# cells. The smaller blocks are still placed by the floorplanner.
#
# Layout (die ≈471x471 µm, each macro 106x188):
#   x positions: 10, 125, 240, 355   (4 macros, ~9 µm spacing)
#   y position:  282                 (top edge ≈ 470)
#   orientation: R0

place_macro -macro_name inst_ram_w16_l32768_id0_0/u_ram_w16_l32768_id0_0_mem \
            -location {10 282} -orientation R0

place_macro -macro_name inst_ram_w16_l32768_id0_1/u_ram_w16_l32768_id0_1_mem \
            -location {125 282} -orientation R0

place_macro -macro_name inst_ram_w16_l32768_id1_0/u_ram_w16_l32768_id1_0_mem \
            -location {240 282} -orientation R0

place_macro -macro_name inst_ram_w16_l32768_id1_1/u_ram_w16_l32768_id1_1_mem \
            -location {355 282} -orientation R0
