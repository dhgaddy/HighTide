# Open a stage ODB in OpenROAD GUI with full timing context loaded.
# Invoked by tools/gui/launch_gui.sh, which sets:
#   ODB_FILE         absolute path of the stage ODB
#   SDC_FILE         absolute path of the matching SDC (optional)
#   PLATFORM_DIR     absolute path of the orfs+/flow/platforms/<plat>/
#   LIB_FILES_LIST   ":"-separated absolute paths of Liberty files
#
# Mirrors orfs/scripts/load.tcl::load_design but with all paths
# pre-resolved by the bash launcher (so we don't need SCRIPTS_DIR /
# RESULTS_DIR / DESIGN_NAME / hier_options machinery).

# 1. Liberty (timing models) — must come before read_db.
foreach lib [split $::env(LIB_FILES_LIST) ":"] {
    if { $lib ne "" } {
        read_liberty $lib
    }
}

# 2. Database (cells + nets + placement + routing).
read_db $::env(ODB_FILE)

# 3. SDC (clocks + IO delays + exceptions).
if { [info exists ::env(SDC_FILE)] && [file exists $::env(SDC_FILE)] } {
    read_sdc $::env(SDC_FILE)
}

# 4. RC corner (resistance/capacitance for parasitic estimation).
set rc_tcl "$::env(PLATFORM_DIR)/setRC.tcl"
if { [file exists $rc_tcl] } {
    source $rc_tcl
}

gui::fit
