# ==============================================================
# Makefile for IEEE 754 Double-Precision FPU
# Supports: VCS (primary), Questa (vsim)
# ==============================================================

# -- RTL Source Files --
RTL_SRC   = src/fp_add.v \
            src/fp_sub.v \
            src/fp_mul.v \
            src/fp_div.v \
            src/fp_fma.v \
            src/fpu.v

# -- UVM Testbench Files --
TB_SRC    = sv_tb/fpu_if.sv \
            sv_tb/fpu_transaction.sv \
            sv_tb/fpu_generator.sv \
            sv_tb/fpu_directed_sequences.sv \
            sv_tb/fpu_driver_monitor.sv \
            sv_tb/fpu_agent.sv \
            sv_tb/fpu_scoreboard.sv \
            sv_tb/fpu_coverage.sv \
            sv_tb/fpu_env.sv \
            sv_tb/fpu_assertions.sv \
            sv_tb/tb_fpu_sv.sv

# -- Legacy Verilog Testbench (non-UVM) --
TB_LEGACY = tb/tb_fpu.v

ALL_SRC   = $(RTL_SRC) $(TB_SRC)

# -- Default target --
.PHONY: all clean vcs vcs_gui uvm uvm_cov uvm_sva cov_full cov_report questa

all: vcs

# ==============================================================
# VCS Simulation — Base Random Test (UVM)
# ==============================================================

# Common VCS UVM compile flags
VCS_UVM   = vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
            -ntb_opts uvm +incdir+sv_tb

vcs: $(ALL_SRC)
	@echo "=== Compiling FPU with VCS (Base Random Test) ==="
	$(VCS_UVM) $(ALL_SRC) -o simv_fpu
	@echo "=== Running Base Random Test (10,000 transactions) ==="
	./simv_fpu -no_save +UVM_TESTNAME=fpu_base_test +UVM_VERBOSITY=UVM_LOW

vcs_gui: $(ALL_SRC)
	$(VCS_UVM) $(ALL_SRC) -o simv_fpu
	./simv_fpu -gui -no_save +UVM_TESTNAME=fpu_base_test

# ==============================================================
# UVM Tests
# ==============================================================

# Base random test (10,000 random transactions)
uvm: $(ALL_SRC)
	@echo "=== Compiling UVM Testbench ==="
	$(VCS_UVM) $(ALL_SRC) -o simv_fpu
	@echo "=== Running Base Random Test ==="
	./simv_fpu -no_save +UVM_TESTNAME=fpu_base_test +UVM_VERBOSITY=UVM_LOW

# Coverage-driven test (directed sequences + random noise)
uvm_directed: $(ALL_SRC)
	@echo "=== Compiling UVM Testbench ==="
	$(VCS_UVM) $(ALL_SRC) -o simv_fpu
	@echo "=== Running Coverage-Driven Test ==="
	./simv_fpu -no_save +UVM_TESTNAME=fpu_coverage_test +UVM_VERBOSITY=UVM_LOW

# ==============================================================
# SVA Assertions (VCS Simulation with Assertions)
# ==============================================================

# UVM + SVA: Run with all assertions enabled
uvm_sva: $(ALL_SRC)
	@echo "=== Compiling UVM + SVA Assertions ==="
	$(VCS_UVM) -assert enable_diag -assert vpiSeq \
	    $(ALL_SRC) -o simv_sva
	@echo "=== Running with Assertions (Coverage Test) ==="
	./simv_sva -no_save -assert report=assert_report.txt \
	    +UVM_TESTNAME=fpu_coverage_test +UVM_VERBOSITY=UVM_LOW
	@echo "=== Assertion report at: assert_report.txt ==="

# SVA + Coverage: Full coverage run with assertions checking
sva_cov_full: $(ALL_SRC)
	@echo "=== Compiling UVM + SVA + Coverage ==="
	$(VCS_UVM) $(CM_FLAGS) -assert enable_diag \
	    $(ALL_SRC) -o simv_sva_cov
	@echo "=== Run 1: Directed coverage with assertions ==="
	./simv_sva_cov -no_save $(CM_FLAGS) -cm_name sva_directed \
	    -assert report=assert_report_directed.txt \
	    +UVM_TESTNAME=fpu_coverage_test +UVM_VERBOSITY=UVM_LOW
	@echo "=== Run 2: Random stress with assertions ==="
	./simv_sva_cov -no_save $(CM_FLAGS) -cm_name sva_random \
	    -assert report=assert_report_random.txt \
	    +UVM_TESTNAME=fpu_base_test +UVM_VERBOSITY=UVM_LOW
	@echo "=== Generating Merged Report ==="
	urg -dir simv_sva_cov.vdb -report cov_report_sva -format both
	@echo "=== Coverage: cov_report_sva/dashboard.html ==="
	@echo "=== Assertions: assert_report_*.txt ==="

# ==============================================================
# Coverage Analysis (VCS)
# ==============================================================

# Coverage metrics: line, condition, FSM, toggle, branch
CM_FLAGS  = -cm line+cond+fsm+tgl+branch

# Compile + run with code & functional coverage (directed test)
uvm_cov: $(ALL_SRC)
	@echo "=== Compiling with Coverage ==="
	$(VCS_UVM) $(CM_FLAGS) $(ALL_SRC) -o simv_cov
	@echo "=== Running Coverage Test ==="
	./simv_cov -no_save $(CM_FLAGS) -cm_name cov_test \
	    +UVM_TESTNAME=fpu_coverage_test +UVM_VERBOSITY=UVM_LOW
	@echo "=== Generating Report ==="
	urg -dir simv_cov.vdb -report cov_report -format both
	@echo "=== Report at: cov_report/dashboard.html ==="

# Run both test suites and merge coverage into one report
cov_full: $(ALL_SRC)
	@echo "=== Compiling with Coverage ==="
	$(VCS_UVM) $(CM_FLAGS) $(ALL_SRC) -o simv_cov
	@echo "=== Run 1: Coverage test (directed + subnormal + rounding) ==="
	./simv_cov -no_save $(CM_FLAGS) -cm_name cov_directed \
	    +UVM_TESTNAME=fpu_coverage_test +UVM_VERBOSITY=UVM_LOW
	@echo "=== Run 2: Base random test (10,000 random transactions) ==="
	./simv_cov -no_save $(CM_FLAGS) -cm_name cov_random \
	    +UVM_TESTNAME=fpu_base_test +UVM_VERBOSITY=UVM_LOW
	@echo "=== Generating Merged Report ==="
	urg -dir simv_cov.vdb -report cov_report -format both
	@echo "=== Merged report at: cov_report/dashboard.html ==="

# Generate report from existing coverage data
cov_report:
	urg -dir simv_cov.vdb -report cov_report -format both
	@echo "=== Report at: cov_report/dashboard.html ==="

# ==============================================================
# Questa Simulation (alternative)
# ==============================================================
WORK_DIR = work

questa: $(ALL_SRC)
	@echo "=== Compiling with Questa ==="
	vlib $(WORK_DIR)
	vlog -work $(WORK_DIR) -sv +incdir+sv_tb -L uvm $(ALL_SRC)
	@echo "=== Running simulation ==="
	vsim -work $(WORK_DIR) -c -do "run -all; quit" tb_fpu_sv \
	    +UVM_TESTNAME=fpu_base_test

questa_gui: $(ALL_SRC)
	vlib $(WORK_DIR)
	vlog -work $(WORK_DIR) -sv +incdir+sv_tb -L uvm $(ALL_SRC)
	vsim -work $(WORK_DIR) -do "add wave -recursive *; run -all" tb_fpu_sv \
	    +UVM_TESTNAME=fpu_base_test

# ==============================================================
# Legacy Verilog Testbench (non-UVM, quick sanity check)
# ==============================================================
legacy: $(RTL_SRC) $(TB_LEGACY)
	@echo "=== Compiling Legacy TB with VCS ==="
	vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all \
	    $(RTL_SRC) $(TB_LEGACY) -o simv_legacy
	@echo "=== Running Legacy Test ==="
	./simv_legacy -no_save

# ==============================================================
# Clean
# ==============================================================
clean:
	rm -rf $(WORK_DIR) simv_fpu simv_cov simv_sva simv_sva_cov simv_legacy csrc
	rm -rf simv_fpu.daidir simv_cov.daidir simv_sva.daidir simv_sva_cov.daidir simv_legacy.daidir
	rm -rf transcript vsim.wlf ucli.key DVEfiles inter.vpd
	rm -rf simv_cov.vdb simv_sva_cov.vdb
	rm -rf cov_report cov_report_sva urgReport
	rm -rf assert_report*.txt
	rm -rf *.log *.key
