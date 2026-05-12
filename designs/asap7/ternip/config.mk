export DESIGN_NAME = ternip_core
export PLATFORM    = asap7

export DESIGN_NICKNAME = ternip

-include $(BENCH_DESIGN_HOME)/src/ternip/verilog.mk

export SDC_FILE         = $(BENCH_DESIGN_HOME)/$(PLATFORM)/ternip/constraint.sdc
export CORE_UTILIZATION = 40
export CORE_ASPECT_RATIO = 1.0
export CORE_MARGIN      = 4
export PLACE_DENSITY    = 0.7
export TNS_END_PERCENT  = 100

export SYNTH_HDL_FRONTEND = slang
