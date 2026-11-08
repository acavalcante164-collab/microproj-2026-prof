--   PATTERSON, D. A.; HENNESSY, J. L. Organização e Projeto de Computadores,
--   5 edicao, Versão traduzida. 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity banco_reg is
  port (
    clk, rst  : in  std_logic;
    we        : in  std_logic;                        -- habilita escrita
    ra1, ra2  : in  std_logic_vector(4 downto 0);     -- enderecos de leitura
    wa        : in  std_logic_vector(4 downto 0);     -- endereco de escrita
    wd        : in  std_logic_vector(31 downto 0);    -- dado de escrita
    rd1, rd2  : out std_logic_vector(31 downto 0);    -- leituras
    dbg_addr  : in  std_logic_vector(4 downto 0);
    dbg_data  : out std_logic_vector(31 downto 0)
  );
end entity banco_reg;

architecture rtl of banco_reg is
  type tipo_banco is array (0 to 31) of std_logic_vector(31 downto 0);
  signal regs : tipo_banco := (others => (others => '0'));
begin

  -- Escrita e Reset sincronos na borda de descida (meio do ciclo = fim da 1a metade)
  -- Processo sensivel apenas ao clock
  process(clk)
  begin
    if falling_edge(clk) then
      if rst = '1' then
        regs <= (others => (others => '0'));
      elsif we = '1' and unsigned(wa) /= 0 then
        regs(to_integer(unsigned(wa))) <= wd;
      end if;
    end if;
  end process;

  -- Leituras combinacionais (2a metade ja enxerga o valor escrito na borda de descida)
  -- Dupla protecao para $zero: endereco 0 devolve 0 sempre
  rd1 <= (others => '0') when unsigned(ra1) = 0 else regs(to_integer(unsigned(ra1)));
  rd2 <= (others => '0') when unsigned(ra2) = 0 else regs(to_integer(unsigned(ra2)));
  dbg_data <= (others => '0') when unsigned(dbg_addr) = 0 else regs(to_integer(unsigned(dbg_addr)));

end architecture rtl;