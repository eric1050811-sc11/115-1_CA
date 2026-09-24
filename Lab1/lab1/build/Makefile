#=========================================================================
# Lab 1 Verilog Build
#=========================================================================

.SUFFIXES:
% : %,v
% : RCS/%,v
% : RCS/%
% : s.%
% : SCCS/s.%

default : all
.PHONY : default

topdir = ..

#-------------------------------------------------------------------------
# Tools
#-------------------------------------------------------------------------

COMP       ?= iverilog
COMP_FLAGS ?= -g2005 -Wall -Wno-sensitivity-entire-vector -Wno-sensitivity-entire-array
VVP        ?= vvp
PYTHON     ?= python3

RISCV_GCC     ?= $(firstword $(shell command -v riscv32-unknown-elf-gcc 2>/dev/null) $(shell command -v riscv64-unknown-elf-gcc 2>/dev/null) riscv32-unknown-elf-gcc)
RISCV_OBJDUMP ?= $(firstword $(shell command -v riscv32-unknown-elf-objdump 2>/dev/null) $(shell command -v riscv64-unknown-elf-objdump 2>/dev/null) riscv32-unknown-elf-objdump)

RISCV_TEST_FLAGS ?= \
  -march=rv32im \
  -mabi=ilp32 \
  -T $(topdir)/tests/scripts/test.ld \
  -nostartfiles \
  -nostdlib \
  -I $(topdir)/tests/riscv

#-------------------------------------------------------------------------
# Lab 1 assembly tests
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
  riscv-sub.vmh \
  riscv-and.vmh \
  riscv-or.vmh \
  riscv-xor.vmh \
  riscv-slt.vmh \
  riscv-sltu.vmh \
  riscv-sra.vmh \
  riscv-srl.vmh \
  riscv-sll.vmh \
  riscv-mul.vmh \
  riscv-div.vmh \
  riscv-divu.vmh \
  riscv-rem.vmh \
  riscv-remu.vmh \
  riscv-andi.vmh \
  riscv-xori.vmh \
  riscv-slti.vmh \
  riscv-sltiu.vmh \
  riscv-srai.vmh \
  riscv-srli.vmh \
  riscv-slli.vmh \
  riscv-lh.vmh \
  riscv-lhu.vmh \
  riscv-lb.vmh \
  riscv-lbu.vmh \
  riscv-sh.vmh \
  riscv-sb.vmh \
  riscv-jalr.vmh \
  riscv-beq.vmh \
  riscv-bltu.vmh \
  riscv-bge.vmh \
  riscv-bgeu.vmh \
  riscv-mulh.vmh \
  riscv-mulhu.vmh \
  riscv-mulhsu.vmh



bmarks = \
  ubmark-vvadd.vmh \
  ubmark-cmplx-mult.vmh \
  ubmark-masked-filter.vmh \
  ubmark-bin-search.vmh \

#-------------------------------------------------------------------------
# Source packages
#-------------------------------------------------------------------------

subpkgs = \
  vc \
  imuldiv \
  riscvstall \

# Enable these after running their setup.sh scripts.
subpkgs += riscvbyp
# subpkgs += riscvlong

subpkgs_mk := \
  $(join $(addprefix $(topdir)/, $(subpkgs)), \
         $(patsubst %, /%.mk, $(subpkgs)))

-include $(subpkgs_mk)

VPATH := $(topdir)/tests/build/vmh
VPATH += $(topdir)/ubmark/build/vmh

check-riscv-tools :
	@command -v $(RISCV_GCC) >/dev/null 2>&1 || \
	  { echo "ERROR: cannot find RISCV_GCC ($(RISCV_GCC)); set RISCV_GCC=<path>"; exit 1; }
	@command -v $(RISCV_OBJDUMP) >/dev/null 2>&1 || \
	  { echo "ERROR: cannot find RISCV_OBJDUMP ($(RISCV_OBJDUMP)); set RISCV_OBJDUMP=<path>"; exit 1; }

%.elf : $(topdir)/tests/riscv/%.S $(topdir)/tests/riscv/riscv-macros.h $(topdir)/tests/scripts/test.ld | check-riscv-tools
	$(RISCV_GCC) $(RISCV_TEST_FLAGS) -o $@ $<

%.dump : %.elf
	$(RISCV_OBJDUMP) -EL -sz --section=.xcpthandler --section=.text --section=.data $< > $@

%.vmh : %.dump
	$(PYTHON) $(topdir)/tests/scripts/objdump2vmh.py $< > $@

.PHONY : check-riscv-tools

vc_src_paths      = $(addprefix $(topdir)/vc/,$(vc_srcs))
imuldiv_src_paths = $(addprefix $(topdir)/imuldiv/,$(imuldiv_srcs))

common_src_paths = \
  $(topdir)/Testbench.v \
  $(topdir)/Pattern.v \
  $(vc_src_paths) \
  $(imuldiv_src_paths) \

sim_incs = \
  -I $(topdir) \
  -I $(topdir)/vc \
  -I $(topdir)/imuldiv \
  -I $(topdir)/riscvstall \

# Enable these after running their setup.sh scripts.
sim_incs += -I $(topdir)/riscvbyp
sim_incs += -I $(topdir)/riscvlong

PATTERN_DEFAULT_MAX_CYCLES      ?= 100000
RAND_PATTERN_DEFAULT_MAX_CYCLES ?= 500000
RAND_PATTERN_MAX_DELAY          ?= 4
RAND_PATTERN_RESET_CYCLES       ?= 6
VCD                             ?= 0

ASM_SIM_FLAGS   ?= +stats=1 +vcd=$(VCD)
BMARK_SIM_FLAGS ?= +verbose=1 +vcd=$(VCD)

sim_exes =
outs     =
junk     =
junk += $(patsubst %.vmh,%.elf,$(tests))
junk += $(patsubst %.vmh,%.dump,$(tests))
junk += $(tests)

#-------------------------------------------------------------------------
# Processor simulator rules
#-------------------------------------------------------------------------

define proc_template
$(1)_src_paths = $$(addprefix $$(topdir)/$(1)/,$$($(1)_srcs))
$(1)_sim_deps  = $$(common_src_paths) $$($(1)_src_paths)

$(1)-sim : $$($(1)_sim_deps)
	$$(COMP) $$(COMP_FLAGS) -o $$@ -s Testbench $$(sim_incs) \
	  $$(topdir)/Testbench.v \
	  -DRISCV_CORE_$(2) \
	  -DPATTERN_MAX_DELAY=0 \
	  -DPATTERN_RESET_CYCLES=2 \
	  -DPATTERN_DEFAULT_MAX_CYCLES=$$(PATTERN_DEFAULT_MAX_CYCLES) \
	  -DPATTERN_IS_RAND_DELAY=0

$(1)-randdelay-sim : $$($(1)_sim_deps)
	$$(COMP) $$(COMP_FLAGS) -o $$@ -s Testbench $$(sim_incs) \
	  $$(topdir)/Testbench.v \
	  -DRISCV_CORE_$(2) \
	  -DPATTERN_MAX_DELAY=$$(RAND_PATTERN_MAX_DELAY) \
	  -DPATTERN_RESET_CYCLES=$$(RAND_PATTERN_RESET_CYCLES) \
	  -DPATTERN_DEFAULT_MAX_CYCLES=$$(RAND_PATTERN_DEFAULT_MAX_CYCLES) \
	  -DPATTERN_IS_RAND_DELAY=1

$(1)_sim_exes = \
  $(1)-sim \
  $(1)-randdelay-sim \

all-$(1) : $$($(1)_sim_exes)
all-$(3) : all-$(1)

.PHONY : all-$(1) all-$(3)

sim_exes += $$($(1)_sim_exes)
junk     += $$($(1)_sim_exes)
endef

$(eval $(call proc_template,riscvstall,RISCVSTALL,stall))

# Enable these after running their setup.sh scripts.
$(eval $(call proc_template,riscvbyp,RISCVBYP,byp))
$(eval $(call proc_template,riscvlong,RISCVLONG,long))

#-------------------------------------------------------------------------
# Assembly test rules
#-------------------------------------------------------------------------

define asm_template
$(1)_tests_outs = $$(patsubst %.vmh,%-$(3).out,$$(tests))
$$($(1)_tests_outs) : %-$(3).out : %.vmh $(1)-sim
	$$(VVP) ./$(1)-sim $$(ASM_SIM_FLAGS) +exe=$$< > $$@

$(1)_tests_rand_outs = $$(patsubst %.vmh,%-$(3)-rand.out,$$(tests))
$$($(1)_tests_rand_outs) : %-$(3)-rand.out : %.vmh $(1)-randdelay-sim
	$$(VVP) ./$(1)-randdelay-sim $$(ASM_SIM_FLAGS) +exe=$$< > $$@

check-asm-$(1) : $$($(1)_tests_outs)
	@echo
	@perl -ne 'print "  [$$$$1] $$$$ARGV\t$$$$2\n" if /\*{3}(.{8})\*{3}(.*)/' $$^
	@echo

check-asm-$(3) : check-asm-$(1)

check-asm-rand-$(1) : $$($(1)_tests_rand_outs)
	@echo
	@perl -ne 'print "  [$$$$1] $$$$ARGV\t$$$$2\n" if /\*{3}(.{8})\*{3}(.*)/' $$^
	@echo

check-asm-rand-$(3) : check-asm-rand-$(1)

.PHONY : check-asm-$(1) check-asm-$(3) check-asm-rand-$(1) check-asm-rand-$(3)

outs += $$($(1)_tests_outs)
junk += $$($(1)_tests_outs) $$($(1)_tests_rand_outs)
endef

$(eval $(call asm_template,riscvstall,RISCVSTALL,stall))

# Enable these after running their setup.sh scripts.
$(eval $(call asm_template,riscvbyp,RISCVBYP,byp))
$(eval $(call asm_template,riscvlong,RISCVLONG,long))

check-asm : check-asm-riscvbyp
check-asm-rand : check-asm-rand-riscvbyp

.PHONY : check-asm check-asm-rand

#-------------------------------------------------------------------------
# Benchmark rules
#-------------------------------------------------------------------------

define bmark_template
$(1)_bmarks_outs = $$(patsubst %.vmh,%-$(3).out,$$(bmarks))
$$($(1)_bmarks_outs) : %-$(3).out : %.vmh $(1)-sim
	$$(VVP) ./$(1)-sim $$(BMARK_SIM_FLAGS) +exe=$$< > $$@

$(1)_bmarks_rand_outs = $$(patsubst %.vmh,%-$(3)-rand.out,$$(bmarks))
$$($(1)_bmarks_rand_outs) : %-$(3)-rand.out : %.vmh $(1)-randdelay-sim
	$$(VVP) ./$(1)-randdelay-sim $$(BMARK_SIM_FLAGS) +exe=$$< > $$@

run-bmark-$(1) : $$($(1)_bmarks_outs)
	@echo
	@perl -ne 'print "  [$$$$1] $$$$ARGV\t$$$$2\n" if /\*{3}(.{8})\*{3}(.*)/' $$^
	@echo

run-bmark-$(3) : run-bmark-$(1)

run-bmark-rand-$(1) : $$($(1)_bmarks_rand_outs)
	@echo
	@perl -ne 'print "  [$$$$1] $$$$ARGV\t$$$$2\n" if /\*{3}(.{8})\*{3}(.*)/' $$^
	@echo

run-bmark-rand-$(3) : run-bmark-rand-$(1)

.PHONY : run-bmark-$(1) run-bmark-$(3) run-bmark-rand-$(1) run-bmark-rand-$(3)

junk += $$($(1)_bmarks_outs) $$($(1)_bmarks_rand_outs)
endef

$(eval $(call bmark_template,riscvstall,RISCVSTALL,stall))

# Enable these after running their setup.sh scripts.
$(eval $(call bmark_template,riscvbyp,RISCVBYP,byp))
$(eval $(call bmark_template,riscvlong,RISCVLONG,long))

#-------------------------------------------------------------------------
# Aggregate targets
#-------------------------------------------------------------------------

all : $(sim_exes)
check : check-asm

.PHONY : all check

#-------------------------------------------------------------------------
# Makefile debugging
#-------------------------------------------------------------------------

debug-% :
	@echo $* = $($*)

#-------------------------------------------------------------------------
# Clean
#-------------------------------------------------------------------------

clean :
	rm -rf *~ \#* *.vcd $(junk)

.PHONY : clean








