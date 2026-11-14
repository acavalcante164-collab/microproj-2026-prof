#!/usr/bin/env python3
"""
Gera a Serie S de tracos limpos (5, 10, 20, 50, 100 e 200 instrucoes uteis)
como variacoes de T0 contendo todas as classes da ISA (addi, lw, sw, beq nao
tomado com rotulo simbolico para o MARS, add, sub, or, slt, and), livres de
conflitos em O1 e O2 (Issue #12).
Cada bloco de 5 instrucoes respeita distancia >= 3 entre escrita e leitura.
Grava todos os 32 registradores (0 a 31) nos arquivos *_esperado.txt.
"""
import os

SIZES = [5, 10, 20, 50, 100, 200]
OUT_DIR = "tracos"

def to_s32(v):
    v &= 0xFFFFFFFF
    return v - 0x100000000 if v & 0x80000000 else v

os.makedirs(OUT_DIR, exist_ok=True)

for n in SIZES:
    regs = [0] * 32
    mem = {0: 0}
    last_write = {}

    asm_lines = [
        f"# Traco S{n}: {n} instrucoes uteis + break (Variacao de T0 livre de conflitos em O1 e O2)",
        "# Mix com todas as classes (I-type addi, Memoria sw/lw, Controle beq nao tomado, R-type add/sub/or/slt/and)"
    ]
    hex_lines = []

    for k in range(n):
        m = k % 5
        b = k // 5

        if m == 0:
            # Slot 0: addi $t0, $t0, 10 (escreve R8, le R8 com distancia 5)
            rs, rt, imm = 8, 8, 10
            word = (0x08 << 26) | (rs << 21) | (rt << 16) | (imm & 0xFFFF)
            asm = "addi $t0, $t0, 10"
            read_regs = [rs]
            write_reg = rt
            regs[rt] = (regs[rs] + imm) & 0xFFFFFFFF

        elif m == 1:
            # Slot 1: addi $t1, $t1, 3 (escreve R9, le R9 com distancia 5)
            rs, rt, imm = 9, 9, 3
            word = (0x08 << 26) | (rs << 21) | (rt << 16) | (imm & 0xFFFF)
            asm = "addi $t1, $t1, 3"
            read_regs = [rs]
            write_reg = rt
            regs[rt] = (regs[rs] + imm) & 0xFFFFFFFF

        elif m == 2:
            # Slot 2: alterna entre sw $t4, 0($zero) e beq $t4, $zero, L_b{b} (nao tomado)
            if b % 2 == 0:
                rs, rt, imm = 0, 12, 0
                word = (0x2B << 26) | (rs << 21) | (rt << 16) | (imm & 0xFFFF)
                asm = "sw   $t4, 0($zero)"
                read_regs = [rs, rt]
                write_reg = 0
                mem[0] = regs[rt]
            else:
                # Aponta para o rotulo L_b{b} na instrucao m=4 (2 instrucoes adiante -> offset = +1)
                rs, rt, imm = 12, 0, 1
                word = (0x04 << 26) | (rs << 21) | (rt << 16) | (imm & 0xFFFF)
                asm = f"beq  $t4, $zero, L_b{b}"
                read_regs = [rs, rt]
                write_reg = 0
                assert regs[rs] != regs[rt], f"Erro: beq tomado em k={k}"

        elif m == 3:
            # Slot 3: lw $t3, 0($zero) (escreve R11, le R0)
            rs, rt, imm = 0, 11, 0
            word = (0x23 << 26) | (rs << 21) | (rt << 16) | (imm & 0xFFFF)
            asm = "lw   $t3, 0($zero)"
            read_regs = [rs]
            write_reg = rt
            regs[rt] = mem[0]

        elif m == 4:
            # Slot 4: R-type escrevendo R12 ($t4), lendo R8 ($t0, dist 4) e R9 ($t1, dist 3)
            op_idx = b % 5
            if op_idx == 0:
                rs, rt, rd, funct = 8, 9, 12, 0x20
                regs[rd] = (regs[rs] + regs[rt]) & 0xFFFFFFFF
                asm_instr = "add  $t4, $t0, $t1"
            elif op_idx == 1:
                rs, rt, rd, funct = 8, 9, 12, 0x22
                regs[rd] = (regs[rs] - regs[rt]) & 0xFFFFFFFF
                asm_instr = "sub  $t4, $t0, $t1"
            elif op_idx == 2:
                rs, rt, rd, funct = 8, 9, 12, 0x25
                regs[rd] = (regs[rs] | regs[rt]) & 0xFFFFFFFF
                asm_instr = "or   $t4, $t0, $t1"
            elif op_idx == 3:
                rs, rt, rd, funct = 9, 8, 12, 0x2A
                regs[rd] = 1 if to_s32(regs[rs]) < to_s32(regs[rt]) else 0
                asm_instr = "slt  $t4, $t1, $t0"
            else:
                rs, rt, rd, funct = 8, 9, 12, 0x24
                regs[rd] = (regs[rs] & regs[rt]) & 0xFFFFFFFF
                asm_instr = "and  $t4, $t0, $t1"

            # Se neste bloco houve um beq (b impar), adiciona o rotulo L_b{b}:
            if b % 2 == 1:
                asm = f"L_b{b}: {asm_instr}"
            else:
                asm = asm_instr

            word = (0x00 << 26) | (rs << 21) | (rt << 16) | (rd << 11) | funct
            read_regs = [rs, rt]
            write_reg = rd

        for r_used in read_regs:
            if r_used != 0 and r_used in last_write:
                dist = k - last_write[r_used]
                assert dist >= 3, f"Conflito RAW em k={k}: R{r_used} dist={dist}"
        if write_reg != 0:
            last_write[write_reg] = k

        asm_lines.append(asm)
        hex_lines.append(f"{word:08X}")

    asm_lines.append("break")
    hex_lines.append("0000000D")

    asm_path = os.path.join(OUT_DIR, f"s{n}.asm")
    hex_path = os.path.join(OUT_DIR, f"s{n}.hex")
    esp_path = os.path.join(OUT_DIR, f"s{n}_esperado.txt")

    with open(asm_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(asm_lines) + "\n")

    with open(hex_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(hex_lines) + "\n")

    with open(esp_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"# Valores esperados de todos os 32 registradores para S{n} ({n} instrucoes uteis)\n")
        for r in range(32):
            f.write(f"{r} {regs[r]:08X}\n")

print("Serie S variada regenerada com rotulos simbolicos (L_b*) 100% compativeis com o MARS!")
