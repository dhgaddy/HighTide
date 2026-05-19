
localparam int D = 2560;
localparam int TmatmulParallelism = 256;
localparam int VectorParallelism = 8;
localparam int LutParallelism = 1;

localparam int FixedPointPrecision = 16;
localparam int FixedPointExponent = -5;

parameter mul_impl_e MultiplicationImplementation = MUL_BSG;
parameter div_impl_e DivisionImplementation = DIV_BSG;

localparam bit UseHardSigmoid = 1;

localparam int BatchSize = 4;

localparam int NumVectorRegisters = 8;
localparam int ImmediateWidth = 16;
localparam int DdrAddressWidth = 64;
localparam int InstructionWidth = 128;
