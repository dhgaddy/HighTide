# Every gt2n fakeram macro's LEF blocks routing on M1-M4, so the clock
# must route on M6+; re-model clock wire RC at M6 to match
# MIN_CLK_ROUTING_LAYER=M6 (platform default models it at M5).
set_wire_rc -clock -layer M6
