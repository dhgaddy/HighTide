# Workaround for OpenROAD CTS-0105 false skip.
# https://github.com/The-OpenROAD-Project/OpenROAD/issues/10177
#
# Yosys output port buffers arrive in the ODB with dbSourceType::TIMING,
# causing CTS to mistake them for pre-existing clock tree buffers and
# skip the clock net (CTS-0041 warnings on every single-sink net). On
# bp_quad this leaves all 339k registers on an unbuffered clock and
# the post-CTS repair_timing eventually trips ODB-1200.
#
# bp_quad's 4-core hierarchical synthesis produces TIMING-tagged
# buffers under various names (not just "output*"), so reset every
# TIMING-typed instance to NETLIST. Pre-CTS, no legitimate clock-tree
# buffers exist yet, so this is safe.

set block [[[ord::get_db] getChip] getBlock]
set count 0
foreach inst [$block getInsts] {
    if {[$inst getSourceType] == "TIMING"} {
        $inst setSourceType NETLIST
        incr count
    }
}
puts "PRE_CTS workaround: reset $count TIMING-typed instance(s) to NETLIST"
