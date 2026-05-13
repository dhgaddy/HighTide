// SV interface instantiations for the TBOX subsystem.
// Separated from tbox_types.vh so that interfaces are compiled exactly once
// (as a source file in the RTL glob) rather than being re-instantiated each
// time tbox_types.vh is `include'd by a different compilation unit.
`include "soc_defines.vh"
`include "fp_types.vh"
`include "tbox_types.vh"

localparam IMG_INFO_TABLE_WIDTH = $bits(imageInformationTableEntry_t);
localparam VADDR_MEM_WIDTH = $bits(imageInformationVaddressEntry_t);

`ENQIO_IF(sample_request_if, sample_request_t)
`ENQIO_IF(addressInTableOutIO_if, addressInTableOutIO_t)
`ENQIO_IF(addressOutIO_if, addressOutIO_t)
`ENQIO_IF(futureTagsDataIO_if, futureTagsDataIO_t)
`ENQIO_IF(decompressL2IO_if, decompressL2IO_t)
`ENQIO_IF(imageInformationL2Req_if, logic [PA_SIZE_TBOX-1:0])
`VALID_IF(imageInformationL2Rep_if, logic [MEM_ENTRY_SZ-1:0])
`ENQIO_IF(imageInformationRdRep_if, logic [IMG_INFO_TABLE_WIDTH+ENTRY_IDX_SZ-1:0])
`ENQIO_IF(l2ReorderFifo_req_if, l2ReorderFifo_req_t)
`VALID_IF(l2ReorderFifo_rep_if, l2ReorderFifo_rep_t)
`ENQIO_IF(virtualAddressL2IO_if, virtualAddressL2IO_t)
`ENQIO_IF(futureTagsVirtualAddressIO_if, futureTagsVirtualAddressIO_t)
`VALID_IF(imageInformationVAddrIO_if, imageInformationVAddrIO_t)
`VALID_IF(addressInIO_if, addressInIO_t)
`ENQIO_IF(cacheDataL2IO_if, logic [TEX_L1_DATA_SZ-1:0])
`ENQIO_IF(tmuxInIO_if, tmuxInIO_t)
`ENQIO_IF(tmuxOutIO_if, tmuxOutIO_t)
`VALID_IF(addressAckOut_if, addressAckOut_t)
`ENQIO_IF(pixelAccumOutIO_if, pixelAccumOutIO_t)
`ENQIO_IF(blenderOutIO_if, blenderOutIO_t)
