# 115-1 CA Lab3 Report

## Part 1

### Design

Here we are going to implement the missing part of the two wide superscalar, including:

- scoreboard
- control unit
  - FUA/B pipeline stage registers
  - bubble logic
  - PC and fetch stage fix
  - steering logic: inst0/1 to FUA/B

#### Scoreboard

The design of scoreboard is similar to the one in Lab2. But instead of varying length for register latency, the scoreboard entries here always travel through 5 stages (X0, X1, X2, X3, W). Overall, the design is simpler compared to the one in Lab2.

The default IO ports already listed the ports for functional unit A, we only need 3 more inputs from functional unit B, `dstB`, `dstB_en` and `stall_B_Dhl`, since the functional unit B only handles simple ALU operations within a single cycle, therefore won't stall the later instruction.

Observe the bypass mux defined in datapath, we have 10 different places to bypass from (1-5: FUA's X0-W; 6-10: FUB's X0-W). And we need to track which write destination is in which functional unit/operation (FUA: ALU, MEM, MULDIV; FUB: ALU) for the bypass check.

As shown in the spec, an entry in our scoreboard uses destination register as index, needs a pending bit, a functional unit slot, and a one-hot latency shift register, just like the one in Lab2.

The allocate logic is similar: in issue (decode) stage (with the valid instruction, and the destination register not `x0`, not stalling), allocate an entry with pending bit set to 1, record the functional unit and operation the destination register is going to, and set the latency to `5'b10000` (`X0`), for both functional unit A and B. Here we might have both functional units compete for same destination register, my design handles this in steering logic, so we don't need specific checking here.

The expired logic is simple, without stalling (an entry in X0 holds while X0 stalls, same for X1, from X2 on it never stalls), the latency register shifts right by one bit. Once the latency register reaches 1 (instruction reaches writeback stage), scoreboard can release the entry in next cycle, mark not pending.

For bypass mux outputs, the selections are based on the current stage of each destination register inside scoreboard, and the latency register together with the functional unit determines whether the data is ready. If not, the instruction stalls in issue (decode) stage. The selection always selects the newest data in the pipeline. Here the bypass outputs are for inst0/inst1, and steering logic will map them to FUA/B after deciding which FU those instructions are going to.

For stall signals, since the data from muldiv/memory operation is ready in X3/X1, any reference before that causes a stall. If any instruction wants to reference them in issue (decode), they must stall until the data is ready to be bypassed.

#### Control Unit

##### Pipeline stage registers

This is the easiest one to implement first. The provided source code does not have the latch signals in decode stage for FUA, and the following between X0, X1, X2, X3 to W for FUB. Declare them and add them first.

The missing signals for FUA can be derived from X0<-D section. For FUB, since FUB only handles simple ALU, we only need to add `irB_*hl` from D to W, `aluB_fn_*hl` from D to X0, `rfB_wen_*hl`, `rfB_waddr_*hl` from D to W. And in W, update `rfB_wen_out_Whl` and `irB_debug`.

##### Bubble bit

FUA/B can't shared same bubble chain, because sometimes one of the issue slot can be empty while another issues, and their bubble chain won't matched, so a dedicated bubble chain for FUB is needed.

The missing `bubble_sel_Dhl` for FUA is similar to the one in Lab2, need to consider squashing decode and stalling FUA, `bubble_next_Dhl` works fine here. For FUB, create `bubbleB_sel_Dhl` and check for squashing decode and stalling FUB, copy the pattern from FUA's for `bubbleB_next_Dhl`. `bubble_next_Dhl` and `bubbleB_next_Dhl` share the bubble bit in decode since it describes the whole instruction pair.

In the following stages (X0-X3), both FUs share the same `bubble_sel_*hl` since both FUs share squash and stall signals, only need to create `bubbleB_next_*hl`. And need to add the missing `bubbleB_*hl` for stages too (X0-W). After reaching W, since each functional unit use their valid bit to write regfile, we can just use `bubbleB_Whl` to check if the register write reaching W is a bubble or not.

##### PC and fetch stage fixes

Now only FUA handles jumps, and a jump might not issue this cycle. So we need to change the `pc_mux_sel_Phl` from `brj_taken_Dhl` to `issue_A_Dhl && brj_taken_Dhl`, in this way we guard that a jump switches the PC only if the instruction is leaving decode.

And `squash_Fhl` needs to consider whether the jump in FUA is actually leaving decode, so that it can squash the fetch stage safely. Change `( inst_val_Dhl && brj_taken_Dhl )` to `( issue_A_Dhl && brj_taken_Dhl )` for `squash_Fhl`.

##### Steering logic

This is the most important part of the whole superscalar processor. We have added the pipeline registers from D to FUA and FUB, the only thing left is to steer the inst0/1 to them depending on inst0/1 instruction type.

The core idea of steering is shown in the spec, so here we implement the checks:

- `is_alu_0/1` and `is_nonalu_0/1` for instruction type check, an instruction is non-ALU if it is memory/branch/jump/muldiv/csrw, others are considered ALU. Non-ALU can only go to FUA
- `is_jump_0_Dhl` and `is_branch_0_Dhl` check whether inst0 is a jump/branch, these can only steer to FUA, and let inst1 wait
- `raw_1_on_0_Dhl` and `waw_1_on_0_Dhl`, if inst1 has raw/waw hazard on inst0, it needs to wait for inst0, which also protects the scoreboard from 2 instructions competing for allocation (waw hazard) as mentioned before in scoreboard section
- `split_Dhl`, inst1 can't issue in the same cycle as inst0, situations like both non-ALU, raw/waw hazard, jump/branch, are bundled into this signal
- `inst0_issued_Dhl` marks whether inst0 has already issued alone, with it set to 1, we still need to issue inst1

And the stall conditions:

- `stall_0_Dhl` check if X0 stalls, or inst0 has a data hazard, inst0 can't issue
- `stall_1_Dhl` check if X0 stalls, or inst1 has a data hazard, or need to issue inst0 first (including stalled inst0), or `split_Dhl`, inst1 can't issue

Then we steer `stall_0/1_Dhl` to `stall_A/B_Dhl` depending on `steering_mux_sel_Dhl`. On inst1's second turn, `stall_B_Dhl` is forced to 1, since FUB still holds inst0 which has already issued.

`steering_mux_sel_Dhl = (is_alu_0 && is_nonalu_1) || inst0_issued_Dhl;` this line is the core of steering:

- `(is_alu_0 && is_nonalu_1)` part handles issuing 2 instructions swaping correctly
- `inst0_issued_Dhl` sends inst1 to FUA on its second turn, while FUB is a bubble

Decode holds the instruction pair (`stall_Dhl`) until every instruction that has to issue has left. If inst0 is a jump, inst1 is on the wrong path and dropped, so decode releases right after inst0 issues. An X0 stall stops both instructions, and squashing decode clears `inst0_issued_Dhl`.

One design is worth mentioning here: when inst0 is a branch, inst1 is held for one cycle instead of issuing together, which differs from the spec's Table 1. A branch resolves in X0, by which time inst1 would already be in FUB's X0 on a possibly wrong path, with a scoreboard entry. Killing it would need an extra squash for FUB and a scoreboard cleanup, so for Part 1 inst1 simply issues next cycle if the branch is not taken, and is squashed with decode if it is taken.

### Evaluation

|    ubmark     | Instructions | Cycles |  IPC  | Cycles (rand) | IPC (rand) |
| :-----------: | -----------: | -----: | ----: | ------------: | ---------: |
| vvadd         | 1061         | 1424   | 0.745 | 3928          | 0.270      |
| bin-search    | 1123         | 1578   | 0.712 | 3331          | 0.337      |
| cmplx-mult    | 2946         | 3826   | 0.770 | 10250         | 0.287      |
| masked-filter | 6961         | 8809   | 0.790 | 24926         | 0.279      |

## Part 2

### Profiling

To find where the cycles of the Part 1 design go, I added simulation-only counters to the control unit. Every cycle, the instruction pair in decode is put into exactly one category, checked in this order, so the first matching cause gets the blame:

1. D empty: no valid pair in decode (bubble, or squashed by a taken branch/jump)
2. Mem stall: X0/X1 is stalled, nothing issues
3. Second turn: inst0 already issued, inst1 issues alone, or waits on a hazard
4. inst0 hazard: inst0 waits on a load/mul result, nothing issues
5. Jump: inst0 is a jump, inst1 is dropped
6. Branch hold: inst0 is a branch, inst1 waits
7. Both non-ALU: both need FUA, inst0 issues alone
8. RAW: inst1 reads inst0's destination, inst0 issues alone
9. WAW: inst1 writes inst0's destination (without RAW), inst0 issues alone
10. inst1 hazard: inst1 waits on a load/mul result, inst0 issues alone
11. Dual issue: both instructions issue

A total counter checks that the categories add up to `num_cycles` reported by the testbench. The counters print when the program writes its status. All numbers are from the normal (fixed memory latency) runs.

| Category                  | vvadd    | bin-search | cmplx-mult | masked-filter |
| :------------------------ | --------: | --------: | ---------: | ---------: |
| D empty                   | 437 (31%) | 470 (30%) |  431 (11%) | 3089 (35%) |
| Mem stall                 |   0 ( 0%) |   0 ( 0%) |    0 ( 0%) |    0 ( 0%) |
| Second turn, inst1 issues | 321 (23%) | 396 (25%) | 1194 (31%) | 1126 (13%) |
| inst0 hazard              |  85 ( 6%) |  77 ( 5%) |  113 ( 3%) |  760 ( 9%) |
| inst1 hazard              |   0 ( 0%) |   6 ( 0%) |    0 ( 0%) |    0 ( 0%) |
| Jump                      |   3 ( 0%) |   3 ( 0%) |    4 ( 0%) |    2 ( 0%) |
| Branch hold               |  90 ( 6%) | 239 (15%) |  119 ( 3%) |  780 ( 9%) |
| Both non-ALU              | 284 (20%) |  26 ( 2%) |  829 (22%) |  689 ( 8%) |
| RAW                       |  31 ( 2%) | 239 (15%) |  258 ( 7%) |  348 ( 4%) |
| WAW                       |   2 ( 0%) |   2 ( 0%) |    2 ( 0%) |    2 ( 0%) |
| Second turn, inst1 hazard |   3 ( 0%) |  11 ( 1%) |  603 (16%) |    3 ( 0%) |
| Dual issue                | 168 (12%) | 109 ( 7%) |  273 ( 7%) | 2010 (23%) |
| Total (= `num_cycles`)    | **1424**  |  **1578** |  **3826**  |  **8809**  |

To see what empties decode, I also counted control-flow instructions (branches resolved in X0, and jumps leaving decode). These are counts, not cycle categories:

|                             | vvadd     | bin-search | cmplx-mult | masked-filter |
| :-------------------------- | --------: | ---------: | ---------: | ---------: |
| Branches                    | 158       | 262        | 300        | 1224       |
| Taken                       | 145 (92%) | 135 (52%)  | 105 (35%)  | 1114 (91%) |
| Not taken                   | 13 ( 8%)  | 127 (48%)  | 195 (65%)  | 110 ( 9%)  |
| Jumps                       | 5         | 55         | 35         | 8          |
| D empty / (taken + jumps)   | 2.9       | 2.5        | 3.1        | 2.8        |

1. Decode is empty for about a third of all cycles in vvadd, bin-search and masked-filter. Dividing the D-empty cycles by the redirects (taken branches and jumps) gives 2.5–3.1 cycles each, so nearly all of them are the refill after a taken branch resolves in X0
2. True dual issue is rare (7–23%). Most cycles issue one instruction
3. The single-issue causes differ by benchmark: vvadd and cmplx-mult are limited by pairs that both need FUA (memory and mul/div), bin-search by RAW and branch hold, and cmplx-mult also waits for mul/div results (second-turn hazard)
4. Memory stalls are 0, as expected with fixed memory latency
5. WAW pairs are negligible (2 cycles in every benchmark), so letting WAW pairs dual-issue is not worth optimizing

### Branch prediction

The profile shows that D empty is the largest category in vvadd, bin-search and masked-filter, and that almost all of it is the 2.5–3.1 cycle refill after each taken branch, which only redirects once it resolves in X0. So the first optimization is branch prediction.

Here I choose to predict at decode stage, since in dpath's decode stage there is already a signal `branch_targ_Dhl` that calculates the target address.

First thing first, we build the prediction counter in control. Here I choose to use 2-bit saturating counters with 32 direct-mapped entries, indexed by bits 6–2 of the branch's PC (from FUA in decode for the lookup, from X0 for the update), initialized to `2'b01` (weakly not taken). With this initial state, a branch behaves exactly like in Part 1 until it has been seen taken; starting at weakly taken instead changed the cycle counts by less than 25 cycles, in both directions. The counter is updated once per branch in X0 (not while X0 is stalled), counting up if taken and down if not, saturating at `00` and `11`. X0 also reports whether the prediction was wrong, so the PC can be set back to the correct address.

In decode, a branch steered to FUA that is predicted taken redirects the PC to `branch_targ_Dhl` and squashes fetch, the same way a jump does. This works whether the branch is inst0 or inst1. If inst0 is predicted taken, inst1 is on the wrong path and is dropped. Otherwise, inst1 is held for one cycle as in Part 1, and is squashed if the branch turns out to be taken.

In X0, the branch's outcome is compared with the prediction it carried from decode. Unlike Part 1, a correctly predicted taken branch must not redirect or squash again, since decode already holds instructions from the target. On a misprediction, the PC mux selects the other address (the branch target, or the branch's fall-through PC), and fetch and decode are squashed. A misprediction from X0 has priority over a redirect from decode.

Lastly are the small modifications:

- Dpath provides the predictor index bits (`pcA[6:2]`) from decode and X0 to control
- Control has the two index inputs
- Connect the 2 added ports between control and dpath in Core
- Widen the PC mux select to 3 bits across Core, control and dpath, for two new inputs: `branch_targ_Dhl` (predicted taken) and the fall-through PC of the branch in X0, which needs a new X0 pipeline register `pcA_plus4_X0hl`
- Fix the pending-redirect latch in dpath, so a redirect in the current cycle wins over a pending one; otherwise an X0 misprediction could be lost behind an older decode redirect
- Update squash/stall logic in fetch, decode stages

Here are the profiling results after adding branch prediction:

| Category                  | vvadd     | bin-search | cmplx-mult | masked-filter |
| :------------------------ | --------: | --------: | ---------: | ---------: |
| D empty                   | 241 (20%) | 381 (26%) |  362 (10%) | 1592 (22%) |
| Mem stall                 |   0 ( 0%) |   0 ( 0%) |    0 ( 0%) |    0 ( 0%) |
| Second turn, inst1 issues | 321 (26%) | 366 (25%) | 1195 (32%) | 1153 (16%) |
| inst0 hazard              |  85 ( 7%) |  58 ( 4%) |  112 ( 3%) |  620 ( 8%) |
| inst1 hazard              |   0 ( 0%) |   6 ( 0%) |    0 ( 0%) |   28 ( 0%) |
| Jump                      |   3 ( 0%) |   4 ( 0%) |    4 ( 0%) |    3 ( 0%) |
| Branch hold               |  90 ( 7%) | 191 (13%) |  120 ( 3%) |  752 (10%) |
| Both non-ALU              | 284 (23%) |  45 ( 3%) |  831 (22%) |  745 (10%) |
| RAW                       |  31 ( 3%) | 239 (16%) |  258 ( 7%) |  320 ( 4%) |
| WAW                       |   2 ( 0%) |   2 ( 0%) |    2 ( 0%) |    2 ( 0%) |
| Second turn, inst1 hazard |   3 ( 0%) |  30 ( 2%) |  604 (16%) |  171 ( 2%) |
| Dual issue                | 168 (14%) | 138 ( 9%) |  271 ( 7%) | 1982 (27%) |
| Total (= `num_cycles`)    | **1228**  |  **1460** |  **3759**  |  **7368**  |
| Mispredicted branches     | 20 / 158 (13%) | 62 / 262 (24%) | 28 / 300 (9%) | 88 / 1224 (7%) |

D-empty cycles drop by 45% in vvadd and 48% in masked-filter, and meets the Level 1 cycle requirements for all four benchmarks:

| ubmark        | Part 1 | Branch prediction | Change | Level 1 limit | Level 2 limit |
| :------------ | -----: | ----------------: | -----: | ------------: | ------------: |
| vvadd         | 1424   | 1228              | −13.8% | 1400          | 1200          |
| bin-search    | 1578   | 1460              | −7.5%  | 1500          | 1300          |
| cmplx-mult    | 3826   | 3759              | −1.8%  | 4000          | 3500          |
| masked-filter | 8809   | 7368              | −16.4% | 8500          | 7500          |

