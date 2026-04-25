export DESIGN_NAME = CoreMiniAxi
export PLATFORM    = nangate45
export DESIGN_NICKNAME = coralnpu
export DESIGN_RESULTS_NAME = coralnpu

-include $(BENCH_DESIGN_HOME)/src/coralnpu/verilog.mk

export SYNTH_HIERARCHICAL = 1

export SDC_FILE      = $(BENCH_DESIGN_HOME)/$(PLATFORM)/coralnpu/constraint.sdc

export CORE_UTILIZATION = 40
export PLACE_DENSITY_LB_ADDON = 0.20

export MACRO_PLACE_HALO    = 40 40

export TNS_END_PERCENT     = 100
