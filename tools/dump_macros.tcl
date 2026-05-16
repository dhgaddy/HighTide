read_db /home/mrg/HighTide/fakeram/bazel-bin/designs/sky130hd/cnn/results/sky130hd/cnn/base/2_floorplan.odb
set blk [ord::get_db_block]
set u [$blk getDbUnitsPerMicron]
set core [$blk getCoreArea]
puts "CORE_UM [expr [$core xMin]/$u.0] [expr [$core yMin]/$u.0] [expr [$core xMax]/$u.0] [expr [$core yMax]/$u.0]"
foreach inst [$blk getInsts] {
  set m [$inst getMaster]
  if { [$m isBlock] } {
    set bb [$inst getBBox]
    set w [expr ([$bb xMax]-[$bb xMin])/$u.0]
    set h [expr ([$bb yMax]-[$bb yMin])/$u.0]
    puts "MACRO [$inst getName] | [$m getName] | [$inst getOrient] | [format %.1f [expr [$bb xMin]/$u.0]] [format %.1f [expr [$bb yMin]/$u.0]] | ${w}x${h} | [$inst getPlacementStatus]"
  }
}
exit
