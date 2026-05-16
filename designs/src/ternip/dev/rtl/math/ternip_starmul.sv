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

// ternip_starmul
//
// Two-stage signed '*' multiplier.
//
// Registers a_i and b_i, computes their product with the SystemVerilog '*'
// operator, and registers y_o. The product is truncated to DataWidth bits.
// File intended for DSP inference.

module ternip_starmul #(
    parameter int DataWidth = 32
) (
    input  logic                        clk_i,
    input  logic                        rst_ni,

    output logic                        in_ready_o,
    input  logic                        in_valid_i,
    input  logic signed [DataWidth-1:0] a_i,
    input  logic signed [DataWidth-1:0] b_i,

    input  logic                        out_ready_i,
    output logic                        out_valid_o,
    output logic signed [DataWidth-1:0] y_o
);

logic valid_d1, valid_q1, valid_q2;

assign out_valid_o = valid_q2;
assign valid_d1 = in_valid_i && in_ready_o;

logic signed [DataWidth-1:0] a_d1, a_q1;
logic signed [DataWidth-1:0] b_d1, b_q1;
logic signed [DataWidth-1:0] y_d2, y_q2;

assign a_d1 = a_i;
assign b_d1 = b_i;
assign y_d2 = a_q1 * b_q1;
assign y_o = y_q2;

logic stall1, stall2;
assign stall2 = !out_ready_i && out_valid_o;
assign stall1 = stall2 && valid_q1;
assign in_ready_o = !stall1;

always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        valid_q1 <= 0;
    end else if (!stall1) begin
        valid_q1 <= valid_d1;
    end
end
always_ff @(posedge clk_i) begin
    if (!stall1) begin
        a_q1 <= a_d1;
        b_q1 <= b_d1;
    end
    if (!stall2) begin
        y_q2 <= y_d2;
    end
    `ifndef SYNTHESIS
    if (!rst_ni) begin
        a_q1 <= 'x;
        b_q1 <= 'x;
        y_q2 <= 'x;
    end
    `endif
end

always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        valid_q2 <= 0;
    end else if (!stall2) begin
        valid_q2 <= valid_q1;
    end
end

endmodule
