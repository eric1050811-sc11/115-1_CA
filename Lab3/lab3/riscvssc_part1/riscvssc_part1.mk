#=========================================================================
# riscvssc_part1 Subpackage
#=========================================================================

riscvssc_part1_deps = \
  vc \
  imuldiv \

riscvssc_part1_srcs = \
  riscvssc_part1-CoreDpath.v \
  riscvssc_part1-CoreDpathRegfile.v \
  riscvssc_part1-CoreDpathAlu.v \
  riscvssc_part1-CoreDpathPipeMulDiv.v \
  riscvssc_part1-CoreCtrl.v \
  riscvssc_part1-CoreScoreboard.v \
  riscvssc_part1-Core.v \
  riscvssc_part1-InstMsg.v \

riscvssc_part1_test_srcs = \
  riscvssc_part1-InstMsg.t.v \
  riscvssc_part1-CoreDpathPipeMulDiv.t.v \

riscvssc_part1_prog_srcs =

