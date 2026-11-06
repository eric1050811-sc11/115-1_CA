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
