-- Referencia bibliografica (Secao 8.2):
-- PATTERSON, D. A.; HENNESSY, J. L. Organizacao e Projeto de Computadores,
-- 5a edicao, Elsevier, 2017.

library ieee;
use ieee.std_logic_1164.all;

entity alu_control is
  port (
    alu_op   : in  std_logic_vector(1 downto 0);
    funct    : in  std_logic_vector(5 downto 0);
    alu_ctrl : out std_logic_vector(3 downto 0)
  );
end entity alu_control;

architecture rtl of alu_control is
begin
  process(alu_op, funct)
  begin
    case alu_op is
      when "00" => -- lw, sw, addi
        alu_ctrl <= "0010"; -- ADD

      when "01" => -- beq
        alu_ctrl <= "0110"; -- SUB

      when "10" => -- R-type (olha o campo funct)
        case funct is
          when "100000" => alu_ctrl <= "0010"; -- add (0x20)
          when "100010" => alu_ctrl <= "0110"; -- sub (0x22)
          when "100100" => alu_ctrl <= "0000"; -- and (0x24)
          when "100101" => alu_ctrl <= "0001"; -- or  (0x25)
          when "101010" => alu_ctrl <= "0111"; -- slt (0x2A)
          when others   => alu_ctrl <= "0000";
        end case;

      when others =>
        alu_ctrl <= "0000";
    end case;
  end process;
end architecture rtl;
