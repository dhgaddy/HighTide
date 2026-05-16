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

// s_axi_ternip_rst
//
// Minimal AXI4 write subordinate (slave) that generates an active-low reset pulse.
//
// Any accepted write transaction clears the internal reset shift register and
// produces rst_no low for RST_LENGTH cycles before it shifts back high. The
// module accepts address and data beats independently, then returns a single
// write response using the captured AWID.
//
// Use this as a software-visible reset register for Ternip logic. The written
// data and address are ignored; the write itself is the reset trigger.

module s_axi_ternip_rst #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 8,
    parameter RST_LENGTH = 8
) (
    input  wire                  s_axi_aclk,
    input  wire                  s_axi_aresetn,

    // AXI4 Write Request Info
    input  wire [ID_WIDTH-1:0]   s_axi_awid,
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire [7:0]            s_axi_awlen,
    input  wire                  s_axi_awvalid,
    output wire                  s_axi_awready,

    // AXI4 Write Request Data
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire                  s_axi_wvalid,
    output wire                  s_axi_wready,

    // AXI4 Write Response
    output wire                  s_axi_bvalid,
    input  wire                  s_axi_bready,
    output reg  [ID_WIDTH-1:0]   s_axi_bid,

    output wire                  rst_no
);

reg [RST_LENGTH-1:0] rst_nq = '0;
assign rst_no = rst_nq[0];

reg aw_valid_d, aw_valid_q;
reg w_valid_d, w_valid_q;
reg b_valid_d, b_valid_q;
reg awid_d, awid_q;

always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn || b_valid_q) begin
        rst_nq <= '0;
    end else begin
        rst_nq <= ({1'b1, rst_nq} >> 1);
    end
end

assign s_axi_awready = !aw_valid_q;
assign s_axi_wready  = !w_valid_q;
assign s_axi_bvalid  = b_valid_q;

always @* begin
    aw_valid_d = aw_valid_q;
    w_valid_d = w_valid_q;
    b_valid_d = b_valid_q;
    awid_d = awid_q;
    s_axi_bid = {ID_WIDTH{1'bx}};

    if (s_axi_awvalid && !aw_valid_q) begin
        aw_valid_d = 1;
        awid_d = s_axi_awid;
    end
    if (s_axi_wvalid && !w_valid_q) begin
        w_valid_d = 1;
    end
    if (aw_valid_q && w_valid_q && !b_valid_q) begin
        b_valid_d = 1;
        aw_valid_d = 0;
        w_valid_d = 0;
    end
    if (b_valid_q && s_axi_bready) begin
        b_valid_d = 0;
        s_axi_bid = awid_q;
    end
end

always @(posedge s_axi_aclk) begin
    if (!s_axi_aresetn) begin
        aw_valid_q <= 0;
        w_valid_q <= 0;
        b_valid_q <= 0;
        awid_q <= {ID_WIDTH{1'bx}};
    end else begin
        aw_valid_q <= aw_valid_d;
        w_valid_q <= w_valid_d;
        b_valid_q <= b_valid_d;
        awid_q <= awid_d;
    end
end

endmodule
