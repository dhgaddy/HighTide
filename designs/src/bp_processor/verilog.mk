export PLATFORM_DESIGN_DIR=$(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)

BP_DEV_DIR := $(BENCH_DESIGN_HOME)/src/$(DESIGN_NAME)/dev
BP_SRC_DIR := $(BENCH_DESIGN_HOME)/src/$(DESIGN_NAME)

# Select RTL variant based on DESIGN_NICKNAME.
ifeq ($(DESIGN_NICKNAME),bp_quad)
BP_DEV_RTL := $(BP_DEV_DIR)/generated/bp_processor_quad.v
BP_RELEASE_RTL := $(BP_SRC_DIR)/bp_processor_quad.v
else
BP_DEV_RTL := $(BP_DEV_DIR)/generated/bp_processor.v
BP_RELEASE_RTL := $(BP_SRC_DIR)/bp_processor.v
endif

# DEV_SRC intentionally left empty — regenerating BP RTL via sv2v is expensive.
export DEV_SRC :=

ifneq ($(wildcard $(DEV_FLAG)),)
$(BP_DEV_RTL): $(BP_DEV_DIR)/setup.sh
	@echo "Generating Black-Parrot RTL via setup.sh"
	@cd $(BP_DEV_DIR) && bash setup.sh

export VERILOG_FILES = $(BP_DEV_RTL) \
                       $(PLATFORM_DESIGN_DIR)/macros.v
else
ifeq ($(wildcard $(BP_RELEASE_RTL)),)
$(warning $(BP_RELEASE_RTL) is missing; using dev RTL. Run 'make update-rtl' to regenerate and promote.)
export VERILOG_FILES = $(BP_DEV_RTL) \
                       $(PLATFORM_DESIGN_DIR)/macros.v
else
export VERILOG_FILES = $(BP_RELEASE_RTL) \
                       $(PLATFORM_DESIGN_DIR)/macros.v
endif
endif
