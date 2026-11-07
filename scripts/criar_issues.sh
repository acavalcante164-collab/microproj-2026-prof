#!/usr/bin/env bash
# scripts/criar_issues.sh
# Cria labels, milestones e issues do MicroProj no repositorio indicado.
#
# Uso:
#   DRY_RUN=1 bash scripts/criar_issues.sh      # so mostra o que faria
#   bash scripts/criar_issues.sh                # cria de verdade
#   bash scripts/criar_issues.sh dono/repo      # outro repositorio
#
# Pode ser executado mais de uma vez: itens que ja existem sao ignorados.

set -u

REPO="${1:-acavalcante164-collab/microproj-2026-prof}"
DRY="${DRY_RUN:-0}"

command -v gh >/dev/null 2>&1 || { echo "ERRO: GitHub CLI (gh) nao encontrado."; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "ERRO: rode 'gh auth login' antes."; exit 1; }

echo "Repositorio: $REPO (DRY_RUN=$DRY)"

# ---------------------------------------------------------------- labels
# Sem --force: se a label ja existe, ela e mantida como esta.
label() { # nome | cor | descricao
  if [ "$DRY" = 1 ]; then echo "[simulacao] label: $1"; return; fi
  if gh label create "$1" --repo "$REPO" --color "$2" --description "$3" >/dev/null 2>&1; then
    echo "label criada: $1"
  else
    echo "label ja existe (ou falhou): $1"
  fi
}

echo; echo "== Labels =="
label "P0-crítica"     "B60205" "Bloqueia o caminho crítico"
label "P1-alta"        "D93F0B" "Requisito obrigatório"
label "P2-média"       "FBCA04" "Artefato de relatório/defesa"
label "área:o1"        "1D76DB" "Organização O1 (monociclo)"
label "área:o2"        "0E8A7D" "Organização O2 (pipeline)"
label "área:isa"       "0052CC" "ISA MIPS32"
label "área:hazard"    "C2E0C6" "Unidade de detecção de conflitos"
label "área:testbench" "BFD4F2" "Testbench e verificação"
label "área:tracos"    "D4C5F9" "Traços de execução (.asm, .hex, esperado.txt)"
label "área:metricas"  "F9D0C4" "Métricas, período de clock e gráficos"
label "área:relatorio" "FEF2C0" "Relatório e artefatos"
label "área:defesa"    "E99695" "Defesa oral"
label "área:docs"      "0075CA" "Documentação e esclarecimentos"
label "área:infra"     "5319E7" "Repositório, scripts e toolchain"

# ------------------------------------------------------------ milestones
# Nomes baseados nos checkpoints do cronograma do enunciado (secao 2).
M1="M1 - O1 executa T0"
M2="M2 - O2 executa T0 e aborta em TD, TE e TC"
M3="M3 - Metricas de O1 e O2 geradas"
M4="M4 - Entrega final"
M5="M5 - Avaliacao por pares e defesa"

milestone() { # titulo | descricao
  if [ "$DRY" = 1 ]; then echo "[simulacao] milestone: $1"; return; fi
  if gh api "repos/$REPO/milestones?state=all&per_page=100" --jq '.[].title' | grep -Fxq -- "$1"; then
    echo "milestone ja existe: $1"
  else
    gh api "repos/$REPO/milestones" -f title="$1" -f description="$2" >/dev/null \
      && echo "milestone criado: $1"
  fi
}

echo; echo "== Milestones =="
milestone "$M1" "Semana 1: tabela da ISA, O1 completa, testbench e primeira versao de T0."
milestone "$M2" "Semana 2: O2 com registradores entre estagios, deteccao de conflitos e tracos TD, TE e TC."
milestone "$M3" "Semana 3: script que gera a tabela de metricas (metricas.csv)."
milestone "$M4" "Semana 4: periodo de clock, graficos, analise, relatorio, README e tag final."
milestone "$M5" "Semanas 5 e 6: avaliacao por pares e defesa oral."

# ---------------------------------------------------------------- issues
EXISTENTES="$(gh issue list --repo "$REPO" --state all --limit 300 --json title --jq '.[].title' 2>/dev/null)"

issue() { # titulo | labels (separadas por virgula) | milestone (ou vazio) | corpo
  local titulo="$1" labels="$2" ms="$3" corpo="$4"
  if printf '%s\n' "$EXISTENTES" | grep -Fxq -- "$titulo"; then
    echo "issue ja existe: $titulo"; return
  fi
  if [ "$DRY" = 1 ]; then echo "[simulacao] issue: $titulo"; return; fi
  local args=(--repo "$REPO" --title "$titulo" --body "$corpo" --label "$labels")
  [ -n "$ms" ] && args+=(--milestone "$ms")
  if gh issue create "${args[@]}" >/dev/null; then
    echo "issue criada: $titulo"
  else
    echo "FALHOU: $titulo"
  fi
}

echo; echo "== Issues =="

issue "[ISA] Tabela da ISA MIPS32 implementada" "P0-crítica,área:isa" "$M1" \
$'Tabela com mnemônico, formato, opcode/funct e operação em RTL (artefato da seção 6 do enunciado).\n\nCritério de conclusão:\n- [ ] 10 instruções do subconjunto mínimo (add, sub, addi, and, or, slt, lw, sw, beq, break)\n- [ ] docs/isa.md e docs/tableISA.xlsx coerentes entre si\n- [ ] Códigos hexadecimais conferidos no RARS'

issue "[Interface] Entidade de topo cpu_top (interface R3)" "P0-crítica,área:o1,área:o2" "$M1" \
$'Entidade de topo cpu_top idêntica em O1 e O2, para um único testbench servir às duas (R3).\n\nCritério de conclusão:\n- [ ] Genéricos PROG_FILE e MEM_UNIFICADA\n- [ ] Portas clk, rst, done, hazard_abort, hazard_type, hazard_pc, hazard_cycle, retired, stage_valid(9 downto 0), dbg_reg_addr e dbg_reg_data\n- [ ] O1 usa só stage_valid(0); O2 usa os bits 4..0\n- [ ] O mesmo tb_cpu.vhd compila com as duas organizações'

issue "[Testbench] Testbench único tb/tb_cpu.vhd" "P0-crítica,área:testbench" "$M1" \
$'Testbench único (seção 7): gera clock e reset, carrega o programa, conta ciclos, instruções e ocupação, verifica o desfecho e grava metricas.csv.\n\nCritério de conclusão:\n- [ ] Compila em VHDL-2008 com GHDL (atenção: no PDF o generic MAX_CICLOS aparece depois do ");" do generic, o que não compila)\n- [ ] Compara registradores com esperado.txt\n- [ ] Grava uma linha por execução em metricas.csv\n- [ ] Funciona em O1 e O2 sem alterações'

issue "[Traços] Traço T0 limpo (≥30 instruções úteis)" "P0-crítica,área:tracos" "$M1" \
$'Programa com pelo menos 30 instruções úteis, sem conflitos em O1 e O2, cobrindo todas as classes da ISA (R5).\n\nCritério de conclusão:\n- [ ] Fonte .asm, .hex (RARS: Dump Memory em hexadecimal) e esperado.txt\n- [ ] Tabela do traço: endereço, instrução, registradores lidos e escritos, distância até o produtor mais próximo\n- [ ] Se usar NOPs, informar o CPI com e sem contá-los\n- [ ] Nenhum desvio tomado'

issue "[O1] Caminho de dados da linha de base (mono ou multiciclo)" "P0-crítica,área:o1" "$M1" \
$'Caminho de dados da linha de base, sem pipeline. Decisão do projeto: monociclo.\n\nCritério de conclusão:\n- [ ] Executa T0 sem erros em relação ao esperado.txt\n- [ ] Memórias de instruções e de dados separadas\n- [ ] Banco de registradores escreve na 1ª metade do ciclo e lê na 2ª\n- [ ] break: done vai a 1 e o processador congela\n- [ ] Justificativa da escolha do monociclo registrada para o relatório'

issue "[O2] Pipeline de 5 estágios com registradores entre estágios" "P0-crítica,área:o2" "$M2" \
$'Pipeline escalar de 5 estágios (IF, ID, EX, MEM, WB), 1 instrução por ciclo, com registradores entre estágios e bit de validade em cada um.\n\nCritério de conclusão:\n- [ ] Registradores IF/ID, ID/EX, EX/MEM e MEM/WB\n- [ ] stage_valid e retired corretos\n- [ ] Executa T0 sem erros em relação ao esperado.txt\n- [ ] Sem forwarding, stall, flush ou predição\n- [ ] Definido quando o break conclui no O2 (sugestão: ao passar por WB, depois das instruções anteriores)'

issue "[Hazard] Detecção de conflito de dados (RAW)" "P1-alta,área:hazard,área:o2" "$M2" \
$'Detectar leitura de registrador que uma instrução anterior ainda não escreveu (R4). hazard_type = 01 e hazard_pc aponta para a instrução consumidora.\n\nCritério de conclusão:\n- [ ] Escrita em $zero não gera dependência\n- [ ] Detecção antes de a instrução prejudicada produzir efeito errado\n- [ ] Considera que o banco escreve na 1ª metade do ciclo e lê na 2ª\n- [ ] Traço TD aborta com o tipo e o PC corretos'

issue "[Hazard] Detecção de conflito estrutural (MEM_UNIFICADA)" "P1-alta,área:hazard,área:o2" "$M2" \
$'Só com MEM_UNIFICADA = true: IF e um lw/sw em MEM no mesmo ciclo (R4). hazard_type = 10 e hazard_pc aponta para a instrução mais nova, que não obteve o recurso.\n\nCritério de conclusão:\n- [ ] Com MEM_UNIFICADA = false o conflito não é detectado\n- [ ] Traço TE aborta com o tipo e o PC corretos'

issue "[Hazard] Detecção de conflito de controle" "P1-alta,área:hazard,área:o2" "$M2" \
$'Desvio tomado (ou salto) com instruções já buscadas depois dele (R4). hazard_type = 11 e hazard_pc aponta para o desvio.\n\nCritério de conclusão:\n- [ ] Estágio em que o desvio é resolvido definido e justificado\n- [ ] beq não tomado seguido de busca sequencial NÃO é conflito (preparar a justificativa para a defesa)\n- [ ] Traço TC aborta com o tipo e o PC corretos'

issue "[Hazard] Semântica de aborto e congelamento" "P1-alta,área:hazard,área:o2" "$M2" \
$'Ao detectar um conflito: hazard_abort = 1, preencher hazard_type, hazard_pc e hazard_cycle e congelar PC, registradores entre estágios, banco de registradores e memória até o próximo reset (R4).\n\nCritério de conclusão:\n- [ ] Sinais estáveis até o próximo reset\n- [ ] hazard_cycle segue a convenção do testbench (ciclo 1 = primeiro após o reset)\n- [ ] Waveform mostra o congelamento no ciclo exato'

issue "[Traços] Traços com conflito TD, TE e TC" "P1-alta,área:tracos" "$M2" \
$'Um traço curto para cada tipo de conflito, que provoca o aborto em O2 (R5).\n\nCritério de conclusão:\n- [ ] td, te e tc com fonte .asm e .hex\n- [ ] Tabela de registro de conflitos: tipo esperado, tipo detectado, hazard_pc, hazard_cycle e organização\n- [ ] Rodam com ESPERA_ABORTO = true e o TIPO_ESPERADO certo no testbench'

issue "[Traços] Série S de tamanhos (5–200 instruções úteis)" "P1-alta,área:tracos" "$M3" \
$'Variações de T0 com 5, 10, 20, 50, 100 e 200 instruções úteis, para o gráfico de speedup por tamanho (R5). Podem ser geradas por script.\n\nCritério de conclusão:\n- [ ] 6 traços com .asm, .hex e esperado.txt\n- [ ] Todos livres de conflitos em O1 e O2'

issue "[Infra] Script único run_all" "P1-alta,área:infra" "$M3" \
$'Script (Makefile ou .sh) que compila, roda todos os traços e gera a tabela de métricas com um único comando (R7).\n\nCritério de conclusão:\n- [ ] Cada organização compila em workdir próprio (build/o1 e build/o2)\n- [ ] Gera metricas.csv\n- [ ] Todo número do relatório é reproduzível pelo script'

issue "[Métricas] Cálculo das métricas de desempenho" "P1-alta,área:metricas" "$M3" \
$'Para cada organização e cada traço limpo: ciclos totais, CPI, IPC, tempo de execução, speedup de O2 sobre O1 comparado ao ideal, efeito do enchimento e esvaziamento e taxa de ocupação por estágio e por via (R6).\n\nCritério de conclusão:\n- [ ] Ciclos contados do 1º ciclo após o reset até done = 1, inclusive\n- [ ] break não conta como instrução útil\n- [ ] metricas.csv completo'

issue "[Métricas] Período de clock de cada organização" "P1-alta,área:metricas" "$M4" \
$'Período de clock vindo de síntese (Yosys, Quartus ou Vivado) ou de tabela de atrasos por componente somando o overhead dos registradores entre estágios (R6).\n\nCritério de conclusão:\n- [ ] Valor justificado\n- [ ] Mesmo critério nas duas organizações'

issue "[Docs] README com instruções de reprodução" "P1-alta,área:docs" "$M4" \
$'README com instruções de execução e o comando único de reprodução (seção 1.4).\n\nCritério de conclusão:\n- [ ] Dependências (GHDL, GTKWave, RARS)\n- [ ] Como rodar o script único\n- [ ] Como abrir as waveforms'

issue "[Métricas] Gráficos de CPI e speedup" "P2-média,área:metricas" "$M4" \
$'CPI por organização, speedup medido ao lado do ideal e speedup × tamanho do traço, com eixo x logarítmico (seção 6).\n\nCritério de conclusão:\n- [ ] 3 gráficos gerados por script\n- [ ] Figuras numeradas, com legenda e citadas no texto'

issue "[Relatório] Diagramas instrução × ciclo" "P2-média,área:relatorio" "$M4" \
$'Uma tabela por organização, para as 10 primeiras e as 3 últimas instruções de T0 (seção 6.1).\n\nCritério de conclusão:\n- [ ] Formato instrução × ciclo, com o estágio em cada célula\n- [ ] Coerente com a waveform'

issue "[Relatório] Diagramas de caminho de dados, unidade de detecção e registradores" "P2-média,área:relatorio" "$M4" \
$'Diagramas do caminho de dados de O1 e O2 (em O2, com IF/ID, ID/EX, EX/MEM e MEM/WB nomeados), da unidade de detecção, e lista de campos de cada registrador entre estágios com largura em bits (seção 6).\n\nCritério de conclusão:\n- [ ] Coerentes com o código VHDL\n- [ ] Elaborados pelo próprio grupo'

issue "[Relatório] Waveforms anotadas" "P2-média,área:relatorio" "$M4" \
$'Waveforms anotadas de T0 (enchimento e esvaziamento do pipeline em O2) e de cada tipo de conflito (seções 6 e 6.2).\n\nCritério de conclusão:\n- [ ] Eixo de tempo ou número do ciclo\n- [ ] Sinais agrupados por estágio, com PC e instruções em hexadecimal\n- [ ] Marcadores de texto no ciclo relevante'

issue "[Relatório] Relatório no modelo SBC (4–10 páginas)" "P2-média,área:relatorio" "$M4" \
$'Relatório em PDF de 4 a 10 páginas, modelo SBC (seção 3), mais apêndices.\n\nCritério de conclusão:\n- [ ] Seções: introdução, fundamentação, metodologia, implementação, resultados, análise crítica, conclusão e referências\n- [ ] Apêndice A (link, tag e comando de reprodução), B (divisão de tarefas) e C (declaração de uso de IA)\n- [ ] Todo número reproduzível pelo script'

issue "[Infra] Tag final e congelamento do repositório" "P1-alta,área:infra" "$M4" \
$'Tag final no repositório. Depois da entrega o repositório fica congelado e a demonstração roda a partir da tag (seção 2).\n\nCritério de conclusão:\n- [ ] Branch de onde sai a tag definida (por exemplo, main)\n- [ ] Tag criada e enviada\n- [ ] run_all executado a partir da tag'

issue "[Defesa] Slides e roteiro da demonstração ao vivo" "P2-média,área:defesa" "$M5" \
$'Slides e demonstração ao vivo (seção 5).\n\nCritério de conclusão:\n- [ ] Roteiro: problema, ISA, caminhos de dados, unidade de detecção, resultados e análise crítica\n- [ ] Demonstração a partir da tag: script único, waveform de T0 e traço de conflito sorteado pelo professor\n- [ ] Todos os integrantes sabem explicar qualquer trecho'

issue "[ISA] Instruções opcionais (bne, j, andi, ori)" "P2-média,área:isa" "" \
$'Instruções extras são opcionais e, se feitas, devem constar da tabela da ISA do relatório (R1).\n\nCritério de conclusão:\n- [ ] Decidir se entram\n- [ ] Se entrarem: tabela da ISA atualizada e T0 revisado'

issue "[Testbench] Verificação da memória de dados" "P2-média,área:testbench" "" \
$'Item opcional do esqueleto do testbench (seção 7): verificar também posições da memória de dados.\n\nCritério de conclusão:\n- [ ] Formato do esperado.txt estendido\n- [ ] Verificação funcionando em O1 e O2'

issue "[Docs] Esclarecer menções a O3 no enunciado" "P1-alta,área:docs" "$M1" \
$'O enunciado cita O3 em alguns trechos (R3, R4 e na descrição), mas só define O1 e O2.\n\nCritério de conclusão:\n- [ ] Confirmação do professor registrada neste issue\n- [ ] Interface R3 mantida: stage_valid com 10 bits e retired com 2 bits'

echo
echo "Concluido. Confira com: gh issue list --repo $REPO --limit 50"
