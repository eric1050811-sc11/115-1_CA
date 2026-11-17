#=========================================================================
# Makefile for Verilog Packages
#=========================================================================
# This is a simple start to a much more sophisticated Verilog build
# system. For most packages, a developer will not need to make any
# changes to this file except to make sure that the subpkgs make variable
# correctly lists the desired subpackages to include in this package.
# Developers also need to make sure each subpackage makefile fragment
# (e.g., vc.mk) is uptodate with a list of all of the subpackage
# dependencies, Verilog source files, test source files, and program
# source files. The key targets for this Makefile are as follows:
#
#  - default   : build all programs
#  - check     : build and run all unit tests
#  - clean     : remove all generated content
#

#-------------------------------------------------------------------------
# Basic setup
#-------------------------------------------------------------------------

# Remove all default implicit rules since they can cause subtle bugs
# and they just make things run slower
.SUFFIXES:
% : %,v
% : RCS/%,v
% : RCS/%
% : s.%
% : SCCS/s.%

# Default is to build the prereqs of the all target (defined at bottom)
default : all
.PHONY : default

topdir = ..

#-------------------------------------------------------------------------
# List of subpackages
#-------------------------------------------------------------------------

subpkgs = \
  vc \
  riscvlong \
  riscvbc \

#-------------------------------------------------------------------------
# List of Assembly Tests
#-------------------------------------------------------------------------

tests = \
  riscv-add.vmh \
  riscv-addi.vmh \
  riscv-bne.vmh \
  riscv-blt.vmh \
  riscv-jal.vmh \
  riscv-lui.vmh \
  riscv-lw.vmh \
  riscv-ori.vmh \
  riscv-sw.vmh \
  riscv-jr.vmh \
  riscv-and.vmh \
  riscv-andi.vmh \
  riscv-beq.vmh \
  riscv-bge.vmh \
  riscv-bgeu.vmh \
  riscv-bltu.vmh \
  riscv-div.vmh \
  riscv-divu.vmh \
  riscv-j.vmh \
  riscv-jalr.vmh \
  riscv-lb.vmh \
  riscv-lbu.vmh \
  riscv-lh.vmh \
  riscv-lhu.vmh \
  riscv-mul.vmh \
  riscv-or.vmh \
  riscv-rem.vmh \
  riscv-remu.vmh \
  riscv-sb.vmh \
  riscv-sh.vmh \
  riscv-sll.vmh \
  riscv-slli.vmh \
  riscv-slt.vmh \
  riscv-slti.vmh \
  riscv-sltiu.vmh \
  riscv-sltu.vmh \
  riscv-sra.vmh \
  riscv-srai.vmh \
  riscv-srl.vmh \
  riscv-srli.vmh \
  riscv-sub.vmh \
  riscv-xor.vmh \
  riscv-xori.vmh \

riscvlong_rtl_sim = riscvlong-sim
riscvlong_rtl_rand_sim = riscvlong-randdelay-sim

long_tests_outs = $(patsubst %.vmh,%-long.out,$(tests))
$(long_tests_outs) : %-long.out : %.vmh $(riscvlong_rtl_sim)
	./$(riscvlong_rtl_sim) +stats=1 +exe=$< > $@

long_tests_rand_outs = $(patsubst %.vmh,%-long-rand.out,$(tests))
$(long_tests_rand_outs) : %-long-rand.out : %.vmh $(riscvlong_rtl_rand_sim)
	./$(riscvlong_rtl_rand_sim) +stats=1 +exe=$< > $@

check-asm-riscvlong : $(long_tests_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(long_tests_outs); echo;

check-asm-rand-riscvlong : $(long_tests_rand_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(long_tests_rand_outs); echo;

junk += $(long_tests_outs)
junk += $(long_tests_rand_outs)

# Build and run each cache configuration with a distinct executable and
# output name. This avoids reusing stale artifacts when switching designs.

define riscvbc_asm_test_template
riscvbc_$(1)_rtl_sim      = riscvbc-$(1)-sim
riscvbc_$(1)_rtl_rand_sim = riscvbc-$(1)-randdelay-sim

bc_$(1)_tests_outs = $$(patsubst %.vmh,%$(2).out,$$(tests))
$$(bc_$(1)_tests_outs) : %$(2).out : %.vmh $$(riscvbc_$(1)_rtl_sim)
	./$$(riscvbc_$(1)_rtl_sim) +stats=1 +exe=$$< > $$@

bc_$(1)_tests_rand_outs = $$(patsubst %.vmh,%$(2)-rand.out,$$(tests))
$$(bc_$(1)_tests_rand_outs) : %$(2)-rand.out : %.vmh $$(riscvbc_$(1)_rtl_rand_sim)
	./$$(riscvbc_$(1)_rtl_rand_sim) +stats=1 +exe=$$< > $$@

check-asm-riscvbc-$(1) : $$(bc_$(1)_tests_outs)
	@echo; \
  perl -ne 'print "  [$$$$1] $$$$ARGV \t$$$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $$(bc_$(1)_tests_outs); echo;

check-asm-rand-riscvbc-$(1) : $$(bc_$(1)_tests_rand_outs)
	@echo; \
  perl -ne 'print "  [$$$$1] $$$$ARGV \t$$$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $$(bc_$(1)_tests_rand_outs); echo;

junk += $$(bc_$(1)_tests_outs)
junk += $$(bc_$(1)_tests_rand_outs)
endef

$(eval $(call riscvbc_asm_test_template,none,-none))
$(eval $(call riscvbc_asm_test_template,icache,-icache))
$(eval $(call riscvbc_asm_test_template,dcache,-dcache))
$(eval $(call riscvbc_asm_test_template,all,-all))

check-asm-riscvbc : check-asm-riscvbc-all

check-asm-rand-riscvbc : check-asm-rand-riscvbc-all

.PHONY : \
  check-asm-riscvbc check-asm-rand-riscvbc \
  check-asm-riscvbc-none check-asm-rand-riscvbc-none \
  check-asm-riscvbc-icache check-asm-rand-riscvbc-icache \
  check-asm-riscvbc-dcache check-asm-rand-riscvbc-dcache \
  check-asm-riscvbc-all check-asm-rand-riscvbc-all

riscvmc_rtl_sim      = riscvmc-sim
riscvmc_rtl_rand_sim = riscvmc-randdelay-sim

mc_tests_outs = $(patsubst %.vmh,%-mc.out,$(tests))
$(mc_tests_outs) : %-mc.out : %.vmh $(riscvmc_rtl_sim)
	./$(riscvmc_rtl_sim) +stats=1 +exe=$< > $@

mc_tests_rand_outs = $(patsubst %.vmh,%-mc-rand.out,$(tests))
$(mc_tests_rand_outs) : %-mc-rand.out : %.vmh $(riscvmc_rtl_rand_sim)
	./$(riscvmc_rtl_rand_sim) +stats=1 +exe=$< > $@

check-asm-riscvmc : $(mc_tests_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(mc_tests_outs); echo;

check-asm-rand-riscvmc : $(mc_tests_rand_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(mc_tests_rand_outs); echo;

junk += $(mc_tests_outs)
junk += $(mc_tests_rand_outs)
riscvmc_junk += $(mc_tests_outs)
riscvmc_junk += $(mc_tests_rand_outs)

.PHONY : check-asm-riscvmc check-asm-rand-riscvmc

#-------------------------------------------------------------------------
# List of Benchmarks
#-------------------------------------------------------------------------

bmarks = \
  ubmark-vvadd.vmh \
  ubmark-cmplx-mult.vmh \
  ubmark-masked-filter.vmh \
  ubmark-bin-search.vmh \

cache_stress = ubmark-cache-public.vmh

long_bmarks_outs = $(patsubst %.vmh,%-long.out,$(bmarks))
$(long_bmarks_outs) : %-long.out : %.vmh $(riscvlong_rtl_sim)
	./$(riscvlong_rtl_sim) +verbose=1 +max-cycles=5000000 +exe=$< > $@

run-bmark-riscvlong : $(long_bmarks_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(long_bmarks_outs); echo;

long_bmarks_rand_outs = $(patsubst %.vmh,%-long-rand.out,$(bmarks))

$(long_bmarks_rand_outs) : %-long-rand.out : %.vmh $(riscvlong_rtl_rand_sim)
	./$(riscvlong_rtl_rand_sim) +verbose=1 +exe=$< > $@

run-bmark-rand-riscvlong : $(long_bmarks_rand_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(long_bmarks_rand_outs); echo;

define riscvbc_bmark_template
bc_$(1)_bmarks_outs = $$(patsubst %.vmh,%$(2).out,$$(bmarks))
$$(bc_$(1)_bmarks_outs) : %$(2).out : %.vmh $$(riscvbc_$(1)_rtl_sim)
	./$$(riscvbc_$(1)_rtl_sim) +verbose=1 +max-cycles=5000000 +exe=$$< > $$@

run-bmark-riscvbc-$(1) : $$(bc_$(1)_bmarks_outs)
	@echo; \
  perl -ne 'print "  [$$$$1] $$$$ARGV \t$$$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $$(bc_$(1)_bmarks_outs); echo;

bc_$(1)_bmarks_rand_outs = $$(patsubst %.vmh,%$(2)-rand.out,$$(bmarks))
$$(bc_$(1)_bmarks_rand_outs) : %$(2)-rand.out : %.vmh $$(riscvbc_$(1)_rtl_rand_sim)
	./$$(riscvbc_$(1)_rtl_rand_sim) +verbose=1 +exe=$$< > $$@

run-bmark-rand-riscvbc-$(1) : $$(bc_$(1)_bmarks_rand_outs)
	@echo; \
  perl -ne 'print "  [$$$$1] $$$$ARGV \t$$$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $$(bc_$(1)_bmarks_rand_outs); echo;

junk += $$(bc_$(1)_bmarks_outs)
junk += $$(bc_$(1)_bmarks_rand_outs)
endef

$(eval $(call riscvbc_bmark_template,none,-none))
$(eval $(call riscvbc_bmark_template,icache,-icache))
$(eval $(call riscvbc_bmark_template,dcache,-dcache))
$(eval $(call riscvbc_bmark_template,all,-all))

run-bmark-riscvbc : \
  run-bmark-riscvbc-none \
  run-bmark-riscvbc-icache \
  run-bmark-riscvbc-dcache \
  run-bmark-riscvbc-all

run-bmark-rand-riscvbc : \
  run-bmark-rand-riscvbc-none \
  run-bmark-rand-riscvbc-icache \
  run-bmark-rand-riscvbc-dcache \
  run-bmark-rand-riscvbc-all

.PHONY : \
  run-bmark-riscvbc run-bmark-rand-riscvbc \
  run-bmark-riscvbc-none run-bmark-rand-riscvbc-none \
  run-bmark-riscvbc-icache run-bmark-rand-riscvbc-icache \
  run-bmark-riscvbc-dcache run-bmark-rand-riscvbc-dcache \
  run-bmark-riscvbc-all run-bmark-rand-riscvbc-all

mc_bmarks_outs = $(patsubst %.vmh,%-mc.out,$(bmarks))
mc_cache_stress_out = $(patsubst %.vmh,%-mc.out,$(cache_stress))

$(mc_bmarks_outs) $(mc_cache_stress_out) : %-mc.out : %.vmh $(riscvmc_rtl_sim)
	./$(riscvmc_rtl_sim) +verbose=1 +max-cycles=5000000 +exe=$< > $@

run-bmark-riscvmc : $(mc_bmarks_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(mc_bmarks_outs); echo;

run-cachestress-riscvmc : $(mc_cache_stress_out)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(mc_cache_stress_out); echo;

mc_bmarks_rand_outs = $(patsubst %.vmh,%-mc-rand.out,$(bmarks))
$(mc_bmarks_rand_outs) : %-mc-rand.out : %.vmh $(riscvmc_rtl_rand_sim)
	./$(riscvmc_rtl_rand_sim) +verbose=1 +exe=$< > $@

run-bmark-rand-riscvmc : $(mc_bmarks_rand_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(mc_bmarks_rand_outs); echo;

junk += $(mc_bmarks_outs)
junk += $(mc_cache_stress_out)
junk += $(mc_bmarks_rand_outs)
riscvmc_junk += $(mc_bmarks_outs)
riscvmc_junk += $(mc_cache_stress_out)
riscvmc_junk += $(mc_bmarks_rand_outs)

.PHONY : \
  run-bmark-riscvmc run-bmark-rand-riscvmc \
  run-cachestress-riscvmc

junk += $(long_bmarks_outs)

#-------------------------------------------------------------------------
# Programs
#-------------------------------------------------------------------------

COMP       = iverilog
COMP_FLAGS = -g2005 -Wall -Wno-sensitivity-entire-vector -Wno-sensitivity-entire-array

#-------------------------------------------------------------------------
# Makefile fragments from subpackages
#-------------------------------------------------------------------------

subpkgs_mk := \
  $(join $(addprefix $(topdir)/, $(subpkgs)), \
         $(patsubst %, /%.mk, $(subpkgs)))

-include $(subpkgs_mk)
VPATH := $(addprefix $(topdir)/, $(subpkgs))

VPATH += $(topdir)/tests/build/vmh
VPATH += $(topdir)/ubmark/build/vmh

#-------------------------------------------------------------------------
# Template for per subpackage rules
#-------------------------------------------------------------------------

# Helper template for collecting sources from subpackage dependencies

define subpkg_template_collect_deps
$(1)_deps_srcs += $$($(2)_srcs)
endef

# Main subpackage template

define subpkg_template

# Subpackage subdirectory

$(2)_dir := $$(addprefix $(topdir)/, $(1))

# Subpackage dependencies

$(2)_incs := $$(addprefix -I $(topdir)/, $$($(2)_deps))

$$(foreach dep,$$($(2)_deps), \
  $$(eval $$(call subpkg_template_collect_deps,$(2),$$(dep))))

# Build unit tests

$(2)_test_exes := $$(patsubst %.t.v,%-utst,$$($(2)_test_srcs))

$$($(2)_test_exes) : %-utst : $$($(2)_dir)/%.t.v $$($(2)_srcs) $$($(2)_deps_srcs)
	$(COMP) $(COMP_FLAGS) -o $$@ \
    -I $(topdir)/vc -I $(topdir)/$(2) $$($(2)_incs) $$<

$(2)_junk += $$($(2)_test_exes)

# Run unit tests

$(2)_test_outs := $$(addsuffix .out, $$($(2)_test_exes))

$$($(2)_test_outs) : %.out : %
	./$$< +verbose=2 > $$@

$(2)_junk += $$($(2)_test_outs)

# Build programs

$(2)_prog_exes := $$(patsubst %.v, %, $$($(2)_prog_srcs))

$$($(2)_prog_exes) : % : $$($(2)_dir)/%.v $$($(2)_srcs) $$($(2)_deps_srcs)
	$(COMP) $(COMP_FLAGS) -o $$@ \
    -I $(topdir)/$(2) $$($(2)_incs) $$< -DCACHE_DESIGN=$(DESIGN)

$(2)_junk += $$($(2)_prog_exes)

# Other subpkg specific targets

all-$(1) : $$($(2)_prog_exes)

check-$(1) : $$($(2)_test_outs)
	@echo
	@grep -h -e "Entering Test Suite" -e "FAILED" $($(2)_test_outs)
	@echo;

clean-$(1) :
	rm -rf $$($(2)_junk)

.PHONY : all-$(1) check-$(1) clean-$(1)

# Update running variables

exes += $$($(2)_prog_exes)
outs += $$($(2)_test_outs)
junk += $$($(2)_junk)

endef

# Call template for each subpackage

$(foreach subpkg,$(subpkgs), \
  $(eval $(call subpkg_template,$(subpkg),$(subst -,_,$(subpkg)))))

#-------------------------------------------------------------------------
# Processor Simulators
#-------------------------------------------------------------------------
#
# Each cache configuration has its own executable name so changing the cache
# selection can never reuse a simulator compiled for another configuration.

sim_top_srcs = \
  $(topdir)/Testbench.v \
  $(topdir)/Pattern.v \
  $(topdir)/vc/vc-MemWidthAdapter.v \

sim_incs = \
  -I $(topdir) \
  -I $(topdir)/vc \
  -I $(topdir)/imuldiv \
  -I $(topdir)/riscvlong \
  -I $(topdir)/riscvbc \
  -I $(topdir)/riscvmc \

riscvlong_sim_deps = \
  $(sim_top_srcs) \
  $(riscvlong_srcs) \
  $(riscvlong_deps_srcs) \

riscvbc_sim_deps = \
  $(sim_top_srcs) \
  $(riscvbc_srcs) \
  $(riscvbc_deps_srcs) \

riscvmc_srcs = \
  $(topdir)/riscvmc/riscvmc-CacheMsg.v \
  $(topdir)/riscvmc/riscvmc-CacheIcache.v \
  $(topdir)/riscvmc/riscvmc-CacheDcache.v \
  $(topdir)/riscvmc/riscvmc-CacheAll.v \

riscvmc_sim_deps = \
  $(riscvlong_sim_deps) \
  $(riscvmc_srcs) \

riscvlong-sim : $(riscvlong_sim_deps)
	$(COMP) $(COMP_FLAGS) -o $@ -s Testbench $(sim_incs) \
    $(topdir)/Testbench.v \
    -DPATTERN_MAX_DELAY=50 \
    -DPATTERN_RESET_CYCLES=2 \
    -DPATTERN_DEFAULT_MAX_CYCLES=100000 \
    -DPATTERN_IS_RAND_DELAY=0

riscvlong-randdelay-sim : $(riscvlong_sim_deps)
	$(COMP) $(COMP_FLAGS) -o $@ -s Testbench $(sim_incs) \
    $(topdir)/Testbench.v \
    -DPATTERN_MAX_DELAY=4 \
    -DPATTERN_RESET_CYCLES=6 \
    -DPATTERN_DEFAULT_MAX_CYCLES=100000 \
    -DPATTERN_IS_RAND_DELAY=1

define riscvbc_sim_template
riscvbc-$(1)-sim : $$(riscvbc_sim_deps)
	$$(COMP) $$(COMP_FLAGS) -o $$@ -s Testbench $$(sim_incs) \
    $$(topdir)/Testbench.v \
    -DRISCV_USE_CACHE \
    -DCACHE_DESIGN=$(2) \
    -DPATTERN_MAX_DELAY=50 \
    -DPATTERN_RESET_CYCLES=2 \
    -DPATTERN_DEFAULT_MAX_CYCLES=100000 \
    -DPATTERN_IS_RAND_DELAY=0

riscvbc-$(1)-randdelay-sim : $$(riscvbc_sim_deps)
	$$(COMP) $$(COMP_FLAGS) -o $$@ -s Testbench $$(sim_incs) \
    $$(topdir)/Testbench.v \
    -DRISCV_USE_CACHE \
    -DCACHE_DESIGN=$(2) \
    -DPATTERN_MAX_DELAY=100 \
    -DPATTERN_RESET_CYCLES=500 \
    -DPATTERN_DEFAULT_MAX_CYCLES=50000000 \
    -DPATTERN_IS_RAND_DELAY=1
endef

$(eval $(call riscvbc_sim_template,none,None))
$(eval $(call riscvbc_sim_template,icache,Icache))
$(eval $(call riscvbc_sim_template,dcache,Dcache))
$(eval $(call riscvbc_sim_template,all,All))

riscvmc-sim : $(riscvmc_sim_deps)
	$(COMP) $(COMP_FLAGS) -o $@ -s Testbench $(sim_incs) \
    $(topdir)/Testbench.v \
    -DRISCV_USE_CACHE \
    -DRISCV_USE_MCACHE \
    -DCACHE_DESIGN=MyCache \
    -DPATTERN_MAX_DELAY=50 \
    -DPATTERN_RESET_CYCLES=2 \
    -DPATTERN_DEFAULT_MAX_CYCLES=100000 \
    -DPATTERN_IS_RAND_DELAY=0

riscvmc-randdelay-sim : $(riscvmc_sim_deps)
	$(COMP) $(COMP_FLAGS) -o $@ -s Testbench $(sim_incs) \
    $(topdir)/Testbench.v \
    -DRISCV_USE_CACHE \
    -DRISCV_USE_MCACHE \
    -DCACHE_DESIGN=MyCache \
    -DPATTERN_MAX_DELAY=100 \
    -DPATTERN_RESET_CYCLES=500 \
    -DPATTERN_DEFAULT_MAX_CYCLES=50000000 \
    -DPATTERN_IS_RAND_DELAY=1

riscvlong_sim_exes = \
  riscvlong-sim \
  riscvlong-randdelay-sim \

riscvbc_sim_exes = \
  riscvbc-none-sim \
  riscvbc-icache-sim \
  riscvbc-dcache-sim \
  riscvbc-all-sim \
  riscvbc-none-randdelay-sim \
  riscvbc-icache-randdelay-sim \
  riscvbc-dcache-randdelay-sim \
  riscvbc-all-randdelay-sim \

riscvmc_sim_exes = \
  riscvmc-sim \
  riscvmc-randdelay-sim \

all-riscvlong : $(riscvlong_sim_exes)
all-riscvbc   : $(riscvbc_sim_exes)
all-riscvmc   : $(riscvmc_sim_exes)

riscvlong_junk += $(riscvlong_sim_exes)
riscvbc_junk   += $(riscvbc_sim_exes)
riscvmc_junk   += $(riscvmc_sim_exes)
exes           += $(riscvlong_sim_exes) $(riscvbc_sim_exes) $(riscvmc_sim_exes)
junk           += $(riscvlong_sim_exes) $(riscvbc_sim_exes) $(riscvmc_sim_exes)

clean-riscvmc :
	rm -rf $(riscvmc_junk)

.PHONY : all-riscvmc clean-riscvmc

#-------------------------------------------------------------------------
# Check
#-------------------------------------------------------------------------

check : $(outs)
	@echo "No standalone Verilog unit tests are included in Lab 4."
	@echo "Use the check-asm-* targets below for processor/cache testing."

.PHONY : check

#-------------------------------------------------------------------------
# Default
#-------------------------------------------------------------------------

all : $(exes)
.PHONY : all

#-------------------------------------------------------------------------
# Makefile debugging
#-------------------------------------------------------------------------
# This handy rule will display the contents of any make variable by
# using the target debug-<varname>. So for example, make debug-junk will
# display the contents of the junk variable.

debug-% :
	@echo $* = $($*)

#-------------------------------------------------------------------------
# Clean up junk
#-------------------------------------------------------------------------

clean :
	rm -rf *~ \#* *.vcd $(junk)

.PHONY : clean
