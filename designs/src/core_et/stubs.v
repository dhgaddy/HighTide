// FakeRAM black-box stubs for CORE-ET memory macros.
// Port widths are hardcoded to match the default parameter values used by the
// RTL instantiations.  No parameters are declared here — the RTL does not pass
// any parameter overrides, and yosys-slang elaborates parameterised blackboxes
// in a way that strips the parameter declarations, causing a HIERARCHY mismatch.

(* blackbox *)
module icache_data_ram (
    input  wire         clk,
    input  wire         ce,
    input  wire         we,
    input  wire [8:0]   addr,
    input  wire [143:0] din,
    output wire [143:0] dout
);
endmodule

(* blackbox *)
module dcache_128x32_1r1w_lram (
    input        clk,
    input        wr_enable,
    input        rd_enable,
    input  [6:0] wr_addr,      // ADDR_BITS = 7
    input  [31:0] wr_data,     // WIDTH = 32
    input  [6:0] rd_addr,
    output [31:0] rd_data
);
endmodule

(* blackbox *)
module icache_tag_data_array (
    input         clk,
    input         wr_enable,
    input         rd_enable_a,
    input         rd_enable_b,
    input  [6:0]  wr_addr,     // ADDR_BITS = 7
    input  [26:0] wr_data,     // WIDTH = 27
    input  [6:0]  rd_addr_a,
    input  [6:0]  rd_addr_b,
    output [26:0] rd_data_a,
    output [26:0] rd_data_b
);
endmodule

(* blackbox *)
module icache_lru_state_array (
    input         clk,
    input         wr_enable,
    input         rd_enable,
    input  [6:0]  wr_addr,     // ADDR_BITS = 7
    input  [15:0] wr_data,     // WIDTH = 16
    input  [6:0]  rd_addr,
    output [15:0] rd_data
);
endmodule

(* blackbox *)
module vpu_64x32_3r2w_vpurf (
    input         clk,
    input         wr_enable0,
    input  [5:0]  wr_addr0,    // ADDR_BITS = 6
    input  [31:0] wr_data0,    // WIDTH = 32
    input         wr_enable1,
    input  [5:0]  wr_addr1,
    input  [31:0] wr_data1,
    input         rd_enable0,
    input  [5:0]  rd_addr0,
    output [31:0] rd_data0,
    input         rd_enable1,
    input  [5:0]  rd_addr1,
    output [31:0] rd_data1,
    input         rd_enable2,
    input  [5:0]  rd_addr2,
    output [31:0] rd_data2
);
endmodule

(* blackbox *)
module vpu_tensorc_rf_buffer_array (
    input         clk,
    input         wr_enable,
    input         rd_enable,
    input  [3:0]  wr_addr,     // ADDR_BITS = 4
    input  [31:0] wr_data,     // WIDTH = 32
    input  [3:0]  rd_addr,
    output [31:0] rd_data
);
endmodule
