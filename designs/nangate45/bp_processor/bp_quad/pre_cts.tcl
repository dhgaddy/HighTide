# Workaround for OpenROAD CTS-0105 false skip.
# https://github.com/The-OpenROAD-Project/OpenROAD/issues/10177
#
# Yosys hierarchical synthesis output port buffers arrive in the ODB with
# dbSourceType::TIMING, causing CTS to mistake them for pre-existing clock
# tree buffers and skip the clock net (CTS-0041 warnings on every
# single-sink net). Reset those buffers to NETLIST so CTS builds a real
# tree. Mirrors designs/asap7/bp_processor/bp_quad/pre_cts.tcl.

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

# Widen DPL diamond search for CTS-internal legalization (DPL-0036). ORFS
# cts.tcl builds its own dpl_args and does not honor DETAIL_PLACEMENT_ARGS,
# so a few CTS-inserted leaf clock buffers can land too far from a legal
# row for the default 500-site search to reach. Same workaround as
# asap7/snitch_cluster (commit 0af20020).
if { ![info exists ::__hightide_dpl_wrapped] } {
    rename detailed_placement __hightide_dpl_orig
    proc detailed_placement {args} {
        if { [lsearch -exact $args "-max_displacement"] == -1 } {
            __hightide_dpl_orig -max_displacement {2000 400} {*}$args
        } else {
            __hightide_dpl_orig {*}$args
        }
    }
    set ::__hightide_dpl_wrapped 1
}
