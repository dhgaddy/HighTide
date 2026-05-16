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

// s_axi_ternip_write_byte
//
// Minimal AXI4 write slave that forwards the first written byte to AXI-Stream.
//
// The module accepts one AXI write burst, sends s_axi_wdata[7:0] from the first
// data beat on m_axis_tdata, drains the remaining write beats, then returns one
// write response with the captured AWID. Address fields and upper data bits are
// ignored.
//
// Use this as a tiny software command mailbox when only an 8-bit command value
// is needed but the host speaks AXI4 writes.

module s_axi_ternip_write_byte #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter ID_WIDTH   = 8
) (
    input  wire                  clk,
    input  wire                  resetn,

    // AXI4 Write Request Info
    input  wire [ID_WIDTH-1:0]   s_axi_awid,
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire [7:0]            s_axi_awlen,
    input  wire                  s_axi_awvalid,
    output reg                   s_axi_awready,

    // AXI4 Write Request Data
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,

    // AXI4 Write Response
    output wire                  s_axi_bvalid,
    input  wire                  s_axi_bready,
    output reg  [ID_WIDTH-1:0]   s_axi_bid,

    // AXIS Write Data
    input  wire                  m_axis_tready,
    output reg                   m_axis_tvalid,
    output reg  [7:0]            m_axis_tdata
);

    reg [8:0]          burst_countdown_d, burst_countdown_q;
    reg                first_beat_d, first_beat_q;
    reg                s_bvalid_d, s_bvalid_q;
    reg [ID_WIDTH-1:0] awid_d, awid_q;

    assign s_axi_bvalid = s_bvalid_q;

    always @* begin
        burst_countdown_d = burst_countdown_q;
        first_beat_d = first_beat_q;
        s_bvalid_d = s_bvalid_q;
        awid_d = awid_q;

        s_axi_awready = 0;
        s_axi_wready = 0;
        m_axis_tvalid = 0;
        m_axis_tdata = {8{1'bx}};
        s_axi_bid = {ID_WIDTH{1'bx}};

        // Address phase
        if (burst_countdown_q == 0) begin
            if (!s_bvalid_q) begin
                s_axi_awready = 1;
                if (s_axi_awvalid) begin
                    burst_countdown_d = s_axi_awlen + 1;
                    first_beat_d = 1;
                    awid_d = s_axi_awid;
                end
            end
        end else begin
            // Only send first byte of first beat to AXIS
            if (first_beat_q) begin
                m_axis_tvalid = 1;
                m_axis_tdata = s_axi_wdata[7:0];
                if (m_axis_tready) begin
                    first_beat_d = 0;
                end
            end

            s_axi_wready = !first_beat_q || m_axis_tready;
            if (s_axi_wvalid && s_axi_wready) begin
                if (burst_countdown_q == 1) begin
                    burst_countdown_d = 0;
                    s_bvalid_d = 1;
                end else begin
                    burst_countdown_d = burst_countdown_q - 1;
                end
            end
        end

        if (s_bvalid_q && s_axi_bready) begin
            s_bvalid_d = 0;
            s_axi_bid = awid_q;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            burst_countdown_q <= 0;
            first_beat_q      <= 0;
            s_bvalid_q        <= 0;
            awid_q            <= {ID_WIDTH{1'bx}};
        end else begin
            burst_countdown_q <= burst_countdown_d;
            first_beat_q      <= first_beat_d;
            s_bvalid_q        <= s_bvalid_d;
            awid_q            <= awid_d;
        end
    end

endmodule
