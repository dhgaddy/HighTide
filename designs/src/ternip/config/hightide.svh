
localparam int D = 1024;
localparam int TmatmulParallelism = 64;
localparam int VectorParallelism = 1;
localparam int LutParallelism = 1;

localparam int FixedPointPrecision = 16;
localparam int FixedPointExponent = -5;

parameter mul_impl_e MultiplicationImplementation = MUL_BSG;
parameter div_impl_e DivisionImplementation = DIV_BSG;

localparam bit UseHardSigmoid = 1;

localparam int BatchSize = 1;

localparam int NumVectorRegisters = 4;
localparam int ImmediateWidth = 16;
localparam int DdrAddressWidth = 64;
localparam int InstructionWidth = 128;

localparam int DdrDataWidth = 128;
localparam int InstrFetchWidth = 128;
localparam int CoreInterconnectNumStages = 8;

localparam real DramMaxBytesPerSecond = 10.0**12; // 1 TB/s
localparam real ClockPeriod = 5.0 * 10.0**-9; // 200MHz
