current_design litepcie_core

# See designs/asap7/litepci/constraint.sdc for the SDC story.  Single user
# clock on `pcie_us/user_clk`; `clk` is the user clock forwarded off-chip
# and modeled as a generated clock to avoid the spurious WNS from
# `set_output_delay` timing the CTS buffer tree as data.

set clk_name      sys_clk
# 20 ns / 50 MHz — sky130hd baseline.  Real critical path is FakeRAM
# clk-to-Q + DMA datapath; SDC target left above the FakeRAM-bounded
# typical worst-case to allow clean closure (analogous to asap7's 3.6 ns).
set clk_period    20000
set clk_io_pct    0.2

create_clock -name $clk_name -period $clk_period [get_pins pcie_us/user_clk]
create_clock -name pcie_refclk -period 10000 [get_ports pcie_clk_p]
set_clock_groups -asynchronous \
    -group [get_clocks $clk_name] \
    -group [get_clocks pcie_refclk]

# Same forwarded-clock-feedthrough fix as asap7 / designs/asap7/litedram.
create_generated_clock -name clk_fwd -source [get_pins pcie_us/user_clk] \
    -divide_by 1 [get_ports clk]

set non_clock_inputs [lsearch -inline -all -not \
    [lsearch -inline -all -not [all_inputs] pcie_clk_p] pcie_clk_n]
set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_name [all_outputs]
