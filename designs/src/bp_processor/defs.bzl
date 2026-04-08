"""Shared constants for bp_processor designs."""

load("//designs/src/bp_processor:dev/generated/srcs.bzl", "BP_INCLUDE_DIRS_STR")

# Blackboxed modules: bsg_mem_*_synth (replaced by FakeRAM macros at synthesis)
# and all fakeram_* modules (LEF-only, no RTL needed).
_BLACKBOXES = " ".join([
    "bsg_mem_1rw_sync_synth",
    "bsg_mem_1rw_sync_mask_write_bit_synth",
    "fakeram_512x64_1rw",
    "fakeram_64x184_1rw",
    "fakeram_512x8_1rw",
    "fakeram_64x50_1rw",
    "fakeram_32x66_1rw",
    "fakeram_32x48_1rw",
    "fakeram_8x174_1rw",
    "fakeram_128x8_1rw",
])

BP_COMMON_ARGS = {
    "SYNTH_HDL_FRONTEND": "slang",
    "VERILOG_DEFINES": "-D YOSYS",
    "VERILOG_INCLUDE_DIRS": BP_INCLUDE_DIRS_STR,
    "SYNTH_HIERARCHICAL": "1",
    "SYNTH_MINIMUM_KEEP_SIZE": "500",
    "ABC_AREA": "1",
    "SYNTH_MEMORY_MAX_BITS": "65536",
    "TNS_END_PERCENT": "100",
}
