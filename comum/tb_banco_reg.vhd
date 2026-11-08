library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_banco_reg is
end entity tb_banco_reg;

architecture sim of tb_banco_reg is
  constant CLK_PERIOD : time := 10 ns;

  signal clk      : std_logic := '0';
  signal rst      : std_logic := '0';
  signal we       : std_logic := '0';
  signal ra1, ra2 : std_logic_vector(4 downto 0)  := (others => '0');
  signal wa       : std_logic_vector(4 downto 0)  := (others => '0');
  signal wd       : std_logic_vector(31 downto 0) := (others => '0');
  signal rd1, rd2 : std_logic_vector(31 downto 0);
  signal dbg_addr : std_logic_vector(4 downto 0)  := (others => '0');
  signal dbg_data : std_logic_vector(31 downto 0);

  signal sim_done : boolean := false;
begin

  uut: entity work.banco_reg
    port map (
      clk      => clk,
      rst      => rst,
      we       => we,
      ra1      => ra1,
      ra2      => ra2,
      wa       => wa,
      wd       => wd,
      rd1      => rd1,
      rd2      => rd2,
      dbg_addr => dbg_addr,
      dbg_data => dbg_data
    );

  -- Gerador de clock (10 ns: sobe em 0, 10, 20... e desce em 5, 15, 25...)
  clk_proc: process
  begin
    while not sim_done loop
      clk <= '0';
      wait for CLK_PERIOD / 2; -- 5 ns
      clk <= '1';
      wait for CLK_PERIOD / 2; -- 5 ns
    end loop;
    wait;
  end process;

  stim_proc: process
    variable erros : integer := 0;
  begin
    -- Pulso inicial de reset
    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait for 1 ns;
    rst <= '0';

    -- =========================================================================
    -- T01: Escrever 42 (0x0000002A) em $t0 (reg 8) e ler pelo rd1
    -- =========================================================================
    wait until rising_edge(clk);
    we  <= '1';
    wa  <= std_logic_vector(to_unsigned(8, 5));
    wd  <= x"0000002A"; -- 42
    ra1 <= std_logic_vector(to_unsigned(8, 5));
    wait until falling_edge(clk); -- Escrita ocorre aqui!
    wait for 1 ns;
    if rd1 /= x"0000002A" then
      report "FALHA T01: Escrita/leitura de 42 em $t0 (reg 8) falhou." severity error;
      erros := erros + 1;
    end if;

    -- =========================================================================
    -- T02: Duas leituras ao mesmo tempo em registradores diferentes ($t0 e $t1)
    -- =========================================================================
    wait until rising_edge(clk);
    we  <= '1';
    wa  <= std_logic_vector(to_unsigned(9, 5)); -- $t1 = reg 9
    wd  <= x"00000064"; -- 100
    ra1 <= std_logic_vector(to_unsigned(8, 5)); -- le $t0 (42)
    ra2 <= std_logic_vector(to_unsigned(9, 5)); -- le $t1 (100)
    wait until falling_edge(clk);
    wait for 1 ns;
    if not (rd1 = x"0000002A" and rd2 = x"00000064") then
      report "FALHA T02: Leituras simultaneas rd1 ($t0=42) e rd2 ($t1=100) falharam." severity error;
      erros := erros + 1;
    end if;

    -- =========================================================================
    -- T03: Ler $zero (reg 0) devolve 0
    -- =========================================================================
    we  <= '0';
    ra1 <= "00000";
    ra2 <= "00000";
    wait for 1 ns;
    if not (rd1 = x"00000000" and rd2 = x"00000000") then
      report "FALHA T03: Leitura de $zero nao retornou 0." severity error;
      erros := erros + 1;
    end if;

    -- =========================================================================
    -- T04: Escrever em $zero e ler de novo ainda da 0
    -- =========================================================================
    wait until rising_edge(clk);
    we  <= '1';
    wa  <= "00000";
    wd  <= x"DEADBEEF";
    ra1 <= "00000";
    wait until falling_edge(clk);
    wait for 1 ns;
    if rd1 /= x"00000000" then
      report "FALHA T04: Escrita em $zero alterou o valor do registrador 0!" severity error;
      erros := erros + 1;
    end if;

    -- =========================================================================
    -- T05: we = '0' -> o valor de $t0 nao pode mudar
    -- =========================================================================
    wait until rising_edge(clk);
    we  <= '0';
    wa  <= std_logic_vector(to_unsigned(8, 5));
    wd  <= x"12345678";
    ra1 <= std_logic_vector(to_unsigned(8, 5));
    wait until falling_edge(clk);
    wait for 1 ns;
    if rd1 /= x"0000002A" then
      report "FALHA T05: Registrador $t0 mudou de valor mesmo com we = '0'!" severity error;
      erros := erros + 1;
    end if;

    -- =========================================================================
    -- T06: Escrever e ler o mesmo registrador ($t0) no mesmo ciclo
    --      1a metade (antes da borda de descida): deve ler valor ANTIGO (42 = 0x2A)
    --      2a metade (apos a borda de descida):   deve ler valor NOVO   (99 = 0x63)
    -- =========================================================================
    wait until rising_edge(clk); -- Inicio do ciclo (1a metade: clk = '1')
    we  <= '1';
    wa  <= std_logic_vector(to_unsigned(8, 5));
    wd  <= x"00000063"; -- 99
    ra1 <= std_logic_vector(to_unsigned(8, 5));
    wait for 2 ns; -- Ainda na 1a metade do ciclo (antes da borda de descida)
    if rd1 /= x"0000002A" then
      report "FALHA T06 (1a metade): Esperava valor antigo (0x2A) antes da borda de descida." severity error;
      erros := erros + 1;
    end if;

    wait until falling_edge(clk); -- Meio do ciclo: escrita acontece na borda de descida!
    wait for 2 ns; -- Agora na 2a metade do ciclo (apos a borda de descida)
    if rd1 /= x"00000063" then
      report "FALHA T06 (2a metade): Esperava valor novo (0x63) apos a borda de descida." severity error;
      erros := erros + 1;
    end if;
    we <= '0';

    -- =========================================================================
    -- T07: Porta de depuracao (dbg_addr/dbg_data) le o mesmo valor que rd1
    -- =========================================================================
    ra1      <= std_logic_vector(to_unsigned(8, 5));
    dbg_addr <= std_logic_vector(to_unsigned(8, 5));
    wait for 1 ns;
    if not (dbg_data = rd1 and dbg_data = x"00000063") then
      report "FALHA T07: Porta de depuracao (dbg_data) divergiu de rd1." severity error;
      erros := erros + 1;
    end if;

    -- =========================================================================
    -- T08: Reset estritamente SINCRONO na borda de descida
    --      1) Com rst='1' na borda de subida, antes da descida $t0 ainda retem valor
    --      2) Na borda de descida, o reset atua e zera os registradores
    -- =========================================================================
    wait until rising_edge(clk);
    ra1      <= std_logic_vector(to_unsigned(8, 5)); -- $t0 (possui 0x63 do T06/T07)
    ra2      <= std_logic_vector(to_unsigned(9, 5)); -- $t1 (possui 0x64 do T02)
    dbg_addr <= std_logic_vector(to_unsigned(8, 5));
    rst      <= '1';

    -- Verifica se NAO reseta de forma assincrona (permanece com dado antes da descida)
    wait for 2 ns; -- Ainda na fase alta do clock (antes de falling_edge)
    if rd1 /= x"00000063" then
      report "FALHA T08: Reset atuou de forma assincrona antes da borda de descida!" severity error;
      erros := erros + 1;
    end if;

    -- Agora espera a borda de descida onde o reset sincrono deve atuar
    wait until falling_edge(clk);
    wait for 1 ns;
    if not (rd1 = x"00000000" and rd2 = x"00000000" and dbg_data = x"00000000") then
      report "FALHA T08: Reset sincrono na borda de descida nao zerou os registradores." severity error;
      erros := erros + 1;
    end if;
    rst <= '0';

    -- =========================================================================
    -- T09: Prioridade do Reset Sincrono sobre a Escrita (we = '1')
    --      Quando rst='1' e we='1' na borda de descida, rst tem precedencia
    -- =========================================================================
    wait until rising_edge(clk);
    rst <= '1';
    we  <= '1';
    wa  <= std_logic_vector(to_unsigned(8, 5)); -- tenta escrever em $t0
    wd  <= x"CAFEBABE";
    ra1 <= std_logic_vector(to_unsigned(8, 5));

    wait until falling_edge(clk); -- Na borda de descida, rst deve prevalecer
    wait for 1 ns;
    if rd1 /= x"00000000" then
      report "FALHA T09: Escrita ocorreu mesmo com rst = '1' (rst deve ter prioridade sobre we)!" severity error;
      erros := erros + 1;
    end if;
    rst <= '0';
    we  <= '0';

    -- Veredito final
    if erros = 0 then
      report "PASSOU: todos os 9 testes (T01 a T09) do banco_reg foram verificados sem erros." severity note;
    else
      assert false
        report "FALHOU: " & integer'image(erros) & " erro(s) encontrado(s) no banco_reg."
        severity failure;
    end if;

    sim_done <= true;
    wait;
  end process;

end architecture sim;