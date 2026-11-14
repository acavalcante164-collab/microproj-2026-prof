# Especificação dos Registradores Entre Estágios do Pipeline O2 (Issue #19 — Requisito R4)

Documentação exata de todos os sinais que compõem os quatro registradores de estágio (`IF/ID`, `ID/EX`, `EX/MEM`, `MEM/WB`) implementados em `o2/cpu_top.vhd`, seguindo a organização clássica de **Patterson & Hennessy (2017)** [1] acrescida dos bits de validade (`valid`), endereço da instrução (`pc`) e flag de término (`is_break`) exigidos pela interface **R3** e pela unidade de detecção de conflitos (**R5**).

---

## 1. Resumo da Largura em Bits por Registrador de Estágio

| Registrador de Pipeline | Sinais de Estado / Rastreio (`valid`, `pc`, `is_break`) | Sinais de Controle da ISA | Barramentos de Dados e Endereços | **Largura Total (bits)** |
| :--- | :---: | :---: | :---: | :---: |
| **`IF/ID`** | $1 + 32 = 33\text{ bits}$ | $0\text{ bits}$ *(ainda codificados na instrução)* | $32\text{ bits}$ (`id_instr`) | **65 bits** |
| **`ID/EX`** | $1 + 32 + 1 = 34\text{ bits}$ | $8\text{ bits}$ (`alu_src`, `alu_op[1:0]`, `mem_to_reg`, `reg_write`, `mem_read`, `mem_write`, `branch`) | $32 + 32 + 32 + 5 + 6 = 107\text{ bits}$ | **149 bits** |
| **`EX/MEM`** | $1 + 32 + 1 = 34\text{ bits}$ | $4\text{ bits}$ (`mem_to_reg`, `reg_write`, `mem_read`, `mem_write`) | $32 + 32 + 5 = 69\text{ bits}$ | **107 bits** |
| **`MEM/WB`** | $1 + 32 + 1 = 34\text{ bits}$ | $2\text{ bits}$ (`mem_to_reg`, `reg_write`) | $32 + 32 + 5 = 69\text{ bits}$ | **105 bits** |
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
