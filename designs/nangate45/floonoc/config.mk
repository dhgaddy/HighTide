export DESIGN_NICKNAME ?= floonoc
export DESIGN_NAME = floonoc_mesh_top
export PLATFORM    = nangate45

-include $(BENCH_DESIGN_HOME)/src/$(DESIGN_NICKNAME)/verilog.mk

export SDC_FILE      = $(BENCH_DESIGN_HOME)/$(PLATFORM)/floonoc/constraint.sdc

# FOOTPRINT_TCL invokes io.tcl during floorplan and makes ORFS skip
# the default place_pins annealer (see flow/scripts/io_placement.tcl).
export FOOTPRINT_TCL = $(BENCH_DESIGN_HOME)/$(PLATFORM)/floonoc/io.tcl

# Skip SVA assertions (guarded by ifndef VERILATOR in PULP sources)
export VERILOG_DEFINES = -D VERILATOR

# Die sized for ~17% cell utilization with explicit IO placement. With
# metal5 pitch 0.28um, 1599 pins/edge land on 2 tracks each at 900um per
# edge (1599 × 0.28 × 2 = 895um), so 900x900 is at the explicit-placement
# minimum. Cell area ~140k um^2 fits comfortably.
export DIE_AREA  = 0 0 900 900
export CORE_AREA = 5 5 895 895

export TNS_END_PERCENT         = 100
