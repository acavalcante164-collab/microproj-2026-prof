library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_alu is
end entity tb_alu;

architecture sim of tb_alu is
    signal a        : std_logic_vector(31 downto 0) := (others => '0');
    signal b        : std_logic_vector(31 downto 0) := (others => '0');
    signal alu_ctrl : std_logic_vector(3 downto 0)  := (others => '0');
    signal result   : std_logic_vector(31 downto 0);
    signal zero     : std_logic;
begin

    uut: entity work.alu
        port map (
            a        => a,
            b        => b,
            alu_ctrl => alu_ctrl,
            result   => result,
            zero     => zero
        );

    stim_proc: process
        variable erros : integer := 0;
    begin
        -- 1. ADD basico: 10 + 20 = 30 (0x0000001E), zero = '0'
        a        <= x"0000000A";
        b        <= x"00000014";
        alu_ctrl <= "0010";
        wait for 10 ns;
        if not (result = x"0000001E" and zero = '0') then
            report "FALHA Teste 1 (ADD): 10 + 20 esperado 0x0000001E" severity error;
            erros := erros + 1;
        end if;

        -- 2. ADD overflow (wrap-around): 0x7FFFFFFF + 1 = 0x80000000, zero = '0'
        a        <= x"7FFFFFFF";
        b        <= x"00000001";
        alu_ctrl <= "0010";
        wait for 10 ns;
        if not (result = x"80000000" and zero = '0') then
            report "FALHA Teste 2 (ADD overflow): 0x7FFFFFFF + 1 esperado 0x80000000" severity error;
            erros := erros + 1;
        end if;

        -- 3. SUB (diferente de zero): 30 - 10 = 20 (0x00000014), zero = '0'
        a        <= x"0000001E";
        b        <= x"0000000A";
        alu_ctrl <= "0110";
        wait for 10 ns;
        if not (result = x"00000014" and zero = '0') then
            report "FALHA Teste 3 (SUB != 0): 30 - 10 esperado 0x00000014" severity error;
            erros := erros + 1;
        end if;

        -- 4. SUB (igual a zero / beq): 25 - 25 = 0 (0x00000000), zero = '1'
        a        <= x"00000019";
        b        <= x"00000019";
        alu_ctrl <= "0110";
        wait for 10 ns;
        if not (result = x"00000000" and zero = '1') then
            report "FALHA Teste 4 (SUB == 0): 25 - 25 esperado 0x00000000 e zero=1" severity error;
            erros := erros + 1;
        end if;

        -- 5. AND (nao-zero, testa pares 00, 01, 10, 11): 0x3C & 0x15 = 0x14, zero = '0'
        a        <= x"0000003C";
        b        <= x"00000015";
        alu_ctrl <= "0000";
        wait for 10 ns;
        if not (result = x"00000014" and zero = '0') then
            report "FALHA Teste 5 (AND): 0x3C & 0x15 esperado 0x00000014" severity error;
            erros := erros + 1;
        end if;

        -- 6. OR (bits sobrepostos, difere de ADD): 0x3C | 0x15 = 0x3D, zero = '0'
        a        <= x"0000003C";
        b        <= x"00000015";
        alu_ctrl <= "0001";
        wait for 10 ns;
        if not (result = x"0000003D" and zero = '0') then
            report "FALHA Teste 6 (OR): 0x3C | 0x15 esperado 0x0000003D" severity error;
            erros := erros + 1;
        end if;

        -- 7. SLT com sinal (negativo < positivo): -5 (0xFFFFFFFB) < 2 -> 1, zero = '0'
        a        <= x"FFFFFFFB";
        b        <= x"00000002";
        alu_ctrl <= "0111";
        wait for 10 ns;
        if not (result = x"00000001" and zero = '0') then
            report "FALHA Teste 7 (SLT -5 < 2): esperado 1" severity error;
            erros := erros + 1;
        end if;

        -- 8. SLT com sinal (positivo < negativo): 1 < -1 (0xFFFFFFFF) -> 0, zero = '1'
        a        <= x"00000001";
        b        <= x"FFFFFFFF";
        alu_ctrl <= "0111";
        wait for 10 ns;
        if not (result = x"00000000" and zero = '1') then
            report "FALHA Teste 8 (SLT 1 < -1): esperado 0 e zero=1" severity error;
            erros := erros + 1;
        end if;

        -- 9. SLT operandos iguais (desigualdade estrita): 5 < 5 -> 0, zero = '1'
        a        <= x"00000005";
        b        <= x"00000005";
        alu_ctrl <= "0111";
        wait for 10 ns;
        if not (result = x"00000000" and zero = '1') then
            report "FALHA Teste 9 (SLT 5 < 5): esperado 0 e zero=1" severity error;
            erros := erros + 1;
        end if;

        -- 10. SLT positivos falso: 20 < 10 -> 0, zero = '1'
        a        <= x"00000014";
        b        <= x"0000000A";
        alu_ctrl <= "0111";
        wait for 10 ns;
        if not (result = x"00000000" and zero = '1') then
            report "FALHA Teste 10 (SLT 20 < 10): esperado 0 e zero=1" severity error;
            erros := erros + 1;
        end if;

        -- Veredito final condicional
        if erros = 0 then
            report "PASSOU: todos os 10 testes da ULA foram verificados sem erros." severity note;
        else
            assert false
                report "FALHOU: " & integer'image(erros) & " erro(s) encontrado(s) na ULA."
                severity failure;
        end if;

        wait;
    end process;

end architecture sim;