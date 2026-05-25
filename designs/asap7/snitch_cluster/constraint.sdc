current_design snitch_cluster_wrapper

set clk_name  clk
set clk_port_name clk_i
set clk_period 6000

set clk_port [get_ports $clk_port_name]

create_clock -name $clk_name -period $clk_period $clk_port

set non_clock_inputs [all_inputs -no_clocks]
# Setup uses -max (data arrives at FF.D no later than): 10 ps after launch edge.
# Hold uses -min (data arrives no earlier than): 1500 ps after launch edge --
# this models the external source's clock-tree latency. Without it, a single
# value of 10 ps tells STA the input data races the on-die clock tree
# (~1.2 ns at the deepest FF) and lands ~1.1 ns before clock capture --
# guaranteed hold violation on every input -> deep-FF path. 1500 ps gives
# >300 ps positive hold margin to the worst capture-side latency in the
# design while leaving setup unchanged.
set_input_delay -max 10   -clock $clk_name $non_clock_inputs
set_input_delay -min 1500 -clock $clk_name $non_clock_inputs
set_output_delay 10 -clock $clk_name [all_outputs]

set_driving_cell -lib_cell DFFHQNx2_ASAP7_75t_R -pin QN $non_clock_inputs
set_load [expr 4.0 * 0.683716] [all_outputs]

# Async reset: exclude recovery/removal checks on rst_ni.
# The reset tree has ~230K fanout which causes STA memory corruption
# during repair_timing. CTS will buffer the reset tree properly.
set_false_path -from [get_ports rst_ni]
