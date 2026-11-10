# Especificação do Conjunto de Instruções (ISA) — Subconjunto MIPS32

Tabela de instruções implementadas nas organizações **O1 (Monociclo)** e **O2 (Pipeline de 5 estágios)**, baseada em **Patterson & Hennessy (2017)** [1].

| Instrução | Formato | `opcode` (31..26) | `funct` (5..0) | Operação RTL (Semântica Real Implementada) | Sinais de Controle (`reg_dst`, `alu_src`, `mem_to_reg`, `reg_write`, `mem_read`, `mem_write`, `branch`, `alu_op`, `is_break`) |
| :--- | :---: | :---: | :---: | :--- | :---: |
| `add rd, rs, rt` | R | `000000` | `100000` (`0x20`) | `Regs[rd] <= Regs[rs] + Regs[rt]; PC <= PC + 4` | `1, 0, 0, 1, 0, 0, 0, "10", 0` |
| `sub rd, rs, rt` | R | `000000` | `100010` (`0x22`) | `Regs[rd] <= Regs[rs] - Regs[rt]; PC <= PC + 4` | `1, 0, 0, 1, 0, 0, 0, "10", 0` |
| `and rd, rs, rt` | R | `000000` | `100100` (`0x24`) | `Regs[rd] <= Regs[rs] and Regs[rt]; PC <= PC + 4` | `1, 0, 0, 1, 0, 0, 0, "10", 0` |
| `or rd, rs, rt` | R | `000000` | `100101` (`0x25`) | `Regs[rd] <= Regs[rs] or Regs[rt]; PC <= PC + 4` | `1, 0, 0, 1, 0, 0, 0, "10", 0` |
| `slt rd, rs, rt` | R | `000000` | `101010` (`0x2A`) | `Regs[rd] <= 1 se (signed(Regs[rs]) < signed(Regs[rt])) senão 0; PC <= PC + 4` | `1, 0, 0, 1, 0, 0, 0, "10", 0` |
| `addi rt, rs, imm` | I | `001000` | — | `Regs[rt] <= Regs[rs] + sign_ext(imm); PC <= PC + 4` | `0, 1, 0, 1, 0, 0, 0, "00", 0` |
| `lw rt, imm(rs)` | I | `100011` | — | `Regs[rt] <= Mem[(Regs[rs] + sign_ext(imm))][31:0]; PC <= PC + 4` | `0, 1, 1, 1, 1, 0, 0, "00", 0` |
| `sw rt, imm(rs)` | I | `101011` | — | `Mem[(Regs[rs] + sign_ext(imm))][31:0] <= Regs[rt]; PC <= PC + 4` | `0, 1, 0, 0, 0, 1, 0, "00", 0` |
| `beq rs, rt, imm` | I | `000100` | — | `se (Regs[rs] = Regs[rt]) PC <= (PC + 4) + (sign_ext(imm) << 2) senão PC <= PC + 4` | `0, 0, 0, 0, 0, 0, 1, "01", 0` |
| `break` | R | `000000` | `001101` (`0x0D`) | `done <= '1'` (no próprio ciclo em O1; ao atingir WB em O2); `retired <= "00"`; `halted_reg(t+1) <= '1'`; `PC(t+1) <= PC` (PC estaciona no endereço do `break`) | `0, 0, 0, 0, 0, 0, 0, "00", 1` |

> **Nota sobre a planilha da ISA:** Caso você mantenha uma planilha externa (`.xlsx` ou `.csv`), atualize a célula da operação RTL da linha `break` de `done_reg(t+1) <- 1` para:
> `done <= '1' (no próprio ciclo em O1; em WB no O2); retired <= "00"; PC(t+1) <= PC (congela no endereço do break)`.

---

## Referências
[1] PATTERSON, D. A.; HENNESSY, J. L. **Organização e Projeto de Computadores: A Interface Hardware/Software**. 5. ed. Rio de Janeiro: Elsevier, 2017.
