current_design litepcie_core

# litepcie_core has three clocks on the top boundary:
#   clk           — sys_clk (AXI-Lite MMAP / DMA, target 125 MHz on KCU105)
#   pcie_clk_p/n  — PCIe diff refclk (100 MHz from the link partner)
# Reset is async (pcie_rst_n), so no clock needed on it.
#
# All non-clock IOs are constrained off `sys_clk` since that's the user-clock
# domain the DMA/MMAP/MSI ports live in.  The PHY-side AXI-stream signals
# (m_axis_*, s_axis_*) are internal to the netlist (sunk into pcie_us
# blackbox), so they don't appear on the boundary.

set clk_name      sys_clk
set clk_port_name clk
set clk_period    700
set clk_io_pct    0.2

set clk_port [get_ports $clk_port_name]
create_clock -name $clk_name -period $clk_period $clk_port

# Treat the PCIe diff refclk as a separate, asynchronous clock domain.  In the
# ASIC build pcie_clk_p just feeds the IBUFDS_GTE3 stub (passthrough), so
# we model it as 100 MHz (10 ns) for completeness; nothing critical lives
# between it and sys_clk.
create_clock -name pcie_refclk -period 10000 [get_ports pcie_clk_p]
set_clock_groups -asynchronous \
    -group [get_clocks $clk_name] \
    -group [get_clocks pcie_refclk]

set non_clock_inputs [lsearch -inline -all -not [lsearch -inline -all -not \
    [lsearch -inline -all -not [all_inputs] $clk_port] pcie_clk_p] pcie_clk_n]

set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_name [all_outputs]
