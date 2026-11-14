# Traco S5: 5 instrucoes uteis + break (Variacao de T0 livre de conflitos em O1 e O2)
# Mix com todas as classes (I-type addi, Memoria sw/lw, Controle beq nao tomado, R-type add/sub/or/slt/and)
addi $t0, $t0, 10
addi $t1, $t1, 3
sw   $t4, 0($zero)
lw   $t3, 0($zero)
add  $t4, $t0, $t1
break
