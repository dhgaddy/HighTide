ifneq ($(wildcard $(DEV_FLAG)),)
export VERILOG_FILES = $(wildcard $(BENCH_DESIGN_HOME)/src/ternip/dev/gen/rtl/**/*.sv) \
                       $(wildcard $(BENCH_DESIGN_HOME)/src/ternip/dev/gen/rtl/**/*.v)
else
export VERILOG_FILES = $(wildcard $(BENCH_DESIGN_HOME)/src/ternip/rtl/**/*.sv) \
                       $(wildcard $(BENCH_DESIGN_HOME)/src/ternip/rtl/**/*.v)
endif
