// ternip_pipelined_mem — FakeRAM replacement for HighTide ASIC synthesis.
//
// Drop-in replacement for the behavioral ternip_pipelined_mem module.
// Replaces the internal reg array with a FakeRAM SRAM macro and removes the
// redundant read_data_q2 register (the FakeRAM output is already registered).

`define SAFE_CLOG2(x) ( (((x)==1) || ((x)==0)) ? 1 : $clog2(x) )

module ternip_pipelined_mem #(
    parameter int DATA_WIDTH      = 8,
    parameter int NUM_ENTRIES     = 256,
    parameter bit DECOUPLED_READY = 0
) (
    input  logic                                clk_i,
    input  logic                                rst_ni,

    output logic                                request_ready_o,
    input  logic                                request_valid_i,
    input  logic                                request_write_not_read_i,
    input  logic [`SAFE_CLOG2(NUM_ENTRIES)-1:0] request_addr_i,
    input  logic [DATA_WIDTH-1:0]               request_w_data_i,

    input  logic                                read_ready_i,
    output logic                                read_valid_o,
    output logic [`SAFE_CLOG2(NUM_ENTRIES)-1:0] read_addr_o,
    output logic [DATA_WIDTH-1:0]               read_data_o
);

localparam int ADDR_WIDTH = `SAFE_CLOG2(NUM_ENTRIES);

// Pipeline registers (unchanged from original)
logic read_valid_d;
logic read_valid_q1;
logic read_valid_q2;

logic write_valid_d;
logic write_valid_q1;
logic write_valid_q2;

logic [ADDR_WIDTH-1:0] request_addr_q1;
logic [ADDR_WIDTH-1:0] request_addr_q2;
logic [DATA_WIDTH-1:0] request_w_data_q1;
logic [DATA_WIDTH-1:0] read_data_q2;

logic                                         buffer_in_ready;
logic                                         buffer_in_valid;
logic [$bits({read_addr_o, read_data_o})-1:0] buffer_in_data;

logic                                         buffer_out_ready;
logic                                         buffer_out_valid;
logic [$bits({read_addr_o, read_data_o})-1:0] buffer_out_data;

assign read_valid_d = (request_valid_i && !request_write_not_read_i);
assign write_valid_d = (request_valid_i && request_write_not_read_i);

logic stall1, stall2, stall3;

if (DECOUPLED_READY) begin
    assign stall2 = !buffer_in_ready && read_valid_q2;
end else begin
    assign stall3 = !read_ready_i && read_valid_o;
    assign stall2 = stall3 && (read_valid_q2 || write_valid_q2);
end

assign stall1 = stall2 && (read_valid_q1 || write_valid_q1);
assign request_ready_o = !stall1;

// Stage 1 pipeline registers
always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        read_valid_q1 <= 0;
        write_valid_q1 <= 0;
    end else if (!stall1) begin
        read_valid_q1 <= read_valid_d;
        write_valid_q1 <= write_valid_d;
    end
end
always_ff @(posedge clk_i) begin
    if (!stall1) begin
        request_addr_q1 <= request_addr_i;
        request_w_data_q1 <= request_w_data_i;
    end
end

// Stage 2 pipeline registers
always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
        read_valid_q2 <= 0;
        write_valid_q2 <= 0;
    end else if (!stall2) begin
        read_valid_q2   <= read_valid_q1;
        write_valid_q2  <= write_valid_q1;
    end
end
always_ff @(posedge clk_i) begin
    if (!stall2) begin
        request_addr_q2 <= request_addr_q1;
    end
end

// FakeRAM SRAM macro — replaces the behavioral reg array.
// The FakeRAM has a synchronous registered output, which replaces read_data_q2.
wire fakeram_ce = !stall2 && (write_valid_q1 || read_valid_q1);
wire fakeram_we = write_valid_q1;

generate
    if (DATA_WIDTH == 16 && NUM_ENTRIES == 4096) begin : gen_sram
        fakeram7_4096x16 sram (
            .rw0_clk(clk_i),
            .rw0_ce_in(fakeram_ce),
            .rw0_we_in(fakeram_we),
            .rw0_addr_in(request_addr_q1),
            .rw0_wd_in(request_w_data_q1),
            .rw0_rd_out(read_data_q2)
        );
    end else if (DATA_WIDTH == 16 && NUM_ENTRIES == 1024) begin : gen_sram
        fakeram7_1024x16 sram (
            .rw0_clk(clk_i),
            .rw0_ce_in(fakeram_ce),
            .rw0_we_in(fakeram_we),
            .rw0_addr_in(request_addr_q1),
            .rw0_wd_in(request_w_data_q1),
            .rw0_rd_out(read_data_q2)
        );
    end else if (DATA_WIDTH == 1024 && NUM_ENTRIES == 16) begin : gen_sram
        fakeram7_16x1024 sram (
            .rw0_clk(clk_i),
            .rw0_ce_in(fakeram_ce),
            .rw0_we_in(fakeram_we),
            .rw0_addr_in(request_addr_q1),
            .rw0_wd_in(request_w_data_q1),
            .rw0_rd_out(read_data_q2)
        );
    end
endgenerate

// Output stage (unchanged from original)
if (DECOUPLED_READY) begin : decoupled_ready
    assign buffer_in_valid = read_valid_q2;
    assign buffer_in_data = {request_addr_q2, read_data_q2};

    assign buffer_out_ready = read_ready_i;
    assign read_valid_o = buffer_out_valid;
    assign {read_addr_o, read_data_o} = buffer_out_data;

    ternip_pipelined_interconnect #(
        .DataWidth($bits(buffer_in_data)),
        .NumStages(1)
    ) buffer (
        .clk_i,
        .rst_ni,

        .in_ready_o(buffer_in_ready),
        .in_valid_i(buffer_in_valid),
        .in_data_i(buffer_in_data),

        .out_ready_i(buffer_out_ready),
        .out_valid_o(buffer_out_valid),
        .out_data_o(buffer_out_data)
    );
end else begin : coupled_ready
    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            read_valid_o <= 1'b0;
        end else if (!stall3) begin
            read_valid_o <= read_valid_q2;
        end
    end
    always_ff @(posedge clk_i) begin
        if (!stall3) begin
            read_addr_o  <= read_valid_q2 ? request_addr_q2 : 'x;
            read_data_o  <= read_valid_q2 ? read_data_q2    : 'x;
        end
    end
end

endmodule

`undef SAFE_CLOG2
