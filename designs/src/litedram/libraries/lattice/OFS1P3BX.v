// Lattice ECP5 output flip-flop with sync preset (SP, active-low enable)
// and async preset (PD, active-high). Used by GENSDRPHY for the SDR
// command/data output path; in the generated litedram_core.v both PD and
// SP are tied to constants, so this collapses to a plain D flip-flop.
module OFS1P3BX (
    input  D,
    input  PD,
    input  SCLK,
    input  SP,
    output reg Q
);
    always @(posedge SCLK or posedge PD) begin
        if (PD)        Q <= 1'b1;
        else if (~SP)  Q <= 1'b1;
        else           Q <= D;
    end
endmodule
