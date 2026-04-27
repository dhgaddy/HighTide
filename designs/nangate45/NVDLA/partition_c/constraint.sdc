# ===================================================================
# NVDLA partition_c — nangate45 timing constraints
# Period scaled from asap7 1500 ps -> nangate45 4.5 ns (~3x).
# ===================================================================
current_design NV_NVDLA_partition_c

set clk_name nvdla_core_clk
set clk_period 4.5
set clk_io_pct 0.2

set clk_port [get_ports $clk_name]

create_clock -name $clk_name -period $clk_period -waveform [list 0 [expr $clk_period / 2]] $clk_port

set non_clock_inputs [lsearch -inline -all -not -exact [all_inputs] $clk_port]

set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_name [all_outputs]

set_clock_transition -rise -min 0.1 [get_clocks $clk_name]
set_clock_transition -rise -max 0.1 [get_clocks $clk_name]
set_clock_transition -fall -min 0.1 [get_clocks $clk_name]
set_clock_transition -fall -max 0.1 [get_clocks $clk_name]

set_ideal_network [get_ports {global_clk_ovr_on}]
set_ideal_network [get_ports {test_mode}]
set_ideal_network [get_ports {direct_reset_}]
set_ideal_network [get_ports {dla_reset_rstn}]
set_ideal_network [get_ports {nvdla_core_clk}]
set_ideal_network [get_ports {nvdla_clk_ovr_on}]
set_ideal_network [get_ports {tmc2slcg_disable_clock_gating}]
set_ideal_network [get_ports {pwrbus_ram_pd*}]

set_false_path -to [get_pin */RESETN]
set_false_path -to [get_pin */SETN]

set_max_fanout 128 [current_design]
set_wire_load_mode enclosed
