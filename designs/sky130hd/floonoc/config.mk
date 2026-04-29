export DESIGN_NICKNAME ?= floonoc
export DESIGN_NAME = floonoc_mesh_top
export PLATFORM    = sky130hd

-include $(BENCH_DESIGN_HOME)/src/$(DESIGN_NICKNAME)/verilog.mk

export SDC_FILE      = $(BENCH_DESIGN_HOME)/$(PLATFORM)/floonoc/constraint.sdc

# FOOTPRINT_TCL invokes io.tcl during floorplan and makes ORFS skip
# the default place_pins annealer (see flow/scripts/io_placement.tcl).
export FOOTPRINT_TCL = $(BENCH_DESIGN_HOME)/$(PLATFORM)/floonoc/io.tcl

# Skip SVA assertions (guarded by ifndef VERILATOR in PULP sources)
export VERILOG_DEFINES = -D VERILATOR

# Die sized for ~24% cell utilization with explicit IO placement. With
# met2 pitch 0.46um, 1599 pins/edge need ~1471um per edge minimum
# (2 tracks/pin). 1800x1800 has 22% headroom on the IO requirement and
# leaves ~24% cell utilization (cell area ~762k um^2).
export DIE_AREA  = 0 0 1800 1800
export CORE_AREA = 5 5 1795 1795

export TNS_END_PERCENT         = 100
