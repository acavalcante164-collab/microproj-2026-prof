# Diagramas de Execução Instrução × Ciclo (Issue #18 — Requisitos R4 e R5)

Representação temporal ciclo a ciclo da progressão das instruções nas organizações **O1 (Monociclo)** e **O2 (Pipeline de 5 estágios: IF, ID, EX, MEM, WB)**, extraída diretamente das simulações em `tb/tb_cpu.vhd`.

---

## 1. Traço Principal `T0` (31 Instruções Úteis + `break` = 32 Instruções)

### 1.1. Comparação Global: O1 vs. O2 em `T0`
- **Em O1 (Monociclo)**: Cada instrução $I_k$ ($k \in \{0, \dots, 30\}$) executa integralmente (Busca, Decodificação, ULA, Memória e Escrita) em **1 único ciclo** ($C = k + 1$). No ciclo **32**, a instrução `break` (`0x7C`) é decodificada, eleva `done = '1'` com `retired = "00"` e encerra a execução em **32 ciclos** ($25{,}60\text{ ns}$).
- **Em O2 (Pipeline de 5 Estágios)**:
  - **Fase de Enchimento (Ciclos 1 a 4)**: Nos 4 primeiros ciclos, o pipeline está sendo preenchido (`wb_valid = '0'`, portanto `retired = "00"`).
  - **Regime Permanente (Ciclos 5 a 35)**: Todos os 5 estágios estão ocupados; a cada ciclo, 1 instrução útil conclui no estágio `WB` (`retired = "01"`), totalizando 31 instruções úteis retiradas.
  - **Fase de Esvaziamento e Conclusão (Ciclos 32 a 36)**: A instrução `break` (`0x7C`) é buscada em `IF` no ciclo 32. A partir do ciclo 33, `break_in_flight = '1'` desativa novas buscas (`if_valid = '0'`), drenando o pipeline até que o `break` alcance o estágio `WB` no **ciclo 36**, quando `done = '1'` e a simulação encerra em **36 ciclos** ($7{,}20\text{ ns}$).

### 1.2. Diagrama Instrução × Ciclo de `T0` em `O2` (Enchimento, Regime Permanente e Esvaziamento)

| Endereço | Instrução (`t0.asm`) | C1 | C2 | C3 | C4 | C5 | C6 | C7 | C8 | C9 | ... | C31 | C32 | C33 | C34 | C35 | C36 |
| :---: | :--- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| `0x00` | `addi $t0, $zero, 10` | **IF** | **ID** | **EX** | **MEM** | **WB** | | | | | ... | | | | | | |
| `0x04` | `addi $t1, $zero, 20` | | **IF** | **ID** | **EX** | **MEM** | **WB** | | | | ... | | | | | | |
| `0x08` | `addi $t2, $zero, 30` | | | **IF** | **ID** | **EX** | **MEM** | **WB** | | | ... | | | | | | |
| `0x0C` | `addi $t3, $zero, 40` | | | | **IF** | **ID** | **EX** | **MEM** | **WB** | | ... | | | | | | |
| `0x10` | `add $t4, $t0, $t1` *(dist=3,4)* | | | | | **IF** | **ID** | **EX** | **MEM** | **WB** | ... | | | | | | |
| `...` | *(Instruções `0x14` a `0x6C`)* | | | | | | ... | ... | ... | ... | ... | ... | | | | | |
| `0x70` | `beq $a2, $a3, FIM` *(não tomado)* | | | | | | | | | | ... | **EX** | **MEM** | **WB** | | | |
| `0x74` | `addi $k0, $zero, 999` | | | | | | | | | | ... | **ID** | **EX** | **MEM** | **WB** | | |
| `0x78` | `addi $k1, $zero, 111` | | | | | | | | | | ... | **IF** | **ID** | **EX** | **MEM** | **WB** | |
| `0x7C` | `break` | | | | | | | | | | ... | | **IF** | **ID** | **EX** | **MEM** | **WB** (`done=1`) |
| — | *Slots ativos (`stage_valid`)* | `1` | `2` | `3` | `4` | `5` | `5` | `5` | `5` | `5` | `5` | `5` | `5` | `4` | `3` | `2` | `1` |
| — | *Instruções úteis retiradas (`retired`)* | `0` | `0` | `0` | `0` | `1` | `1` | `1` | `1` | `1` | `1` | `1` | `1` | `1` | `1` | `1` | `0` |

> **Observação sobre a ausência de conflito no ciclo 6 (`0x10: add $t4, $t0, $t1`)**: No ciclo 6, quando `add $t4, $t0, $t1` está em `ID`, a produtora de `$t0` (`0x00`, distância 4) já concluiu no ciclo 5, e a produtora de `$t1` (`0x04`, distância 3) está em **`WB`**. Como `WB` escreve na **borda de descida** do ciclo 6 e `ID` lê combinacionalmente na 2ª metade do ciclo 6, `$t1` já é lido atualizado (`20`), sem conflito RAW.

---

## 2. Traço `TD` — Conflito de Dados RAW (`hazard_type = "01"`)

No traço `tracos/td.asm`, a instrução em `0x04` (`add $t1, $t0, $t0`) consome `$t0` (`R8`) imediatamente após `0x00` (`addi $t0, $zero, 10`), configurando **distância 1**:

| Endereço | Instrução (`td.asm`) | Ciclo 1 | Ciclo 2 | Ciclo 3 (ABORTO!) |
| :---: | :--- | :---: | :---: | :---: |
| `0x00` | `addi $t0, $zero, 10` *(escreve `$t0`)* | **IF** | **ID** | **EX** (`ex_reg_write=1`, `ex_wa=$t0`) |
| `0x04` | `add $t1, $t0, $t0` *(lê `$t0`)* | | **IF** | **ID** (`id_rs=$t0`, `id_rt=$t0` -> **RAW!**) |
| `0x08` | `break` | | | **IF** |

- **Instante da Detecção**: No **Ciclo 3**, a instrução produtora (`0x00`) está em `EX` (`ex_valid = '1'`, `ex_reg_write = '1'`, `ex_wa = "01000"`) e a instrução consumidora (`0x04`) está em `ID` (`id_uses_rs = '1'`, `id_rs = "01000"`).
- **Sinais de Saída no Ciclo 3**:
  - `hazard_abort = '1'` (congela todo o pipeline imediatamente)
  - `hazard_type = "01"` (Conflito de Dados — RAW)
  - `hazard_pc = 0x00000004` (PC da instrução consumidora em `ID`)
  - `hazard_cycle = 3`

---

## 3. Traço `TE` — Conflito Estrutural (`hazard_type = "10"`, `MEM_UNIFICADA = true`)

No traço `tracos/te.asm`, a instrução `0x00` (`sw $zero, 0($zero)`) alcança o estágio `MEM` no **Ciclo 4**, exatamente quando o estágio `IF` busca a instrução `0x0C`:

| Endereço | Instrução (`te.asm`) | Ciclo 1 | Ciclo 2 | Ciclo 3 | Ciclo 4 (ABORTO com `MEM_UNIFICADA=true`!) |
| :---: | :--- | :---: | :---: | :---: | :---: |
| `0x00` | `sw $zero, 0($zero)` | **IF** | **ID** | **EX** | **MEM** (`mem_valid=1`, `mem_write=1` -> **Usa Memória!**) |
| `0x04` | `add $zero, $zero, $zero` | | **IF** | **ID** | **EX** |
| `0x08` | `add $zero, $zero, $zero` | | | **IF** | **ID** |
| `0x0C` | `add $zero, $zero, $zero` | | | | **IF** (`if_valid=1` -> **Disputa porta única da Memória!**) |

- **Instante da Detecção (`MEM_UNIFICADA = true`)**: No **Ciclo 4**, `MEM` realiza escrita na memória (`mem_valid = '1'` e `mem_mem_write = '1'`) simultaneamente à busca válida em `IF` (`if_valid = '1'`).
- **Sinais de Saída no Ciclo 4**:
  - `hazard_abort = '1'` (bloqueia inclusive a escrita do `sw` em `MEM` via `freeze_pipe = '1'`)
  - `hazard_type = "10"` (Conflito Estrutural)
  - `hazard_pc = 0x0000000C` (PC da instrução mais nova em `IF`)
  - `hazard_cycle = 4`
- **Comportamento com `MEM_UNIFICADA = false` (Harvard)**: Não há disputa de porta; o traço conclui normalmente no **Ciclo 9** (`done = '1'`, `4` instruções úteis retiradas, `0` erros).

---

## 4. Traço `TC` — Conflito de Controle (`hazard_type = "11"`)

No traço `tracos/tc.asm`, a instrução `0x00` (`beq $zero, $zero, ALVO`) tem desvio tomado avaliado no estágio `EX` durante o **Ciclo 3**:

| Endereço | Instrução (`tc.asm`) | Ciclo 1 | Ciclo 2 | Ciclo 3 (ABORTO!) |
| :---: | :--- | :---: | :---: | :---: |
| `0x00` | `beq $zero, $zero, ALVO` | **IF** | **ID** | **EX** (`ex_branch=1`, `alu_zero=1` -> **Desvio Tomado!**) |
| `0x04` | `addi $t0, $zero, 1` *(caminho sequencial errado)* | | **IF** | **ID** (`id_valid=1` -> **Instrução indevida já no pipeline!**) |
| `0x08` | `addi $t1, $zero, 2` *(caminho sequencial errado)* | | | **IF** (`if_valid=1` -> **Instrução indevida já buscada!**) |
| `0x0C` | `ALVO: break` | | | *(Deveria ser o alvo do desvio)* |

- **Instante da Detecção**: No **Ciclo 3**, a ULA em `EX` confirma `ex_alu_zero = '1'` para o `beq` (`ex_take_branch = '1'`), enquanto `ID` (`0x04`) e `IF` (`0x08`) já contêm instruções buscadas do fluxo sequencial incorreto (`PC + 4` e `PC + 8`).
- **Sinais de Saída no Ciclo 3**:
  - `hazard_abort = '1'`
  - `hazard_type = "11"` (Conflito de Controle)
  - `hazard_pc = 0x00000000` (PC da instrução de desvio em `EX`)
  - `hazard_cycle = 3`
