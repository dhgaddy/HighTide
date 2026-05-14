current_design litepcie_core

# litepcie_core has only ONE user-side clock (despite the LiteX-emitted module
# header listing `clk` as an output and naming an internal `sys_clk` wire):
#
#   pcie_clk_p      — PCIe diff refclk input (100 MHz from the link partner)
#   pcie_us/user_clk — the PCIe hard-IP's recovered user clock; LiteX wires
#                      `pcie_clk` to this and then `assign sys_clk = pcie_clk;`,
#                      so every DMA / MMAP / DMA-FIFO flop is on this single
#                      clock domain.  The `clk` *output* port is just a fanout
#                      of pcie_us/user_clk for the consumer-side SoC.
#
# Earlier drafts created sys_clk on `[get_ports clk]` — but `clk` is an
# *output* in this module, so STA accepted the SDC silently and found no
# launch/capture paths on sys_clk.  All the real R-to-R timing landed under
# `pcie_clk` instead.  Single-clock SDC below.

set clk_name      sys_clk
# 3.6 ns / 278 MHz — clears the FakeRAM-mapped design's period_min of 3.52 ns
# (was 2.4 ns with -5 ns TNS).  Real critical path is FakeRAM rw0_addr_in /
# rw0_wd_in fanout through the DMA datapath.
set clk_period    3600
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
