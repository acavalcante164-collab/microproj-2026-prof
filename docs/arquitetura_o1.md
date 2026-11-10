# Arquitetura da Organização O1 (Linha de Base — Monociclo)

Documentação arquitetural da organização de linha de base **O1 (MIPS32 Monociclo)**, projetada conforme a microarquitetura clássica e convenção de sinais de controle de **Patterson & Hennessy (2017)** [1].

---

## 1. Justificativa da Escolha: Monociclo vs. Multiciclo

O enunciado permite adotar uma organização Monociclo ou Multiciclo como linha de base (**O1**). Optou-se pela organização **Monociclo** pelos seguintes motivos:

1. **Contraste Direto de CPI vs. Período de Clock ($T_{\text{clk}}$)**: No Monociclo, cada instrução é executada em um único ciclo ($\text{CPI}_{\text{útil}} = 1{,}0$, ou $\text{CPI}_{\text{total}} = (N+1)/N$ incluindo o ciclo de término do `break`), porém o período de relógio $T_{\text{clk, O1}}$ é penalizado pela soma em série de todos os elementos do caminho crítico da instrução mais lenta (`lw`). Isso oferece um contraponto direto e didático ao Pipeline de 5 estágios (**O2**), que reduz o período de clock ao atraso do estágio mais lento somado ao *overhead* do registrador de estágio.
2. **Por que não Multiciclo?**: Uma organização Multiciclo quebraria a execução das instruções em múltiplos passos controlados por uma Máquina de Estados Finitos (FSM), compartilhando recursos (como uma única ULA e memória unificada), mas resultaria em um **$\text{CPI} > 1$ variável** conforme o *mix* de instruções (tipicamente 3 ciclos para `beq`, 4 para tipo-R/`sw`/`addi` e 5 para `lw`). Além de exigir lógica sequencial de controle mais complexa, o Multiciclo misturaria variações de CPI com variações de período de clock na comparação de *speedup* contra `O2`, tornando menos transparente a análise isolada do ganho de paralelismo temporal do pipeline.
3. **Papel de Linha de Base de Desempenho (e não Oráculo Funcional)**: A verificação de corretude funcional dos registradores ao final da simulação utiliza como referência áurea (*oráculo*) os valores extraídos do simulador **MARS** e consolidados nos arquivos `*_esperado.txt`. O papel da organização **O1** é servir exclusivamente como **referência de linha de base para número de ciclos, tempo de execução e cálculo de *speedup*** frente à organização **O2**.

---

## 2. Caminho de Dados e Separação de Memórias (Arquitetura Harvard)

O caminho de dados e os nomes dos sinais da unidade de controle (`reg_dst`, `alu_src`, `mem_to_reg`, `reg_write`, `mem_read`, `mem_write`, `branch`, `alu_op`) seguem fielmente o projeto monociclo de Patterson & Hennessy [1]:

- **Memória de Instruções (`comum/instruction_memory.vhd`)**: Memória somente de leitura (ROM) puramente combinacional, inicializada a partir do arquivo hexadecimal indicado pelo genérico `PROG_FILE`.
- **Memória de Dados (`comum/data_memory.vhd`)**: Memória RAM com leitura combinacional (`mem_read = '1'`, instrução `lw`) e escrita síncrona na borda de descida (`mem_write = '1'`, instrução `sw`).
- **Capacidade e Endereçamento (*Wrap-around*)**: Ambas as memórias possuem capacidade fixa de **1024 palavras de 32 bits (4 KB)**, indexadas diretamente pelos bits `addr(11 downto 2)` (endereçamento alinhado à palavra, ignorando os 2 bits menos significativos `addr(1 downto 0)`). Como os bits superiores `addr(31 downto 12)` são descartados na indexação da matriz VHDL, endereços iguais ou superiores a `4096` bytes (`0x00001000`) sofrem **dobramento modular (*wrap-around*)** dentro da janela de 4 KB (`endereço_efetivo = (addr / 4) mod 1024`).

---

## 3. Temporização de Meio Ciclo e Interação com o Testbench

Na simulação funcional RTL em VHDL:
1. **Borda de Subida (`rising_edge(clk)`)**: Atualiza o registrador `pc_reg` com `pc_next` (exceto quando congelado por `break`).
2. **1ª Metade do Ciclo (`clk = '1'`)**: A instrução buscada propaga combinacionalmente pela Unidade de Controle, leitura do Banco de Registradores, extensor de sinal, ULA e leitura da Memória de Dados (na simulação RTL sem atrasos de porta, esses sinais estabilizam em *delta cycles* após a borda de subida).
3. **Borda de Descida (`falling_edge(clk)`, meio do ciclo)**:
   - O componente compartilhado `banco_reg` realiza a escrita síncrona de `reg_wd` no registrador destino `reg_wa`.
   - A `data_memory` realiza a escrita síncrona de `reg_rd2` nas instruções `sw`.
   - **Amostragem pelo Testbench (`tb/tb_cpu.vhd`)**: O processo principal do testbench executa `wait until falling_edge(clk)` e amostra **exatamente na borda de descida** os sinais `done`, `hazard_abort`, `retired` e `stage_valid(0)`.

### 3.1. Limitações e Ameaças à Validade (Impacto sobre o Período de Clock $T_{\text{clk, O1}}$)

Reutilizar exatamente o mesmo módulo `comum/banco_reg.vhd` (que escreve na **borda de descida**, no meio do ciclo) tanto em `O2` quanto em `O1` simplifica o projeto de RTL, mas impõe uma distinção importante entre **simulação comportamental sem atraso** e **temporização física real**:

- Em `O2` (Pipeline), quem escreve no banco na borda de descida é o estágio `WB`, cujo dado já está registrado no barramento `MEM/WB` desde a borda de subida; logo, apenas o caminho do multiplexador de `WB` mais o tempo de *setup* do banco precisam caber na 1ª metade do ciclo.
- Em `O1` (Monociclo), porém, se a escrita física no banco ocorrer na borda de descida (em $T_{\text{clk, O1}} / 2$), todo o caminho crítico da instrução mais lenta (`lw`: `PC` $\rightarrow$ Memória de Instruções $\rightarrow$ Decodificação/Leitura do Banco $\rightarrow$ ULA $\rightarrow$ Memória de Dados $\rightarrow$ Mux `mem_to_reg` $\rightarrow$ *setup* do Banco) precisa propagar e estabilizar **dentro da 1ª metade do ciclo** ($T_{\text{clk, O1}} / 2$), enquanto a 2ª metade do ciclo fica ociosa para a instrução `lw`.

Para o cálculo das métricas temporais (Issue #15) e análise crítica no relatório, adota-se o **Critério Clássico de Livro-Texto (com ameaça à validade declarada)**:
- **Critério adotado no cálculo de métricas**: Calcula-se $T_{\text{clk, O1}}$ pela soma padrão dos atrasos dos componentes ao longo do caminho crítico completo da instrução `lw` assumindo captura no fim do ciclo ($T_{\text{clk, O1}} = t_{\text{PC}} + t_{\text{IMEM}} + t_{\text{RegRead}} + t_{\text{ULA}} + t_{\text{DMEM}} + t_{\text{Mux}} + t_{\text{RegSetup}}$), como em Patterson & Hennessy [1], e registra-se como **ameaça à validade interna** que o RTL simulado antecipa o gatilho de escrita para a borda de descida a fim de compartilhar a entidade `banco_reg` com `O2` e sincronizar com a amostragem em `falling_edge(clk)` do testbench.
- *(Nota comparativa)*: Caso a síntese física do Monociclo mantivesse literalmente a escrita na borda de descida com *duty cycle* de $50\%$, o período mínimo real de `O1` teria de ser duplicado ($T_{\text{clk, O1}}^{\text{meio-ciclo}} = 2 \times T_{\text{caminho\_lw}}$), penalizando ainda mais a frequência máxima do Monociclo.

---

## 4. Semântica da Instrução `break` e Congelamento do `PC`

Quando a Memória de Instruções entrega a palavra correspondente a `break` (`opcode = "000000"`, `funct = "001101"`):
1. **No próprio ciclo da instrução `break` (combinacionalmente)**:
   - A Unidade de Controle ativa `is_break = '1'` e mantém `reg_write = '0'` e `mem_write = '0'`.
   - O sinal de topo `done` vai imediatamente a `'1'` (`done <= '1' when halted_reg = '1' or (rst = '0' and is_break = '1')`), de modo que o testbench já enxerga `done = '1'` na borda de descida daquele mesmo ciclo e encerra a contagem de ciclos.
   - O sinal `retired` recebe `"00"`, garantindo que `break` não seja contabilizada como instrução útil.
2. **Congelamento do `PC` e do estado (`halted_reg`)**:
   - Na borda de subida seguinte, como `is_break = '1'`, o registrador `halted_reg` recebe `'1'` e **`pc_reg` não recebe `pc_next`**, permanecendo **congelado exatamente no endereço da instrução `break`** até que ocorra um novo pulso de reset (`rst = '1'`).

---

## 5. Referências

[1] PATTERSON, D. A.; HENNESSY, J. L. **Organização e Projeto de Computadores: A Interface Hardware/Software**. 5. ed. Rio de Janeiro: Elsevier, 2017.
