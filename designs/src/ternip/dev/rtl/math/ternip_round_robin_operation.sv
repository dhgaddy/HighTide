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

// ternip_round_robin_operation
//
// Round-robin bank of multicycle arithmetic units.
//
// Sends each accepted input to one of workers and merges the
// results back into one output stream.
// Set Operation to "MUL" or "DIV".

module ternip_round_robin_operation #(
    parameter int DataWidth = 16,
    parameter int NumRobins = 2*DataWidth,
    parameter string Operation = "MUL"
) (
    input  logic                        clk_i,
    input  logic                        rst_ni,

    output logic                        in_ready_o,
    input  logic                        in_valid_i,
    input  logic signed [DataWidth-1:0] a_i,
    input  logic signed [DataWidth-1:0] b_i,

    input  logic                        out_ready_i,
    output logic                        out_valid_o,
    output logic signed [DataWidth-1:0] out_div_remainder_o,
    output logic signed [DataWidth-1:0] y_o
);

logic [NumRobins-1:0] robin_in_ready;
logic [NumRobins-1:0] robin_in_valid;
logic [NumRobins-1:0] robin_out_ready;
logic [NumRobins-1:0] robin_out_valid;
logic [NumRobins-1:0][2*DataWidth-1:0] robin_out_result;

// https://github.com/bespoke-silicon-group/basejump_stl/blob/a43571d2/bsg_dataflow/bsg_round_robin_1_to_n.sv
bsg_round_robin_1_to_n #(
    .num_out_p(NumRobins)
) round_robin_1_to_n (
    .clk_i,
    .reset_i(!rst_ni),

    .ready_and_o(in_ready_o),
    .valid_i(in_valid_i),

    .valid_o(robin_in_valid),
    .ready_and_i(robin_in_ready)
);

for (genvar i_GEN = 0; i_GEN < NumRobins; i_GEN++) begin

if (Operation == "MUL") begin

// https://github.com/bespoke-silicon-group/basejump_stl/blob/a43571d2/bsg_misc/bsg_imul_iterative.sv
bsg_imul_iterative #(
    .width_p(DataWidth)
) bsg_imul_iterative (
    .clk_i,
    .reset_i(!rst_ni),
    .v_i(robin_in_valid[i_GEN]),
    .ready_and_o(robin_in_ready[i_GEN]),

    .opA_i(a_i),
    .signed_opA_i(1),
    .opB_i(b_i),
    .signed_opB_i(1),
    .gets_high_part_i(0),

    .v_o(robin_out_valid[i_GEN]),
    .result_o(robin_out_result[i_GEN]),
    .yumi_i(robin_out_ready[i_GEN] && robin_out_valid[i_GEN])
);

end else if (Operation == "DIV") begin

// https://github.com/bespoke-silicon-group/basejump_stl/blob/a43571d2/bsg_misc/bsg_idiv_iterative.sv
bsg_idiv_iterative #(
    .width_p(DataWidth),
    .bits_per_iter_p(1)
) bsg_idiv_iterative (
    .clk_i,
    .reset_i(!rst_ni),
    .v_i(robin_in_valid[i_GEN]),
    .ready_and_o(robin_in_ready[i_GEN]),

    .dividend_i(a_i),
    .divisor_i(b_i),
    .signed_div_i(1),

    .v_o(robin_out_valid[i_GEN]),
    .quotient_o(robin_out_result[i_GEN][0+:DataWidth]),
    .remainder_o(robin_out_result[i_GEN][DataWidth+:DataWidth]),
    .yumi_i(robin_out_ready[i_GEN] && robin_out_valid[i_GEN])
);

end else begin

$fatal(0, "Unknown Operation: ", Operation);

end

end

// https://github.com/bespoke-silicon-group/basejump_stl/blob/a43571d2/bsg_dataflow/bsg_round_robin_n_to_1.sv
bsg_round_robin_n_to_1 #(
    .width_p(2*DataWidth),
    .num_in_p(NumRobins),
    .strict_p(1)
) round_robin_n_to_1 (
    .clk_i,
    .reset_i(!rst_ni),

    .data_i(robin_out_result),
    .v_i(robin_out_valid),
    .yumi_o(robin_out_ready),

    .v_o(out_valid_o),
    .data_o({out_div_remainder_o, y_o}),
    .tag_o(),
    .yumi_i(out_ready_i && out_valid_o)
);

endmodule
