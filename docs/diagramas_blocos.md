# Diagramas de Blocos das Organizações O1 (Monociclo) e O2 (Pipeline de 5 Estágios) (Issue #20)

Representação estrutural completa dos caminhos de dados, unidades de controle, multiplexadores e sinais da interface **R3** para ambas as organizações implementadas.

---

## 1. Diagrama de Blocos da Organização O1 (Monociclo — `o1/cpu_top.vhd`)

```mermaid
flowchart LR
    subgraph IF_Stage ["Busca da Instrução"]
        PC["pc_reg (32b)\n(Borda de Subida)"] --> IMEM["instruction_memory\n(1024x32b ROM - 4 KB)"]
        PC --> ADD4["Somador PC + 4"]
    end

    subgraph ID_Stage ["Decodificação e Banco de Registradores"]
        IMEM -->|"instr(31:26), funct(5:0)"| CTRL["control_unit\n(O1)"]
        IMEM -->|"rs, rt"| BREG["banco_reg (32x32b)\nEscrita: falling_edge"]
        IMEM -->|"rt, rd"| MUX_WA["Mux reg_dst"]
        MUX_WA -->|"reg_wa"| BREG
        IMEM -->|"imm16"| SEXT["sign_ext\n(16 -> 32b)"]
    end

    subgraph EX_Stage ["Execução e Endereço de Desvio"]
        BREG -->|"reg_rd1"| ULA["alu (32b)"]
        BREG -->|"reg_rd2"| MUX_ALU["Mux alu_src"]
        SEXT -->|"imm32"| MUX_ALU
        MUX_ALU -->|"alu_b"| ULA
        CTRL -->|"alu_op"| ACTRL["alu_control"]
        IMEM -->|"funct"| ACTRL
        ACTRL -->|"alu_ctrl"| ULA
        ADD4 --> ADDBR["Somador Branch\n(PC+4 + imm32<<2)"]
        SEXT --> ADDBR
        ADDBR --> MUX_PC["Mux take_branch"]
        ADD4 --> MUX_PC
        MUX_PC -->|"pc_next"| PC
    end

    subgraph MEM_WB ["Memória de Dados e Write-Back"]
        ULA -->|"alu_result"| DMEM["data_memory (4 KB)\nEscrita: falling_edge"]
        BREG -->|"reg_rd2 (wd)"| DMEM
        DMEM -->|"mem_rd_data"| MUX_WB["Mux mem_to_reg"]
        ULA -->|"alu_result"| MUX_WB
        MUX_WB -->|"reg_wd"| BREG
    end
```

---

## 2. Diagrama de Blocos da Organização O2 (Pipeline 5 Estágios — `o2/cpu_top.vhd`)

```mermaid
flowchart LR
    subgraph S1_IF ["1. IF (Busca)"]
        PC2["pc_reg\n(32b)"] --> IMEM2["instruction_memory\n(ROM 4 KB)"]
    end

    S1_IF --> R_IF_ID["Reg IF/ID\n(65 bits)\nid_valid, id_pc, id_instr"]

    subgraph S2_ID ["2. ID (Decodificação)"]
        R_IF_ID --> CTRL2["control_unit"]
        R_IF_ID --> BREG2["banco_reg\n(Leitura 2ª metade)"]
        R_IF_ID --> SEXT2["sign_ext"]
    end

    S2_ID --> R_ID_EX["Reg ID/EX\n(149 bits)\nex_valid, ex_pc, ex_rd1/2,\nex_imm32, ex_wa, controles"]

    subgraph S3_EX ["3. EX (Execução)"]
        R_ID_EX --> ULA2["alu + alu_control\nex_alu_result, ex_alu_zero"]
    end

    S3_EX --> R_EX_MEM["Reg EX/MEM\n(107 bits)\nmem_valid, mem_pc,\nmem_alu_result, mem_rd2, mem_wa"]

    subgraph S4_MEM ["4. MEM (Memória)"]
        R_EX_MEM --> DMEM2["data_memory (4 KB)\n(Escrita falling_edge)"]
    end

    S4_MEM --> R_MEM_WB["Reg MEM/WB\n(105 bits)\nwb_valid, wb_pc,\nwb_alu_result, wb_mem_data, wb_wa"]

    subgraph S5_WB ["5. WB (Escrita)"]
        R_MEM_WB --> MUX_WB2["Mux wb_mem_to_reg"]
        MUX_WB2 -->|"wb_wd (Escrita 1ª metade)"| BREG2
    end

    subgraph HDU ["Unidade de Detecção de Hazards (R5)"]
        R_IF_ID -.->|"id_rs, id_rt, id_pc"| H_LOGIC["Detector RAW (01),\nEstrutural (10),\nControle (11)"]
        R_ID_EX -.->|"ex_wa, ex_reg_write,\nex_take_branch, ex_pc"| H_LOGIC
        R_EX_MEM -.->|"mem_wa, mem_reg_write,\nmem_read/write"| H_LOGIC
        S1_IF -.->|"if_valid, pc_reg"| H_LOGIC
        H_LOGIC ==>|"freeze_pipe, hazard_abort,\nhazard_type, hazard_pc, hazard_cycle"| R3_OUT["Saídas Interface R3"]
    end
```
