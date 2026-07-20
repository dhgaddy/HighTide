# Platform default (platforms/gt2n/setRC.tcl) models clock wire RC at M5
# (166.95 ohm/um, top of the local tier). Re-model at M4 to match
# MIN_CLK_ROUTING_LAYER=M4 (chosen after testing M6/M10/M4/M2 as the
# clock floor — see designs/src/NVDLA/DECISIONS.md).
set_wire_rc -clock -layer M4
