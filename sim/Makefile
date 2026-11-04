UVM_VERBOSITY = UVM_MEDIUM
UVM_TESTNAME = apb_gpio_virtual_test
UVM_VERSION = uvm-1.2

EXTRA_OPT =

RUN_OPT = +UVM_TESTNAME=$(UVM_TESTNAME) +UVM_VERBOSITY=$(UVM_VERBOSITY) $(EXTRA_OPT)

VCS_SRC_FILES =	../rtl/apb_gpio.v \
								../src/master/apb_master_if.sv \
								../src/gpio/gpio_if.sv \
								../src/common/apb_gpio_pkg.sv \
								../src/common/apb_gpio_tb_top.sv

VCS_INCDIR = +incdir+../src/common \
						 +incdir+../src/master \
						 +incdir+../src/gpio

VCS_OPTS = -full64 -sverilog -debug_access+all -kdb -lca \
						-ntb_opts $(UVM_VERSION) -timescale=1ns/1ps

SIMV_OPTS = -l simv.log $(RUN_OPT) \
						-cm_dir coverage.vdb

all : clean compile sim

compile:
	vcs $(VCS_OPTS) $(VCS_INCDIR) $(VCS_SRC_FILES) -l compile.log -o simv
	@echo "compile.."

sim :
	./simv $(SIMV_OPTS)
	@echo "simulation.."

clean :
	rm -rf simv* csrc *.log *.key *.h *.vdb *.conf *.rc *.fsdb verdiLog
	@echo "clear.."

coverage :
	verdi -dbdir simv.daidir/ -ssf apb_gpio_test.fsdb -cov -covdir coverage.vdb/

