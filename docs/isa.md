# ISA implementada (MIPS32)

Subconjunto mínimo do enunciado. Mesmo conjunto em O1 (monociclo) e O2 (pipeline).

| Mnemônico | Formato | opcode | funct | Binário (opcode / funct) | Operação em RTL |
|---|---|---|---|---|---|
| add | R | 0x00 | 0x20 | 000000 / 100000 | `R[rd] <- R[rs] + R[rt]; PC <- PC + 4` |
| sub | R | 0x00 | 0x22 | 000000 / 100010 | `R[rd] <- R[rs] - R[rt]; PC <- PC + 4` |
| and | R | 0x00 | 0x24 | 000000 / 100100 | `R[rd] <- R[rs] & R[rt]; PC <- PC + 4` |
| or | R | 0x00 | 0x25 | 000000 / 100101 | `R[rd] <- R[rs] \| R[rt]; PC <- PC + 4` |
| slt | R | 0x00 | 0x2A | 000000 / 101010 | `if (R[rs] < R[rt]) R[rd] <- 1 else R[rd] <- 0; PC <- PC + 4` |
| addi | I | 0x08 | — | 001000 / — | `R[rt] <- R[rs] + ExtSinal(imediato); PC <- PC + 4` |
| lw | I | 0x23 | — | 100011 / — | `R[rt] <- MemDados[R[rs] + ExtSinal(imediato)]; PC <- PC + 4` |
| sw | I | 0x2B | — | 101011 / — | `MemDados[R[rs] + ExtSinal(imediato)] <- R[rt]; PC <- PC + 4` |
| beq | I | 0x04 | — | 000100 / — | `if (R[rs] == R[rt]) PC <- PC + 4 + (ExtSinal(imediato) << 2) else PC <- PC + 4` |
| break | especial | 0x00 | 0x0D | 000000 / 001101 | `retired <- 0; PCWrite <- 0; RegWrite <- 0; MemWrite <- 0; done_reg(t+1) <- 1 (mantém 1 até rst)` |

## Formatos de instrução

| Formato | 31..26 | 25..21 | 20..16 | 15..11 | 10..6 | 5..0 |
|---|---|---|---|---|---|---|
| R | opcode | rs | rt | rd | shamt | funct |
| I | opcode | rs | rt | imediato (15..0) | | |

## Decisões de projeto

- O1 é monociclo.
- PC inicial: `0x00000000`.
- O `break` não conta como instrução útil (`retired = 0`). O RTL acima descreve o O1; o O2 terá o seu próprio.
