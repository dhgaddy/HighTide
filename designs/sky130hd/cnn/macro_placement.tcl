# Hard-coded sky130hd cnn macro placement.
#
# Extracted from the routed ODB (commit 5d40700b k8s build) so the
# vertical die dimension can be shrunk from 7168 -> 7000 um without
# letting RTLMP find a different layout.  All 65 macros pinned at
# their original (lower-left, orient) positions.  Top of the highest
# macro is at y=5265.43, so 7000 still leaves ~1735 um clearance.

place_macro -macro_name inst_ram_w16_l32768_id0_0/u_ram_w16_l32768_id0_0_mem \
            -location {4912.14 803.57} -orientation MX
place_macro -macro_name inst_ram_w16_l32768_id0_1/u_ram_w16_l32768_id0_1_mem \
            -location {4912.14 1949.07} -orientation R0
place_macro -macro_name inst_ram_w16_l32768_id1_0/u_ram_w16_l32768_id1_0_mem \
            -location {4912.14 4239.99} -orientation R0
place_macro -macro_name inst_ram_w16_l32768_id1_1/u_ram_w16_l32768_id1_1_mem \
            -location {4912.14 3094.49} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id0_0/u_ram_w16_l512_id0_0_mem \
            -location {5704.68 432.97} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id0_1/u_ram_w16_l512_id0_1_mem \
            -location {5704.68 63.05} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id10_0/u_ram_w16_l512_id10_0_mem \
            -location {61.38 3765.65} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id10_1/u_ram_w16_l512_id10_1_mem \
            -location {61.38 1173.49} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id11_0/u_ram_w16_l512_id11_0_mem \
            -location {61.38 4135.57} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id11_1/u_ram_w16_l512_id11_1_mem \
            -location {61.38 803.57} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id12_0/u_ram_w16_l512_id12_0_mem \
            -location {437.6 4506.17} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id12_1/u_ram_w16_l512_id12_1_mem \
            -location {437.6 3765.65} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id13_0/u_ram_w16_l512_id13_0_mem \
            -location {61.38 1914.01} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id13_1/u_ram_w16_l512_id13_1_mem \
            -location {61.38 2654.53} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id14_0/u_ram_w16_l512_id14_0_mem \
            -location {437.6 2284.61} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id14_1/u_ram_w16_l512_id14_1_mem \
            -location {437.6 4135.57} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id15_0/u_ram_w16_l512_id15_0_mem \
            -location {61.38 2284.61} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id15_1/u_ram_w16_l512_id15_1_mem \
            -location {437.6 3395.05} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id16_0/u_ram_w16_l512_id16_0_mem \
            -location {437.6 2654.53} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id16_1/u_ram_w16_l512_id16_1_mem \
            -location {437.6 803.57} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id17_0/u_ram_w16_l512_id17_0_mem \
            -location {61.38 3395.05} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id17_1/u_ram_w16_l512_id17_1_mem \
            -location {61.38 3025.13} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id18_0/u_ram_w16_l512_id18_0_mem \
            -location {437.6 3025.13} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id18_1/u_ram_w16_l512_id18_1_mem \
            -location {437.6 1173.49} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id19_0/u_ram_w16_l512_id19_0_mem \
            -location {813.82 2456.35} -orientation MY
place_macro -macro_name inst_ram_w16_l512_id19_1/u_ram_w16_l512_id19_1_mem \
            -location {1190.04 2456.35} -orientation MY
place_macro -macro_name inst_ram_w16_l512_id1_0/u_ram_w16_l512_id1_0_mem \
            -location {437.6 1544.09} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id1_1/u_ram_w16_l512_id1_1_mem \
            -location {437.6 1914.01} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id20_0/u_ram_w16_l512_id20_0_mem \
            -location {61.38 1544.09} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id20_1/u_ram_w16_l512_id20_1_mem \
            -location {61.38 4506.17} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id21_0/u_ram_w16_l512_id21_0_mem \
            -location {3071.14 432.97} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id21_1/u_ram_w16_l512_id21_1_mem \
            -location {5328.46 432.97} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id22_0/u_ram_w16_l512_id22_0_mem \
            -location {3071.14 63.05} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id22_1/u_ram_w16_l512_id22_1_mem \
            -location {4199.8 63.05} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id23_0/u_ram_w16_l512_id23_0_mem \
            -location {813.82 432.97} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id23_1/u_ram_w16_l512_id23_1_mem \
            -location {2318.7 63.05} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id24_0/u_ram_w16_l512_id24_0_mem \
            -location {1190.04 63.05} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id24_1/u_ram_w16_l512_id24_1_mem \
            -location {4576.02 63.05} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id25_0/u_ram_w16_l512_id25_0_mem \
            -location {2694.92 432.97} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id25_1/u_ram_w16_l512_id25_1_mem \
            -location {2318.7 432.97} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id26_0/u_ram_w16_l512_id26_0_mem \
            -location {61.38 432.97} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id26_1/u_ram_w16_l512_id26_1_mem \
            -location {4199.8 432.97} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id27_0/u_ram_w16_l512_id27_0_mem \
            -location {3447.36 63.05} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id27_1/u_ram_w16_l512_id27_1_mem \
            -location {3823.58 432.97} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id28_0/u_ram_w16_l512_id28_0_mem \
            -location {813.82 63.05} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id28_1/u_ram_w16_l512_id28_1_mem \
            -location {437.6 432.97} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id2_0/u_ram_w16_l512_id2_0_mem \
            -location {5328.46 63.05} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id2_1/u_ram_w16_l512_id2_1_mem \
            -location {437.6 63.05} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id3_0/u_ram_w16_l512_id3_0_mem \
            -location {4576.02 432.97} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id3_1/u_ram_w16_l512_id3_1_mem \
            -location {3447.36 432.97} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id4_0/u_ram_w16_l512_id4_0_mem \
            -location {4952.24 63.05} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id4_1/u_ram_w16_l512_id4_1_mem \
            -location {61.38 63.05} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id5_0/u_ram_w16_l512_id5_0_mem \
            -location {1942.48 63.05} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id5_1/u_ram_w16_l512_id5_1_mem \
            -location {1566.26 63.05} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id6_0/u_ram_w16_l512_id6_0_mem \
            -location {4952.24 432.97} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id6_1/u_ram_w16_l512_id6_1_mem \
            -location {3823.58 63.05} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id7_0/u_ram_w16_l512_id7_0_mem \
            -location {2694.92 63.05} -orientation MX
place_macro -macro_name inst_ram_w16_l512_id7_1/u_ram_w16_l512_id7_1_mem \
            -location {1190.04 432.97} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id8_0/u_ram_w16_l512_id8_0_mem \
            -location {1566.26 432.97} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id8_1/u_ram_w16_l512_id8_1_mem \
            -location {1942.48 432.97} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id9_0/u_ram_w16_l512_id9_0_mem \
            -location {813.82 1173.49} -orientation R180
place_macro -macro_name inst_ram_w16_l512_id9_1/u_ram_w16_l512_id9_1_mem \
            -location {813.82 803.57} -orientation R180
place_macro -macro_name inst_ram_w16_l8192_id0_0/u_ram_w16_l8192_id0_0_mem \
            -location {3655.865 1437.33} -orientation MX
place_macro -macro_name inst_ram_w16_l8192_id0_1/u_ram_w16_l8192_id0_1_mem \
            -location {3655.865 803.57} -orientation MX
place_macro -macro_name inst_ram_w64_l256_id0/u_ram_w64_l256_id0_mem \
            -location {813.82 1569.63} -orientation MY
