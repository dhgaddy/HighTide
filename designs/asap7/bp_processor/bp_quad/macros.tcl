# Manual macro placement generator (workaround for OpenROAD #9985 / MPL-0040:
# rtl_macro_placer annealing failure on bp_quad's pipe_fma cluster).
#
# Sourced by ORFS at the floorplan_macro stage. Reads the live design DB,
# packs all fakeram_* instances into vertical column groups along the left
# edge of the die at status FIRM. rtl_macro_placer then runs and skips the
# already-placed macros.

set block [ord::get_db_block]
set tech  [ord::get_db_tech]
set dbu   [$tech getDbUnitsPerMicron]
set die   [$block getDieArea]

set die_xl [expr {[$die xMin] / double($dbu)}]
set die_yl [expr {[$die yMin] / double($dbu)}]
set die_xh [expr {[$die xMax] / double($dbu)}]
set die_yh [expr {[$die yMax] / double($dbu)}]

set margin  30.0
set col_gap 10.0
set row_gap  4.0

# Group fakeram_* instances by master name so same-size macros share columns.
set by_master [dict create]
foreach inst [$block getInsts] {
  set master [$inst getMaster]
  set mname  [$master getName]
  if { ![string match "fakeram_*" $mname] } { continue }
  set w [expr {[$master getWidth]  / double($dbu)}]
  set h [expr {[$master getHeight] / double($dbu)}]
  dict lappend by_master $mname [list [$inst getName] $w $h]
}

# Largest masters first so they take the leftmost (less-fragmented) columns.
set masters [lsort -command {apply {{a b} {
  upvar 1 by_master by_master
  set wa [lindex [dict get $by_master $a] 0 1]
  set wb [lindex [dict get $by_master $b] 0 1]
  expr {$wb - $wa}
}}} [dict keys $by_master]]

set cur_x  [expr {$die_xl + $margin}]
set y_top  [expr {$die_yh - $margin}]
set placed 0

foreach mname $masters {
  set instances [dict get $by_master $mname]
  set first     [lindex $instances 0]
  set mw        [lindex $first 1]
  set mh        [lindex $first 2]

  set col_x $cur_x
  set col_y [expr {$die_yl + $margin}]

  foreach entry $instances {
    set iname [lindex $entry 0]

    # Wrap to a new column if this macro would overflow the top.
    if { ($col_y + $mh) > $y_top } {
      set col_x [expr {$col_x + $mw + $col_gap}]
      set col_y [expr {$die_yl + $margin}]
    }

    place_macro -macro_name $iname \
      -location [list $col_x $col_y] -orientation R0
    incr placed

    set col_y [expr {$col_y + $mh + $row_gap}]
  }

  set cur_x [expr {$col_x + $mw + 2 * $col_gap}]
}

puts "macros.tcl: placed $placed fakeram_* instances; right edge of macro region x=[format %.2f $cur_x]"
