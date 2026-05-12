current_design litepcie_core

# nangate45 — 4× slower than asap7, so widen the clock to keep the design buildable.
set clk_name      sys_clk
set clk_port_name clk
set clk_period    4000
set clk_io_pct    0.2

set clk_port [get_ports $clk_port_name]
create_clock -name $clk_name -period $clk_period $clk_port

create_clock -name pcie_refclk -period 10000 [get_ports pcie_clk_p]
set_clock_groups -asynchronous \
    -group [get_clocks $clk_name] \
    -group [get_clocks pcie_refclk]

set non_clock_inputs [lsearch -inline -all -not [lsearch -inline -all -not \
    [lsearch -inline -all -not [all_inputs] $clk_port] pcie_clk_p] pcie_clk_n]

set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_name [all_outputs]
