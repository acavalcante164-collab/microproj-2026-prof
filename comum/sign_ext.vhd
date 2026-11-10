-- Referencia bibliografica (Secao 8.2):
-- PATTERSON, D. A.; HENNESSY, J. L. Organizacao e Projeto de Computadores,
-- 5a edicao, Elsevier, 2017.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sign_ext is
  port (
    imm_in  : in  std_logic_vector(15 downto 0);
    imm_out : out std_logic_vector(31 downto 0)
  );
end entity sign_ext;

architecture rtl of sign_ext is
begin
  imm_out <= std_logic_vector(resize(signed(imm_in), 32));
end architecture rtl;
