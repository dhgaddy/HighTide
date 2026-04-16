// Stub modules for bp_processor synthesis.
// These provide synthesizable stand-ins for modules that are
// referenced but not included in the synthesis file list.

// bsg_fifo_1r1w_small_hardened is instantiated when harden_p != 0
// in bsg_fifo_1r1w_small (used by the quad-core coherence network).
// No actual hard macro exists for ASIC synthesis, so we delegate to
// the unhardened implementation.
module bsg_fifo_1r1w_small_hardened (
	clk_i,
	reset_i,
	v_i,
	ready_param_o,
	data_i,
	v_o,
	data_o,
	yumi_i
);
	parameter width_p = 0;
	parameter els_p = 0;
	parameter ready_THEN_valid_p = 0;
	input clk_i;
	input reset_i;
	input v_i;
	output wire ready_param_o;
	input [width_p - 1:0] data_i;
	output wire v_o;
	output wire [width_p - 1:0] data_o;
	input yumi_i;
	bsg_fifo_1r1w_small_unhardened #(
		.width_p(width_p),
		.els_p(els_p),
		.ready_THEN_valid_p(ready_THEN_valid_p)
	) fifo (
		.clk_i(clk_i),
		.reset_i(reset_i),
		.v_i(v_i),
		.ready_param_o(ready_param_o),
		.data_i(data_i),
		.v_o(v_o),
		.data_o(data_o),
		.yumi_i(yumi_i)
	);
endmodule
