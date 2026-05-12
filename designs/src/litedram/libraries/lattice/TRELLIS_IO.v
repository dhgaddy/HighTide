// Lattice ECP5 generic IO buffer (BIDIR/INPUT/OUTPUT) — for the
// SDR DQ tristate bus. With DIR="BIDIR", T selects between drive (I)
// and high-impedance, and the pad voltage is sampled back on O.
module TRELLIS_IO #(
    parameter DIR = ""
)(
    inout  B,
    input  I,
    input  T,
    output O
);
    assign B = T ? 1'bz : I;
    assign O = B;
endmodule
