#!/usr/bin/env bash
set -e

echo "=================================================================="
echo " 1. Preparando diretorios de build e gerando tracos da Serie S"
echo "=================================================================="
mkdir -p build/o1 build/o2 tracos graficos
rm -f metricas.csv metricas_completas.csv
echo "org;programa;ciclos;instrucoes;CPI;IPC;ocup_via;ocup_s0_if;ocup_s1_id;ocup_s2_ex;ocup_s3_mem;ocup_s4_wb;erros" > metricas.csv

python3 scripts/gen_serie_s.py

echo "=================================================================="
echo " 2. Compilando Organizacao O1 (Monociclo) em build/o1"
echo "=================================================================="
ghdl -a --std=08 --workdir=build/o1 \
  comum/ula.vhd \
  comum/banco_reg.vhd \
  comum/sign_ext.vhd \
  comum/alu_control.vhd \
  comum/instruction_memory.vhd \
  comum/data_memory.vhd \
  o1/control_unit.vhd \
  o1/cpu_top.vhd \
  tb/tb_cpu.vhd
ghdl -e --std=08 --workdir=build/o1 tb_cpu

echo "=================================================================="
echo " 3. Compilando Organizacao O2 (Pipeline 5 estagios) em build/o2"
echo "=================================================================="
ghdl -a --std=08 --workdir=build/o2 \
  comum/ula.vhd \
  comum/banco_reg.vhd \
  comum/sign_ext.vhd \
  comum/alu_control.vhd \
  comum/instruction_memory.vhd \
  comum/data_memory.vhd \
  o1/control_unit.vhd \
  o2/cpu_top.vhd \
  tb/tb_cpu.vhd
ghdl -e --std=08 --workdir=build/o2 tb_cpu

echo "=================================================================="
echo " 4. Executando Traco Principal T0 em O1 e O2"
echo "=================================================================="
ghdl -r --std=08 --workdir=build/o1 tb_cpu \
  -gORG_NOME=O1 -gNUM_SLOTS=1 \
  -gPROG_FILE=tracos/t0.hex -gESPERADO_FILE=tracos/t0_esperado.txt \
  --wave=build/o1_t0.ghw

ghdl -r --std=08 --workdir=build/o2 tb_cpu \
  -gORG_NOME=O2 -gNUM_SLOTS=5 \
  -gPROG_FILE=tracos/t0.hex -gESPERADO_FILE=tracos/t0_esperado.txt \
  --wave=build/o2_t0.ghw

echo "=================================================================="
echo " 5. Executando Serie S (s5, s10, s20, s50, s100, s200) em O1 e O2"
echo "=================================================================="
for N in 5 10 20 50 100 200; do
  ghdl -r --std=08 --workdir=build/o1 tb_cpu \
    -gORG_NOME=O1 -gNUM_SLOTS=1 \
    -gPROG_FILE=tracos/s${N}.hex -gESPERADO_FILE=tracos/s${N}_esperado.txt

  ghdl -r --std=08 --workdir=build/o2 tb_cpu \
    -gORG_NOME=O2 -gNUM_SLOTS=5 \
    -gPROG_FILE=tracos/s${N}.hex -gESPERADO_FILE=tracos/s${N}_esperado.txt
done

echo "=================================================================="
echo " 6. Executando Tracos de Conflito (TD, TE, TC) em O2"
echo "=================================================================="
ghdl -r --std=08 --workdir=build/o2 tb_cpu \
  -gORG_NOME=O2 -gNUM_SLOTS=5 \
  -gPROG_FILE=tracos/td.hex \
  -gESPERA_ABORTO=true -gTIPO_ESPERADO=1 -gPC_ESPERADO=4 \
  --wave=build/o2_td.ghw

ghdl -r --std=08 --workdir=build/o2 tb_cpu \
  -gORG_NOME=O2 -gNUM_SLOTS=5 \
  -gPROG_FILE=tracos/te.hex \
  -gMEM_UNIFICADA=true -gESPERA_ABORTO=true -gTIPO_ESPERADO=2 -gPC_ESPERADO=12 \
  --wave=build/o2_te.ghw

ghdl -r --std=08 --workdir=build/o2 tb_cpu \
  -gORG_NOME=O2 -gNUM_SLOTS=5 \
  -gPROG_FILE=tracos/te.hex -gESPERADO_FILE=tracos/te_esperado.txt \
  -gMEM_UNIFICADA=false -gESPERA_ABORTO=false \
  --wave=build/o2_te_harvard.ghw

ghdl -r --std=08 --workdir=build/o2 tb_cpu \
  -gORG_NOME=O2 -gNUM_SLOTS=5 \
  -gPROG_FILE=tracos/tc.hex \
  -gESPERA_ABORTO=true -gTIPO_ESPERADO=3 -gPC_ESPERADO=0 \
  --wave=build/o2_tc.ghw

echo "=================================================================="
echo " 7. Calculando Metricas Completas e Gerando Graficos"
echo "=================================================================="
python3 scripts/process_metrics.py

echo "=================================================================="
echo " CONCLUIDO COM SUCESSO! Veja metricas.csv e metricas_completas.csv"
echo "=================================================================="
