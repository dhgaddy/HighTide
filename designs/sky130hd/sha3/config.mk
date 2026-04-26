export DESIGN_NAME = sha3
export PLATFORM    = sky130hd

-include $(BENCH_DESIGN_HOME)/src/$(DESIGN_NAME)/verilog.mk

export SDC_FILE      = $(BENCH_DESIGN_HOME)/$(PLATFORM)/$(DESIGN_NAME)/constraint.sdc

export CORE_UTILIZATION = 25

export PLACE_DENSITY_LB_ADDON = 0.20
