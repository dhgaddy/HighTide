export DESIGN_NAME = CoreMiniAxi
export PLATFORM    = sky130hd
export DESIGN_NICKNAME = coralnpu
export DESIGN_RESULTS_NAME = coralnpu

-include $(BENCH_DESIGN_HOME)/src/coralnpu/verilog.mk

export SYNTH_HIERARCHICAL = 1

export SDC_FILE      = $(BENCH_DESIGN_HOME)/$(PLATFORM)/coralnpu/constraint.sdc

export CORE_UTILIZATION = 20
export PLACE_DENSITY = 0.15

export MACRO_PLACE_HALO    = 30 30

export ROUTING_LAYER_ADJUSTMENT = 0.25

export TNS_END_PERCENT     = 100
