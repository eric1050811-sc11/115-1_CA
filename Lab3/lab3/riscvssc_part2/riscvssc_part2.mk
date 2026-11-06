#=========================================================================
# riscvssc_part2 Subpackage
#=========================================================================

riscvssc_part2_deps = \
  vc \
  imuldiv \

riscvssc_part2_srcs = \
  riscvssc_part2-CoreDpath.v \
  riscvssc_part2-CoreDpathRegfile.v \
  riscvssc_part2-CoreDpathAlu.v \
  riscvssc_part2-CoreDpathPipeMulDiv.v \
  riscvssc_part2-CoreCtrl.v \
  riscvssc_part2-CoreScoreboard.v \
  riscvssc_part2-Core.v \
  riscvssc_part2-InstMsg.v \

riscvssc_part2_test_srcs = \
  riscvssc_part2-InstMsg.t.v \
  riscvssc_part2-CoreDpathPipeMulDiv.t.v \

riscvssc_part2_prog_srcs =

