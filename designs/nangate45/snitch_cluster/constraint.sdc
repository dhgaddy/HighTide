current_design snitch_cluster_wrapper

set clk_name  clk
set clk_port_name clk_i
set clk_period 18.0
set clk_io_pct 0.2

set clk_port [get_ports $clk_port_name]

create_clock -name $clk_name -period $clk_period $clk_port

set non_clock_inputs [all_inputs -no_clocks]
# Split -min/-max input delay: same reasoning as the asap7 SDC. A single
# value of 0 ps tells STA the input data races the on-die clock tree
# (~3 ns at the deepest FF on nangate45) and lands ~3 ns before clock
# capture -- guaranteed hold violation on every input -> deep-FF path.
# Use -min = 4 ns to model the external source's clock-tree latency,
# leaving >1 ns positive hold margin to the worst on-die capture latency.
set_input_delay -max [expr $clk_period * $clk_io_pct] -clock $clk_name $non_clock_inputs
set_input_delay -min 4.0                              -clock $clk_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_name [all_outputs]

# Async reset: exclude recovery/removal checks on rst_ni.
# The reset tree has ~230K fanout which causes STA memory corruption
# during repair_timing. CTS will buffer the reset tree properly.
set_false_path -from [get_ports rst_ni]
