# Lab 2 Notes: Out-of-Order RISC-V — Scoreboard & ROB

Working log of the Lab 2 implementation so far: design decisions, how each
piece works, and the bugs hit along the way (with the mechanism behind each).

## 1. Status

| Item | State | Evidence |
|---|---|---|
| Scoreboard (Section 4), dummy ROB | Done | `make check-asm-riscvooo` 46/46, `make check-asm-rand-riscvooo` 46/46 (commit `12adc39`) |
| `riscv-test1.S` (out-of-order commit bug) | Done | Fails on dummy ROB (status = 22, the `TEST_CHECK_EQ` line); passes with real ROB |
| ROB (`riscvooo-CoreReorderBuffer.v`) | Done | Step 1: 46 original tests still passed with ROB connected but RF still written from W |
| RF write port switched to commit path (`CoreDpath.v`) | Done | — |
| Scoreboard: pending cleared on commit | Done | Step 2: 45/47; `jr`, `jalr` timed out (Bug 16) |
| Scoreboard: ROB bypass (sel 5), both sources | Done | **Step 3: `make check-asm-riscvooo` 47/47, `make check-asm-rand-riscvooo` 47/47** (includes `riscv-test1`, `jr`, `jalr`) |
| `riscv-test2.S` … `riscv-test5.S` | Done | All wired into `riscv.mk` / `build/Makefile`; **`make check-asm-riscvooo` 51/51, `make check-asm-rand-riscvooo` 51/51** (§5) |
| Benchmarks (`make run-bmark-riscvooo`, `run-bmark-rand-riscvooo`) | All pass | 4/4 fixed, 4/4 random-delay; compared against Lab 1 riscvlong in §6 |

## 2. Pipeline facts the design depends on

Read from `riscvooo-CoreCtrl.v` / `riscvooo-CoreDpath.v`:

- Pipes:
  - ALU: `X → W`
  - MEM: `X → M → W`
  - MUL: `X → M → X2 → X3 → W` (MUL passes through the M pipeline register: `ir_X2hl <= ir_Mhl`)
- `X2` and `X3` can never stall (`stall_X2hl = stall_X3hl = 1'b0`).
- `stall_Xhl = stall_Mhl || stall_dmem_Xhl || stall_wb_hazard_Xhl` — an M stall always implies an X stall.
- `stall_Whl = 1'b0` — W never stalls.
- **Every** instruction is copied down `X → M → X2 → X3` regardless of unit, so stale copies sit in later pipeline registers. The pipeline registers cannot tell you who really needs W; the scoreboard must track it.
- There is a single writeback port. `wb_mux_sel_Whl` decides, combinationally, which of X / M / X3 is latched into W at the **end of the current cycle** (`CoreCtrl.v:942`). Any other value → bubble.
- Bypass mux encoding (`CoreDpath.v:215`):

  | sel | source | stage |
  |---|---|---|
  | 0 | `rf_rdata` | register file |
  | 1 | `alu_out_Xhl` | X |
  | 2 | `dmemresp_mux_out_Mhl` | M |
  | 3 | `muldiv_mux_out_X3hl` | X3 |
  | 4 | `wb_mux_out_Whl` | W |
  | 5 | `rob_data[slot]` | ROB (written back, not committed) |

- `latency` input (one-hot, from ctrl): ALU `00010`, MEM `00100`, MUL `10000`.
- `stalls` input: `{stall_X, stall_M, 0, 0, stall_W}`.

## 3. Scoreboard design

### 3.1 Bit ↔ stage table

Each set bit in a latency vector names the stage the producer is in. The
vector shifts right once per (unstalled) cycle.

| unit | at issue | bit 4 | bit 3 | bit 2 | bit 1 | bit 0 |
|---|---|---|---|---|---|---|
| ALU | `00010` | – | – | – | X | W |
| MEM | `00100` | – | – | X | M | W |
| MUL | `10000` | X | M | X2 | X3 | W |

Observation: the `stalls` port layout is exactly MUL's stage order, so
`MUL_stall_vec = stalls`. ALU/MEM stall vectors are the same signals placed at
their own bit positions:

```verilog
wire [4:0] ALU_stall_vec = {1'b0, 1'b0,      1'b0, stall_Xhl, stall_Whl};
wire [4:0] MEM_stall_vec = {1'b0, 1'b0, stall_Xhl, stall_Mhl, stall_Whl};
wire [4:0] MUL_stall_vec = stalls;
```

### 3.2 Per-register state

| State | Set | Updated / cleared |
|---|---|---|
| `pending[r]` | on issue of a writer to `r` | when `rob_commit_wen && rob_commit_slot == reg_rob_slot[r]` (was `reg_latency == 00001` with the dummy ROB — see §3.4) |
| `reg_latency[r]` | `latency` on issue | shift right each cycle unless the producer's current stage is stalled |
| `functional_unit[r]` | `func_unit` on issue | holds last writer's unit (stays set after completion — not an "in flight" flag) |
| `reg_rob_slot[r]` | `rob_alloc_slot` on issue | holds the newest writer's ROB slot |

**Issue** = `inst_val_Dhl && !stall_Dhl && dst_en && dst != 0`.
`inst_val_Dhl` already excludes squashed instructions.

Two separate events update the state:

- **Issue** — only when the instruction actually leaves D.
- **Advance** — every cycle for every in-flight register, independent of D stalling.

`reg_latency[r]` is one-hot (only the newest writer matters), so freezing the
whole vector when its single bit is in a stalled stage is correct.

### 3.3 Bypass / hazard (combinational, one block per source)

```
default: sel = 0, stall = 0
if src_en && pending[src]:
    if reg_latency[src] == 0:                     // written back, not committed
        sel = 5                                   // rob_data[reg_rob_slot[src]]
    else case functional_unit[src]
      ALU: X(00010)→1, W(00001)→4, else stall
      MEM: M(00010)→2, W(00001)→4, else stall     // MEM in X has only the address
      MUL: X3(00010)→3, W(00001)→4, else stall    // no product before X3
stall_hazard = stall0 || stall1
src*_byp_rob_slot = reg_rob_slot[src*]
```

Key rule: a tap is a wire in a specific pipe. Being "in stage X" does not mean
`alu_out_Xhl` carries *your* result — a load in X puts its *address* on
`alu_out_Xhl`. Every pending case either picks a tap that carries that unit's
result or stalls; none fall back to the RF.

### 3.4 Changes for the real ROB (Section 5)

Once the RF is written at **commit** instead of W, a value has three phases:

```
issue ──► executing (X/M/X3) ──► written back to rob_data ──► committed to RF
          bypass sel 1–4         bypass sel 5                 read RF (sel 0)
```

1. **Pending clears on the matching commit**, not when the value leaves W:
   `rob_commit_wen && rob_commit_slot == reg_rob_slot[r]`. The slot match
   handles WAW: if `mul x7` (slot 2) and `add x7` (slot 3) are both in flight,
   slot 2 committing must not clear `pending[7]`, because `reg_rob_slot[7] == 3`.
   If a new writer issues on the same edge an older one commits, *set* wins.
2. **ROB bypass (sel 5)** when `pending && reg_latency == 0`. Why it is safe:
   - `rob_data[slot]` is written on the same edge `reg_latency` goes `00001 → 0`, so the data is valid from the first cycle the condition holds.
   - The slot can't be reallocated until it commits, and commit clears `pending`, so the data stays valid as long as the condition holds.
   - `reg_rob_slot[r]` always names the **newest** writer, so WAW reads the right entry.
   - `latency` is never 0 at issue, so `pending && latency == 0` can only mean "past W".
   - Applied to **both** source operands.

First attempt only bypassed in the commit cycle
(`rob_commit_wen && rob_commit_slot == reg_rob_slot[src]`). It passed all
tests but still stalled on a value stuck behind an older instruction at the
head, e.g.:

```
mul  x5, x2, x3   // slow, at ROB head
addi x6, x0, 1    // written back early, can't commit past the mul
nop
nop
add  x7, x6, x6   // x6: pending=1, latency=0, not at head → should be sel 5, not a stall
```

The general `latency == 0` condition covers that case and the commit-cycle case.

### 3.5 Writeback-port arbitration

Three per-unit trackers `wb_alu_latency`, `wb_mem_latency`, `wb_mul_latency`:

| | `reg_latency[r]` | `wb_<unit>_latency` |
|---|---|---|
| indexed by | register | functional unit |
| loaded on | issue of a writer to `r` | issue of **any** valid instruction of that unit |
| bits set | one-hot | **multiple** (back-to-back MULs coexist) |

- Load on every instruction (not just `dst_en`): stores, branches and `csrw` still have to reach W (`retire_valid`, and the test's pass/fail CSR write happens in W).
- On issue: `(tracker >> 1) | latency` — shift the in-flight bits *and* insert the new one. Issue implies `!stall_Dhl` ⇒ `!stall_X` ⇒ `!stall_M`, so nothing needs to freeze that cycle.
- Otherwise, per-bit masked shift:

  ```verilog
  next = (tracker & stall_vec) | ((tracker & ~stall_vec) >> 1);
  ```

  Held bits stay; free bits advance. Collision-free because stalled stages are always a contiguous top-of-pipe prefix (`stall_M ⇒ stall_X`, X2/X3 never stall), so a moving bit never lands on a held one.

- "Wants W this cycle" is **bit 1** for every unit (X for ALU, M for MEM, X3 for MUL).
- Priority: **MUL > MEM > ALU**
  - MUL cannot stall (X2/X3 have no stall).
  - MEM must beat ALU: stalling M also stalls X (`stall_Xhl ⊇ stall_Mhl`), so letting ALU win would just stall both.

```verilog
assign wb_mux_sel = wb_mul_latency[1] ? MUL : wb_mem_latency[1] ? MEM : wb_alu_latency[1] ? ALU : 0;
assign stall_wb_hazard_M = wb_mem_latency[1] && wb_mul_latency[1];
assign stall_wb_hazard_X = wb_alu_latency[1] && (wb_mem_latency[1] || wb_mul_latency[1]);
```

- These outputs are computed from the trackers only, **never from `stalls`** — `stalls` contains `stall_X/M`, which are built from `stall_wb_hazard_*`, so reading it would form a combinational loop.

## 4. ROB design

- 16 entries (`` `SLOTS ``), 4-bit pointers (`` `LOG_S ``).
- Per entry: `rob_valid`, `rob_pending`, `rob_phyreg`. **No data array** — the data lives in the datapath's `rob_data`, indexed by `rob_fill_slot_Whl` (write) and `rob_commit_slot_Chl` (read). The ROB only produces control.
- `head` = next to commit; `tail` = next to allocate.
- Full = `head == tail && valid[head]`; empty = `head == tail && !valid[head]`.

| Event | Condition | Effect |
|---|---|---|
| Alloc | `rob_alloc_req_val && !full` | `valid[tail]=1`, `pending[tail]=1`, `phyreg[tail]=preg`, `tail++` |
| Fill | `rob_fill_val` | `pending[fill_slot]=0` |
| Commit | `valid[head] && !pending[head]` | `valid[head]=0`, `head++`, RF write `phyreg[head] ← rob_data[head]` |

Outputs: `alloc_req_rdy = !full`, `alloc_resp_slot = tail`,
`commit_wen = valid[head] && !pending[head]`, `commit_rf_waddr = phyreg[head]`,
`commit_slot = head`.

Notes:

- Alloc and commit on the same entry can only coincide when the ROB is empty, and then nothing commits — no conflict.
- Fill clears pending at the same edge the datapath writes `rob_data`; commit reads it the next cycle — timing is correct.
- A full ROB can't allocate in the cycle it commits (loses ≤1 cycle, only when full).
- Control only allocates for `rf_wen && rf_waddr != 0` (`CoreCtrl.v:1007`), consistent with the scoreboard's x0 exclusion.

Integration was done in three steps, testing after each, so every failure
could be pinned on one change:

| Step | Change | Result |
|---|---|---|
| 1 | ROB implemented and connected; RF still written from W | 46/46 original pass (alloc/commit never deadlock); test1 still fails (nothing uses the commit outputs yet) |
| 2 | RF write port → commit path (`CoreDpath.v`: `rf_wen_Chl`, `rf_waddr_Chl`, `rf_wdata_Chl`); scoreboard pending cleared on commit | All tests X-out before the pending change (Bug 15); after it, 45/47 — `jr`/`jalr` time out (Bug 16) |
| 3 | Scoreboard ROB bypass (sel 5), both sources | **47/47 fixed-latency, 47/47 random-delay**, including test1, `jr`, `jalr` |

## 5. Tests

### `riscv-test1.S` — out-of-order commit

```asm
li    x2, 6
li    x3, 7
mul   x4, x2, x3        // older, slow (MUL pipe):  x4 = 42
addi  x4, x0, 1         // younger, fast (ALU pipe): x4 = 1
nop ×4
TEST_CHECK_EQ( x4, 1 )
```

- Dummy ROB: `addi` reaches W ~3 cycles before `mul`. RF is written from W, so `mul`'s 42 overwrites the younger 1 → **FAILED (status = 22)**.
- Real ROB: commits `mul` then `addi` → x4 = 1 → passes.
- **The nops matter.** Without them the check's `bne` reads x4 while `mul` is still in flight, gets the `addi` value via bypass, and the test **passes** even on the broken design. The wrong value only becomes visible after the late write lands.
- Don't use x1 / x29 as test registers — `TEST_CHECK_EQ` clobbers them.

### `riscv-test2.S` — bypass from the ROB

```asm
li    x2, 6
li    x3, 7
mul   x5, x2, x3   // slow, at ROB head
addi  x6, x0, 1    // written back early, can't commit past the mul
nop
nop
add   x7, x6, x6   // x6 written back, not committed → sel 5
TEST_CHECK_EQ( x7, 2 )
```

- Probe at the `add` in D: `x6: pend=1 lat=00000 slot=3 | sel0=5 sel1=5 | rob head=2`, while the `mul` (slot 2) is still in W. The value is bypassed from `rob_data[3]` with the head blocked by an older entry — the general case, not just the commit cycle.
- The one-cycle stall the `add` sees just before issuing is a W-port conflict (nop in X vs `mul` in X3), not the scoreboard; sel is already 5 in that cycle.
- The spec only asks for the scenario. A bypass changes timing, not results, so this test can't fail on a design that stalls until commit instead; the probe trace is the evidence the bypass happens. On the dummy-ROB design the state never exists (RF written at W), so the `add` just reads the RF.

### `riscv-test3.S` — WAW correct on both designs

`mul x4` … *gap* nops … `addi x4, x0, 1` … 4 nops … `TEST_CHECK_EQ( x4, 1 )`, using 4 gap nops.

Measured on the original I2O2 design (commit `12adc39`, dummy ROB, RF written at W) and the final ROB design:

| gap nops | check right after `addi` | check after 4 tail nops |
|---|---|---|
| 0 | original PASS (!) / ROB PASS | original **FAIL** / ROB PASS (= test1) |
| 1 | original **FAIL** / ROB PASS | original **FAIL** / ROB PASS |
| 2 | both PASS | both PASS |
| ≥3 | both PASS | both PASS |

- **gap = 2** is the boundary. `mul` (leaving X3) and `addi` (leaving X) want the W port in the same cycle; MUL wins arbitration, `addi` stalls a cycle in X, so it still writes second. At gap ≥ 3 the `mul` simply finishes first.
- **Tail nops are required.** With the check right after the `addi`, gap 0 passes even on the broken design — the check bypasses the `addi` value before the late `mul` write lands (same lesson as test1).

### `riscv-test4.S` — riscvlong IPC > riscvooo IPC

Three groups of `mul` / `nop` / `lw` / `addi`, each with fresh destinations and only shared sources (`x2`, `x3`, load base, `x0`), plus two checks. The load address is a dummy; its value is never used.

| | cycles | IPC |
|---|---|---|
| riscvlong (Lab 1) | 31 | **0.774** |
| riscvooo | 34 | 0.706 |

- In each group the `mul` is in X3, the `lw` in M and the `addi` in X **in the same cycle**, all wanting the single W port. MUL > MEM > ALU: the `lw` waits 1 cycle, the `addi` 2. The stall probe shows exactly 2 W-port stall cycles per group and no RAW stalls.
- riscvlong sends every instruction through the same `X → M → X2 → X3 → W` path, so writebacks arrive in order and never collide.
- riscvooo starts ~3 cycles ahead (ALU ops skip M/X2/X3, so the pipeline drains sooner). One group (2 cycles) isn't enough to overcome that; three groups (6 cycles) are.
- Iterations that didn't work, and why: `ld` (RV64-only) / `sp` as base (sp is x2, overwritten); load base = `mul` result (RAW stall instead of W-port stall, and address 42); two filler nops instead of one (`lw`/`addi` collide one cycle after the `mul`); grouping by type (3 `mul`, 3 `lw`, 3 `addi`) instead of interleaved groups.

### `riscv-test5.S` — maximum ROB occupancy

Six back-to-back independent `mul`s, then `TEST_CHECK_EQ` on the first (`x5`) and last (`x10`) result.

Peak occupancy (probe counting `rob_valid` entries each cycle):

| pattern | peak |
|---|---|
| `mul` + 10 independent `addi` | 5 |
| 4 `mul` then 4 `addi` | 5 |
| back-to-back independent `mul` (test5) | **6** |

- **Why 6 is the ceiling.** One allocation per cycle, so peak = cycles a head entry stays uncommitted: allocate → X, M, X2, X3, W → commit = 6. After that, one commits and one allocates each cycle.
- **Why it can't go higher.** Every way to hold the head longer also stalls D (no allocation): memory stall in M ⇒ X stall ⇒ D stall; losing the W port ⇒ `stall_wb_hazard_X` ⇒ D stall; RAW on the head stalls the consumer in D. `div` uses the same fixed 4-stage pipe. X2/X3/W never stall.
- **Why only `mul`s.** Mixing in ALU ops loses allocation cycles to W-port arbitration (MUL beats ALU), capping at 5.
- With 16 slots `rob_full` can't assert in these tests (peak 6 < 16), and the stall counters show 0 ROB-full cycles across all four benchmarks (§6). A build with fewer slots would be needed to exercise the full/`rdy` stall.

### Instruction counts (all < 30; counted from the disassembly between `_test` and `_pass`/`_fail`, including `TEST_CHECK_EQ` expansions)

| test | instrs in `_test` | riscvooo cycles / IPC |
|---|---|---|
| test1 | 11 | 19 / 0.737 |
| test2 | 10 | 18 / 0.722 |
| test3 | 15 | 23 / 0.783 |
| test4 | 21 | 34 / 0.706 |
| test5 | 14 | 24 / 0.708 |

## 6. Benchmarks: riscvooo vs. riscvlong

riscvooo numbers from `build/ubmark-*-ooo.out` / `-ooo-rand.out`. riscvlong numbers from the Lab 1 riscvlong simulator run on the same `.vmh` files (same instruction counts).

### Fixed memory latency

| benchmark | insts | riscvlong cycles | riscvlong IPC | riscvooo cycles | riscvooo IPC |
|---|---|---|---|---|---|
| bin-search | 1123 | 1542 | **0.728** | 1578 | 0.712 |
| cmplx-mult | 2946 | 3913 | **0.753** | 4095 | 0.719 |
| masked-filter | 6961 | 10048 | **0.693** | 11254 | 0.619 |
| vvadd | 1061 | 1450 | **0.732** | 1525 | 0.696 |

### Random memory delay

| benchmark | riscvlong cycles | riscvlong IPC | riscvooo cycles | riscvooo IPC |
|---|---|---|---|---|
| bin-search | 3822 | **0.294** | 3892 | 0.289 |
| cmplx-mult | 10742 | **0.274** | 11933 | 0.247 |
| masked-filter | 26818 | **0.260** | 29248 | 0.238 |
| vvadd | 4202 | **0.252** | 4684 | 0.227 |

**riscvlong wins every benchmark.**

### Where riscvooo's extra cycles come from

Stall-cause counters (probe on riscvooo, fixed latency):

| benchmark | stall_D | RAW (scoreboard) | W-port conflict (`stall_wb_hazard_X`) | `stall_wb_hazard_M` | ROB full |
|---|---|---|---|---|---|
| bin-search | 127 | 88 | 39 | 0 | 0 |
| cmplx-mult | 901 | 716 | 185 | 0 | 0 |
| masked-filter | 2054 | 845 | 1209 | 0 | 0 |
| vvadd | 166 | 88 | 78 | 0 | 0 |

Compare the cycle gap with the W-port conflict count:

| benchmark | ooo − long cycles | W-port conflict cycles |
|---|---|---|
| bin-search | 36 | 39 |
| cmplx-mult | 182 | 185 |
| masked-filter | 1206 | 1209 |
| vvadd | 75 | 78 |

- The gap is **exactly W-port conflicts − 3** on every benchmark — the same mechanism and the same ~3-cycle drain advantage as test4. (Measured correlation; the "RAW stalls are the same on both" part is inferred from this, not separately counted on riscvlong.)
- All conflicts are ALU-in-X losing (`stall_wb_hazard_X`); `stall_wb_hazard_M` is 0, i.e. MUL-vs-MEM never collided in these programs.
- ROB never filled (0 cycles), so ROB size isn't a factor here.
- masked-filter has by far the most conflicts (1209). Since `stall_wb_hazard_M` is 0, every one is an ALU op in X losing to a load in M or a mul in X3; which pairing dominates wasn't broken down.

### Iron Law view

Time = Instructions × CPI × cycle time.
- **Instructions**: identical (same binaries).
- **CPI**: riscvooo higher on all four benchmarks, entirely from writeback-port structural hazards.
- **Cycle time**: not modeled by the simulator. riscvooo's shorter ALU path and in-D ROB/scoreboard logic would affect it in real hardware, but that can't be measured here.

Interpretation (reasoned, not measured): the out-of-order writeback buys nothing in this design because issue is still in-order and single-wide: finishing an ALU op early only helps if something younger could use it sooner, which the bypass network already handled in riscvlong. Meanwhile the shared W port adds a structural hazard riscvlong doesn't have.

## 7. Bugs encountered

| # | Bug | Symptom / evidence | Mechanism | Fix |
|---|---|---|---|---|
| 1 | Undeclared `stall`, wrong loop var (`dst == k` in `j` loop), missing backtick on `FUNC_UNIT_*`, 6-bit `{1'b0, x>>1}` | iverilog/verilator elaboration errors | — | Use `stalls`, correct var, `` `FUNC_UNIT_* ``, plain `>> 1` |
| 2 | Global `if (!stall)` gating the latency shift | (reasoned) deadlock | D stalls on a RAW hazard → producer countdown frozen → value never "ready" → stall forever | Separate **issue** (gated by D) from **advance** (every cycle, per-stage freeze) |
| 3 | `pending` derived from `reg_latency` with a register | (reasoned) one-cycle lag | Both registered ⇒ `pending` sees the new latency one edge late; back-to-back dependent reads stale RF | Set `pending` on the issue edge directly |
| 4 | Writes to x0 tracked | (reasoned) `addi x1, x0, 5` after `j` would bypass the jump's link value | `j`/`jal x0` have `dst_en=1, dst=0` | Exclude `dst == 0` on issue |
| 5 | Pending block missing its `for` loop | silent — iverilog accepts | `i` held its post-reset value (32) / `x` → no entry updated | Wrap in `for` |
| 6 | `reg_latency[1]` instead of `reg_latency[j][1]` | verilator `WIDTHTRUNC` | Single index selects register x1's whole vector | Two indices |
| 7 | Freeze by unit instead of by stage | (reasoned) wrong bypass after dmem stall | MEM in X with `stall_dmem_Xhl` kept shifting → scoreboard thinks it reached M | Per-unit stall vectors aligned to bit positions |
| 8 | Bypass block clocked (`@(posedge clk)`), wrong taps (MEM in X → sel 1, MUL in X/M → sel 1/2), missing MUL X3, "no tap" → sel 0 | review | Sel must be same-cycle; taps must carry *that unit's* result; not-ready must stall, not read RF | `always @(*)`, corrected table, stall flag |
| 9 | Bypass: missing `pending` guard, then `stall0` default = 1, `5'b01001` typo, `<=` in comb block | (reasoned) every instruction stalls / `COMBDLY` lint | `functional_unit` persists after completion; default must describe the "nothing in flight" case | Guard with `pending`, default 0, fix constant, use `=` |
| 10 | src1 block copy-pasted still reading `src0` | verilator `UNUSEDSIGNAL: src1_en` | — | Rename; lesson: unexpected "unused" ⇒ look for copy-paste |
| 11 | WB outputs left undriven | `riscv-addi` timeout; `x assertion failed: memreq0_val / memresp0_rdy` from t=125 | `z` → `stall_wb_hazard_X` → `stall_Xhl = x` → `stall_Dhl = x` → `imemreq_val`, `imemresp_rdy` = x | Drive all outputs |
| 12a | WB trackers: loaded into all three, issue path didn't shift, all-or-nothing freeze, used bit 0 | review | Phantom W requests; lost in-flight bits; decisions one cycle late | Gate on `func_unit`; `(t>>1)\|latency`; masked shift; bit 1 |
| 12b | Masked shift written as `t ^ mask`, then `~(t & mask)` | demo on 8-bit example: `belt ^ hold` creates bits; `~(belt & hold)` = all ones | XOR flips, doesn't mask; `~` applied to the AND result instead of the mask | `t & ~mask` |
| 13 | Empty `riscv-test*.S` listed in `riscv.mk` | `ld: cannot find entry symbol _test` / `.bss` link failure | `_test` is defined by `TEST_RISCV_BEGIN`; empty file defines nothing | Write the test skeleton; keep unwritten tests out of the build lists |
| 14 | ROB used `` `SLOT `` and `for (int i ...)` | `Define or directive not defined`; `Incomprehensible for loop` under `-g2005` | Macro is `` `SLOTS ``; `int` / loop-scoped decl is SystemVerilog | `` `SLOTS ``, `for (i = 0; ...)` with `integer i` |
| 15 | After switching RF to the commit path: all tests X-out | probe: `rob_alloc_req_val = x` → `rob_valid[head] = x` → `rob_full = x` → `rob_req_rdy = x` at t=125 | Scoreboard cleared `pending` at W, but RF is now written at commit (≥1 cycle later). `bne tp, ra` in `riscv-add` read uninitialized (X) `tp` from RF → branch X → `squash_Dhl` X → `inst_val_Dhl` X → poisoned ROB alloc | Clear `pending` on matching commit (`rob_commit_slot == reg_rob_slot[r]`) |
| 16 | `jr` / `jalr` time out (symptom fixed; root cause latent) | probe at `jr sp`: t=235 stalled, `op0 = 0x8004c` (stale); t=245 `op0 = 0x80068` (correct) but fetch returns to 0x8004c → infinite loop | Provided fetch logic (`CoreDpath.v:106`) latches `pc_redirect_targ` when `squash_Fhl` during an F stall; `squash_Fhl` uses `brj_taken_Dhl`, not gated by `stall_Dhl`, so a `jr` stalled in D latches a target computed from a stale operand. Latent before the ROB — exposed now because "written back, not committed" values stall | Sel 5 removed this stall → `jr`/`jalr` pass. The framework bug remains for other `jr` stalls (e.g. `lw x5` → `jr x5`); real fix is in provided ctrl/dpath — ask TA whether editing `CoreCtrl.v` is allowed |
| 17 | ROB bypass only in the commit cycle | review — all tests passed, so not caught by the suite | Values written back but blocked behind an older head entry still stalled until commit; lost IPC and wouldn't demonstrate test2 | Condition `pending && reg_latency == 0`, both sources (§3.4) |

## 8. Next steps

1. Commit tests 2–5, Makefile wiring, and this report.
2. Ask the TA about Bug 16 (provided `jr`/`jalr` fetch-redirect latch); optionally add a `lw` → `jr` test documenting it.
3. Optional (Section 7): ROB size sweep (2–16 slots) with test5 — expectation from §5: IPC flat for ≥ 6 slots, drops below; small sizes also finally exercise `rob_full`.
4. Package per Section 8.2 (`make clean`, remove `tests/build` and `ubmark/build`, `tar -cvzf <id>-lab2.tar.gz lab2`), then `tar -tzf` to verify the 5 tests and 4 modified `riscvooo/` files are inside.

## 9. Debugging techniques that paid off

- `verilator --lint-only -Wall` on a single module: `UNDRIVEN`, `UNUSEDSIGNAL`, `WIDTHTRUNC`, `COMBDLY` caught most structural bugs before simulation.
- Compiling with the Makefile's exact flags (`iverilog -g2005 ...`) — SystemVerilog-isms only fail there.
- When a test X-outs, the first `RTL-ERROR` timestamp tells you whether it's a cycle-0 wiring problem or a data-path problem.
- A throwaway `probe` module compiled as a second top (`-s Testbench -s probe`) printing hierarchical signals per cycle, without touching source files.
- Testing bit-manipulation expressions on a small unrelated vector before trusting them in the design.
