# Especificação da Interface de Topo `cpu_top` (Requisito R3) e Nota sobre O3

Este documento especifica a entidade de topo padronizada `cpu_top` compartilhada entre as organizações **O1 (Monociclo)** e **O2 (Pipeline de 5 estágios)**, permitindo que o mesmo testbench (`tb/tb_cpu.vhd`) verifique ambas as arquiteturas sem modificações.

---

## 1. Esclarecimento sobre Menções à Organização O3 (Issue #26)

O enunciado menciona uma terceira organização (`O3`, superescalar de 2 vias) em trechos dos requisitos R3 e R4, mas restringe o escopo de implementação exclusivamente às organizações **O1** e **O2**. 

Conforme confirmado com o professor:
1. Apenas **O1** e **O2** são implementadas no projeto.
2. **A interface R3 original deve ser integralmente mantida** na entidade `cpu_top` para preservar a compatibilidade com o testbench único:
   - `stage_valid` mantém largura de **10 bits** (`std_logic_vector(9 downto 0)`).
   - `retired` mantém largura de **2 bits** (`unsigned(1 downto 0)` ou `std_logic_vector(1 downto 0)` conforme o pacote utilizado).

---

## 2. Parâmetros Genéricos (`generic`)

| Genérico | Tipo | Valor Padrão | Descrição |
| :--- | :--- | :--- | :--- |
| `PROG_FILE` | `string` | `"tracos/t0.hex"` | Caminho do arquivo hexadecimal carregado na Memória de Instruções. |
| `MEM_UNIFICADA` | `boolean` | `false` | Em `O2`, quando `true`, ativa a detecção de conflito estrutural (`hazard_type = "10"`) entre busca (`IF`) e acesso a dados (`MEM`) no mesmo ciclo. |

---

## 3. Portas da Entidade `cpu_top` (`port`)

| Sinal | Direção | Tipo / Largura | Comportamento em O1 (Monociclo) | Comportamento em O2 (Pipeline) |
| :--- | :---: | :--- | :--- | :--- |
| `clk` | `in` | `std_logic` | Relógio principal do sistema. | Relógio principal do sistema. |
| `rst` | `in` | `std_logic` | Reset síncrono ativo em `'1'`. | Reset síncrono ativo em `'1'`. |
| `done` | `out` | `std_logic` | Vai a `'1'` quando `break` é executada e congela o estado. | Vai a `'1'` quando `break` atinge o estágio `WB` e congela o estado. |
| `hazard_abort` | `out` | `std_logic` | Constante `'0'` (O1 não possui hazards de pipeline). | Vai a `'1'` ao detectar conflito (RAW, estrutural ou controle) e congela o processador. |
| `hazard_type` | `out` | `std_logic_vector(1 downto 0)` | Constante `"00"`. | `"00"` = nenhum, `"01"` = dados (RAW), `"10"` = estrutural, `"11"` = controle. |
| `hazard_pc` | `out` | `std_logic_vector(31 downto 0)` | Constante `x"00000000"`. | PC da instrução prejudicada (RAW/Estrutural) ou do desvio tomado (Controle). |
| `hazard_cycle` | `out` | `std_logic_vector(31 downto 0)` | Constante `x"00000000"`. | Ciclo em que o conflito ocorreu (contado a partir de 1 no 1º ciclo após `rst = '0'`). |
| `retired` | `out` | `std_logic_vector(1 downto 0)` | `"01"` a cada instrução útil concluída (`"00"` durante `rst`, no `break` ou após `done`). | `"01"` quando uma instrução útil válida conclui em `WB`; `"00"` para bolha, `break` ou congelado. |
| `stage_valid` | `out` | `std_logic_vector(9 downto 0)` | Usa apenas `stage_valid(0)` (`'1'` enquanto executa instrução válida); bits `9 downto 1` fixos em `'0'`. | Usa `stage_valid(4 downto 0)` para indicar validade em `(4=>WB, 3=>MEM, 2=>EX, 1=>ID, 0=>IF)`; bits `9 downto 5` fixos em `'0'`. |
| `dbg_reg_addr` | `in` | `std_logic_vector(4 downto 0)` | Endereço de leitura da porta de depuração do Banco de Registradores. | Endereço de leitura da porta de depuração do Banco de Registradores. |
| `dbg_reg_data` | `out` | `std_logic_vector(31 downto 0)` | Dado lido combinacionalmente do registrador apontado por `dbg_reg_addr`. | Dado lido combinacionalmente do registrador apontado por `dbg_reg_addr`. |