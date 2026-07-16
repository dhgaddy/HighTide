# macros.tcl for cnn on gt2n
#
# Explicit placement bypasses RTLMP.  In v7 (RTLMP), the two l8192 SRAMs
# landed at (1085, 94) um -- 1077 um from the CLK port at (12, 0) -- while
# the l32768 row was only 393-803 um away.  CTS averaged 3197 um of clock
# wire per SRAM sink vs 517 um for registers, producing a 1648 ps hold
# violation that held at -1607 ps even after 3000 GRT hold-repair iterations.
# This layout moves the l8192 pair to the center-x strip (~340 um from CLK)
# and groups all SRAM types in the lower-left 900x700 um of the 1400x1400 die,
# giving CTS a much more balanced tree.
#
# Die: 0..1400 x 0..1400 um
# Core: 6..1394 x 6..1394 um (1388x1388 um)
# Macros occupy lower-left ~900x700 um; stdcells fill the remaining area.
#
# Large  fakeram_w16_l32768: 193.537 x 331.776 um  -- 4 insts (2 pairs)
# Medium fakeram_w16_l8192:   96.769 x 165.888 um  -- 2 insts (1 pair)
# Wide   fakeram_w64_l256:    48.385 x  41.472 um  -- 1 inst
# Small  fakeram_w16_l512:    24.193 x  41.472 um  -- 58 insts (29 pairs)
#
# All SRAM types have pins distributed on all four faces.
# Clearances on every face:
#   - All macros >= 3 um from core boundary.
#   - Large SRAMs >= 5 um from core left/right walls.
#   - Within-pair gap (between _0 and _1 banks): ~3 um total, ~2 um after
#     0.5 um blockage halos. Hold buffers initialised inside SRAM footprints
#     need ~12 um to reach free rows -- within DPL's default ~24 um reach.
#   - Large-to-small and small-to-large gaps: ~5 um total, ~4 um after halos.
#
# Layout:
#   Left column  (x=11.004):  large id0 pair stacked vertically
#   Right column (x=693.192): large id1 pair (shifted 24 um right vs v3/v4
#                              to open 5 um gaps around the small SRAM grid)
#   Center strip: small 9/row x 4-row grid, wide SRAM, medium pair above
#
# Key margin/gap summary:
#   left-large left  to core left:   11.004 - 6.0  = 5.004 um
#   right-large right to core right: 894 - 886.729 = 7.271 um
#   bottom row to core bottom:       9.024 - 6.0   = 3.024 um
#   left-large right to small grid:  5.015 um  (~4.0 um after blockage)
#   small grid right to right-large: 4.997 um  (~4.0 um after blockage)
#   within-pair gap (_0 to _1):      3.005 um  (~2.0 um after blockage)
#   inter-row gap (small SRAMs):     2.016 um  (~1.0 um after blockage)
#   small row3 top to wide bottom:   2.016 um
#   wide top to medium bottom:       2.016 um

# ── Large SRAMs ─────────────────────────────────────────────────────────────
place_macro -macro_name inst_ram_w16_l32768_id0_0/u_ram_w16_l32768_id0_0_mem \
    -location {11.004 9.024}   -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l32768_id0_1/u_ram_w16_l32768_id0_1_mem \
    -location {11.004 342.816} -orientation R0 -exact

place_macro -macro_name inst_ram_w16_l32768_id1_0/u_ram_w16_l32768_id1_0_mem \
    -location {693.192 9.024}   -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l32768_id1_1/u_ram_w16_l32768_id1_1_mem \
    -location {693.192 342.816} -orientation R0 -exact

# ── Medium SRAMs ─────────────────────────────────────────────────────────────
place_macro -macro_name inst_ram_w16_l8192_id0_0/u_ram_w16_l8192_id0_0_mem \
    -location {325.476 226.464} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l8192_id0_1/u_ram_w16_l8192_id0_1_mem \
    -location {424.260 226.464} -orientation R0 -exact

# ── Wide SRAM ────────────────────────────────────────────────────────────────
place_macro -macro_name inst_ram_w64_l256_id0/u_ram_w64_l256_id0_mem \
    -location {325.476 182.976} -orientation R0 -exact

# ── Small SRAMs ──────────────────────────────────────────────────────────────
# 29 logical pairs (id0..id28), each with _0 and _1 banks placed side-by-side.
# Grid: 9 pairs/row x 4 rows (row 3 partial: id27, id28 only).
# Column pitch: 53.406 um  (pair width 51.391 + between-group gap 2.015)
# Within pair:  _1 offset +27.198 um from _0  (3.005 um gap between banks)
# Row pitch:    43.488 um  (height 41.472 + gap 2.016)
# Row y:        9.024 / 52.512 / 96.000 / 139.488  (3.024 um from core bottom)
# Col x (_0):  209.556 / 262.962 / 316.368 / 369.774 / 423.180 /
#              476.586 / 529.992 / 583.398 / 636.804

# row 0  y=9.024
place_macro -macro_name inst_ram_w16_l512_id0_0/u_ram_w16_l512_id0_0_mem   -location {209.556  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id0_1/u_ram_w16_l512_id0_1_mem   -location {236.754  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id1_0/u_ram_w16_l512_id1_0_mem   -location {262.962  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id1_1/u_ram_w16_l512_id1_1_mem   -location {290.160  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id2_0/u_ram_w16_l512_id2_0_mem   -location {316.368  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id2_1/u_ram_w16_l512_id2_1_mem   -location {343.566  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id3_0/u_ram_w16_l512_id3_0_mem   -location {369.774  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id3_1/u_ram_w16_l512_id3_1_mem   -location {396.972  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id4_0/u_ram_w16_l512_id4_0_mem   -location {423.180  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id4_1/u_ram_w16_l512_id4_1_mem   -location {450.378  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id5_0/u_ram_w16_l512_id5_0_mem   -location {476.586  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id5_1/u_ram_w16_l512_id5_1_mem   -location {503.784  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id6_0/u_ram_w16_l512_id6_0_mem   -location {529.992  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id6_1/u_ram_w16_l512_id6_1_mem   -location {557.190  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id7_0/u_ram_w16_l512_id7_0_mem   -location {583.398  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id7_1/u_ram_w16_l512_id7_1_mem   -location {610.596  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id8_0/u_ram_w16_l512_id8_0_mem   -location {636.804  9.024} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id8_1/u_ram_w16_l512_id8_1_mem   -location {664.002  9.024} -orientation R0 -exact

# row 1  y=52.512
place_macro -macro_name inst_ram_w16_l512_id9_0/u_ram_w16_l512_id9_0_mem   -location {209.556 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id9_1/u_ram_w16_l512_id9_1_mem   -location {236.754 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id10_0/u_ram_w16_l512_id10_0_mem -location {262.962 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id10_1/u_ram_w16_l512_id10_1_mem -location {290.160 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id11_0/u_ram_w16_l512_id11_0_mem -location {316.368 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id11_1/u_ram_w16_l512_id11_1_mem -location {343.566 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id12_0/u_ram_w16_l512_id12_0_mem -location {369.774 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id12_1/u_ram_w16_l512_id12_1_mem -location {396.972 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id13_0/u_ram_w16_l512_id13_0_mem -location {423.180 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id13_1/u_ram_w16_l512_id13_1_mem -location {450.378 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id14_0/u_ram_w16_l512_id14_0_mem -location {476.586 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id14_1/u_ram_w16_l512_id14_1_mem -location {503.784 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id15_0/u_ram_w16_l512_id15_0_mem -location {529.992 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id15_1/u_ram_w16_l512_id15_1_mem -location {557.190 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id16_0/u_ram_w16_l512_id16_0_mem -location {583.398 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id16_1/u_ram_w16_l512_id16_1_mem -location {610.596 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id17_0/u_ram_w16_l512_id17_0_mem -location {636.804 52.512} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id17_1/u_ram_w16_l512_id17_1_mem -location {664.002 52.512} -orientation R0 -exact

# row 2  y=96.000
place_macro -macro_name inst_ram_w16_l512_id18_0/u_ram_w16_l512_id18_0_mem -location {209.556 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id18_1/u_ram_w16_l512_id18_1_mem -location {236.754 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id19_0/u_ram_w16_l512_id19_0_mem -location {262.962 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id19_1/u_ram_w16_l512_id19_1_mem -location {290.160 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id20_0/u_ram_w16_l512_id20_0_mem -location {316.368 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id20_1/u_ram_w16_l512_id20_1_mem -location {343.566 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id21_0/u_ram_w16_l512_id21_0_mem -location {369.774 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id21_1/u_ram_w16_l512_id21_1_mem -location {396.972 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id22_0/u_ram_w16_l512_id22_0_mem -location {423.180 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id22_1/u_ram_w16_l512_id22_1_mem -location {450.378 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id23_0/u_ram_w16_l512_id23_0_mem -location {476.586 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id23_1/u_ram_w16_l512_id23_1_mem -location {503.784 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id24_0/u_ram_w16_l512_id24_0_mem -location {529.992 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id24_1/u_ram_w16_l512_id24_1_mem -location {557.190 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id25_0/u_ram_w16_l512_id25_0_mem -location {583.398 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id25_1/u_ram_w16_l512_id25_1_mem -location {610.596 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id26_0/u_ram_w16_l512_id26_0_mem -location {636.804 96.000} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id26_1/u_ram_w16_l512_id26_1_mem -location {664.002 96.000} -orientation R0 -exact

# row 3  y=139.488  (partial: id27, id28 only)
place_macro -macro_name inst_ram_w16_l512_id27_0/u_ram_w16_l512_id27_0_mem -location {209.556 139.488} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id27_1/u_ram_w16_l512_id27_1_mem -location {236.754 139.488} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id28_0/u_ram_w16_l512_id28_0_mem -location {262.962 139.488} -orientation R0 -exact
place_macro -macro_name inst_ram_w16_l512_id28_1/u_ram_w16_l512_id28_1_mem -location {290.160 139.488} -orientation R0 -exact
