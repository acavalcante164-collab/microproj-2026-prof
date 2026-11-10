# Pipeline de 5 Estágios (O2) e Unidade de Detecção de Conflitos (Requisitos R4 e R5)

Documentação técnica da organização **O2 (Pipeline escalar de 5 estágios: IF, ID, EX, MEM, WB)**, sem *forwarding*, *stall*, *flush* ou predição de desvio, equipada com Unidade de Detecção de Hazards e semântica de aborto e congelamento, baseada em **Patterson & Hennessy (2017)** [1].

---

## 1. Semântica de Conclusão do `break` em O2 (Issue #6)

Em `O2`, quando a instrução `break` (`opcode = "000000"`, `funct = "001101"`) entra no estágio `ID` (`break_in_flight = '1'`), o estágio `IF` cessa a busca de novas instruções (`if_valid = '0'`) e o `PC` estaciona no endereço do `break`. O `break` propaga normalmente pelos registradores `ID/EX`, `EX/MEM` e `MEM/WB` (com `reg_write = '0'` e `mem_write = '0'`) até atingir o estágio **`WB`** (`wb_valid = '1'` e `wb_is_break = '1'`). Nesse instante, todas as instruções úteis anteriores já escreveram seus resultados no Banco de Registradores e na Memória de Dados, o sinal `done` vai a `'1'` e o pipeline é congelado.

---

## 2. Regras da Unidade de Detecção de Hazards (Issues #7, #8, #9 e #10)

### 2.1. Conflito de Dados — RAW (`hazard_type = "01"`, Issue #7)
- **Condição**: Detectado no estágio `ID` quando uma instrução válida lê `rs` (`id_uses_rs = '1'`) ou `rt` (`id_uses_rt = '1'`) e o registrador lido coincide com o registrador destino (`wa /= "00000"`) de uma instrução anterior válida com `reg_write = '1'` que ainda está no estágio **`EX`** (distância 1) ou **`MEM`** (distância 2).
- **Exceção do registrador `$zero`**: Escritas em `$0` (`wa = "00000"`) nunca disparam conflito RAW (`unsigned(ex_wa) /= 0` e `unsigned(mem_wa) /= 0`).
- **Efeito da Escrita em Meio Ciclo (Distância 3 Limpa)**: Como o módulo `comum/banco_reg.vhd` escreve na **borda de descida (`falling_edge(clk)`)** e lê combinacionalmente na 2ª metade do ciclo, uma instrução produtora no estágio **`WB`** (distância 3 em relação a `ID`) atualiza o registrador na metade do ciclo e a instrução consumidora em `ID` já captura o valor atualizado antes da borda de subida seguinte. Logo, **distância $\ge 3$ é livre de conflitos**.
- **`hazard_pc`**: Recebe `id_pc` (endereço da instrução consumidora prejudicada).

### 2.2. Conflito Estrutural — `MEM_UNIFICADA` (`hazard_type = "10"`, Issue #8)
- **Condição**: Avaliado exclusivamente quando o genérico `MEM_UNIFICADA = true`. Ocorre quando uma instrução válida em `MEM` acessa a memória de dados (`mem_mem_read = '1'` para `lw` ou `mem_mem_write = '1'` para `sw`) no mesmo ciclo em que `IF` realiza uma busca de instrução válida (`if_valid = '1'`).
- **Com `MEM_UNIFICADA = false`**: O sinal `struct_hazard` permanece fixo em `'0'` (arquitetura Harvard com memórias separadas).
- **`hazard_pc`**: Recebe `pc_reg` (endereço da instrução mais nova em `IF`, que não obteve a porta única da memória).

### 2.3. Conflito de Controle — Desvio Tomado (`hazard_type = "11"`, Issue #9)
- **Estágio de Resolução do Desvio**: O desvio condicional `beq` é resolvido no estágio **`EX`**, onde a ULA calcula `rd1 - rd2` e ativa a flag `ex_alu_zero` (`ex_take_branch = ex_valid and ex_branch and ex_alu_zero`).
- **Condição**: Ocorre quando `ex_take_branch = '1'` no estágio `EX` e já existem instruções buscadas sequencialmente nos estágios anteriores (`id_valid = '1'` ou `if_valid = '1'`).
- **Justificativa para a Defesa — Por que `beq` NÃO tomado não é conflito?**: O estágio `IF` busca incondicionalmente a sequência linear `PC + 4`, `PC + 8` nos ciclos seguintes ao `beq`. Quando o `beq` chega em `EX` e o resultado da comparação é falso (`ex_alu_zero = '0'`, desvio não tomado), as instruções que já entraram em `ID` (`PC + 4`) e `IF` (`PC + 8`) são exatamente as instruções corretas do fluxo sequencial do programa. Portanto, nenhuma instrução indevida foi buscada e a execução prossegue sem necessidade de *flush* ou aborto (como comprovado pelo `beq` não tomado no endereço `0x70` do traço `T0`).
- **`hazard_pc`**: Recebe `ex_pc` (endereço da instrução de desvio em `EX`).

### 2.4. Semântica de Aborto e Congelamento (Issue #10)
Ao detectar qualquer conflito (`any_hazard = '1'`):
1. `hazard_abort` vai imediatamente a `'1'` no próprio ciclo do conflito (e é registrado em `abort_reg` para permanecer em `'1'` até o próximo `rst = '1'`).
2. `hazard_type`, `hazard_pc` e `hazard_cycle` (contado a partir de `1` no 1º ciclo após `rst = '0'`) são travados nos valores do ciclo exato da detecção.
3. O sinal `freeze_pipe` vai a `'1'`, bloqueando simultaneamente a escrita no Banco de Registradores (`wb_we_gated = '0'`), a escrita na Memória de Dados (`mem_mw_gated = '0'`), a atualização do `PC` e o avanço dos registradores de estágio `IF/ID`, `ID/EX`, `EX/MEM` e `MEM/WB`.

---

## 3. Tabela de Registro de Conflitos Verificados (Issue #11)

Resultados obtidos pela simulação automatizada no `tb/tb_cpu.vhd`:

| Traço | Organização | `MEM_UNIFICADA` | Tipo Esperado | Tipo Detectado (`hazard_type`) | `hazard_pc` Esperado | `hazard_pc` Obtido | `hazard_cycle` Obtido | Desfecho |
| :--- | :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: |
| `tracos/td.hex` | `O2` | `false` | Dados — RAW (`01`) | `01` (`1`) | `0x00000004` | `0x00000004` | `3` | Aborto esperado (0 erros) |
| `tracos/te.hex` | `O2` | `true` | Estrutural (`10`) | `10` (`2`) | `0x0000000C` | `0x0000000C` | `4` | Aborto esperado (0 erros) |
| `tracos/te.hex` | `O2` | `false` | Nenhum (`00`) | `00` (`0`) | — | — | — (9 ciclos) | Concluído (`done=1`, 0 erros) |
| `tracos/tc.hex` | `O2` | `false` | Controle (`11`) | `11` (`3`) | `0x00000000` | `0x00000000` | `3` | Aborto esperado (0 erros) |

---

## Referências
[1] PATTERSON, D. A.; HENNESSY, J. L. **Organização e Projeto de Computadores: A Interface Hardware/Software**. 5. ed. Rio de Janeiro: Elsevier, 2017.
