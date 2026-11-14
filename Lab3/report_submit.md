# 115-1 CA Lab3 Report

## Part 1

### Design

Part 1 adds the scoreboard and the missing control logic: the FUA/FUB pipeline registers, the bubble logic, the PC and fetch fixes, and the steering of inst0/inst1 to FUA/FUB.

#### Scoreboard

Each entry is indexed by destination register and holds a pending bit, a functional-unit slot (FUA: ALU, MEM, MULDIV; FUB: ALU) and a one-hot shift register for the stage the producer is in (X0, X1, X2, X3, W). Unlike Lab 2, every instruction writes back in W after the same 5 stages, so no variable latency has to be tracked.

- Allocate: in decode, for a valid instruction that issues and writes a register other than `x0`, set pending, record the unit and set the stage to `5'b10000` (X0). This is done for both FUA (`dstA`) and FUB (`dstB`, `dstB_en`, `stall_B_Dhl`). A newer writer overwrites the entry, so the bypass always takes the newest value. Two writers to the same register in one cycle cannot happen: steering splits WAW pairs.
- Advance: the stage bit shifts right every cycle, except that an entry in X0 holds while X0 stalls and one in X1 holds while X1 stalls (from X2 on nothing stalls). The entry is released when it leaves W, since the register file only writes at the end of W.
- Outputs are per instruction (inst0/inst1), and steering maps them to FUA/FUB. The bypass select is the producer's current stage (1–5 for FUA's X0–W, 6–10 for FUB's). The value exists from X0 for ALU, X1 for MEM and X3 for MULDIV, and an instruction stalls in decode until then.

#### Control unit

Pipeline registers: the provided control unit lacks the decode signals that FUA's X0 registers latch, and all FUB control registers. FUB only runs simple ALU instructions, so it needs `irB`, `aluB_fn` (to X0), `rfB_wen` and `rfB_waddr` from D to W, plus `rfB_wen_out_Whl` and `irB_debug` in W.

Bubble bits for FUB: in any cycle one issue slot can be empty while the other issues, so FUB needs its own bubble chain. In D, `bubble_sel` is squash or FUA stall, and `bubbleB_sel` is squash or FUB stall; both fall back to the shared `bubble_Dhl`, which describes the whole instruction pair. From X0 on both chains use the stage's `bubble_sel`, and in W each unit writes the register file only with its own valid bit.

PC and fetch: only FUA handles jumps, and a jump may wait in decode. The PC redirect and `squash_Fhl` therefore use `issue_A_Dhl && brj_taken_Dhl`, so a jump redirects only when it leaves decode.

Steering: an instruction is non-ALU if it is a load, store, branch, jump, mul/div or `csrw`; non-ALU instructions can only go to FUA. `steering_mux_sel = (is_alu_0 && is_nonalu_1) || inst0_issued`: the first term is the swap of the spec's Table 1, the second sends inst1 to FUA on its second turn. inst1 cannot issue with inst0 (`split_Dhl`) if both are non-ALU, if it has a RAW or WAW dependency on inst0 (checked here, because inst0 has no scoreboard entry yet in that cycle), or if inst0 is a jump or branch. Stalls are decided per instruction and then mapped to FUA/FUB with `sel`: inst0 stalls on an X0 stall or a hazard; inst1 also stalls when inst0 stalls (in-order issue) or on `split`. If only inst0 issues, `inst0_issued_Dhl` is set and decode holds the pair; on inst1's turn FUB is forced to a bubble, because its slot still holds inst0. A jump in inst0 drops inst1 (wrong path), and a squash clears the bit.

One choice differs from Table 1: a branch in inst0 does not pair with inst1. The branch resolves in X0, when inst1 would already be in FUB's X0 on a possibly wrong path with a scoreboard entry; instead inst1 issues one cycle later, or is squashed with decode if the branch is taken.

### Evaluation

The design passes all assembly tests (43/43) and all ubmarks (4/4) under both normal and randomized-delay simulation.

| ubmark | Instructions | Cycles |  IPC  | Cycles (rand) |
| :----- | -----------: | -----: | ----: | ------------: |
| vvadd  |         1061 |   1424 | 0.745 |          3928 |
| bin-search |     1123 |   1578 | 0.712 |          3331 |
| cmplx-mult |     2946 |   3826 | 0.770 |         10250 |
| masked-filter |  6961 |   8809 | 0.790 |         24926 |

## Part 2

### Profiling

I added simulation-only counters (inside `` `ifndef SYNTHESIS ``) to the control unit. Every cycle, the pair in decode is counted in exactly one category, the first that applies: 1. D empty (bubble or squashed), 2. memory stall, 3. inst1's second turn (issues alone, or waits on a hazard), 4. inst0 hazard, 5. jump, 6. branch hold, 7. both non-ALU, 8. RAW, 9. WAW, 10. inst1 hazard, 11. dual issue. A total counter checks that the categories add up to `num_cycles`. All numbers are from the normal (fixed memory latency) runs. The table shows the Part 1 design and, after the arrow, the final Part 2 design; memory stall, jump, WAW and inst1 hazard are merged into "Other".

| Cycles (Part 1 → final) | vvadd | bin-search | cmplx-mult | masked-filter |
| :-- | --: | --: | --: | --: |
| D empty | 437 → 86 | 470 → 175 | 431 → 192 | 3089 → 423 |
| Second turn, inst1 issues | 321 → 321 | 396 → 366 | 1194 → 1194 | 1126 → 1153 |
| Second turn, inst1 hazard | 3 → 3 | 11 → 30 | 603 → 403 | 3 → 114 |
| inst0 hazard | 85 → 85 | 77 → 58 | 113 → 113 | 760 → 512 |
| Branch hold | 90 → 90 | 239 → 191 | 119 → 119 | 780 → 752 |
| Both non-ALU | 284 → 284 | 26 → 45 | 829 → 829 | 689 → 745 |
| RAW | 31 → 31 | 239 → 239 | 258 → 258 | 348 → 320 |
| Other | 5 → 5 | 11 → 12 | 6 → 6 | 4 → 33 |
| Dual issue | 168 → 168 | 109 → 138 | 273 → 273 | 2010 → 1982 |
| **Total (`num_cycles`)** | **1424 → 1073** | **1578 → 1254** | **3826 → 3387** | **8809 → 6034** |
| Taken branches / jumps (count) | 145 / 5 | 135 / 55 | 105 / 35 | 1114 / 8 |

In the Part 1 design, decode is empty for about a third of all cycles in vvadd, bin-search and masked-filter. Dividing those cycles by the redirects (taken branches and jumps) gives 2.5–3.1 cycles each, so almost all of them are the refill after a taken branch, which only redirects when it resolves in X0. The other large costs are single issue: pairs that both need FUA, and in cmplx-mult inst1 waiting for a `mul` result (603 cycles). Memory stalls are 0 and WAW pairs only 2 cycles, so these were not targeted.

### Optimization strategy

1. Branch prediction, for the largest category (D empty) in three of the four benchmarks.
2. After prediction, cmplx-mult was the only benchmark above its Level 2 limit, and its remaining cost was not branches but `mul` waits. Counting the blocking producer in its 603 second-turn hazard cycles showed a `mul` in X2 in 200 of them, which a later bypass can remove.

### Design

Quick resource check for all changes: two ALUs, one multiplier, two IMEM and one DMEM port, a 4-read/2-write register file and 7 stages are unchanged. The BTB is storage, its tag and target checks are equality comparators, and pc+4/pc+8 already exist, so no ALU or adder is added.

#### Branch prediction

The first version predicted in decode, with 32 two-bit counters indexed by PC bits 6–2 and the target from `branch_targ_Dhl`. It met Level 1 (1228 / 1460 / 3759 / 7368 cycles), but a redirect from decode still costs a bubble, because the pair after the branch is already being fetched.

The final design predicts in fetch instead.

- BTB in the datapath: 32 entries indexed by PC bits 6–2, each with a valid bit, a tag (PC bits 31–7), a target and a 2-bit counter. Fetch looks up both slots of its pair (`pc_Fhl`, `pc_Fhl+4`). On a hit predicted taken, the next fetch goes to the stored target instead of pc+8 (slot 0 wins). This is not a squash: the pair in fetch is correct, only the next fetch address changes.
- Check in decode: the per-slot guess and the target used travel with the pair. A branch is predicted taken only if fetch guessed it and the stored target equals `branch_targ_Dhl`; a predicted-taken branch in inst0 drops inst1 like a jump. A `jal` already redirected to `jump_targ_Dhl` does not redirect again; other jumps redirect from decode. If fetch guessed a slot taken but decode finds no taken branch or jump there, decode redirects to the pair's pc+8 and keeps inst1.
- X0: compares the outcome with the prediction. A correctly predicted taken branch no longer squashes; a misprediction redirects to the branch target or to its fall-through PC (new pipeline register `pcA_plus4_X0hl`) and squashes fetch and decode, with priority over a decode redirect. X0 also updates the BTB once per branch (a taken branch fills or counts up, a not-taken branch counts down); a `jal` leaving decode fills an entry, `jalr` is never stored.
- The PC mux select grows to 3 bits for three new inputs: X0 fall-through, BTB target, decode pair pc+8. The pending-redirect latch in the datapath now lets a redirect in the current cycle win over a pending one, so an X0 misprediction cannot be lost behind an older redirect.

I also tried keeping the decode counters as a second stage behind the BTB. It corrected the BTB only 1 / 0 / 11 / 1 times, and in cmplx-mult its untagged table was worse (28 mispredictions instead of 14), so the final design uses the BTB alone.

#### Late bypass of multiply results

A consumer of a `mul` waited in decode until the `mul` reached X3. A consumer that issues while the `mul` is in X2 enters X0 exactly when the `mul` is in X3 (X2 and X3 never stall), so it can take the value there one cycle earlier.

Here are the modifications for late bypass:

- Scoreboard: a `mul` in X2 is no longer a hazard and reports a "late" bit for that source. Consumers that read operands in decode keep the stall: `mul`/`div` (the multiplier takes its operands in decode) and `jalr` (target computed in decode).
- Control: the late bits are steered to FUA/FUB and kept only where the operand comes from a register: FUA operands 0/1, FUA store data, FUB operands 0/1. These five flags travel into X0.
- Datapath: in X0 a flagged operand is taken from the `mul` result in X3, which covers the ALU inputs, the branch condition and the store data. If X0 stalls, the forwarded value is written into the X0 operand register in that cycle and the flag is cleared, because the `mul` moves on.

### Evaluation

All three Part 2 versions pass all assembly tests and ubmarks under normal and randomized-delay simulation. Also all four ubmarks meet both Level 1 and Level 2 cycle limits.

| ubmark | Part 1 | Decode prediction | Fetch prediction | + Late bypass (final) | Speedup | Level 1 | Level 2 |
| :------------ | ---: | ---: | ---: | ---: | ----: | ---: | ---: |
| vvadd         | 1424 | 1228 | 1073 | 1073 | 1.33× | 1400 | 1200 |
| bin-search    | 1578 | 1460 | 1254 | 1254 | 1.26× | 1500 | 1300 |
| cmplx-mult    | 3826 | 3759 | 3587 | 3387 | 1.13× | 4000 | 3500 |
| masked-filter | 8809 | 7368 | 6199 | 6034 | 1.46× | 8500 | 7500 |

Branch prediction contributes most: it removes 80–86% of the D-empty cycles in vvadd and masked-filter (mispredictions: 19/158, 63/262, 14/300, 90/1224). The late bypass removes exactly the 200 measured cycles in cmplx-mult (and 165 in masked-filter) and brings it under its Level 2 limit.

### Analysis

The remaining cycles are mostly single issue (the profile above):

- FUA is the bottleneck. Every load, store, branch, jump and mul/div needs FUA, so cycles cannot go below the number of such instructions: 778 / 469 / 2343 / 4000. vvadd, cmplx-mult and masked-filter are FUA-bound, and most "both non-ALU" pairs are two memory operations (281 / 15 / 626 / 688), which the single dmem port can never issue together.
- inst1 alone on its second turn (19–35%): issue is tied to the fetched pair. Pairing a leftover inst1 with the next instruction (an instruction buffer) could add at most 59 / 67 / 66 / 236 pairs by estimation, since the next instruction is often non-ALU too.
- `mul`/load waits: 403 cycles remain in cmplx-mult, while the next element's independent loads wait behind the stalled instruction. Only out-of-order issue (issue queue and reorder buffer) would fill them; loads would then also need to pass older stores safely.
- Branches: part of the remaining D-empty cycles are cold BTB misses (first execution) and mispredictions; a 4× larger BTB changed no cycle count.
