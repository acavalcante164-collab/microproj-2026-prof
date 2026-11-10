# Traco TD: Conflito de Dados (RAW) de distancia 1 entre EX e ID
# Endereco  Hex         Instrucao
# 0x00      2008000A    addi $t0, $zero, 10   # Produz $t0 (R8)
# 0x04      01084820    add  $t1, $t0, $t0    # Consome $t0 imediatamente (RAW no ciclo 3, PC=0x04)
# 0x08      0000000D    break
addi $t0, $zero, 10
add  $t1, $t0, $t0
break
