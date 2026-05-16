// ternip_readmem_path.svh
//
// Helper macros for constructing $readmem file paths.
//
// Define READMEM_DIR at compile time to prefix LUT/table filenames with a build
// directory. Without READMEM_DIR, READMEM_PATH(f) expands to just "f". Include
// this header before modules that load generated memories so simulation and
// synthesis flows can share the same source code while selecting different file
// locations.

`ifndef _TERNIP_READMEM_PATH_SVH
`define _TERNIP_READMEM_PATH_SVH

`define _READMEM_STR(x) `"x`"

`ifdef READMEM_DIR
  `define READMEM_PATH(f) `_READMEM_STR(`READMEM_DIR/f)
`else
  `define READMEM_PATH(f) `"f`"
`endif

`endif
