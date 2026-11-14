#!/usr/bin/env python3
"""
Processa metricas.csv bruto do GHDL para os tracos limpos (t0 e s5..s200),
calculando o periodo de clock pela regra unica e pelos atrasos da Figura 4.27
de Patterson & Hennessy (5a ed., Secao 4.5, p. 273):
  - IMEM (IF) = 200 ps, RegRead (ID) = 100 ps, ULA (EX) = 200 ps,
    DMEM (MEM) = 200 ps, RegWrite (WB) = 100 ps (overhead de reg = 0 ps).
  - Regra unica: T_clk = atraso do maior caminho entre elementos de estado,
    respeitando T_clk / 2 >= max(t_RegWrite, t_RegRead) = 100 ps.
  - O1 (Monociclo, caminho lw): 200 + 100 + 200 + 200 + 100 = 800 ps (0.80 ns)
  - O2 (Pipeline 5 estagios): max(200, 100, 200, 200, 100) = 200 ps (0.20 ns)
  - Razao de clock (assintota real de O2 sobre O1): 0.80 / 0.20 = 4.00x
  - Speedup ideal teorico de pipeline equilibrado (k = 5 estagios): 5.00x
"""
import csv
import os

T_CLK_NS = {
    "O1": 0.80,
    "O2": 0.20,
}
CLOCK_RATIO_ASYMPTOTE = T_CLK_NS["O1"] / T_CLK_NS["O2"]  # 4.00x
SPEEDUP_IDEAL_K5 = 5.00                                  # k = 5 estagios equilibrados

CLEAN_PROGS = {
    "tracos/t0.hex",
    "tracos/s5.hex",
    "tracos/s10.hex",
    "tracos/s20.hex",
    "tracos/s50.hex",
    "tracos/s100.hex",
    "tracos/s200.hex",
}

raw_rows = []
with open("metricas.csv", "r", encoding="utf-8") as f:
    reader = csv.reader(f, delimiter=";")
    for row in reader:
        if not row or row[0].startswith("org"):
            continue
        prog = row[1].strip()
        if prog not in CLEAN_PROGS:
            continue
        raw_rows.append({
            "org": row[0].strip(),
            "programa": prog,
            "ciclos": int(row[2]),
            "instrucoes": int(row[3]),
            "cpi": float(row[4]),
            "ipc": float(row[5]),
            "ocup_via": float(row[6]),
            "ocup_if": float(row[7]),
            "ocup_id": float(row[8]),
            "ocup_ex": float(row[9]),
            "ocup_mem": float(row[10]),
            "ocup_wb": float(row[11]),
            "erros": int(row[12]),
        })

by_prog = {}
for r in raw_rows:
    by_prog.setdefault(r["programa"], {})[r["org"]] = r

with open("metricas_completas.csv", "w", newline="\n", encoding="utf-8") as f:
    writer = csv.writer(f, delimiter=";")
    writer.writerow([
        "org", "programa", "ciclos", "instrucoes_uteis", "CPI", "IPC",
        "t_clk_ns", "tempo_exec_ns",
        "ocup_via", "ocup_if", "ocup_id", "ocup_ex", "ocup_mem", "ocup_wb",
        "ciclos_enchimento_esvaziamento",
        "speedup_tempo_medido", "razao_clock_assintotica", "speedup_ideal_k5", "erros"
    ])

    for r in raw_rows:
        org = r["org"]
        prog = r["programa"]
        ciclos = r["ciclos"]
        instrs = r["instrucoes"]
        t_clk = T_CLK_NS[org]
        t_exec = ciclos * t_clk

        drain_fill = (ciclos - (instrs + 1)) if org == "O2" else 0
        o1_ref = by_prog[prog]["O1"]
        t_o1 = o1_ref["ciclos"] * T_CLK_NS["O1"]
        sp_tempo = t_o1 / t_exec

        writer.writerow([
            org, prog, ciclos, instrs,
            f"{r['cpi']:.6f}", f"{r['ipc']:.6f}",
            f"{t_clk:.2f}", f"{t_exec:.3f}",
            f"{r['ocup_via']:.6f}",
            f"{r['ocup_if']:.6f}", f"{r['ocup_id']:.6f}", f"{r['ocup_ex']:.6f}",
            f"{r['ocup_mem']:.6f}", f"{r['ocup_wb']:.6f}",
            drain_fill,
            f"{sp_tempo:.6f}", f"{CLOCK_RATIO_ASYMPTOTE:.2f}", f"{SPEEDUP_IDEAL_K5:.2f}",
            r["erros"]
        ])

print("Tabela enriquecida (apenas tracos limpos) salva em: metricas_completas.csv")

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError as e:
    print(f"Aviso: matplotlib nao instalado ({e}). Pulei geracao de PNGs.")
else:
    os.makedirs("graficos", exist_ok=True)

    progs_order = ["tracos/t0.hex", "tracos/s5.hex", "tracos/s10.hex", "tracos/s20.hex", "tracos/s50.hex", "tracos/s100.hex", "tracos/s200.hex"]
    labels = ["T0 (31)", "S5 (5)", "S10 (10)", "S20 (20)", "S50 (50)", "S100 (100)", "S200 (200)"]
    cpi_o1 = [by_prog[p]["O1"]["cpi"] for p in progs_order]
    cpi_o2 = [by_prog[p]["O2"]["cpi"] for p in progs_order]

    x = list(range(len(progs_order)))
    w = 0.35
    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.bar([i - w/2 for i in x], cpi_o1, width=w, label="O1 (Monociclo)")
    ax.bar([i + w/2 for i in x], cpi_o2, width=w, label="O2 (Pipeline 5 estágios)")
    ax.axhline(1.0, color="gray", linestyle="--", linewidth=1, label="CPI Ideal = 1,0")
    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    ax.set_ylabel("CPI (Ciclos por Instrução Útil)")
    ax.set_title("Figura 1: Comparação de CPI por Organização (T0 e Série S)")
    ax.legend()
    ax.grid(axis="y", linestyle=":", alpha=0.7)
    fig.tight_layout()
    fig.savefig("graficos/fig1_cpi.png", dpi=200)
    plt.close(fig)

    t0_sp = (by_prog["tracos/t0.hex"]["O1"]["ciclos"] * T_CLK_NS["O1"]) / (by_prog["tracos/t0.hex"]["O2"]["ciclos"] * T_CLK_NS["O2"])
    s200_sp = (by_prog["tracos/s200.hex"]["O1"]["ciclos"] * T_CLK_NS["O1"]) / (by_prog["tracos/s200.hex"]["O2"]["ciclos"] * T_CLK_NS["O2"])

    fig, ax = plt.subplots(figsize=(7, 4.5))
    cats = ["Speedup Medido\n(T0: 31 instr.)", "Speedup Medido\n(S200: 200 instr.)", "Razão de Clock\n(T_O1 / T_O2 = 4,0x)", "Speedup Ideal\n(k = 5 estágios)"]
    vals = [t0_sp, s200_sp, CLOCK_RATIO_ASYMPTOTE, SPEEDUP_IDEAL_K5]
    bars = ax.bar(cats, vals, color=["#2b5c8f", "#38761d", "#e69138", "#999999"], width=0.5)
    for b in bars:
        h = b.get_height()
        ax.text(b.get_x() + b.get_width()/2, h + 0.08, f"{h:.2f}x", ha="center", va="bottom", fontweight="bold")
    ax.set_ylim(0, 5.6)
    ax.set_ylabel("Speedup (O2 sobre O1)")
    ax.set_title("Figura 2: Speedup Medido em O2 vs. Razão de Clock (4,0x) e Ideal (k = 5)")
    ax.grid(axis="y", linestyle=":", alpha=0.7)
    fig.tight_layout()
    fig.savefig("graficos/fig2_speedup_ideal.png", dpi=200)
    plt.close(fig)

    s_sizes = [5, 10, 20, 50, 100, 200]
    sp_serie = [
        (by_prog[f"tracos/s{n}.hex"]["O1"]["ciclos"] * T_CLK_NS["O1"]) /
        (by_prog[f"tracos/s{n}.hex"]["O2"]["ciclos"] * T_CLK_NS["O2"])
        for n in s_sizes
    ]

    fig, ax = plt.subplots(figsize=(7.5, 4.5))
    ax.plot(s_sizes, sp_serie, marker="o", linewidth=2, label="Speedup Medido (O2 / O1)")
    ax.axhline(CLOCK_RATIO_ASYMPTOTE, color="#e69138", linestyle="--", linewidth=1.5,
               label=f"Assíntota da Razão de Clock (T_O1/T_O2 = {CLOCK_RATIO_ASYMPTOTE:.2f}x)")
    ax.axhline(SPEEDUP_IDEAL_K5, color="#999999", linestyle=":", linewidth=1.5,
               label=f"Speedup Ideal de Pipeline Equilibrado (k = {SPEEDUP_IDEAL_K5:.2f}x)")
    ax.set_xscale("log")
    ax.set_xticks(s_sizes)
    ax.get_xaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
    ax.set_ylim(1.5, 5.4)
    ax.set_xlabel("Tamanho do Traço — Instruções Úteis (Escala Logarítmica)")
    ax.set_ylabel("Speedup em Tempo de Execução (T_O1 / T_O2)")
    ax.set_title("Figura 3: Speedup de O2 sobre O1 × Tamanho do Traço (Série S)")
    ax.legend(loc="lower right")
    ax.grid(True, which="both", linestyle=":", alpha=0.7)
    fig.tight_layout()
    fig.savefig("graficos/fig3_speedup_serie_s_log.png", dpi=200)
    plt.close(fig)

    print("3 graficos gerados em graficos/: fig1_cpi.png, fig2_speedup_ideal.png, fig3_speedup_serie_s_log.png")
