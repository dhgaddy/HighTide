export DESIGN_NICKNAME ?= floonoc
export DESIGN_NAME = floonoc_mesh_top
export PLATFORM    = asap7

-include $(BENCH_DESIGN_HOME)/src/$(DESIGN_NICKNAME)/verilog.mk

export SDC_FILE      = $(BENCH_DESIGN_HOME)/$(PLATFORM)/floonoc/constraint.sdc

# FOOTPRINT_TCL invokes io.tcl during floorplan and makes ORFS skip
# the default place_pins annealer (see flow/scripts/io_placement.tcl).
export FOOTPRINT_TCL = $(BENCH_DESIGN_HOME)/$(PLATFORM)/floonoc/io.tcl

# Skip SVA assertions (guarded by ifndef VERILATOR in PULP sources)
export VERILOG_DEFINES = -D VERILATOR

# Die sized for ~28% cell utilization (cell area 17.4k um^2):
#   IO pin pitch on M5 (0.048um) lets 1599 pins fit on a ~77um edge,
#   so 250um per edge has 3.25 tracks per pin — plenty for routing.
#   No PLACE_DENSITY: let cells spread toward their perimeter pins.
export DIE_AREA  = 0 0 250 250
export CORE_AREA = 2 2 248 248
