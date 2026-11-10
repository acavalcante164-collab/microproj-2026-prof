-- Referencia bibliografica (Secao 8.2):
-- PATTERSON, D. A.; HENNESSY, J. L. Organizacao e Projeto de Computadores,
-- 5a edicao, Elsevier, 2017.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity data_memory is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    mem_write : in  std_logic;
    mem_read  : in  std_logic;
    addr      : in  std_logic_vector(31 downto 0);
    wd        : in  std_logic_vector(31 downto 0);
    rd        : out std_logic_vector(31 downto 0)
  );
end entity data_memory;

architecture rtl of data_memory is
  constant MEM_DEPTH : natural := 1024;
  type ram_type is array (0 to MEM_DEPTH - 1) of std_logic_vector(31 downto 0);
  signal ram : ram_type := (others => (others => '0'));
  signal word_index : natural range 0 to MEM_DEPTH - 1;
begin

  word_index <= to_integer(unsigned(addr(11 downto 2)));

  process(clk)
  begin
    if falling_edge(clk) then
      if rst = '1' then
        ram <= (others => (others => '0'));
      elsif mem_write = '1' then
        ram(word_index) <= wd;
      end if;
    end if;
  end process;

  rd <= ram(word_index) when mem_read = '1' else (others => '0');

end architecture rtl;
