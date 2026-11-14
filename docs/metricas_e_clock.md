# Metodologia de Período de Clock, Restrição de Meio Ciclo e Métricas (Issues #14, #15 e #17 — Requisito R6)

---

## 1. Regra Única do Período de Clock e Tabela do Livro-Texto (Issue #15)

### 1.1. Regra Única Aplicada a Ambas as Organizações
> **Regra de Temporização**: *"O período de clock mínimo ($T_{\text{clk}}$) de qualquer organização é determinado pelo atraso do caminho combinacional mais longo entre dois elementos de estado consecutivos somado ao overhead de um registrador de estado ($T_{\text{caminho\_max}} + t_{\text{reg}}$), respeitando a restrição de meio ciclo do banco de registradores ($T_{\text{clk}} / 2 \ge \max(t_{\text{RegWrite}}, t_{\text{RegRead}})$)."*

### 1.2. Origem dos Atrasos vs. Hipóteses Adotadas
Os tempos das 5 etapas funcionais são extraídos **literalmente da Figura 4.27 (Capítulo 4, Seção 4.5 — *An Overview of Pipelining*, p. 273)** de **Patterson & Hennessy (2017)** [1]:

| Etapa Funcional / Estágio | Fonte | Atraso |
| :--- | :--- | :---: |
| Busca de Instrução (`IF` — Memória de Instruções) | Patterson & Hennessy [1], Fig. 4.27 | $200\text{ ps}$ |
| Leitura do Banco de Registradores (`ID`) | Patterson & Hennessy [1], Fig. 4.27 | $100\text{ ps}$ |
| Operação da ULA (`EX`) | Patterson & Hennessy [1], Fig. 4.27 | $200\text{ ps}$ |
| Acesso à Memória de Dados (`MEM`) | Patterson & Hennessy [1], Fig. 4.27 | $200\text{ ps}$ |
| Escrita no Banco de Registradores (`WB`) | Patterson & Hennessy [1], Fig. 4.27 | $100\text{ ps}$ |
| Overhead de registrador de estado ($t_{\text{reg}}$) e multiplexadores | **Hipótese simplificadora do livro (Fig. 4.27)** | $0\text{ ps}$ (incluído nos blocos) |

### 1.3. Aplicação da Regra Única a `O1` e `O2`
- **Organização O1 (Monociclo)**: O caminho mais longo entre atualizações do estado arquitetural é o da instrução `lw`, que atravessa todas as 5 etapas em série:
  $$T_{\text{clk, O1}} = 200 + 100 + 200 + 200 + 100 + 0 = \mathbf{800\text{ ps} \ (0{,}80\text{ ns})} \implies f_{\text{max, O1}} = 1{,}25\text{ GHz}$$
- **Organização O2 (Pipeline de 5 Estágios)**: O caminho mais longo entre dois registradores de pipeline é o maior atraso individual entre os 5 estágios (`IF`, `ID`, `EX`, `MEM`, `WB`):
  $$T_{\text{clk, O2}} = \max(200, 100, 200, 200, 100) + 0 = \mathbf{200\text{ ps} \ (0{,}20\text{ ns})} \implies f_{\text{max, O2}} = 5{,}00\text{ GHz}$$

---

## 2. Verificação da Restrição de Meio Ciclo do Banco de Registradores em `O2`

No nosso projeto (`comum/banco_reg.vhd`), o Banco de Registradores realiza a escrita do estágio `WB` na **borda de descida (`falling_edge(clk)`)** — isto é, ao final da 1ª metade do ciclo — e a leitura combinacional do estágio `ID` na **2ª metade do ciclo**. Portanto, ambas as operações precisam caber em meio período ($T_{\text{clk, O2}} / 2$):

- Com $T_{\text{clk, O2}} = 200\text{ ps}$, temos:
  $$\frac{T_{\text{clk, O2}}}{2} = \frac{200\text{ ps}}{2} = \mathbf{100\text{ ps}}$$
- **1ª metade do ciclo (Escrita em `WB`)**:
  $$t_{\text{WB}} = t_{\text{RegWrite}} = 100\text{ ps} \le \frac{T_{\text{clk, O2}}}{2} = 100\text{ ps} \quad \text{(Atendida exatamente!)}$$
- **2ª metade do ciclo (Leitura em `ID`)**:
  $$t_{\text{ID}} = t_{\text{RegRead}} = 100\text{ ps} \le \frac{T_{\text{clk, O2}}}{2} = 100\text{ ps} \quad \text{(Atendida exatamente!)}$$

Essa verificação demonstra por que, na Figura 4.27 de Patterson & Hennessy [1], os estágios `ID` e `WB` possuem atraso de $100\text{ ps}$ (metade dos $200\text{ ps}$ dos demais estágios): a operação em meio ciclo impõe o limite inferior de $2 \times 100\text{ ps} = 200\text{ ps}$ ao período de `O2`.

---

## 3. Speedup Ideal ($k = 5$), Razão de Clock ($4{,}0\times$) e Speedup Medido (Análise Crítica)

Na avaliação do pipeline de $k = 5$ estágios, distinguem-se três grandezas fundamentais:

1. **Speedup Ideal Teórico do Pipeline ($\text{Speedup}_{\text{ideal}} = k = 5{,}00\times$)**:
   Representa o limite teórico clássico de um pipeline de $k = 5$ estágios **perfeitamente equilibrados** (onde cada estágio teria atraso igual a $T_{\text{clk, O1}} / 5 = 160\text{ ps}$), sem *overhead* de registradores e para um número infinito de instruções ($N \to \infty$).
2. **Razão de Clock / Assíntota Real ($\text{Razão}_{\text{clock}} = T_{\text{clk, O1}} / T_{\text{clk, O2}} = 800\text{ ps} / 200\text{ ps} = 4{,}00\times$)**:
   Por que a razão de clock é $4{,}00\times$ e não $5{,}00\times$? Porque **os estágios do pipeline `O2` não são equilibrados**: três estágios (`IF`, `EX`, `MEM`) exigem $200\text{ ps}$, enquanto dois estágios (`ID` e `WB`) exigem apenas $100\text{ ps}$. Como o relógio do pipeline é nivelado pelo estágio mais lento ($200\text{ ps}$), desperdiçam-se $100\text{ ps}$ de folga em `ID` e $100\text{ ps}$ em `WB`, reduzindo o ganho máximo assintótico de $5{,}00\times$ para **$4{,}00\times$**.
3. **Speedup Medido ($\text{Speedup}_{\text{medido}} = T_{\text{exec, O1}} / T_{\text{exec, O2}}$)**:
   Para um programa finito de $N$ instruções úteis, `O1` executa em $N + 1$ ciclos e `O2` em $N + 5$ ciclos (devido aos $4$ ciclos extras de enchimento/esvaziamento do pipeline):
   $$\text{Speedup}_{\text{medido}}(N) = \frac{(N + 1) \times 0{,}80\text{ ns}}{(N + 5) \times 0{,}20\text{ ns}} = 4{,}00 \times \frac{N + 1}{N + 5}$$
   - Para `S5` ($N = 5$): $\text{Speedup}_{\text{medido}} = 4{,}00 \times (6 / 10) = \mathbf{2{,}400\times}$
   - Para `T0` ($N = 31$): $\text{Speedup}_{\text{medido}} = 4{,}00 \times (32 / 36) = \mathbf{3{,}556\times}$
   - Para `S200` ($N = 200$): $\text{Speedup}_{\text{medido}} = 4{,}00 \times (201 / 205) = \mathbf{3{,}922\times}$ (convergindo assintoticamente para $4{,}00\times$).

---

## 4. Referências
[1] PATTERSON, D. A.; HENNESSY, J. L. **Computer Organization and Design: The Hardware/Software Interface** (Organização e Projeto de Computadores). 5. ed. Morgan Kaufmann / Elsevier, 2017. Seção 4.5, Figura 4.27, p. 273.
