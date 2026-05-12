# Manual placement of the three ternip fakeram macros for asap7.
#
# Distributed layout — 4096x16 along the bottom, 16x1024 and 1024x16
# sharing the top row with a 52 µm channel between them.  Sized for
# CORE_UTILIZATION=45 (die ~382 µm) with MACRO_PLACE_HALO=20:
#
#     +--------------- 380 ---------------+
#     |                                   |
#     |  [16x1024]        [1024x16]       |   top row
#     |  (128x149)        (128x64)        |
#     |  @(15,220)        @(235,220)      |
#     |                                   |
#     |                                   |   37 µm halo-to-halo channel
#     |  +----- 4096x16 (256x128) ----+   |
#     |  | @(35, 15)                  |   |
#     |  +----------------------------+   |
#     +-----------------------------------+
#
# 16x1024 (importvector) + 1024x16 (exportvector) are both tmatmul-side
# memories, so keeping them adjacent matches the connectivity.  The
# 4096x16 vector register file gets the bottom alone with ~89 µm of
# clear stdcell area to its right.  All R0; macros have signal pins on
# left AND right edges so orientation can't redirect them.

place_macro -macro_name vector_registers.pipelined_mem.gen_sram.sram \
            -location {35 15} -orientation R0

place_macro -macro_name tmatmul.importvector.gen_sram.sram \
            -location {15 220} -orientation R0

place_macro -macro_name tmatmul.exportvector.gen_sram.sram \
            -location {235 220} -orientation R0
