-- Referencia bibliografica (Secao 8.2):
-- PATTERSON, D. A.; HENNESSY, J. L. Organizacao e Projeto de Computadores,
-- 5a edicao, Elsevier, 2017.
-- tb_cpu.vhd : testbench unico para O1 e O2 (VHDL-2008)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_cpu is
  generic (
    PROG_FILE     : string   := "tracos/t0.hex";          -- programa (.hex)
    ESPERADO_FILE : string   := "tracos/t0_esperado.txt"; -- linhas "reg valor_hex"
    ORG_NOME      : string   := "O2";                     -- rotulo usado na saida
    NUM_SLOTS     : positive := 5;                        -- O1 = 1, O2 = 5
    MEM_UNIFICADA : boolean  := false;                    -- true so no traco TE de O2
    ESPERA_ABORTO : boolean  := false;                    -- true nos tracos TD, TE e TC
    TIPO_ESPERADO : natural  := 0;                        -- 1 dados, 2 estrutural, 3 controle
    PC_ESPERADO   : integer  := -1;                       -- >= 0 valida hazard_pc (em bytes)
    T_CLK         : time     := 10 ns;                    -- periodo de SIMULACAO, nao o real
    MAX_CICLOS    : natural  := 10_000                    -- protecao contra laco infinito
  );
end entity tb_cpu;

architecture sim of tb_cpu is
  signal clk          : std_logic := '0';
  signal rst          : std_logic := '1';
  signal fim_sim      : boolean   := false;

  signal done         : std_logic;
  signal hazard_abort : std_logic;
  signal hazard_type  : std_logic_vector(1 downto 0);
  signal hazard_pc    : std_logic_vector(31 downto 0);
  signal hazard_cycle : unsigned(31 downto 0);
  signal retired      : unsigned(1 downto 0);
  signal stage_valid  : std_logic_vector(9 downto 0);
  signal dbg_reg_addr : std_logic_vector(4 downto 0) := (others => '0');
  signal dbg_reg_data : std_logic_vector(31 downto 0);
begin

  -- 1. Geracao de clock: para quando fim_sim = true
  clk <= not clk after T_CLK / 2 when not fim_sim else '0';

  -- 2. Processador sob teste
  dut : entity work.cpu_top
    generic map (
      PROG_FILE     => PROG_FILE,
      MEM_UNIFICADA => MEM_UNIFICADA
    )
    port map (
      clk          => clk,
      rst          => rst,
      done         => done,
      hazard_abort => hazard_abort,
      hazard_type  => hazard_type,
      hazard_pc    => hazard_pc,
      hazard_cycle => hazard_cycle,
      retired      => retired,
      stage_valid  => stage_valid,
      dbg_reg_addr => dbg_reg_addr,
      dbg_reg_data => dbg_reg_data
    );

  -- 3. Processo principal
  principal : process
    file f_esp        : text;
    file f_csv        : text;
    variable l        : line;
    variable st       : file_open_status;
    variable ciclos   : natural := 0;
    variable instrs   : natural := 0;
    variable ocupados : natural := 0;
    type nat_array is array (0 to 4) of natural;
    type real_array is array (0 to 4) of real;
    variable stg_cnt  : nat_array  := (others => 0);
    variable stg_ocup : real_array := (others => 0.0);
    variable erros    : natural := 0;
    variable reg_num  : integer;
    variable valor    : std_logic_vector(31 downto 0);
    variable cpi, ipc, ocup : real := 0.0;
  begin
    -- 3.1 Reset sincrono durante 2 ciclos
    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';

    -- 3.2 Execucao: amostra na borda de DESCIDA, no meio do ciclo
    loop
      wait until falling_edge(clk);
      ciclos := ciclos + 1;
      instrs := instrs + to_integer(retired);
      for i in 0 to NUM_SLOTS - 1 loop
        if stage_valid(i) = '1' then
          ocupados := ocupados + 1;
        end if;
      end loop;
      for i in 0 to 4 loop
        if stage_valid(i) = '1' then
          stg_cnt(i) := stg_cnt(i) + 1;
        end if;
      end loop;
      exit when done = '1' or hazard_abort = '1' or ciclos = MAX_CICLOS;
    end loop;

    -- 3.3 Desfecho: aborto, fim normal ou tempo esgotado
    if hazard_abort = '1' then
      report ORG_NOME & ": ABORTO tipo=" & to_string(hazard_type) &
             " pc=0x" & to_hstring(hazard_pc) &
             " ciclo=" & integer'image(to_integer(hazard_cycle));
      if not ESPERA_ABORTO then
        erros := erros + 1;
        report "Aborto inesperado: o traco deveria ser livre de conflitos" severity error;
      end if;
      if to_integer(unsigned(hazard_type)) /= TIPO_ESPERADO then
        erros := erros + 1;
        report "Tipo de conflito diferente do esperado" severity error;
      end if;
      assert to_integer(hazard_cycle) = ciclos
        report "hazard_cycle difere da contagem do testbench" severity warning;
      if PC_ESPERADO >= 0 and to_integer(unsigned(hazard_pc)) /= PC_ESPERADO then
        erros := erros + 1;
        report "hazard_pc (0x" & to_hstring(hazard_pc) & ") difere do PC_ESPERADO" severity error;
      end if;

    elsif done = '1' then
      if ESPERA_ABORTO then
        erros := erros + 1;
        report "Conflito esperado nao foi detectado" severity error;
      end if;

      -- 3.4 Verificacao automatica: compara registradores com o esperado
      file_open(st, f_esp, ESPERADO_FILE, read_mode);
      assert st = open_ok
        report "Nao foi possivel abrir " & ESPERADO_FILE severity failure;
      while not endfile(f_esp) loop
        readline(f_esp, l);
        next when l'length = 0;
        next when l(1) = '#';
        read(l, reg_num);
        hread(l, valor);
        dbg_reg_addr <= std_logic_vector(to_unsigned(reg_num, 5));
        wait for 1 ns;
        if dbg_reg_data /= valor then
          erros := erros + 1;
          report "Reg " & integer'image(reg_num) & ": esperado 0x" &
                 to_hstring(valor) & ", obtido 0x" & to_hstring(dbg_reg_data)
                 severity error;
        end if;
      end loop;
      file_close(f_esp);

    else
      report ORG_NOME & ": tempo esgotado em " & integer'image(MAX_CICLOS) &
             " ciclos" severity failure;
    end if;

    -- 3.5 Metricas: uma linha por execucao em metricas.csv
    -- org;programa;ciclos;instrucoes;CPI;IPC;ocup_via;ocup_s0_if;ocup_s1_id;ocup_s2_ex;ocup_s3_mem;ocup_s4_wb;erros
    if instrs > 0 then
      cpi := real(ciclos) / real(instrs);
      ipc := real(instrs) / real(ciclos);
    end if;
    ocup := real(ocupados) / real(ciclos * NUM_SLOTS);
    for i in 0 to 4 loop
      stg_ocup(i) := real(stg_cnt(i)) / real(ciclos);
    end loop;

    file_open(st, f_csv, "metricas.csv", append_mode);
    write(l, ORG_NOME & ";" & PROG_FILE & ";" & integer'image(ciclos) & ";" &
             integer'image(instrs) & ";" & real'image(cpi) & ";" &
             real'image(ipc) & ";" & real'image(ocup) & ";" &
             real'image(stg_ocup(0)) & ";" & real'image(stg_ocup(1)) & ";" &
             real'image(stg_ocup(2)) & ";" & real'image(stg_ocup(3)) & ";" &
             real'image(stg_ocup(4)) & ";" & integer'image(erros));
    writeline(f_csv, l);
    file_close(f_csv);

    -- 3.6 Encerramento
    report ORG_NOME & ": fim da simulacao, " & integer'image(ciclos) &
           " ciclos, " & integer'image(erros) & " erro(s)";
    assert erros = 0
      report ORG_NOME & ": simulacao encerrou com " & integer'image(erros) & " erro(s)!"
      severity failure;
    fim_sim <= true;
    std.env.stop;
    wait;
  end process;
end architecture sim;
