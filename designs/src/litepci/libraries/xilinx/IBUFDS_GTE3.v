///////////////////////////////////////////////////////////////////////////////
// Xilinx IBUFDS_GTE3 - Differential clock buffer for GTH/GTY transceivers.
//
// litepcie's USPCIEPHY (UltraScale+) instantiates exactly one IBUFDS_GTE3 to
// take the PCIe diff reference clock into the GT block.  In an ASIC flow we
// don't have GT transceivers — this synthesizable stub passes the (already
// single-ended at the chip pad) clock through to both O and ODIV2.
///////////////////////////////////////////////////////////////////////////////

module IBUFDS_GTE3 #(
    parameter [0:0] REFCLK_EN_TX_PATH    = 1'b0,
    parameter [3:0] REFCLK_HROW_CK_SEL   = 4'b00,
    parameter [1:0] REFCLK_ICNTL_RX      = 2'b00
)(
    input  I,        // Diff clock + pad
    input  IB,       // Diff clock - pad (unused in stub)
    input  CEB,      // Active-low clock enable (unused in stub)
    output O,        // Direct refclk output to GT
    output ODIV2     // Refclk / 2 output to fabric
);

    `ifdef USE_ASAP7_CELLS
        BUFx2_ASAP7_75t_R  clk_buf_o     (.A(I), .Y(O));
        BUFx2_ASAP7_75t_R  clk_buf_odiv2 (.A(I), .Y(ODIV2));
    `elsif USE_NANGATE45_CELLS
        CLKBUF_X1  clk_buf_o     (.A(I), .Z(O));
        CLKBUF_X1  clk_buf_odiv2 (.A(I), .Z(ODIV2));
    `elsif USE_SKY130HD_CELLS
        sky130_fd_sc_hd__clkbuf_1  clk_buf_o     (.A(I), .X(O));
        sky130_fd_sc_hd__clkbuf_1  clk_buf_odiv2 (.A(I), .X(ODIV2));
    `else
        assign O     = I;
        assign ODIV2 = I;
    `endif

endmodule
