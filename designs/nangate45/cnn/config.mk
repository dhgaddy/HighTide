export DESIGN_NICKNAME = cnn
export DESIGN_NAME = cnn
export PLATFORM    = nangate45

-include $(BENCH_DESIGN_HOME)/src/$(DESIGN_NAME)/verilog.mk

export SYNTH_HIERARCHICAL = 1

export ADDITIONAL_LEFS = $(wildcard $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lef/fakeram_*.lef)
export ADDITIONAL_LIBS = $(wildcard $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lib/fakeram_*.lib)

export SDC_FILE      = $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/constraint.sdc

export CORE_UTILIZATION = 30

export PLACE_DENSITY_LB_ADDON = 0.10

export MACRO_PLACE_HALO    = 40 40
export MACRO_BLOCKAGE_HALO = 0.5
