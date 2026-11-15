# Guia Completo de Execução e Rastreabilidade dos Artefatos (MSYS2 UCRT64 e MARS 4.5)

**Autores:** Alonso Fernandes Cavalcante, Gwylherme Mota Rodrigues  
**Instituição:** Departamento de Ciência da Computação — Universidade Federal de Roraima (DCC/UFRR)  
**Disciplina:** Arquitetura e Organização de Computadores  

---

## 1. Visão Geral e Mapa de Todos os Artefatos do Repositório

A tabela abaixo mapeia cada arquivo do projeto, explicando sua função arquitetural, onde ele reside no repositório e qual ferramenta o utiliza (**GHDL**, **GTKWave**, **Python 3** no terminal **MSYS2 UCRT64** ou o simulador **MARS 4.5**):

| Diretório / Artefato | Tipo | Onde é Usado | Papel no Projeto e Como Funciona |
| :--- | :---: | :---: | :--- |
| **`comum/ula.vhd`** | VHDL-2008 | GHDL (`O1` e `O2`) | Unidade Lógica e Aritmética de 32 bits (`AND`, `OR`, `ADD`, `SUB`, `SLT`) e geração da flag `zero`. |
| **`comum/alu_control.vhd`** | VHDL-2008 | GHDL (`O1` e `O2`) | Decodificador secundário: recebe `alu_op(1:0)` e `funct(5:0)` e gera `alu_ctrl(3:0)` para a ULA. |
| **`comum/sign_ext.vhd`** | VHDL-2008 | GHDL (`O1` e `O2`) | Extensor de sinal de 16 bits (`imm16`) para 32 bits (`imm32`). |
| **`comum/banco_reg.vhd`** | VHDL-2008 | GHDL (`O1` e `O2`) | Banco de 32 registradores de 32 bits (`$0` fixo em `0`). Escreve na **borda de descida (`falling_edge`)** e lê combinacionalmente (`ra1`, `ra2` e `dbg_addr`). |
| **`comum/instruction_memory.vhd`** | VHDL-2008 | GHDL (`O1` e `O2`) | ROM de instruções de 1024 palavras de 32 bits (4 KB) carregada via genérico `PROG_FILE` (`.hex`), com endereçamento modular (`addr(11 downto 2)`). |
| **`comum/data_memory.vhd`** | VHDL-2008 | GHDL (`O1` e `O2`) | RAM de dados de 1024 palavras de 32 bits (4 KB), escrita na **borda de descida** (`sw`) e leitura combinacional (`lw`). |
| **`o1/control_unit.vhd`** | VHDL-2008 | GHDL (`O1` e `O2`) | Unidade de Controle principal: decodifica `opcode` e `funct` nas 10 instruções da ISA (`add`, `sub`, `and`, `or`, `slt`, `addi`, `lw`, `sw`, `beq`, `break`). |
| **`o1/cpu_top.vhd`** | VHDL-2008 | GHDL (`build/o1`) | Topo da organização **O1 (Monociclo)** compatível com a interface padronizada **R3**. |
| **`o2/cpu_top.vhd`** | VHDL-2008 | GHDL (`build/o2`) | Topo da organização **O2 (Pipeline de 5 estágios: IF, ID, EX, MEM, WB)** com registradores de estágio (426 bits) e **Unidade de Detecção de Hazards** (R5). |
| **`tb/tb_cpu.vhd`** | VHDL-2008 | GHDL (`O1` e `O2`) | Testbench único unificado: aplica reset por 2 ciclos, amostra sinais na borda de descida, valida abortos ou os 32 registradores finais e grava `metricas.csv`. |
| **`tracos/*.asm`** | Assembly MIPS | **MARS 4.5** | Código-fonte em linguagem de montagem para `t0`, Série `S` (`s5`..`s200`) e traços de conflito (`td`, `te`, `tc`). |
| **`tracos/*.hex`** | Hexadecimal | **MARS 4.5** $\rightarrow$ **GHDL** | Código de máquina (1 palavra de 8 dígitos hexadecimais por linha) exportado pelo MARS e lido por `instruction_memory.vhd` via `PROG_FILE`. |
| **`tracos/*_esperado.txt`** | Texto (Gabarito) | **MARS 4.5** $\rightarrow$ **GHDL** | Estado final esperado dos registradores (`numero_reg valor_hex`) aferido no MARS e verificado automaticamente por `tb_cpu.vhd` via `ESPERADO_FILE`. |
| **`scripts/gen_serie_s.py`** | Python 3 | UCRT64 | Gera automaticamente os arquivos `.asm`, `.hex` e `_esperado.txt` (32 registradores) da Série `S` (`s5`, `s10`, `s20`, `s50`, `s100`, `s200`). |
| **`scripts/process_metrics.py`** | Python 3 | UCRT64 | Lê `metricas.csv`, aplica os tempos da Fig. 4.27 ($T_{\text{clk, O1}} = 0{,}80\text{ ns}$, $T_{\text{clk, O2}} = 0{,}20\text{ ns}$), gera `metricas_completas.csv` e plota os 3 gráficos em `graficos/`. |
| **`run_all.sh`** | Script Bash | UCRT64 | Script mestre (Requisito R7): limpa, gera a Série `S`, compila `O1` e `O2`, roda as 18 simulações no GHDL, processa métricas e plota os gráficos. |
| **`waves/o1_view.gtkw`** e **`o2_view.gtkw`** | Config GTKWave | GTKWave | Perfis visuais que já abrem os sinais de clock, estágios do pipeline, banco de registradores e sinais de hazard agrupados na tela. |

---

## 2. Preparação do Ambiente no MSYS2 UCRT64 (Windows)

### 2.1. Onde abrir o terminal correto
No menu Iniciar do Windows, abra especificamente o terminal **MSYS2 UCRT64** (ícone roxo/azul escuro do MSYS2).

### 2.2. Instalação das ferramentas (GHDL, GTKWave e Python + Matplotlib)
Caso esteja em uma máquina nova, execute o comando abaixo no terminal **UCRT64** para instalar todas as ferramentas nativas:

```bash
pacman -Syu --noconfirm
pacman -S --noconfirm \
  mingw-w64-ucrt-x86_64-ghdl-llvm \
  mingw-w64-ucrt-x86_64-gtkwave \
  mingw-w64-ucrt-x86_64-python \
  mingw-w64-ucrt-x86_64-python-matplotlib
```

### 2.3. Navegação até a pasta do repositório
Sempre antes de executar qualquer comando, entre no diretório raiz do projeto:

```bash
cd "/c/Users/alons/microproj-2026-prof"
```

---

## 3. Tutorial Passo a Passo no Simulador MARS 4.5 (Oráculo Funcional)

O simulador **MARS 4.5** é usado como **oráculo externo independente** para:
1. Montar os programas `.asm` (`t0.asm`, `s5.asm`..`s200.asm`, `td.asm`, `te.asm`, `tc.asm`).
2. Exportar o código de máquina hexadecimal (`.hex`) que alimenta a memória de instruções do VHDL.
3. Executar o programa passo a passo ou até o `break` para conferir os valores finais dos 32 registradores (que compõem os arquivos `*_esperado.txt`) e da memória de dados.

### 3.1. Configuração Obrigatória de Memória no MARS (`Compact, Data at Address 0`)
Como as memórias `instruction_memory.vhd` e `data_memory.vhd` do nosso processador iniciam no endereço `0x00000000` (4 KB de `0x00000000` a `0x00000FFF`) e instruções como `sw $t4, 0($zero)` acessam o endereço `0x00000000`:
1. Abra o **MARS 4.5**.
2. No menu superior, clique em **`Settings` $\rightarrow$ `Memory Configuration...`**.
3. Selecione a opção **`Compact, Data at Address 0`** (ou, quando quiser inspecionar apenas o código a partir de `0x00000000`, `Compact, Text at Address 0`).
4. Clique em **`Apply and Close`**.

### 3.2. Como Abrir e Montar um Traço (`.asm`) no MARS
1. Clique em **`File` $\rightarrow$ `Open...`** e selecione, por exemplo, `C:\Users\alons\microproj-2026-prof\tracos\t0.asm` (ou `s20.asm`).
2. Pressione **`F3`** (ou clique em **`Run` $\rightarrow$ `Assemble`**).
3. Na aba inferior **Mars Messages**, confirme a mensagem:
   `Assemble: operation completed successfully.`
4. Na tabela **Text Segment**, a coluna **`Code`** exibe exatamente as palavras hexadecimais de 32 bits que estão gravadas no arquivo `.hex` correspondente.

### 3.3. Como Exportar o Arquivo `.hex` pelo MARS
Se você quiser gerar ou validar um arquivo `.hex` diretamente pelo MARS:
1. Com o programa montado (`F3`), vá em **`File` $\rightarrow$ `Dump Memory...`**.
2. Em **Memory Segment**, selecione **`.text`**.
3. Em **Dump Format**, selecione **`Hexadecimal Text`**.
4. Clique em **`Dump To File...`** e salve para comparar linha a linha com `tracos/t0.hex` ou `tracos/s20.hex`.

### 3.4. Como Executar e Conferir os 32 Registradores (`*_esperado.txt`) no MARS
1. Com o programa montado (`F3`), caso queira que `$gp` (reg 28) e `$sp` (reg 29) comecem em zero igual ao hardware após o reset, dê duplo clique no valor de `$gp` e `$sp` no painel direito **Registers** e digite `0`.
2. Pressione **`F5`** (ou clique no ícone verde **Run**) para rodar até a instrução `break` (ou pressione **`F7`** para avançar instrução por instrução).
3. Compare os valores hexadecimais da coluna **Value** no painel **Registers** (registradores `0` a `31`) com o arquivo `tracos/t0_esperado.txt` ou `tracos/s20_esperado.txt`:
   - Exemplo em **`s20.asm`**:
     - `$t0` (Reg `8`) = `0x00000028` (`40`)
     - `$t1` (Reg `9`) = `0x0000000c` (`12`)
     - `$t3` (Reg `11`) = `0x0000000e` (`14`)
     - `$t4` (Reg `12`) = `0x00000001` (`1`)
     - Demais registradores = `0x00000000`.

---

## 4. Execução Automatizada Completa no UCRT64 (`./run_all.sh`)

Para reproduzir **todo o projeto** com um único comando no terminal **MSYS2 UCRT64**:

```bash
cd "/c/Users/alons/microproj-2026-prof"
./run_all.sh
```

### O que o `./run_all.sh` faz internamente (7 etapas em sequência):
1. **Etapa 1:** Cria as pastas `build/o1`, `build/o2`, `tracos`, `graficos`, reinicia `metricas.csv` com o cabeçalho de 13 colunas e executa `python3 scripts/gen_serie_s.py` para gerar `s5`, `s10`, `s20`, `s50`, `s100` e `s200`.
2. **Etapa 2:** Compila (`ghdl -a` e `ghdl -e`) os componentes comuns (`comum/*.vhd`), `o1/control_unit.vhd`, `o1/cpu_top.vhd` e `tb/tb_cpu.vhd` dentro do diretório isolado `build/o1`.
3. **Etapa 3:** Compila os componentes comuns, `o1/control_unit.vhd`, `o2/cpu_top.vhd` e `tb/tb_cpu.vhd` dentro do diretório isolado `build/o2`.
4. **Etapa 4:** Simula o traço principal `T0` em **O1** (`32 ciclos, 0 erro(s)`) e em **O2** (`36 ciclos, 0 erro(s)`), salvando as ondas `build/o1_t0.ghw` e `build/o2_t0.ghw`.
5. **Etapa 5:** Simula todos os 6 traços da **Série S** (`s5` a `s200`) em **O1** e em **O2** (12 simulações, todas com `0 erro(s)`).
6. **Etapa 6:** Simula os **4 cenários de conflito** em **O2** (`TD`, `TE` com `MEM_UNIFICADA=true`, `TE` com `MEM_UNIFICADA=false` e `TC`), salvando as ondas `.ghw` correspondentes.
7. **Etapa 7:** Executa `python3 scripts/process_metrics.py`, que gera a tabela final `metricas_completas.csv` e plota os 3 gráficos em `graficos/`.

Para visualizar a tabela consolidada logo após o `./run_all.sh`:

```bash
cat metricas_completas.csv
```

---

## 5. Como Compilar e Executar Cada Artefato Individualmente no UCRT64

Durante a apresentação ou defesa, o professor pode pedir para você compilar ou rodar **apenas uma organização** ou **apenas um traço específico** passando parâmetros genéricos (`-g...`) ao GHDL. Abaixo estão os comandos individuais prontos:

### 5.1. Compilar e Rodar `O1` (Monociclo) em Qualquer Traço Limpo (`T0` ou `S5..S200`)

```bash
# 1. Compilar O1 em build/o1
mkdir -p build/o1
ghdl -a --std=08 --workdir=build/o1 \
  comum/ula.vhd comum/banco_reg.vhd comum/sign_ext.vhd \
  comum/alu_control.vhd comum/instruction_memory.vhd comum/data_memory.vhd \
  o1/control_unit.vhd o1/cpu_top.vhd tb/tb_cpu.vhd
ghdl -e --std=08 --workdir=build/o1 tb_cpu

# 2. Simular O1 executando T0 (gera build/o1_t0.ghw)
ghdl -r --std=08 --workdir=build/o1 tb_cpu \
  -gORG_NOME=O1 \
  -gNUM_SLOTS=1 \
  -gPROG_FILE=tracos/t0.hex \
  -gESPERADO_FILE=tracos/t0_esperado.txt \
  --wave=build/o1_t0.ghw
```
* **Saída esperada:** `tb/tb_cpu.vhd:180:5:@356ns:(report note): O1: fim da simulacao, 32 ciclos, 0 erro(s)`

---

### 5.2. Compilar e Rodar `O2` (Pipeline 5 Estágios) no Traço Principal `T0`

```bash
# 1. Compilar O2 em build/o2
mkdir -p build/o2
ghdl -a --std=08 --workdir=build/o2 \
  comum/ula.vhd comum/banco_reg.vhd comum/sign_ext.vhd \
  comum/alu_control.vhd comum/instruction_memory.vhd comum/data_memory.vhd \
  o1/control_unit.vhd o2/cpu_top.vhd tb/tb_cpu.vhd
ghdl -e --std=08 --workdir=build/o2 tb_cpu

# 2. Simular O2 executando T0 (gera build/o2_t0.ghw)
ghdl -r --std=08 --workdir=build/o2 tb_cpu \
  -gORG_NOME=O2 \
  -gNUM_SLOTS=5 \
  -gPROG_FILE=tracos/t0.hex \
  -gESPERADO_FILE=tracos/t0_esperado.txt \
  --wave=build/o2_t0.ghw
```
* **Saída esperada:** `tb/tb_cpu.vhd:180:5:@396ns:(report note): O2: fim da simulacao, 36 ciclos, 0 erro(s)`

---

### 5.3. Rodar os Traços de Conflito (`TD`, `TE`, `TC`) Individualmente em `O2`

1. **Conflito de Dados RAW (`tracos/td.hex` — Tipo Esperado = `1` / `"01"`, PC = `4`, Ciclo = `3`):**
   ```bash
   ghdl -r --std=08 --workdir=build/o2 tb_cpu \
     -gORG_NOME=O2 -gNUM_SLOTS=5 \
     -gPROG_FILE=tracos/td.hex \
     -gESPERA_ABORTO=true -gTIPO_ESPERADO=1 -gPC_ESPERADO=4 \
     --wave=build/o2_td.ghw
   ```
   * **Saída esperada:** `O2: ABORTO tipo=01 pc=0x00000004 ciclo=3` (`0 erro(s)`).

2. **Conflito Estrutural com Memória Unificada (`tracos/te.hex` — `MEM_UNIFICADA=true`, Tipo Esperado = `2` / `"10"`, PC = `12` / `0x0C`, Ciclo = `4`):**
   ```bash
   ghdl -r --std=08 --workdir=build/o2 tb_cpu \
     -gORG_NOME=O2 -gNUM_SLOTS=5 \
     -gPROG_FILE=tracos/te.hex \
     -gMEM_UNIFICADA=true -gESPERA_ABORTO=true -gTIPO_ESPERADO=2 -gPC_ESPERADO=12 \
     --wave=build/o2_te.ghw
   ```
   * **Saída esperada:** `O2: ABORTO tipo=10 pc=0x0000000C ciclo=4` (`0 erro(s)`).

3. **Prova de Ausência de Conflito Estrutural com Memória Separada (`tracos/te.hex` — `MEM_UNIFICADA=false`):**
   ```bash
   ghdl -r --std=08 --workdir=build/o2 tb_cpu \
     -gORG_NOME=O2 -gNUM_SLOTS=5 \
     -gPROG_FILE=tracos/te.hex -gESPERADO_FILE=tracos/te_esperado.txt \
     -gMEM_UNIFICADA=false -gESPERA_ABORTO=false \
     --wave=build/o2_te_harvard.ghw
   ```
   * **Saída esperada:** `O2: fim da simulacao, 9 ciclos, 0 erro(s)`.

4. **Conflito de Controle em Desvio Tomado (`tracos/tc.hex` — Tipo Esperado = `3` / `"11"`, PC = `0`, Ciclo = `3`):**
   ```bash
   ghdl -r --std=08 --workdir=build/o2 tb_cpu \
     -gORG_NOME=O2 -gNUM_SLOTS=5 \
     -gPROG_FILE=tracos/tc.hex \
     -gESPERA_ABORTO=true -gTIPO_ESPERADO=3 -gPC_ESPERADO=0 \
     --wave=build/o2_tc.ghw
   ```
   * **Saída esperada:** `O2: ABORTO tipo=11 pc=0x00000000 ciclo=3` (`0 erro(s)`).

---

## 6. Como Abrir e Analisar as Formas de Onda no GTKWave (via UCRT64)

Após rodar `./run_all.sh` (ou qualquer simulação individual com `--wave=...`), abra o **GTKWave** passando o arquivo `.ghw` junto com o perfil visual `.gtkw`:

### 6.1. Comandos para abrir cada forma de onda
* **Monociclo (`O1`) executando `T0`:**
  ```bash
  gtkwave build/o1_t0.ghw waves/o1_view.gtkw
  ```
* **Pipeline (`O2`) executando `T0` (Enchimento, Regime Permanente, Meio Ciclo e Esvaziamento):**
  ```bash
  gtkwave build/o2_t0.ghw waves/o2_view.gtkw
  ```
* **Conflito de Dados RAW (`TD` em `O2`):**
  ```bash
  gtkwave build/o2_td.ghw waves/o2_view.gtkw
  ```
* **Conflito Estrutural (`TE` com `MEM_UNIFICADA=true` em `O2`):**
  ```bash
  gtkwave build/o2_te.ghw waves/o2_view.gtkw
  ```
* **Conflito de Controle (`TC` em `O2`):**
  ```bash
  gtkwave build/o2_tc.ghw waves/o2_view.gtkw
  ```

### 6.2. Atalho Essencial de Zoom no GTKWave
Assim que a janela do GTKWave abrir, clique na área preta das ondas e pressione **`Ctrl + Alt + F`** (*Zoom To Fit*). Isso enquadra todos os ciclos da simulação na tela inteira.

### 6.3. O que mostrar na tela do GTKWave durante a defesa
1. **Escrita na Borda de Descida (`falling_edge(clk)`) em `O2`:**
   - Observe o grupo `Escrita Meio Ciclo (WB -> Banco de Regs)`: no meio do ciclo (borda de descida de `clk`, ex.: `70 ns` no Ciclo 5 de `T0`), `wb_we_gated = '1'`, `wb_wa = 8` (`$t0`) e `wb_wd = 0x0000000A` (`10`).
2. **Enchimento e Esvaziamento dos 5 Estágios (`if_valid` a `wb_valid`):**
   - Nos Ciclos 1 a 4 (`25 ns` a `65 ns`), veja os sinais `if_valid`, `id_valid`, `ex_valid`, `mem_valid` e `wb_valid` ligando em formato de escada.
   - Nos Ciclos 32 a 36 (`335 ns` a `380 ns`), quando o `break` (`0x0000007C`) entra em `ID`, `if_valid` cai para `'0'` e os estágios desligam em escada até `wb_pc = 0x0000007C` acionar `done = '1'` no Ciclo 36.
3. **Congelamento Imediato em Conflito (`build/o2_td.ghw`, `o2_te.ghw`, `o2_tc.ghw`):**
   - Veja `hazard_abort` e `freeze_pipe` subindo para `'1'` exatamente no ciclo do conflito (`cycle_cnt = 3` em `TD`/`TC` e `cycle_cnt = 4` em `TE`), travando `hazard_type`, `hazard_pc` e `hazard_cycle`.

---

## 7. Como Salvar este Tutorial Dentro da Pasta `docs/` do Repositório

Se quiser gravar este tutorial também como `docs/tutorial_execucao.md` no seu repositório Git, basta copiar o arquivo gerado ao lado ou adicioná-lo com `git add docs/ && git commit -m "Adiciona tutorial completo de execucao no UCRT64 e MARS" && git push origin develop`.