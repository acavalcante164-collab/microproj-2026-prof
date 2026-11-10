# Traco TE: Conflito Estrutural (IF + MEM no mesmo ciclo quando MEM_UNIFICADA = true)
# Endereco  Hex         Instrucao
# 0x00      AC000000    sw   $zero, 0($zero)       # Acessa Memoria de Dados em MEM no ciclo 4
# 0x04      00000020    add  $zero, $zero, $zero   # Escrita em $zero nao gera RAW
# 0x08      00000020    add  $zero, $zero, $zero
# 0x0C      00000020    add  $zero, $zero, $zero   # Buscada em IF no ciclo 4 -> Conflito Estrutural (PC=0x0C)
# 0x10      0000000D    break
sw   $zero, 0($zero)
add  $zero, $zero, $zero
add  $zero, $zero, $zero
add  $zero, $zero, $zero
break
