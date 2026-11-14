# Traco S20: 20 instrucoes uteis + break (Variacao de T0 livre de conflitos em O1 e O2)
# Mix com todas as classes (I-type addi, Memoria sw/lw, Controle beq nao tomado, R-type add/sub/or/slt/and)
addi $t0, $t0, 10
addi $t1, $t1, 3
sw   $t4, 0($zero)
lw   $t3, 0($zero)
add  $t4, $t0, $t1
addi $t0, $t0, 10
addi $t1, $t1, 3
beq  $t4, $zero, L_b1
lw   $t3, 0($zero)
L_b1: sub  $t4, $t0, $t1
addi $t0, $t0, 10
addi $t1, $t1, 3
sw   $t4, 0($zero)
lw   $t3, 0($zero)
or   $t4, $t0, $t1
addi $t0, $t0, 10
addi $t1, $t1, 3
beq  $t4, $zero, L_b3
lw   $t3, 0($zero)
L_b3: slt  $t4, $t1, $t0
break
