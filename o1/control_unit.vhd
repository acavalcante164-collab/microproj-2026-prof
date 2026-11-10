-- Referencia bibliografica (Secao 8.2):
-- PATTERSON, D. A.; HENNESSY, J. L. Organizacao e Projeto de Computadores,
-- 5a edicao, Elsevier, 2017.

library ieee;
use ieee.std_logic_1164.all;

entity control_unit is
  port (
    opcode     : in  std_logic_vector(5 downto 0);
    funct      : in  std_logic_vector(5 downto 0);
    reg_dst    : out std_logic;
    alu_src    : out std_logic;
    mem_to_reg : out std_logic;
    reg_write  : out std_logic;
    mem_read   : out std_logic;
    mem_write  : out std_logic;
    branch     : out std_logic;
    alu_op     : out std_logic_vector(1 downto 0);
    is_break   : out std_logic
  );
end entity control_unit;

architecture rtl of control_unit is
begin
  process(opcode, funct)
  begin
    reg_dst    <= '0';
    alu_src    <= '0';
    mem_to_reg <= '0';
    reg_write  <= '0';
    mem_read   <= '0';
    mem_write  <= '0';
    branch     <= '0';
    alu_op     <= "00";
    is_break   <= '0';

    case opcode is
      when "000000" =>
        if funct = "001101" then
          is_break <= '1';
        else
          reg_dst   <= '1';
          reg_write <= '1';
          alu_op    <= "10";
        end if;

      when "001000" => -- addi
        alu_src   <= '1';
        reg_write <= '1';
        alu_op    <= "00";

      when "100011" => -- lw
        alu_src    <= '1';
        mem_to_reg <= '1';
        reg_write  <= '1';
        mem_read   <= '1';
        alu_op     <= "00";

      when "101011" => -- sw
        alu_src   <= '1';
        mem_write <= '1';
        alu_op    <= "00";

      when "000100" => -- beq
        branch <= '1';
        alu_op <= "01";

      when others =>
        null;
    end case;
  end process;
end architecture rtl;
