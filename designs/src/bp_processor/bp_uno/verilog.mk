export PLATFORM_DESIGN_DIR=$(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)

BP_DEV_DIR := $(BENCH_DESIGN_HOME)/src/$(DESIGN_NAME)/dev
BP_DEV_FILES := $(BP_DEV_DIR)/generated/files.txt

export DEV_SRC :=

# Use yosys-slang to read SystemVerilog directly (no sv2v needed).
export SYNTH_HDL_FRONTEND = slang
export VERILOG_DEFINES = -D YOSYS
export SYNTH_BLACKBOXES = bsg_mem_1rw_sync_synth bsg_mem_1rw_sync_mask_write_bit_synth \
    fakeram_512x64_1rw fakeram_64x184_1rw fakeram_512x8_1rw fakeram_64x50_1rw \
    fakeram_32x66_1rw fakeram_32x48_1rw fakeram_8x174_1rw fakeram_128x8_1rw

ifneq ($(wildcard $(DEV_FLAG)),)
$(BP_DEV_FILES): $(BP_DEV_DIR)/setup.sh
	@echo "Generating bp_processor file lists via setup.sh"
	@cd $(BP_DEV_DIR) && bash setup.sh
endif

ifneq ($(wildcard $(BP_DEV_FILES)),)
export VERILOG_FILES = $(addprefix $(BP_DEV_DIR)/,$(shell cat $(BP_DEV_FILES)))
export VERILOG_INCLUDE_DIRS = $(addprefix $(BP_DEV_DIR)/,$(shell cat $(BP_DEV_DIR)/generated/includes.txt))
else
$(warning BP file lists not found. Run 'make dev DESIGN_CONFIG=...' to generate.)
endif
