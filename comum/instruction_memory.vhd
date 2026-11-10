-- Referencia bibliografica (Secao 8.2):
-- PATTERSON, D. A.; HENNESSY, J. L. Organizacao e Projeto de Computadores,
-- 5a edicao, Elsevier, 2017.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity instruction_memory is
  generic (
    PROG_FILE : string := "tracos/t0.hex"
  );
  port (
    addr  : in  std_logic_vector(31 downto 0);
    instr : out std_logic_vector(31 downto 0)
  );
end entity instruction_memory;

architecture rtl of instruction_memory is
  constant MEM_DEPTH : natural := 1024;
  type rom_type is array (0 to MEM_DEPTH - 1) of std_logic_vector(31 downto 0);

  impure function init_rom(file_name : string) return rom_type is
    file f          : text;
    variable status : file_open_status;
    variable l      : line;
    variable mem    : rom_type := (others => (others => '0'));
    variable idx    : natural  := 0;
    variable word   : std_logic_vector(31 downto 0);
    variable ch     : character;
    variable good   : boolean;
  begin
    file_open(status, f, file_name, read_mode);
    assert status = open_ok
      report "Erro fatal: Nao foi possivel abrir o arquivo de programa: " & file_name
      severity failure;

    while not endfile(f) and idx < MEM_DEPTH loop
      readline(f, l);
      while l'length > 0 and (l(l'left) = ' ' or l(l'left) = HT or l(l'left) = CR) loop
        read(l, ch);
      end loop;
      next when l'length = 0;
      next when l(l'left) = '#' or l(l'left) = '-';

      if l'length >= 2 and l(l'left) = '0' and (l(l'left + 1) = 'x' or l(l'left + 1) = 'X') then
        read(l, ch);
        read(l, ch);
      end if;

      hread(l, word, good);
      if good then
        mem(idx) := word;
        idx := idx + 1;
      end if;
    end loop;

    file_close(f);
    return mem;
  end function;

  signal rom : rom_type := init_rom(PROG_FILE);
  signal word_index : natural range 0 to MEM_DEPTH - 1;
begin

  word_index <= to_integer(unsigned(addr(11 downto 2)));
  instr      <= rom(word_index);

end architecture rtl;
