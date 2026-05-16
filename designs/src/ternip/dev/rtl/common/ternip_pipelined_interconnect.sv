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

// ternip_pipelined_interconnect
//
// Ready/valid interconnect that registers both forward data/valid and reverse
// ready paths.
//
// NumStages controls how many cycles of pipeline delay are inserted between the
// source and sink. A small FIFO absorbs the skew between the delayed valid/data
// path and the delayed ready path, and a final output register breaks the FIFO
// read-to-output path.
//
// Use this when timing requires cutting a long ready/valid connection.

module ternip_pipelined_interconnect #(
    parameter int DataWidth = 8,
    parameter int NumStages = 8
) (
    input  logic                 clk_i,
    input  logic                 rst_ni,

    output logic                 in_ready_o,
    input  logic                 in_valid_i,
    input  logic [DataWidth-1:0] in_data_i,

    input  logic                 out_ready_i,
    output logic                 out_valid_o,
    output logic [DataWidth-1:0] out_data_o
);

logic [NumStages-1:0]                in2out_buffer_valid_q;
logic [NumStages-1:0][DataWidth-1:0] in2out_buffer_data_q;
logic [NumStages-1:0]                out2in_buffer_ready_q;

logic fifo_in_ready;
logic fifo_out_ready;
logic fifo_out_valid;
logic [DataWidth-1:0] fifo_out_data;

// Registered output stage: breaks the combinational path from the FIFO's
// read pointer (rptr) through v_o to downstream control logic.
logic final_buffer_valid_d, final_buffer_valid_q;
logic [DataWidth-1:0] final_buffer_data_d, final_buffer_data_q;

always_comb begin
    final_buffer_valid_d = final_buffer_valid_q;
    final_buffer_data_d = final_buffer_data_q;
    fifo_out_ready = 0;
    if (fifo_out_valid && (!final_buffer_valid_q || out_ready_i)) begin
        final_buffer_valid_d = 1;
        final_buffer_data_d = fifo_out_data;
        fifo_out_ready = 1;
    end else if (out_ready_i) begin
        final_buffer_valid_d = 0;
    end
end

always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        in2out_buffer_valid_q <= '0;
        out2in_buffer_ready_q <= '0;
        final_buffer_valid_q <= 0;
    end else begin
        in2out_buffer_valid_q <= {in2out_buffer_valid_q, (in_valid_i && in_ready_o)};
        out2in_buffer_ready_q <= {out2in_buffer_ready_q, out_ready_i};
        final_buffer_valid_q <= final_buffer_valid_d;
    end
end
always_ff @(posedge clk_i) begin
    in2out_buffer_data_q <= {in2out_buffer_data_q, in_data_i};
    final_buffer_data_q <= final_buffer_data_d;
    `ifndef SYNTHESIS
    if (!rst_ni) begin
        in2out_buffer_data_q <= 'x;
        final_buffer_data_q <= 'x;
    end
    `endif
end

assign in_ready_o = out2in_buffer_ready_q[NumStages-1];
assign out_valid_o = final_buffer_valid_q;
assign out_data_o = final_buffer_valid_q ? final_buffer_data_q : 'x;

// https://github.com/bespoke-silicon-group/basejump_stl/blob/a43571d2/bsg_dataflow/bsg_fifo_1r1w_small.sv
bsg_fifo_1r1w_small #(
    .width_p(DataWidth),
    .els_p(2*NumStages+1),
    .harden_p(0),
    .ready_THEN_valid_p(0)
) fifo (
    .clk_i,
    .reset_i(!rst_ni),

    .v_i(in2out_buffer_valid_q[NumStages-1]),
    .ready_param_o(fifo_in_ready), // should never drop a packet
    .data_i(in2out_buffer_data_q[NumStages-1]),

    .v_o(fifo_out_valid),
    .data_o(fifo_out_data),
    .yumi_i(fifo_out_ready && fifo_out_valid)
);

// Property: FIFO must always be ready when the buffered valid signal is high
property p_no_drop;
    @(posedge clk_i)
    disable iff (!rst_ni)
    in2out_buffer_valid_q[NumStages-1] |-> fifo_in_ready;
endproperty

assert property (p_no_drop)
    else begin
        @(posedge clk_i); #1ps;
        $fatal(0, "Fatal, dropped packet");
    end

endmodule
