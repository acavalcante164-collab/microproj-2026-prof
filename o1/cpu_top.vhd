library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_top is
  generic (
    PROG_FILE     : string  := "tracos/t0.hex";
    MEM_UNIFICADA : boolean := false
  );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    done         : out std_logic;
    hazard_abort : out std_logic;
    hazard_type  : out std_logic_vector(1 downto 0);
    hazard_pc    : out std_logic_vector(31 downto 0);
    hazard_cycle : out unsigned(31 downto 0);
    retired      : out unsigned(1 downto 0);
    stage_valid  : out std_logic_vector(9 downto 0);
    dbg_reg_addr : in  std_logic_vector(4 downto 0);
    dbg_reg_data : out std_logic_vector(31 downto 0)
  );
end entity cpu_top;

architecture rtl of cpu_top is
  signal done_reg : std_logic := '0';
begin

  -- O1 (Monociclo) nao possui hazards de pipeline
  hazard_abort <= '0';
  hazard_type  <= "00";
  hazard_pc    <= (others => '0');
  hazard_cycle <= (others => '0');

  -- O1 usa apenas stage_valid(0); bits 9..1 fixos em '0'
  stage_valid(9 downto 1) <= (others => '0');
  stage_valid(0)          <= not rst and not done_reg;

  done         <= done_reg;
  retired      <= "00";
  dbg_reg_data <= (others => '0');

end architecture rtl;