// Copyright (c) 2026 Ethan Sifferman
//
// Redistribution and use in source and binary forms, with or without modification, are permitted
// provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of
//    conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of
//    conditions and the following disclaimer in the documentation and/or other materials provided
//    with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its contributors may be used to
//    endorse or promote products derived from this software without specific prior written
//    permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

// ternip_fixed_point_convert
//
// Convert between signed fixed-point formats.
//
// Interprets in as InPrecision bits scaled by 2**InExponent. Produces out as
// OutPrecision bits scaled by 2**OutExponent, with roundToIntegralTiesToAway rounding.
// The conversion is combinational. clk_i/rst_ni are only used by simulation
// assertions.

module ternip_fixed_point_convert #(
    parameter int InPrecision  = 16,
    parameter int InExponent   = 0,
    parameter int OutPrecision = 16,
    parameter int OutExponent  = 0
) (
    input  logic                           clk_i,
    input  logic                           rst_ni,

    input  logic signed [InPrecision-1:0]  in,
    output logic signed [OutPrecision-1:0] out
);

    if (InPrecision < 1) $fatal(0, "InPrecision (%0d) must be positive", InPrecision);
    if (OutPrecision < 1) $fatal(0, "OutPrecision (%0d) must be positive", OutPrecision);

    function automatic integer max_int(integer a, integer b);
        return ((a>b) ? a : b);
    endfunction

    typedef logic signed [OutPrecision-1:0] out_t;

    localparam int MaxPrecision = max_int(InPrecision, OutPrecision) + 2; // 2 extra bits for abs and rounding
    localparam int LeftShiftAmount = InExponent - OutExponent;
    localparam logic signed [OutPrecision-1:0] OutMin = -(1 <<< (OutPrecision-1));
    localparam logic signed [OutPrecision-1:0] OutMax =  (1 <<< (OutPrecision-1)) - 1;

    wire in_sign;
    logic signed [MaxPrecision-1:0] in_abs;
    logic to_round;
    logic signed [MaxPrecision-1:0] in_abs_rounded;

    assign in_sign = (in < 0);
    assign in_abs  = in_sign ? -in : in;

    localparam logic [MaxPrecision-1:0] guard_bit_mask  = 1 << max_int(0, -LeftShiftAmount);
    localparam logic [MaxPrecision-1:0] round_bit_mask  = guard_bit_mask >> 1;
    localparam logic [MaxPrecision-1:0] sticky_bits_mask = (round_bit_mask != 0)
                                                         ? (round_bit_mask - 1)
                                                         : '0;
    wire guard_bit  = |(in_abs & guard_bit_mask);
    wire round_bit  = |(in_abs & round_bit_mask);
    wire sticky_bit = |(in_abs & sticky_bits_mask);

    always_comb begin
        to_round = round_bit; // roundToIntegralTiesToAway

        // roundToIntegralTiesToEven
        // case ({guard_bit, round_bit, sticky_bit})
        //     3'b000: to_round = 0;
        //     3'b001: to_round = 0;
        //     3'b010: to_round = 0; // round ties toward even
        //     3'b011: to_round = 1;
        //     3'b100: to_round = 0;
        //     3'b101: to_round = 0;
        //     3'b110: to_round = 1; // round ties toward even
        //     3'b111: to_round = 1;
        // endcase
    end

    assign in_abs_rounded = (in_abs&~(round_bit_mask|sticky_bits_mask)) + ((to_round) ? guard_bit_mask : 0);

    localparam int NumNonClampingBits = max_int(0, OutPrecision-1 - LeftShiftAmount);
    localparam logic [MaxPrecision-1:0] clamping_bits_mask = (MaxPrecision'('1) << NumNonClampingBits);

    wire [MaxPrecision-1:0] clamping_bits = in_abs_rounded & clamping_bits_mask;
    wire to_clamp = |clamping_bits;

    logic signed [MaxPrecision-1:0] shifted_abs;

    // Shift with rounding and clamping
    always_comb begin
        if (LeftShiftAmount >= 0) begin
            shifted_abs = in_abs_rounded <<< LeftShiftAmount;
        end else begin
            shifted_abs = in_abs_rounded >>> -LeftShiftAmount;
        end

        // Restore sign
        out = in_sign ? -shifted_abs : shifted_abs;
        if (to_clamp) begin
            out = (in_sign) ? OutMin : OutMax;
        end
    end

    `ifndef SYNTHESIS
    // only run assertions if within real precision
    if (MaxPrecision <= 52)  always @(posedge clk_i) #2ps begin
        automatic real out_max_real = (2.0**(OutPrecision-1)-1) * 2.0**OutExponent;
        automatic real out_min_real = -(2.0**(OutPrecision-1)) * 2.0**OutExponent;
        automatic real in_real;
        automatic real out_model_real;
        automatic logic signed [OutPrecision-1:0] out_model;

        while (!rst_ni || $isunknown(in)) begin
            @(posedge clk_i); #2ps;
        end

        in_real = $itor(in) * 2.0**InExponent;

        out_model_real = in_real;
        if (out_model_real < out_min_real) out_model_real = out_min_real;
        if (out_model_real > out_max_real) out_model_real = out_max_real;
        out_model = out_t'(out_model_real / 2.0**OutExponent);

        if (out_model !== out) begin
            $display(">>> CONVERSION FAILED at time %0t <<<", $time);
            $display("    out_model (expected) = %0d  bin=%b  out (received) = %0d  bin=%b",
                     out_model, out_model, out, out);
            $display("  Parameters:");
            $display("    InPrecision=%0d  InExponent=%0d  OutPrecision=%0d  OutExponent=%0d",
                     InPrecision, InExponent, OutPrecision, OutExponent);
            $display("  Masks (binary):");
            $display("    guard_bit_mask       = %b", guard_bit_mask);
            $display("    round_bit_mask       = %b", round_bit_mask);
            $display("    sticky_bits_mask     = %b", sticky_bits_mask);
            $display("    clamping_bits_mask   = %b", clamping_bits_mask);
            $display("    OutMin(bin)          = %b", OutMin);
            $display("    OutMax(bin)          = %b", OutMax);

            $display("  Signals:");
            $display("    in_sign = %b", in_sign);
            $display("    in (raw) = %0d  bin=%b", in, in);
            $display("    in_abs (pre-round) = %0d  bin=%b", in_abs, in_abs);
            $display("    guard_bit=%b  round_bit=%b  sticky_bit=%b  to_round=%b", guard_bit, round_bit, sticky_bit, to_round);
            $display("    in_abs_rounded = %0d  bin=%b", in_abs_rounded, in_abs_rounded);
            $display("    clamping_bits = %b  to_clamp=%b", clamping_bits, to_clamp);
            $display("    shifted_abs (after shift) = %0d  bin=%b", shifted_abs, shifted_abs);
            $display("    out_model (expected) = %0d  bin=%b  out (received) = %0d  bin=%b",
                     out_model, out_model, out, out);

            assert(0) else $fatal(0, "ternip_fixed_point_convert output does not match expected value");
        end
    end
    `endif

endmodule
