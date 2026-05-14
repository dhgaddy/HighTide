current_design litepcie_core

# See designs/asap7/litepci/constraint.sdc for the SDC story.  Single user
# clock on pcie_us/user_clk; `clk` is an output port (a fanout, not the source).
# Earlier draft's create_clock on [get_ports clk] silently produced no R-to-R
# paths.

set clk_name      sys_clk
# 2 ns / 500 MHz — period_min measured at 1.6 ns from the first real-timing
# build, so 2 ns gives ~25% headroom over Fmax for clean closure.
set clk_period    2000
set clk_io_pct    0.2

create_clock -name $clk_name -period $clk_period [get_pins pcie_us/user_clk]
create_clock -name pcie_refclk -period 10000 [get_ports pcie_clk_p]
set_clock_groups -asynchronous \
    -group [get_clocks $clk_name] \
    -group [get_clocks pcie_refclk]

set non_clock_inputs [lsearch -inline -all -not \
    [lsearch -inline -all -not [all_inputs] pcie_clk_p] pcie_clk_n]
set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_name [all_outputs]
