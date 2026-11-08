# Inicializacao de dados (distancias geram delay natural)
addi $t0, $zero, 10      # I1: $8 = 10
addi $t1, $zero, 20      # I2: $9 = 20
addi $t2, $zero, 30      # I3: $10 = 30
addi $t3, $zero, 40      # I4: $11 = 40

# Aritmetica Logica Bloco 1 (Consome I1 a I4, distancias OK)
add  $t4, $t0, $t1       # I5: $12 = 30. Le $t0 (dist 4), $t1 (dist 3)
sub  $t5, $t2, $t0       # I6: $13 = 20. Le $t2 (dist 3), $t0 (dist 5)
and  $t6, $t3, $t1       # I7: $14 =  0. Le $t3 (dist 3), $t1 (dist 5)
or   $t7, $t4, $t2       # I8: $15 = 30. Le $t4 (dist 3), $t2 (dist 5)
slt  $t8, $t5, $t3       # I9: $24 =  1. Le $t5 (dist 3), $t3 (dist 5)

# Escrita na Memoria (Consome Bloco 1)
sw   $t4, 0($zero)       # I10: Mem[0] = 30. Le $t4 (dist 5)
sw   $t5, 4($zero)       # I11: Mem[4] = 20. Le $t5 (dist 5)
sw   $t8, 8($zero)       # I12: Mem[8] =  1. Le $t8 (dist 3)
addi $s1, $zero, 100     # I13: $17 = 100 (Instrucao de enchimento para delay)

# Leitura da Memoria (Enderecos validos recem-escritos)
lw   $s2, 0($zero)       # I14: $18 = 30 (Lê Mem[0])
lw   $s3, 4($zero)       # I15: $19 = 20 (Lê Mem[4])
lw   $s4, 8($zero)       # I16: $20 =  1 (Lê Mem[8])

# Aritmetica Logica Bloco 2 (Consome os lw)
add  $s5, $s1, $s2       # I17: $21 = 130. Le $s1 (dist 4), $s2 (dist 3)
sub  $s6, $s2, $s3       # I18: $22 =  10. Le $s2 (dist 4), $s3 (dist 3)
and  $s7, $s4, $s3       # I19: $23 =   0. Le $s4 (dist 3), $s3 (dist 4)
or   $t8, $s5, $s4       # I20: $24 = 131. Le $s5 (dist 3), $s4 (dist 4)
slt  $t9, $s6, $s5       # I21: $25 =   1. Le $s6 (dist 3), $s5 (dist 4)

# Preparacoes finais para Teste e Desvio
addi $v0, $zero, 50      # I22: $2 = 50
addi $v1, $zero, 60      # I23: $3 = 60
add  $a0, $t8, $s7       # I24: $4 = 131. Le $t8 (dist 4), $s7 (dist 5)
sub  $a1, $t8, $t9       # I25: $5 = 130. Le $t8 (dist 5), $t9 (dist 4)
and  $a2, $v0, $t9       # I26: $6 =   0. Le $v0 (dist 4), $t9 (dist 5)
or   $a3, $v1, $v0       # I27: $7 =  62. Le $v1 (dist 4), $v0 (dist 5)
slt  $gp, $a0, $v1       # I28: $28 =  0. Le $a0 (dist 4), $v1 (dist 5) 
addi $k0, $zero, 999     # I29: $26 = 999 (Delay)

# Desvio (Nao tomado: 0 == 62 eh falso)
beq  $a2, $a3, FIM_PROGRAMA  # I30: Le $a2 (dist 4), $a3 (dist 3). Não pula.

addi $k1, $zero, 111         # I31: $27 = 111 (Executada, pois o beq falhou)
FIM_PROGRAMA: break          # I32: done_reg(t+1) <- 1 
