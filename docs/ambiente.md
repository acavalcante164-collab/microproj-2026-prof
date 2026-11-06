# Ambiente de desenvolvimento

Requisito R7 do enunciado ([specs/MicroProj.pdf](../specs/MicroProj.pdf)): VHDL-2008, simulado em GHDL e visualizado no GTKWave.

## Versões testadas

| Ferramenta | Versão | Backend / observação |
|---|---|---|
| SO | Windows 11 | |
| GHDL | 5.1.1 | backend GCC 15.2.1 |
| GTKWave | 3.3.125 | |

Link do Git para mais informações do GHDL: https://github.com/ghdl/ghdl.git

Windows : Para usuários do Windows, o GHDL pode ser instalado através do MSYS2, um ambiente semelhante ao Unix para Windows. Isso proporciona uma experiência similar à de usar o GHDL no Linux, e o MSYS2 garante que as dependências sejam gerenciadas corretamente. A documentação do MSYS2 oferece orientações detalhadas sobre como configurar o ambiente.

## Instalação

```bash
# Fedora
sudo dnf install ghdl gtkwave

# Ubuntu / Debian
sudo apt install ghdl gtkwave
```

## Verificação do ambiente

```bash
bash scripts/verifica_ambiente.sh
```

O script:

1. confere se o `ghdl` está no PATH e mostra a versão;
2. analisa, elabora e roda [scripts/smoke/smoke_tb.vhd](../scripts/smoke/smoke_tb.vhd), que usa recursos exclusivos do VHDL-2008 (`to_string`, `to_hstring`, `std.env.stop`);
3. faz isso separadamente em `build/o1` e em `build/o2`;
4. avisa se o `gtkwave` não estiver instalado.

Sai com código 0 se tudo estiver certo.

## Uma workdir por organização

As organizações O1 e O2 definem a mesma entidade de topo, `cpu_top`, para que um único testbench sirva às duas (R3). Por isso cada uma é compilada em sua própria biblioteca `work`:

| Organização | Fontes | Workdir |
|---|---|---|
| O1 | `o1/*.vhd` | `build/o1` |
| O2 | `o2/*.vhd` | `build/o2` |

Exemplo do enunciado (seção 7):

```bash
ghdl -a --std=08 --workdir=build/o2 o2/*.vhd tb/tb_cpu.vhd
ghdl -e --std=08 --workdir=build/o2 tb_cpu
ghdl -r --std=08 --workdir=build/o2 tb_cpu \
     -gPROG_FILE=tracos/td.hex -gESPERA_ABORTO=true -gTIPO_ESPERADO=1 \
     --wave=build/o2_td.ghw
gtkwave build/o2_td.ghw
```

## Estrutura do repositório

| Pasta | Conteúdo |
|---|---|
| `o1/` | VHDL da organização O1 (sem pipeline) |
| `o2/` | VHDL da organização O2 (pipeline de 5 estágios) |
| `tb/` | testbench único `tb_cpu.vhd` |
| `tracos/` | traços: fonte assembly, `.hex` e arquivo esperado |
| `scripts/` | scripts auxiliares (`run_all`, geração da série S, gráficos) |
| `build/` | gerada; não versionada (ver `.gitignore`) |
