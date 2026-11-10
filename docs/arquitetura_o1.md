# Arquitetura da Organização O1 (Linha de Base — Monociclo)

## 1. Justificativa da Escolha do Monociclo como Linha de Base
A organização **O1** foi projetada como um processador **MIPS32 Monociclo** (1 ciclo por instrução, $\text{CPI}_{\text{útil}} \approx 1{,}0$) pelas seguintes razões arquiteturais e metodológicas:
1. **Isolamento do Ganho de Frequência vs. Ganho de Latência em Ciclos**: No Monociclo, toda instrução atravessa o caminho de dados completo em um único ciclo de relógio, exigindo um período de clock ($T_{\text{clk, O1}}$) ditado pela instrução mais lenta (`lw`: Busca $\rightarrow$ Decodificação/Leitura de Registradores $\rightarrow$ ULA $\rightarrow$ Memória de Dados $\rightarrow$ Escrita no Banco). Isso cria o contraste didático ideal com o Pipeline de 5 estágios (**O2**), onde o número de ciclos aumenta ligeiramente devido ao enchimento/esvaziamento ($N + 4$), mas o período de clock cai drasticamente para o atraso do estágio mais lento.
2. **Ausência Nativa de Hazards**: Por concluir integralmente cada instrução antes de atualizar o `PC` na borda de subida seguinte, `O1` é imune a conflitos de dados (RAW), estruturais e de controle, servindo como referência áurea (*golden model* em hardware) para validar os estados finais de todos os traços limpos (`T0` e série `S`).

## 2. Separação de Memórias (Arquitetura Harvard)
Em `O1`, o caminho de dados utiliza memórias fisicamente separadas:
- **Memória de Instruções (`comum/instruction_memory.vhd`)**: ROM combinacional inicializada via arquivo `.hex` (`PROG_FILE`), indexada por `pc_reg(11 downto 2)`.
- **Memória de Dados (`comum/data_memory.vhd`)**: RAM com leitura combinacional (`lw`) e escrita síncrona na borda de descida (`sw`), indexada pelo resultado da ULA (`alu_result(11 downto 2)`).

## 3. Temporização de Meio Ciclo no Banco de Registradores
O módulo `comum/banco_reg.vhd` é compartilhado sem alterações entre `O1` e `O2`:
- **1ª metade do ciclo (`rising_edge` até `falling_edge`)**: O `PC` atualiza na borda de subida; a instrução é buscada, decodificada e processada pela ULA/Memória de Dados.
- **Meio do ciclo (`falling_edge(clk)`)**: O dado final (`reg_wd`) já está estável e é gravado no Banco de Registradores (ou na Memória de Dados, no caso do `sw`).
- **2ª metade do ciclo (`falling_edge` até a próxima `rising_edge`)**: As saídas combinacionais já refletem o estado atualizado e os sinais `done`, `retired` e `stage_valid(0)` são amostrados pelo testbench unificado (`tb/tb_cpu.vhd`).

## 4. Tratamento da Instrução `break`
Ao decodificar `opcode = "000000"` e `funct = "001101"` (`break`), a unidade de controle ativa `is_break = '1'`, bloqueando qualquer escrita (`we_gated = '0'`, `mw_gated = '0'`), levando `done = '1'` e `retired = "00"` (pois `break` não é contabilizada como instrução útil) e travando o registrador `halted_reg = '1'` até o próximo reset.
