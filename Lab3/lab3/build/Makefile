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
  imuldiv \
  mcriscv \
  riscvssc_part1 \
  riscvssc_part2 \

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

riscvssc_part1_rtl_sim = riscvssc_part1-sim
riscvssc_part1_rtl_rand_sim = riscvssc_part1-randdelay-sim
riscvssc_part2_rtl_sim = riscvssc_part2-sim
riscvssc_part2_rtl_rand_sim = riscvssc_part2-randdelay-sim

ssc_part1_tests_outs = $(patsubst %.vmh,%-ssc_part1.out,$(tests))
$(ssc_part1_tests_outs) : %-ssc_part1.out : %.vmh $(riscvssc_part1_rtl_sim)
	./$(riscvssc_part1_rtl_sim) +stats=1 +stats=1 +vcd=1 +exe=$< > $@

ssc_part1_tests_rand_outs = $(patsubst %.vmh,%-ssc_part1-rand.out,$(tests))
$(ssc_part1_tests_rand_outs) : %-ssc_part1-rand.out : %.vmh $(riscvssc_part1_rtl_rand_sim)
	./$(riscvssc_part1_rtl_rand_sim) +stats=1 +stats=1 +vcd=1 +exe=$< > $@

ssc_part2_tests_outs = $(patsubst %.vmh,%-ssc_part2.out,$(tests))
$(ssc_part2_tests_outs) : %-ssc_part2.out : %.vmh $(riscvssc_part2_rtl_sim)
	./$(riscvssc_part2_rtl_sim) +stats=1 +stats=1 +vcd=1 +exe=$< > $@

ssc_part2_tests_rand_outs = $(patsubst %.vmh,%-ssc_part2-rand.out,$(tests))
$(ssc_part2_tests_rand_outs) : %-ssc_part2-rand.out : %.vmh $(riscvssc_part2_rtl_rand_sim)
	./$(riscvssc_part2_rtl_rand_sim) +stats=1 +stats=1 +vcd=1 +exe=$< > $@

check-asm-riscvssc_part1 : $(ssc_part1_tests_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(ssc_part1_tests_outs); echo;

check-asm-rand-riscvssc_part1 : $(ssc_part1_tests_rand_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(ssc_part1_tests_rand_outs); echo;

check-asm-riscvssc_part2 : $(ssc_part2_tests_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(ssc_part2_tests_outs); echo;

check-asm-rand-riscvssc_part2 : $(ssc_part2_tests_rand_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(ssc_part2_tests_rand_outs); echo;

junk += $(ssc_part1_tests_outs)
junk += $(ssc_part1_tests_rand_outs)
junk += $(ssc_part2_tests_outs)
junk += $(ssc_part2_tests_rand_outs)

#-------------------------------------------------------------------------
# List of Benchmarks
#-------------------------------------------------------------------------

bmarks = \
  ubmark-vvadd.vmh \
  ubmark-cmplx-mult.vmh \
  ubmark-masked-filter.vmh \
  ubmark-bin-search.vmh \

ssc_part1_bmarks_outs = $(patsubst %.vmh,%-ssc_part1.out,$(bmarks))
$(ssc_part1_bmarks_outs) : %-ssc_part1.out : %.vmh $(riscvssc_part1_rtl_sim)
	./$(riscvssc_part1_rtl_sim) +verbose=1 +stats=1 +vcd=1 +exe=$< > $@

ssc_part2_bmarks_outs = $(patsubst %.vmh,%-ssc_part2.out,$(bmarks))
$(ssc_part2_bmarks_outs) : %-ssc_part2.out : %.vmh $(riscvssc_part2_rtl_sim)
	./$(riscvssc_part2_rtl_sim) +verbose=1 +stats=1 +vcd=1 +exe=$< > $@

run-bmark-riscvssc_part1 : $(ssc_part1_bmarks_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(ssc_part1_bmarks_outs); echo;

run-bmark-riscvssc_part2 : $(ssc_part2_bmarks_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(ssc_part2_bmarks_outs); echo;

ssc_part1_bmarks_rand_outs = $(patsubst %.vmh,%-ssc_part1-rand.out,$(bmarks))
ssc_part2_bmarks_rand_outs = $(patsubst %.vmh,%-ssc_part2-rand.out,$(bmarks))

$(ssc_part1_bmarks_rand_outs) : %-ssc_part1-rand.out : %.vmh $(riscvssc_part1_rtl_rand_sim)
	./$(riscvssc_part1_rtl_rand_sim) +verbose=1 +stats=1 +vcd=1 +exe=$< > $@

$(ssc_part2_bmarks_rand_outs) : %-ssc_part2-rand.out : %.vmh $(riscvssc_part2_rtl_rand_sim)
	./$(riscvssc_part2_rtl_rand_sim) +verbose=1 +stats=1 +vcd=1 +exe=$< > $@

run-bmark-rand-riscvssc_part1 : $(ssc_part1_bmarks_rand_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(ssc_part1_bmarks_rand_outs); echo;

run-bmark-rand-riscvssc_part2 : $(ssc_part2_bmarks_rand_outs)
	@echo; \
  perl -ne 'print "  [$$1] $$ARGV \t$$2\n" if /\*{3}(.{8})\*{3}(.*)/' \
       $(ssc_part2_bmarks_rand_outs); echo;

junk += $(ssc_part1_bmarks_outs)
junk += $(ssc_part1_bmarks_rand_outs)
junk += $(ssc_part2_bmarks_outs)
junk += $(ssc_part2_bmarks_rand_outs)

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
    -I $(topdir)/$(2) $$($(2)_incs) $$<

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
# Processor simulators: built from the top-level Testbench and Pattern
#-------------------------------------------------------------------------

sim_top_srcs  = $(topdir)/Testbench.v $(topdir)/Pattern.v $(topdir)/InstCounter.v
sim_incs      = -I $(topdir) -I $(topdir)/vc -I $(topdir)/imuldiv

sim_defs      = -DPATTERN_MAX_DELAY=0 -DPATTERN_RESET_CYCLES=2 \
                -DPATTERN_DEFAULT_MAX_CYCLES=100000 -DPATTERN_IS_RAND_DELAY=0
sim_rand_defs = -DPATTERN_MAX_DELAY=4 -DPATTERN_RESET_CYCLES=6 \
                -DPATTERN_DEFAULT_MAX_CYCLES=100000 -DPATTERN_IS_RAND_DELAY=1

riscvssc_part1_sim_deps = $(sim_top_srcs) $(riscvssc_part1_srcs) $(riscvssc_part1_deps_srcs)
riscvssc_part2_sim_deps = $(sim_top_srcs) $(riscvssc_part2_srcs) $(riscvssc_part2_deps_srcs)

riscvssc_part1-sim : $(riscvssc_part1_sim_deps)
	$(COMP) $(COMP_FLAGS) -o $@ -s Testbench $(sim_incs) -I $(riscvssc_part1_dir) \
    $(sim_defs) $(topdir)/Testbench.v

riscvssc_part1-randdelay-sim : $(riscvssc_part1_sim_deps)
	$(COMP) $(COMP_FLAGS) -o $@ -s Testbench $(sim_incs) -I $(riscvssc_part1_dir) \
    $(sim_rand_defs) $(topdir)/Testbench.v

riscvssc_part2-sim : $(riscvssc_part2_sim_deps)
	$(COMP) $(COMP_FLAGS) -o $@ -s Testbench $(sim_incs) -I $(riscvssc_part2_dir) \
    -DRISCV_CORE_PART2 $(sim_defs) $(topdir)/Testbench.v

riscvssc_part2-randdelay-sim : $(riscvssc_part2_sim_deps)
	$(COMP) $(COMP_FLAGS) -o $@ -s Testbench $(sim_incs) -I $(riscvssc_part2_dir) \
    -DRISCV_CORE_PART2 $(sim_rand_defs) $(topdir)/Testbench.v

riscvssc_part1_sim_exes = riscvssc_part1-sim riscvssc_part1-randdelay-sim
riscvssc_part2_sim_exes = riscvssc_part2-sim riscvssc_part2-randdelay-sim

all-riscvssc_part1 : $(riscvssc_part1_sim_exes)
all-riscvssc_part2 : $(riscvssc_part2_sim_exes)

exes += $(riscvssc_part1_sim_exes) $(riscvssc_part2_sim_exes)
junk += $(riscvssc_part1_sim_exes) $(riscvssc_part2_sim_exes)

#-------------------------------------------------------------------------
# Check
#-------------------------------------------------------------------------

check : $(outs)
	@echo
	@grep -h -e "Entering Test Suite" -e "FAILED" $(outs)
	@echo;

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
