// Lattice ECP5 D flip-flop with asynchronous preset (active-high PD).
// Used by GENSDRPHY's reset synchronizer (PD = system reset).
module FD1S3BX (
    input  CK,
    input  D,
    input  PD,
    output reg Q
);
    always @(posedge CK or posedge PD) begin
        if (PD) Q <= 1'b1;
        else    Q <= D;
    end
endmodule
