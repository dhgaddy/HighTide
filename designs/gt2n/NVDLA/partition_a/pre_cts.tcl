# Platform default (platforms/gt2n/setRC.tcl) models clock wire RC at M5
# (166.95 ohm/um, top of the local tier). Re-model at M4, the standard
# gt2n clock-routing floor, to match MIN_CLK_ROUTING_LAYER=M4.
set_wire_rc -clock -layer M4
