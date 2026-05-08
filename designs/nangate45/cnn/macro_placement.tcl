# Hard-coded nangate45 cnn macro placement (full).
#
# All 65 fakeram macros pinned at the positions RTLMP produced in
# the prior routed build (fmax 492 MHz at die 4502x4277).  Pinning
# the full set rather than just the 4 large macros guarantees the
# same layout across rebuilds and avoids RTLMP rerunning if the
# floorplan shrinks further.
#
# Layout:
#   * 4 large fakeram_w16_l32768 (998x1996) at top y=2275..4271,
#     pair-and-flip facing pairs across two 175 um pin channels.
#   * 58 fakeram_w16_l512 (125x251), 2 fakeram_w16_l8192 (499x998),
#     1 fakeram_w64_l256 (177x395) below y~1312.

place_macro -macro_name inst_ram_w16_l32768_id0_0/u_ram_w16_l32768_id0_0_mem \
            -location {51.0 2275.0} -orientation MY
place_macro -macro_name inst_ram_w16_l32768_id0_1/u_ram_w16_l32768_id0_1_mem \
            -location {1224.0 2275.0} -orientation R0
place_macro -macro_name inst_ram_w16_l32768_id1_0/u_ram_w16_l32768_id1_0_mem \
            -location {2227.0 2275.0} -orientation MY
place_macro -macro_name inst_ram_w16_l32768_id1_1/u_ram_w16_l32768_id1_1_mem \
            -location {3400.0 2275.0} -orientation R0
place_macro -macro_name inst_ram_w16_l512_id0_0/u_ram_w16_l512_id0_0_mem \
            -location {3190.09 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id0_1/u_ram_w16_l512_id0_1_mem \
            -location {3354.92 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id10_0/u_ram_w16_l512_id10_0_mem \
            -location {3860.64 313.46} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id10_1/u_ram_w16_l512_id10_1_mem \
            -location {4190.3 604.1} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id11_0/u_ram_w16_l512_id11_0_mem \
            -location {4025.47 313.46} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id11_1/u_ram_w16_l512_id11_1_mem \
            -location {4025.47 894.6} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id12_0/u_ram_w16_l512_id12_0_mem \
            -location {4025.47 604.1} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id12_1/u_ram_w16_l512_id12_1_mem \
            -location {3695.81 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id13_0/u_ram_w16_l512_id13_0_mem \
            -location {3860.64 894.6} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id13_1/u_ram_w16_l512_id13_1_mem \
            -location {4190.3 313.46} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id14_0/u_ram_w16_l512_id14_0_mem \
            -location {3695.81 894.6} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id14_1/u_ram_w16_l512_id14_1_mem \
            -location {4190.3 894.6} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id15_0/u_ram_w16_l512_id15_0_mem \
            -location {4355.13 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id15_1/u_ram_w16_l512_id15_1_mem \
            -location {4355.13 894.6} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id16_0/u_ram_w16_l512_id16_0_mem \
            -location {4355.13 604.1} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id16_1/u_ram_w16_l512_id16_1_mem \
            -location {3860.64 604.1} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id17_0/u_ram_w16_l512_id17_0_mem \
            -location {4355.13 313.46} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id17_1/u_ram_w16_l512_id17_1_mem \
            -location {4190.3 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id18_0/u_ram_w16_l512_id18_0_mem \
            -location {3860.64 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id18_1/u_ram_w16_l512_id18_1_mem \
            -location {4025.47 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id19_0/u_ram_w16_l512_id19_0_mem \
            -location {3190.09 604.1} -orientation R0
place_macro -macro_name inst_ram_w16_l512_id19_1/u_ram_w16_l512_id19_1_mem \
            -location {3190.09 313.46} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id1_0/u_ram_w16_l512_id1_0_mem \
            -location {3695.81 604.1} -orientation R0
place_macro -macro_name inst_ram_w16_l512_id1_1/u_ram_w16_l512_id1_1_mem \
            -location {3695.81 313.46} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id20_0/u_ram_w16_l512_id20_0_mem \
            -location {3519.75 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id20_1/u_ram_w16_l512_id20_1_mem \
            -location {3519.75 313.46} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id21_0/u_ram_w16_l512_id21_0_mem \
            -location {1175.9 22.82} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id21_1/u_ram_w16_l512_id21_1_mem \
            -location {1340.73 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id22_0/u_ram_w16_l512_id22_0_mem \
            -location {681.41 22.82} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id22_1/u_ram_w16_l512_id22_1_mem \
            -location {186.92 22.82} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id23_0/u_ram_w16_l512_id23_0_mem \
            -location {1670.39 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id23_1/u_ram_w16_l512_id23_1_mem \
            -location {846.24 22.82} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id24_0/u_ram_w16_l512_id24_0_mem \
            -location {516.58 22.82} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id24_1/u_ram_w16_l512_id24_1_mem \
            -location {1505.56 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id25_0/u_ram_w16_l512_id25_0_mem \
            -location {2329.71 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id25_1/u_ram_w16_l512_id25_1_mem \
            -location {2164.88 22.82} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id26_0/u_ram_w16_l512_id26_0_mem \
            -location {1835.22 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id26_1/u_ram_w16_l512_id26_1_mem \
            -location {1011.07 22.82} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id27_0/u_ram_w16_l512_id27_0_mem \
            -location {2000.05 22.82} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id27_1/u_ram_w16_l512_id27_1_mem \
            -location {2494.54 22.82} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id28_0/u_ram_w16_l512_id28_0_mem \
            -location {351.75 22.82} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id28_1/u_ram_w16_l512_id28_1_mem \
            -location {22.09 22.82} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id2_0/u_ram_w16_l512_id2_0_mem \
            -location {186.92 313.46} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id2_1/u_ram_w16_l512_id2_1_mem \
            -location {1011.07 313.46} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id3_0/u_ram_w16_l512_id3_0_mem \
            -location {681.41 313.46} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id3_1/u_ram_w16_l512_id3_1_mem \
            -location {186.92 604.1} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id4_0/u_ram_w16_l512_id4_0_mem \
            -location {846.24 313.46} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id4_1/u_ram_w16_l512_id4_1_mem \
            -location {1175.9 313.46} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id5_0/u_ram_w16_l512_id5_0_mem \
            -location {516.58 604.1} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id5_1/u_ram_w16_l512_id5_1_mem \
            -location {846.24 604.1} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id6_0/u_ram_w16_l512_id6_0_mem \
            -location {1011.07 604.1} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id6_1/u_ram_w16_l512_id6_1_mem \
            -location {681.41 604.1} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id7_0/u_ram_w16_l512_id7_0_mem \
            -location {351.75 604.1} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id7_1/u_ram_w16_l512_id7_1_mem \
            -location {516.58 313.46} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id8_0/u_ram_w16_l512_id8_0_mem \
            -location {1175.9 604.1} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id8_1/u_ram_w16_l512_id8_1_mem \
            -location {351.75 313.46} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id9_0/u_ram_w16_l512_id9_0_mem \
            -location {22.09 604.1} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id9_1/u_ram_w16_l512_id9_1_mem \
            -location {22.09 313.46} -orientation R180
place_macro -macro_name inst_ram_w16_l8192_id0_0/u_ram_w16_l8192_id0_0_mem \
            -location {1369.365 313.46} -orientation MY
place_macro -macro_name inst_ram_w16_l8192_id0_1/u_ram_w16_l8192_id0_1_mem \
            -location {1908.495 313.46} -orientation MY
place_macro -macro_name inst_ram_w64_l256_id0/u_ram_w64_l256_id0_mem \
            -location {2447.625 887.46} -orientation MY
