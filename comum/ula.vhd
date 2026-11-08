-- ula.vhd : Unidade Logica e Aritmetica de 32 bits (usada em O1 e O2).
--
-- Fonte da codificacao de alu_ctrl (0000 AND, 0001 OR, 0010 ADD,
-- 0110 SUB, 0111 SLT):
--   PATTERSON, D. A.; HENNESSY, J. L. Organização e Projeto de Computadores,
--   5 edicao, Versão traduzida. 
--
-- Decisoes de projeto:
--   - overflow em ADD/SUB da a volta (wrap-around), sem excecao;
--   - SLT compara com sinal (signed);
--   - zero = '1' quando o resultado da operacao e 0.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu is
    port (
        a        : in  std_logic_vector(31 downto 0);
        b        : in  std_logic_vector(31 downto 0);
        alu_ctrl : in  std_logic_vector(3 downto 0);
        result   : out std_logic_vector(31 downto 0);
        zero     : out std_logic
    );
end entity alu;

architecture rtl of alu is
    signal alu_res : std_logic_vector(31 downto 0);
begin

    process(a, b, alu_ctrl)
    begin
        case alu_ctrl is
            when "0000" => -- AND
                alu_res <= a and b;

            when "0001" => -- OR
                alu_res <= a or b;

            when "0010" => -- ADD (add, addi, lw, sw)
                alu_res <= std_logic_vector(signed(a) + signed(b));

            when "0110" => -- SUB (sub, beq)
                alu_res <= std_logic_vector(signed(a) - signed(b));

            when "0111" => -- SLT (signed comparison)
                if signed(a) < signed(b) then
                    alu_res <= x"00000001";
                else
                    alu_res <= x"00000000";
                end if;

            when others =>
                alu_res <= (others => '0');
        end case;
    end process;

    -- Saída principal
    result <= alu_res;

    -- Flag Zero: vale '1' exclusivamente quando todos os 32 bits do resultado são '0'
    zero <= '1' when alu_res = x"00000000" else '0';

end architecture rtl;