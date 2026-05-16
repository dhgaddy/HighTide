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

// s_axi_ternip_const_rd
//
// Minimal AXI4 read subordinate (slave) that returns a constant value.
//
// The module accepts one read burst at a time and responds with CONST_DATA for
// every beat, preserving the incoming ARID and asserting RLAST on the final beat.
// Address fields are ignored. Responses use OKAY.
//
// Use this for simple memory-mapped status locations or placeholder read ports
// where software expects a legal AXI read transaction but the data is constant.

module s_axi_ternip_const_rd #(
    parameter DATA_WIDTH  = 32,
    parameter ADDR_WIDTH  = 32,
    parameter ID_WIDTH    = 8,
    parameter CONST_DATA  = {DATA_WIDTH{1'b0}}
) (
    input  wire                  s_axi_aclk,
    input  wire                  s_axi_aresetn,

    // AXI4 Read Request
    input  wire [ID_WIDTH-1:0]   s_axi_arid,
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire [7:0]            s_axi_arlen,
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready,

    // AXI4 Read Response
    output reg  [ID_WIDTH-1:0]   s_axi_rid,
    output reg  [DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]            s_axi_rresp,
    output reg                   s_axi_rlast,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready
);

    reg [8:0]             burst_countdown_q, burst_countdown_d;
    reg [ID_WIDTH-1:0]    arid_q, arid_d;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            burst_countdown_q <= 9'd0;
            arid_q <= {ID_WIDTH{1'bx}};
        end else begin
            burst_countdown_q <= burst_countdown_d;
            arid_q <= arid_d;
        end
    end

    always @* begin
        s_axi_arready = 0;
        burst_countdown_d = burst_countdown_q;
        arid_d = arid_q;

        s_axi_rid    = {ID_WIDTH{1'bx}};
        s_axi_rdata  = {DATA_WIDTH{1'bx}};
        s_axi_rresp  = 2'bxx;
        s_axi_rlast  = 1'bx;
        s_axi_rvalid = 0;

        if (burst_countdown_q == 0) begin
            s_axi_arready = 1;
            if (s_axi_arvalid && s_axi_arready) begin
                burst_countdown_d = s_axi_arlen + 1;
                arid_d            = s_axi_arid;
            end
        end else begin
            s_axi_rid    = arid_q;
            s_axi_rdata  = CONST_DATA;
            s_axi_rresp  = 2'b00;
            s_axi_rlast  = (burst_countdown_q == 1);
            s_axi_rvalid = 1;

            if (s_axi_rvalid && s_axi_rready) begin
                burst_countdown_d = burst_countdown_q - 1;
            end
        end
    end

endmodule
