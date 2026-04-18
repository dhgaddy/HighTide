# Workaround for OpenROAD CTS-0105 false skip.
# https://github.com/The-OpenROAD-Project/OpenROAD/issues/10177
#
# Yosys hierarchical synthesis output port buffers arrive with
# dbSourceType::TIMING, causing CTS to mistake them for pre-existing
# clock tree buffers and skip the clock net. Reset them to NETLIST
# so CTS builds the tree.

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
