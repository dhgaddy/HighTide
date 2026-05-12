// Lattice ECP5 input flip-flop with sync preset (SP, active-low enable)
// and async preset (PD, active-high). Used by GENSDRPHY for SDR rddata
// capture; PD and SP tied to constants in generated code, so it acts as
// a plain D flip-flop.
module IFS1P3BX (
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
