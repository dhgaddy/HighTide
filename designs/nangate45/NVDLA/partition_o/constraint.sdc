# ===================================================================
# NVDLA partition_o — nangate45 timing constraints
# Periods scaled from asap7 2000/2500 ps -> nangate45 6.0/7.5 ns (~3x).
# ===================================================================
current_design NV_NVDLA_partition_o

set clk_name nvdla_core_clk
set clk_falcon_name nvdla_falcon_clk
set clk_period 3.62
set clk_falcon_period 7.5
set clk_io_pct 0.2

set clk_port [get_ports $clk_name]
set clk_falcon_port [get_ports $clk_falcon_name]

create_clock -name $clk_name -period $clk_period -waveform [list 0 [expr $clk_period / 2]] $clk_port
set_clock_transition -rise -min 0.1 [get_clocks $clk_name]
set_clock_transition -rise -max 0.1 [get_clocks $clk_name]
set_clock_transition -fall -min 0.1 [get_clocks $clk_name]
set_clock_transition -fall -max 0.1 [get_clocks $clk_name]

create_clock -name $clk_falcon_name -period $clk_falcon_period -waveform [list 0 [expr $clk_falcon_period / 2]] $clk_falcon_port
set_clock_transition -rise -min 0.1 [get_clocks $clk_falcon_name]
set_clock_transition -rise -max 0.1 [get_clocks $clk_falcon_name]
set_clock_transition -fall -min 0.1 [get_clocks $clk_falcon_name]
set_clock_transition -fall -max 0.1 [get_clocks $clk_falcon_name]

set non_clock_inputs [lsearch -inline -all -not -exact [all_inputs] "^($clk_port|$clk_falcon_port)$"]

set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_name [all_outputs]

set_ideal_network [get_ports test_mode]
set_ideal_network [get_ports direct_reset_]
set_ideal_network [get_ports dla_reset_rstn]
set_ideal_network [get_nets nvdla_core_rstn]

set_false_path -from [get_ports direct_reset_]
set_false_path -from [get_ports dla_reset_rstn]
set_false_path -from [get_ports test_mode]
set_false_path -from [get_ports pwrbus_ram_pd*]
set_false_path -from [get_ports tmc2slcg_disable_clock_gating]
set_false_path -from [get_ports global_clk_ovr_on]
set_false_path -from [get_clocks nvdla_core_clk] -to [get_clocks nvdla_falcon_clk]
set_false_path -from [get_clocks nvdla_falcon_clk] -to [get_clocks nvdla_core_clk]
