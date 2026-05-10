# Workaround for OpenROAD CTS-0105 false skip.
# https://github.com/The-OpenROAD-Project/OpenROAD/issues/10177
#
# Yosys hierarchical synthesis output port buffers arrive in the ODB with
# dbSourceType::TIMING, causing CTS to mistake them for pre-existing clock
# tree buffers and skip the clock net (CTS-0041 warnings on every
# single-sink net). Reset those buffers to NETLIST so CTS builds a real
# tree. Mirrors designs/asap7/bp_processor/bp_uno/pre_cts.tcl.

set block [[[ord::get_db] getChip] getBlock]
set count 0
foreach inst [$block getInsts] {
    if {[string match "output*" [$inst getName]] &&
        [$inst getSourceType] == "TIMING"} {
        $inst setSourceType NETLIST
        incr count
    }
}
puts "PRE_CTS workaround: reset $count output buffer(s) from TIMING to NETLIST"
