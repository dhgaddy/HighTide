export DESIGN_NICKNAME ?= bp_uno
export DESIGN_NAME = bp_processor
export PLATFORM    = sky130hd

-include $(BENCH_DESIGN_HOME)/src/$(DESIGN_NAME)/$(DESIGN_NICKNAME)/verilog.mk


export SYNTH_HIERARCHICAL = 1
export SYNTH_MINIMUM_KEEP_SIZE = 500
export ABC_AREA = 1

export SYNTH_MEMORY_MAX_BITS = 65536

export ADDITIONAL_LEFS = $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lef/fakeram_8x174_1rw.lef \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lef/fakeram_32x48_1rw.lef \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lef/fakeram_32x66_1rw.lef \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lef/fakeram_64x50_1rw.lef \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lef/fakeram_64x184_1rw.lef \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lef/fakeram_128x8_1rw.lef \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lef/fakeram_512x8_1rw.lef \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lef/fakeram_512x64_1rw.lef

export ADDITIONAL_LIBS = $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lib/fakeram_8x174_1rw.lib \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lib/fakeram_32x48_1rw.lib \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lib/fakeram_32x66_1rw.lib \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lib/fakeram_64x50_1rw.lib \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lib/fakeram_64x184_1rw.lib \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lib/fakeram_128x8_1rw.lib \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lib/fakeram_512x8_1rw.lib \
                         $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/sram/lib/fakeram_512x64_1rw.lib

export SDC_FILE      = $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/bp_uno/constraint.sdc

export CORE_UTILIZATION = 25

export PLACE_DENSITY_LB_ADDON = 0.20

export MACRO_PLACE_HALO    = 60 60

export TNS_END_PERCENT     = 100
