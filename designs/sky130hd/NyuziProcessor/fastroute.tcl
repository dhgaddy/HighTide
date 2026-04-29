set_global_routing_layer_adjustment met1 0.6
set_global_routing_layer_adjustment met2 0.5
set_global_routing_layer_adjustment met3 0.2
set_global_routing_layer_adjustment met4-$::env(MAX_ROUTING_LAYER) 0.1

set_routing_layers -signal $::env(MIN_ROUTING_LAYER)-$::env(MAX_ROUTING_LAYER)
