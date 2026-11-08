# Banco de Registradores (`banco_reg`)

Documentação do módulo de banco de registradores de 32 bits com 32 registradores de uso geral para a arquitetura MIPS32, baseado na especificação de **Patterson & Hennessy (5ª edição)**.

---

## 1. Interface e Sinais (Portos)

Entidade correspondente definida em [`banco_reg.vhd`](file:///C:/Users/alons/microproj-2026-prof/comum/banco_reg.vhd):

| Sinal | Direção | Largura | Descrição |
|---|---|---|---|
| `clk` | Entrada | 1 bit | Sinal de clock principal. |
| `rst` | Entrada | 1 bit | Reset global **síncrono** (ativo em `'1'`). Zera todos os 32 registradores na borda de descida. |
| `we` | Entrada | 1 bit | *Write Enable*: habilita escrita síncrona no registrador apontado por `wa`. |
| `ra1` | Entrada | 5 bits | Endereço do 1º registrador a ser lido (devolve em `rd1`). |
| `ra2` | Entrada | 5 bits | Endereço do 2º registrador a ser lido (devolve em `rd2`). |
| `wa` | Entrada | 5 bits | Endereço do registrador de destino para escrita. |
| `wd` | Entrada | 32 bits | Dado de 32 bits a ser escrito no registrador `wa`. |
| `rd1` | Saída | 32 bits | Dado lido do registrador apontado por `ra1` (combinacional). |
| `rd2` | Saída | 32 bits | Dado lido do registrador apontado por `ra2` (combinacional). |
| `dbg_addr` | Entrada | 5 bits | Endereço do registrador para monitoração externa/depuração. |
| `dbg_data` | Saída | 32 bits | Dado lido do registrador selecionado por `dbg_addr` (combinacional). |

---

## 2. Decisões de Projeto e Arquitetura

### 2.1. Escrita e Reset na Borda de Descida (`falling_edge(clk)`)
- O processo sequencial é sensível **exclusivamente ao clock** (`process(clk)`).
- A escrita e o reset ocorrem estritamente na borda de descida do clock (`falling_edge(clk)`), que marca o meio do ciclo do processador.
- As leituras são puramente combinacionais: na 2ª metade do ciclo (após a descida), a leitura já enxerga o novo valor escrito, permitindo que registradores de estágios seguintes capturem o dado atualizado na borda de subida seguinte.
- Este modelo segue a convenção clássica do Patterson & Hennessy, eliminando hazards de leitura-após-escrita no mesmo ciclo sem necessidade de lógica complexa de *forwarding* interno ao banco.
- **Uso em O1 e O2**: O mesmo componente é utilizado no monociclo (O1) e no pipeline (O2) para manter uniformidade e simplicidade.

### 2.2. Reset Síncrono com Prioridade sobre a Escrita
O reset é síncrono e avaliado dentro do bloco `if falling_edge(clk)`:
```vhdl
if rst = '1' then
  regs <= (others => (others => '0'));
elsif we = '1' and unsigned(wa) /= 0 then
  regs(to_integer(unsigned(wa))) <= wd;
end if;
```
- **Avaliação na borda**: Se `rst = '1'`, o banco só é zerado na borda de descida subsequente; transições no sinal `rst` fora da borda de descida não alteram o conteúdo dos registradores.
- **Prioridade de controle**: Quando `rst = '1'` e `we = '1'` ocorrem simultaneamente na borda de descida, o comando de reset possui precedência absoluta sobre a escrita, garantindo integridade no reinício do sistema.

### 2.3. Proteção Rígida do Registrador `$zero` (R0)
No MIPS, o registrador `$zero` (`00000`) deve conter impreterivelmente o valor constante zero (`0x00000000`). O hardware implementa dupla proteção:
1. **Bloqueio de escrita**: A escrita só é efetuada se `unsigned(wa) /= 0`. Tentativas de escrever em `$zero` são ignoradas.
2. **Leitura forçada**: As saídas `rd1`, `rd2` e `dbg_data` retornam `(others => '0')` imediatamente se o endereço correspondente for `0`, independentemente de qualquer valor interno.

---

## 3. Comportamento Temporal

### 3.1. Relação Clock e Reset Síncrono

```text
Tempo (ns):   0     5     10    15    20    25
              |     |     |     |     |     |
clk:        __|^^^^^|_____|^^^^^|_____|^^^^^|_____
              ^     v     ^     v     ^
            Sub1  Desc1 Sub2  Desc2 Sub3

rst:        ____|^^^^^^^^^^^^^^^^^|___________
                Ativação      Liberação
```

- Em $t \approx 2\text{ ns}$ (após `Sub1`): `rst` vai para `'1'`. Por ser síncrono, **nenhum registrador é alterado imediatamente**. O conteúdo anterior continua visível em `rd1`, `rd2` e `dbg_data`.
- Em $t = 5\text{ ns}$ (`Desc1`): o clock transiciona para nível baixo (`falling_edge(clk)`). O processo detecta `rst = '1'` e zera todos os 32 registradores de forma síncrona.

---

### 3.2. Exemplo Prático de Escrita e Leitura no Mesmo Ciclo

Considere:
- Período de clock: $T = 10\text{ ns}$ (sobe em $0\text{ ns}$, desce em $5\text{ ns}$, sobe em $10\text{ ns}$).
- Registrador `$t0` (`wa = 8` / `ra1 = 8`), valor inicial: `42` (`0x0000002A`).
- Em $t = 0\text{ ns}$ (borda de subida), são apresentados:
  - Escrita: `we = '1'`, `wa = 8` (`$t0`), `wd = 99` (`0x00000063`).
  - Leitura: `ra1 = 8` (`$t0`).

| Momento do Ciclo | Intervalo ($T = 10\text{ ns}$) | O que acontece no Hardware | Valor lido em `rd1` |
|---|---|---|---|
| **1ª Metade do Ciclo** | $0\text{ ns} \le t < 5\text{ ns}$ (antes da borda de descida) | A borda de descida ainda não ocorreu. O registrador mantém o valor antigo. | Valor Antigo: `42` (`0x0000002A`) |
| **Meio do Ciclo** | $t = 5\text{ ns}$ (`falling_edge(clk)`) | O processo síncrono grava `wd` (`99`) na posição `regs(8)`. | Transição para `99` |
| **2ª Metade do Ciclo** | $5\text{ ns} < t < 10\text{ ns}$ (após a borda de descida) | A leitura combinacional propaga imediatamente o novo valor de `regs(8)` antes da próxima borda de subida. | Valor Novo: `99` (`0x00000063`) |

---

## 4. Porta de Depuração (`dbg_addr` / `dbg_data`)

O banco disponibiliza uma terceira porta de leitura independente, dedicada a *testbenches*, sondas de depuração ou exibição em displays externos:
- Opera de forma combinacional, sem interferir nas portas `rd1` e `rd2` utilizadas pelo fluxo de dados do processador.
- Também obedece à regra do registrador `$zero` (retorna zero quando `dbg_addr = 0`).

---

## 5. Validação no Testbench ([`tb_banco_reg.vhd`](file:///C:/Users/alons/microproj-2026-prof/comum/tb_banco_reg.vhd))

A suíte de testes cobre 9 cenários de validação rigorosos:
- **T01**: Escrita e leitura básica de valor em `$t0`.
- **T02**: Leituras combinacionais simultâneas em registradores distintos (`$t0` e `$t1`).
- **T03**: Leitura do registrador `$zero` (deve retornar `0x00000000`).
- **T04**: Tentativa de escrita em `$zero` (comprova que `$zero` permanece imutável).
- **T05**: Inibição de escrita com `we = '0'`.
- **T06**: Escrita e leitura no mesmo ciclo (metade antiga vs. metade nova).
- **T07**: Porta de monitoramento e depuração (`dbg_addr` e `dbg_data`).
- **T08**: **Comportamento estritamente síncrono do reset**:
  1. Aplica `rst = '1'` e verifica antes da borda de descida se o banco **não** zera de modo assíncrono.
  2. Confirma a reinicialização dos registradores logo após a borda de descida (`falling_edge(clk)`).
- **T09**: **Prioridade do reset sobre a escrita**:
  - Aplica simultaneamente `rst = '1'` e `we = '1'` com dado novo; verifica se o reset prevalece e impede a escrita.


---

## 5. Validação no Testbench ([`tb_banco_reg.vhd`](file:///C:/Users/alons/microproj-2026-prof/comum/tb_banco_reg.vhd))

A suíte de testes cobre 9 cenários de validação rigorosos:
- **T01**: Escrita e leitura básica de valor em `$t0`.
- **T02**: Leituras combinacionais simultâneas em registradores distintos (`$t0` e `$t1`).
- **T03**: Leitura do registrador `$zero` (deve retornar `0x00000000`).
- **T04**: Tentativa de escrita em `$zero` (comprova que `$zero` permanece imutável).
- **T05**: Inibição de escrita com `we = '0'`.
- **T06**: Escrita e leitura no mesmo ciclo (metade antiga vs. metade nova).
- **T07**: Porta de monitoramento e depuração (`dbg_addr` e `dbg_data`).
- **T08**: **Comportamento estritamente síncrono do reset**:
  1. Aplica `rst = '1'` e verifica antes da borda de descida se o banco **não** zera de modo assíncrono.
  2. Confirma a reinicialização dos registradores logo após a borda de descida (`falling_edge(clk)`).
- **T09**: **Prioridade do reset sobre a escrita**:
  - Aplica simultaneamente `rst = '1'` e `we = '1'` com dado novo; verifica se o reset prevalece e impede a escrita.