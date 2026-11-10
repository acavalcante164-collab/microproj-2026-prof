# Traco TC: Conflito de Controle (beq tomado resolvido em EX com instrucoes ja buscadas)
# Endereco  Hex         Instrucao
# 0x00      10000002    beq  $zero, $zero, ALVO    # Tomado em EX no ciclo 3 -> Conflito Controle (PC=0x00)
# 0x04      20080001    addi $t0, $zero, 1         # Buscada sequencialmente em ID
# 0x08      20090002    addi $t1, $zero, 2         # Buscada sequencialmente em IF
# 0x0C      0000000D    ALVO: break
beq  $zero, $zero, 2
addi $t0, $zero, 1
addi $t1, $zero, 2
break
