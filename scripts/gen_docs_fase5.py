#!/usr/bin/env python3
import os

os.makedirs("docs", exist_ok=True)
BT3 = "`" * 3

# 1. Issue #18: docs/diagramas_execucao.md
doc18 = """# Diagramas de Execução Instrução × Ciclo (Issue #18 — Requisitos R4 e R5)

Representação temporal ciclo a ciclo da progressão das instruções nas organizações **O1 (Monociclo)** e **O2 (Pipeline de 5 estágios: IF, ID, EX, MEM, WB)**, extraída diretamente das simulações em `tb/tb_cpu.vhd`.

---

## 1. Traço Principal `T0` (31 Instruções Úteis + `break` = 32 Instruções)

### 1.1. Comparação Global: O1 vs. O2 em `T0`
- **Em O1 (Monociclo)**: Cada instrução $I_k$ ($k \\in \\{0, \\dots, 30\\}$) executa integralmente (Busca, Decodificação, ULA, Memória e Escrita) em **1 único ciclo** ($C = k + 1$). No ciclo **32**, a instrução `break` (`0x7C`) é decodificada, eleva `done = '1'` com `retired = "00"` e encerra a execução em **32 ciclos** ($25{,}60\\text{ ns}$).
- **Em O2 (Pipeline de 5 Estágios)**:
  - **Fase de Enchimento (Ciclos 1 a 4)**: Nos 4 primeiros ciclos, o pipeline está sendo preenchido (`wb_valid = '0'`, portanto `retired = "00"`).
  - **Regime Permanente (Ciclos 5 a 35)**: Todos os 5 estágios estão ocupados; a cada ciclo, 1 instrução útil conclui no estágio `WB` (`retired = "01"`), totalizando 31 instruções úteis retiradas.
  - **Fase de Esvaziamento e Conclusão (Ciclos 32 a 36)**: A instrução `break` (`0x7C`) é buscada em `IF` no ciclo 32. A partir do ciclo 33, `break_in_flight = '1'` desativa novas buscas (`if_valid = '0'`), drenando o pipeline até que o `break` alcance o estágio `WB` no **ciclo 36**, quando `done = '1'` e a simulação encerra em **36 ciclos** ($7{,}20\\text{ ns}$).

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
"""

# 2. Issue #19: docs/registradores_pipeline.md
doc19 = """# Especificação dos Registradores Entre Estágios do Pipeline O2 (Issue #19 — Requisito R4)

Documentação exata de todos os sinais que compõem os quatro registradores de estágio (`IF/ID`, `ID/EX`, `EX/MEM`, `MEM/WB`) implementados em `o2/cpu_top.vhd`, seguindo a organização clássica de **Patterson & Hennessy (2017)** [1] acrescida dos bits de validade (`valid`), endereço da instrução (`pc`) e flag de término (`is_break`) exigidos pela interface **R3** e pela unidade de detecção de conflitos (**R5**).

---

## 1. Resumo da Largura em Bits por Registrador de Estágio

| Registrador de Pipeline | Sinais de Estado / Rastreio (`valid`, `pc`, `is_break`) | Sinais de Controle da ISA | Barramentos de Dados e Endereços | **Largura Total (bits)** |
| :--- | :---: | :---: | :---: | :---: |
| **`IF/ID`** | $1 + 32 = 33\\text{ bits}$ | $0\\text{ bits}$ *(ainda codificados na instrução)* | $32\\text{ bits}$ (`id_instr`) | **65 bits** |
| **`ID/EX`** | $1 + 32 + 1 = 34\\text{ bits}$ | $8\\text{ bits}$ (`alu_src`, `alu_op[1:0]`, `mem_to_reg`, `reg_write`, `mem_read`, `mem_write`, `branch`) | $32 + 32 + 32 + 5 + 6 = 107\\text{ bits}$ | **149 bits** |
| **`EX/MEM`** | $1 + 32 + 1 = 34\\text{ bits}$ | $4\\text{ bits}$ (`mem_to_reg`, `reg_write`, `mem_read`, `mem_write`) | $32 + 32 + 5 = 69\\text{ bits}$ | **107 bits** |
| **`MEM/WB`** | $1 + 32 + 1 = 34\\text{ bits}$ | $2\\text{ bits}$ (`mem_to_reg`, `reg_write`) | $32 + 32 + 5 = 69\\text{ bits}$ | **105 bits** |
| **Total no Pipeline O2** | **135 bits** | **14 bits** | **277 bits** | **426 bits** |

---

## 2. Detalhamento Campo a Campo

### 2.1. Registrador `IF/ID` (65 bits)
Capturado na borda de subida do clock quando `freeze_pipe = '0'`:

| Sinal VHDL (`o2/cpu_top.vhd`) | Largura (bits) | Origem (`IF`) | Destino / Papel no Estágio `ID` e Detecção de Hazards |
| :--- | :---: | :--- | :--- |
| `id_valid` | 1 | `if_valid` | Indica se há instrução válida em `ID`; compõe `stage_valid(1)` e valida detecção de RAW/Controle. |
| `id_pc` | 32 | `pc_reg` | Endereço da instrução em `ID`; reportado em `hazard_pc` caso ocorra conflito RAW (`tipo = "01"`). |
| `id_instr` | 32 | `if_instr` | Palavra de instrução de 32 bits vinda da ROM; subdividida em `opcode`, `rs`, `rt`, `rd`, `imm16` e `funct`. |

### 2.2. Registrador `ID/EX` (149 bits)
Propaga operandos lidos do Banco de Registradores, imediato estendido e todos os sinais de controle para `EX`, `MEM` e `WB`:

| Sinal VHDL (`o2/cpu_top.vhd`) | Largura (bits) | Origem (`ID`) | Destino / Papel nos Estágios `EX`, `MEM`, `WB` e Hazards |
| :--- | :---: | :--- | :--- |
| `ex_valid` | 1 | `id_valid` | Indica se há instrução válida em `EX`; compõe `stage_valid(2)` e qualifica conflitos RAW/Controle. |
| `ex_pc` | 32 | `id_pc` | Endereço da instrução em `EX`; reportado em `hazard_pc` quando ocorre conflito de Controle (`tipo = "11"`). |
| `ex_rd1` | 32 | `id_rd1` | Valor lido da porta 1 do Banco de Registradores (`Regs[rs]`), conectado à entrada `A` da ULA. |
| `ex_rd2` | 32 | `id_rd2` | Valor lido da porta 2 (`Regs[rt]`), usado na entrada `B` da ULA (tipo-R/`beq`) ou como dado de escrita no `sw`. |
| `ex_imm32` | 32 | `id_imm32` | Imediato de 16 bits com extensão de sinal para 32 bits (`addi`, `lw`, `sw`). |
| `ex_wa` | 5 | `id_wa` | Endereço do registrador destino (`rd` se `reg_dst='1'`, senão `rt`); comparado com `id_rs`/`id_rt` para detectar RAW de distância 1. |
| `ex_funct` | 6 | `id_funct` | Campo `instr(5 downto 0)` entregue ao `alu_control` no estágio `EX`. |
| `ex_alu_src` | 1 | `id_alu_src` | Seleciona a entrada `B` da ULA em `EX` (`'0'` = `ex_rd2`, `'1'` = `ex_imm32`). |
| `ex_alu_op` | 2 | `id_alu_op` | Código de operação para o módulo `alu_control` (`"00"` soma, `"01"` sub/beq, `"10"` olha `funct`). |
| `ex_mem_to_reg` | 1 | `id_mem_to_reg` | Propagado até `WB` para selecionar entre saída da memória e saída da ULA. |
| `ex_reg_write` | 1 | `id_reg_write` | Habilita escrita no Banco de Registradores em `WB` e qualifica produtoras na detecção de RAW em `EX`. |
| `ex_mem_read` | 1 | `id_mem_read` | Propagado para habilitar leitura da Memória de Dados em `MEM` (`lw`). |
| `ex_mem_write` | 1 | `id_mem_write` | Propagado para habilitar escrita na Memória de Dados em `MEM` (`sw`). |
| `ex_branch` | 1 | `id_branch` | Combinado com `ex_alu_zero` em `EX` (`ex_take_branch`) para detectar desvio tomado (`beq`). |
| `ex_is_break` | 1 | `id_is_break` | Indica que a instrução em `EX` é `break` (mantém `break_in_flight = '1'`). |

### 2.3. Registrador `EX/MEM` (107 bits)
Armazena o resultado da ULA, o dado para escrita em memória (`sw`) e os sinais de controle de `MEM` e `WB`:

| Sinal VHDL (`o2/cpu_top.vhd`) | Largura (bits) | Origem (`EX`) | Destino / Papel nos Estágios `MEM`, `WB` e Hazards |
| :--- | :---: | :--- | :--- |
| `mem_valid` | 1 | `ex_valid` | Indica instrução válida em `MEM`; compõe `stage_valid(3)` e qualifica RAW (distância 2) e Conflito Estrutural. |
| `mem_pc` | 32 | `ex_pc` | Endereço da instrução no estágio `MEM` para rastreabilidade até `WB`. |
| `mem_alu_result` | 32 | `ex_alu_result` | Resultado calculado pela ULA (endereço efetivo de `lw`/`sw` ou resultado aritmético/lógico). |
| `mem_rd2` | 32 | `ex_rd2` | Dado a ser gravado na Memória de Dados (`wd`) nas instruções `sw`. |
| `mem_wa` | 5 | `ex_wa` | Registrador destino; comparado com `id_rs`/`id_rt` para detectar conflito RAW de distância 2. |
| `mem_mem_to_reg` | 1 | `ex_mem_to_reg` | Propagado para o multiplexador de escrita do estágio `WB`. |
| `mem_reg_write` | 1 | `ex_reg_write` | Qualifica instruções produtoras no estágio `MEM` (RAW distância 2) e propaga para `WB`. |
| `mem_mem_read` | 1 | `ex_mem_read` | Habilita leitura combinacional na `data_memory` e ativa detecção de Conflito Estrutural quando `MEM_UNIFICADA = true`. |
| `mem_mem_write` | 1 | `ex_mem_write` | Habilita escrita na `data_memory` (na borda de descida) e ativa detecção de Conflito Estrutural quando `MEM_UNIFICADA = true`. |
| `mem_is_break` | 1 | `ex_is_break` | Propaga a identificação da instrução `break` rumo a `WB`. |

### 2.4. Registrador `MEM/WB` (105 bits)
Entrega ao estágio final `WB` o dado lido da memória ou calculado pela ULA para escrita no Banco de Registradores na 1ª metade do ciclo (`falling_edge(clk)`):

| Sinal VHDL (`o2/cpu_top.vhd`) | Largura (bits) | Origem (`MEM`) | Destino / Papel no Estágio `WB` e Interface R3 |
| :--- | :---: | :--- | :--- |
| `wb_valid` | 1 | `mem_valid` | Indica instrução válida em `WB`; compõe `stage_valid(4)`, `retired` e `done`. |
| `wb_pc` | 32 | `mem_pc` | Endereço da instrução que está concluindo no estágio `WB`. |
| `wb_alu_result` | 32 | `mem_alu_result` | Resultado da ULA selecionado quando `wb_mem_to_reg = '0'` (tipo-R e `addi`). |
| `wb_mem_data` | 32 | `mem_rd_data` | Palavra lida da Memória de Dados selecionada quando `wb_mem_to_reg = '1'` (`lw`). |
| `wb_wa` | 5 | `mem_wa` | Endereço do registrador destino (`wa`) conectado à porta de escrita do `banco_reg`. |
| `wb_mem_to_reg` | 1 | `mem_mem_to_reg` | Seleciona o dado final `wb_wd` (`'1'` = `wb_mem_data`, `'0'` = `wb_alu_result`). |
| `wb_reg_write` | 1 | `mem_reg_write` | Combinado com `wb_valid` e `not freeze_pipe` (`wb_we_gated`) para habilitar a escrita no `banco_reg`. |
| `wb_is_break` | 1 | `mem_is_break` | Quando `wb_valid = '1'` e `wb_is_break = '1'`, aciona `done = '1'` e garante `retired = "00"`. |

---

## Referências
[1] PATTERSON, D. A.; HENNESSY, J. L. **Organização e Projeto de Computadores: A Interface Hardware/Software**. 5. ed. Rio de Janeiro: Elsevier, 2017.
"""

# 3. Issue #20: docs/diagramas_blocos.md
doc20 = f"""# Diagramas de Blocos das Organizações O1 (Monociclo) e O2 (Pipeline de 5 Estágios) (Issue #20)

Representação estrutural completa dos caminhos de dados, unidades de controle, multiplexadores e sinais da interface **R3** para ambas as organizações implementadas.

---

## 1. Diagrama de Blocos da Organização O1 (Monociclo — `o1/cpu_top.vhd`)

{BT3}mermaid
flowchart LR
    subgraph IF_Stage ["Busca da Instrução"]
        PC["pc_reg (32b)\\n(Borda de Subida)"] --> IMEM["instruction_memory\\n(1024x32b ROM - 4 KB)"]
        PC --> ADD4["Somador PC + 4"]
    end

    subgraph ID_Stage ["Decodificação e Banco de Registradores"]
        IMEM -->|"instr(31:26), funct(5:0)"| CTRL["control_unit\\n(O1)"]
        IMEM -->|"rs, rt"| BREG["banco_reg (32x32b)\\nEscrita: falling_edge"]
        IMEM -->|"rt, rd"| MUX_WA["Mux reg_dst"]
        MUX_WA -->|"reg_wa"| BREG
        IMEM -->|"imm16"| SEXT["sign_ext\\n(16 -> 32b)"]
    end

    subgraph EX_Stage ["Execução e Endereço de Desvio"]
        BREG -->|"reg_rd1"| ULA["alu (32b)"]
        BREG -->|"reg_rd2"| MUX_ALU["Mux alu_src"]
        SEXT -->|"imm32"| MUX_ALU
        MUX_ALU -->|"alu_b"| ULA
        CTRL -->|"alu_op"| ACTRL["alu_control"]
        IMEM -->|"funct"| ACTRL
        ACTRL -->|"alu_ctrl"| ULA
        ADD4 --> ADDBR["Somador Branch\\n(PC+4 + imm32<<2)"]
        SEXT --> ADDBR
        ADDBR --> MUX_PC["Mux take_branch"]
        ADD4 --> MUX_PC
        MUX_PC -->|"pc_next"| PC
    end

    subgraph MEM_WB ["Memória de Dados e Write-Back"]
        ULA -->|"alu_result"| DMEM["data_memory (4 KB)\\nEscrita: falling_edge"]
        BREG -->|"reg_rd2 (wd)"| DMEM
        DMEM -->|"mem_rd_data"| MUX_WB["Mux mem_to_reg"]
        ULA -->|"alu_result"| MUX_WB
        MUX_WB -->|"reg_wd"| BREG
    end
{BT3}

---

## 2. Diagrama de Blocos da Organização O2 (Pipeline 5 Estágios — `o2/cpu_top.vhd`)

{BT3}mermaid
flowchart LR
    subgraph S1_IF ["1. IF (Busca)"]
        PC2["pc_reg\\n(32b)"] --> IMEM2["instruction_memory\\n(ROM 4 KB)"]
    end

    S1_IF --> R_IF_ID["Reg IF/ID\\n(65 bits)\\nid_valid, id_pc, id_instr"]

    subgraph S2_ID ["2. ID (Decodificação)"]
        R_IF_ID --> CTRL2["control_unit"]
        R_IF_ID --> BREG2["banco_reg\\n(Leitura 2ª metade)"]
        R_IF_ID --> SEXT2["sign_ext"]
    end

    S2_ID --> R_ID_EX["Reg ID/EX\\n(149 bits)\\nex_valid, ex_pc, ex_rd1/2,\\nex_imm32, ex_wa, controles"]

    subgraph S3_EX ["3. EX (Execução)"]
        R_ID_EX --> ULA2["alu + alu_control\\nex_alu_result, ex_alu_zero"]
    end

    S3_EX --> R_EX_MEM["Reg EX/MEM\\n(107 bits)\\nmem_valid, mem_pc,\\nmem_alu_result, mem_rd2, mem_wa"]

    subgraph S4_MEM ["4. MEM (Memória)"]
        R_EX_MEM --> DMEM2["data_memory (4 KB)\\n(Escrita falling_edge)"]
    end

    S4_MEM --> R_MEM_WB["Reg MEM/WB\\n(105 bits)\\nwb_valid, wb_pc,\\nwb_alu_result, wb_mem_data, wb_wa"]

    subgraph S5_WB ["5. WB (Escrita)"]
        R_MEM_WB --> MUX_WB2["Mux wb_mem_to_reg"]
        MUX_WB2 -->|"wb_wd (Escrita 1ª metade)"| BREG2
    end

    subgraph HDU ["Unidade de Detecção de Hazards (R5)"]
        R_IF_ID -.->|"id_rs, id_rt, id_pc"| H_LOGIC["Detector RAW (01),\\nEstrutural (10),\\nControle (11)"]
        R_ID_EX -.->|"ex_wa, ex_reg_write,\\nex_take_branch, ex_pc"| H_LOGIC
        R_EX_MEM -.->|"mem_wa, mem_reg_write,\\nmem_read/write"| H_LOGIC
        S1_IF -.->|"if_valid, pc_reg"| H_LOGIC
        H_LOGIC ==>|"freeze_pipe, hazard_abort,\\nhazard_type, hazard_pc, hazard_cycle"| R3_OUT["Saídas Interface R3"]
    end
{BT3}
"""

with open("docs/diagramas_execucao.md", "w", encoding="utf-8", newline="\n") as f:
    f.write(doc18)
with open("docs/registradores_pipeline.md", "w", encoding="utf-8", newline="\n") as f:
    f.write(doc19)
with open("docs/diagramas_blocos.md", "w", encoding="utf-8", newline="\n") as f:
    f.write(doc20)

print("SUCESSO: 3 arquivos gerados em docs/ (Issues #18, #19 e #20)!")
