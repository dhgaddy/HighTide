current_design litepcie_core

# See designs/asap7/litepci/constraint.sdc for the SDC story.  Single user
# clock created on `pcie_us/user_clk` (the actual driver of the
# `sys_clk = pcie_clk = clk` chain inside litepcie_core); the `clk` output
# port is the user clock forwarded off-chip, so model it as a generated
# clock to avoid the spurious WNS from the CTS buffer tree being timed as
# a data path under `set_output_delay`.

set clk_name      sys_clk
# nangate45 (SDC unit = ns).  Real critical path is FakeRAM clk-to-Q + DMA
# datapath; nangate45 (45 nm) is far slower than asap7 (7 nm), so the closing
# period is well above asap7's 3.6 ns.  Probe at 10 ns, then tighten to the
# measured critical path + 10% guardband.
# NOTE: previously `set clk_period 4000` and refclk `-period 10000` — those were
# ps-magnitude values in an ns-unit file (1000x unit error), making STA report
# a meaningless +3197 ns WNS / 0.00 GHz Fmax.
set clk_period    10
set clk_io_pct    0.2

create_clock -name $clk_name -period $clk_period [get_pins pcie_us/user_clk]
create_clock -name pcie_refclk -period 10 [get_ports pcie_clk_p]
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
