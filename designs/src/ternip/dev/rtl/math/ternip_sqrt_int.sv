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

// ternip_sqrt_int
//
// Iterative unsigned integer square root.
//
// Accepts one Width-bit unsigned value and returns floor(sqrt(a_i)). The result
// width is ceil(Width/2). Latency scales with the result width.

module ternip_sqrt_int #(
    parameter int Width = 8
) (
    input  logic             clk_i,
    input  logic             rst_ni,

    output logic             in_ready_o,
    input  logic             in_valid_i,
    input  logic [Width-1:0] a_i,

    input  logic             out_ready_i,
    output logic             out_valid_o,
    output logic [Width-1:0] y_o
);

localparam int ResultWidth    = (Width + 1) / 2;
localparam int RemainderWidth = ResultWidth + 2;

enum logic [1:0] {
    IDLE,
    WORKING,
    DONE
} state_d, state_q;

logic [ResultWidth-1:0][1:0]    a_d, a_q;
logic [RemainderWidth-1:0]      remainder_d, remainder_q;
logic [ResultWidth-1:0]         root_d, root_q;
logic [$clog2(ResultWidth)-1:0] idx_d, idx_q;

assign y_o = root_q;

logic [1:0]                input_pair;
logic [ResultWidth+1:0]    trial_divisor;
logic [RemainderWidth-1:0] partial_remainder;

always_comb begin
    a_d         = a_q;
    remainder_d = remainder_q;
    root_d      = root_q;
    idx_d       = idx_q;
    state_d     = state_q;

    in_ready_o  = 1'b0;
    out_valid_o = 1'b0;

    input_pair = 'x;
    trial_divisor = 'x;
    partial_remainder = 'x;

    if (state_q == IDLE) begin
        in_ready_o = 1;

        if (in_ready_o && in_valid_i) begin
            a_d         = a_i;
            remainder_d = '0;
            root_d      = '0;
            idx_d       = ResultWidth - 1;
            state_d     = WORKING;
        end

    end else if (state_q == WORKING) begin
        input_pair        = a_q[idx_q];
        trial_divisor     = (root_q << 2) | 1;
        partial_remainder = (remainder_q << 2) | input_pair;

        if (partial_remainder >= trial_divisor) begin
            remainder_d = partial_remainder - trial_divisor;
            root_d      = (root_q << 1) | 1;
        end else begin
            remainder_d = partial_remainder;
            root_d      = (root_q << 1);
        end

        if (idx_q > 0) begin
            idx_d--;
        end else begin
            state_d = DONE;
        end

    end else if (state_q == DONE) begin
        out_valid_o = 1;
        if (out_ready_i) begin
            state_d = IDLE;
        end

    end
end

always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        state_q <= IDLE;
    end else begin
        state_q <= state_d;
    end
end
always_ff @(posedge clk_i) begin
    a_q         <= a_d;
    remainder_q <= remainder_d;
    root_q      <= root_d;
    idx_q       <= idx_d;
    `ifndef SYNTHESIS
    if (!rst_ni) begin
        a_q         <= 'x;
        remainder_q <= 'x;
        root_q      <= 'x;
        idx_q       <= 'x;
    end
    `endif
end

endmodule
