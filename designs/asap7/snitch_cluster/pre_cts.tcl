# Widen DPL diamond search for CTS-internal legalization. ORFS cts.tcl
# builds its own dpl_args and does not honor DETAIL_PLACEMENT_ARGS, so a
# few CTS-inserted leaf clock buffers can land too far from a legal row
# for the default 500-site search to reach (DPL-0036 on
# clkbuf_leaf_*_clk_i).
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
