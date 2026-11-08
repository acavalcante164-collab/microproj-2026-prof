# Tabela de Distâncias - Traço T0

Esta tabela comprova a ausência de conflitos de dados (*data hazards*) no traço T0. A distância mínima entre a instrução produtora e a instrução consumidora é rigorosamente respeitada (distância $\ge 3$ para todas as dependências de registadores e leitura/escrita em memória).

| Endereço (Hex) | Instrução Assembly | Lidos | Escrito | Distância até o Produtor |
| :--- | :--- | :--- | :--- | :--- |
| `0x00000000` | `addi $t0, $zero, 10` | Nenhum | `$t0` | - |
| `0x00000004` | `addi $t1, $zero, 20` | Nenhum | `$t1` | - |
| `0x00000008` | `addi $t2, $zero, 30` | Nenhum | `$t2` | - |
| `0x0000000C` | `addi $t3, $zero, 40` | Nenhum | `$t3` | - |
| `0x00000010` | `add  $t4, $t0, $t1` | `$t0, $t1` | `$t4` | `$t1` (dist = 3) |
| `0x00000014` | `sub  $t5, $t2, $t0` | `$t2, $t0` | `$t5` | `$t2` (dist = 3) |
| `0x00000018` | `and  $t6, $t3, $t1` | `$t3, $t1` | `$t6` | `$t3` (dist = 3) |
| `0x0000001C` | `or   $t7, $t4, $t2` | `$t4, $t2` | `$t7` | `$t4` (dist = 3) |
| `0x00000020` | `slt  $t8, $t5, $t3` | `$t5, $t3` | `$t8` | `$t5` (dist = 3) |
| `0x00000024` | `sw   $t4, 0($zero)` | `$t4` | `Mem[0]` | `$t4` (dist = 5) |
| `0x00000028` | `sw   $t5, 4($zero)` | `$t5` | `Mem[4]` | `$t5` (dist = 5) |
| `0x0000002C` | `sw   $t8, 8($zero)` | `$t8` | `Mem[8]` | `$t8` (dist = 3) |
| `0x00000030` | `addi $s1, $zero, 100` | Nenhum | `$s1` | - |
| `0x00000034` | `lw   $s2, 0($zero)` | `Mem[0]` | `$s2` | `sw $t4` (dist = 4) |
| `0x00000038` | `lw   $s3, 4($zero)` | `Mem[4]` | `$s3` | `sw $t5` (dist = 4) |
| `0x0000003C` | `lw   $s4, 8($zero)` | `Mem[8]` | `$s4` | `sw $t8` (dist = 4) |
| `0x00000040` | `add  $s5, $s1, $s2` | `$s1, $s2` | `$s5` | `$s2` (dist = 3) |
| `0x00000044` | `sub  $s6, $s2, $s3` | `$s2, $s3` | `$s6` | `$s3` (dist = 3) |
| `0x00000048` | `and  $s7, $s4, $s3` | `$s4, $s3` | `$s7` | `$s4` (dist = 3) |
| `0x0000004C` | `or   $t8, $s5, $s4` | `$s5, $s4` | `$t8` | `$s5` (dist = 3) |
| `0x00000050` | `slt  $t9, $s6, $s5` | `$s6, $s5` | `$t9` | `$s6` (dist = 3) |
| `0x00000054` | `addi $v0, $zero, 50` | Nenhum | `$v0` | - |
| `0x00000058` | `addi $v1, $zero, 60` | Nenhum | `$v1` | - |
| `0x0000005C` | `add  $a0, $t8, $s7` | `$t8, $s7` | `$a0` | `$t8` (dist = 4) |
| `0x00000060` | `sub  $a1, $t8, $t9` | `$t8, $t9` | `$a1` | `$t9` (dist = 4) |
| `0x00000064` | `and  $a2, $v0, $t9` | `$v0, $t9` | `$a2` | `$v0` (dist = 4) |
| `0x00000068` | `or   $a3, $v1, $v0` | `$v1, $v0` | `$a3` | `$v1` (dist = 4) |
| `0x0000006C` | `slt  $gp, $a0, $v1` | `$a0, $v1` | `$gp` | `$a0` (dist = 4) |
| `0x00000070` | `addi $k0, $zero, 999` | Nenhum | `$k0` | - |
| `0x00000074` | `beq  $a2, $a3, FIM_PROGRAMA` | `$a2, $a3` | Nenhum | `$a3` (dist = 3) |
| `0x00000078` | `addi $k1, $zero, 111` | Nenhum | `$k1` | - |
| `0x0000007C` | `FIM_PROGRAMA: break` | Nenhum | Nenhum | - |
