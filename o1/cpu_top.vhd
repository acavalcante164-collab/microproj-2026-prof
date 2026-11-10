-- Referencia bibliografica (Secao 8.2):
-- PATTERSON, D. A.; HENNESSY, J. L. Organizacao e Projeto de Computadores,
-- 5a edicao, Elsevier, 2017.

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
  signal pc_reg     : std_logic_vector(31 downto 0) := (others => '0');
  signal pc_next    : std_logic_vector(31 downto 0);
  signal pc_plus_4  : std_logic_vector(31 downto 0);
  signal pc_branch  : std_logic_vector(31 downto 0);
  signal halted_reg : std_logic := '0';

  signal instr  : std_logic_vector(31 downto 0);
  signal opcode : std_logic_vector(5 downto 0);
  signal rs     : std_logic_vector(4 downto 0);
  signal rt     : std_logic_vector(4 downto 0);
  signal rd     : std_logic_vector(4 downto 0);
  signal funct  : std_logic_vector(5 downto 0);
  signal imm16  : std_logic_vector(15 downto 0);
  signal imm32  : std_logic_vector(31 downto 0);

  signal reg_dst    : std_logic;
  signal alu_src    : std_logic;
  signal mem_to_reg : std_logic;
  signal reg_write  : std_logic;
  signal mem_read   : std_logic;
  signal mem_write  : std_logic;
  signal branch     : std_logic;
  signal alu_op     : std_logic_vector(1 downto 0);
  signal is_break   : std_logic;
  signal alu_ctrl   : std_logic_vector(3 downto 0);

  signal reg_wa      : std_logic_vector(4 downto 0);
  signal reg_wd      : std_logic_vector(31 downto 0);
  signal reg_rd1     : std_logic_vector(31 downto 0);
  signal reg_rd2     : std_logic_vector(31 downto 0);
  signal alu_b       : std_logic_vector(31 downto 0);
  signal alu_result  : std_logic_vector(31 downto 0);
  signal alu_zero    : std_logic;
  signal mem_rd_data : std_logic_vector(31 downto 0);
  signal take_branch : std_logic;
  signal we_gated    : std_logic;
  signal mw_gated    : std_logic;
begin

  pc_plus_4   <= std_logic_vector(unsigned(pc_reg) + 4);
  pc_branch   <= std_logic_vector(signed(pc_plus_4) + shift_left(signed(imm32), 2));
  take_branch <= branch and alu_zero;
  pc_next     <= pc_branch when take_branch = '1' else pc_plus_4;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        pc_reg     <= (others => '0');
        halted_reg <= '0';
      elsif halted_reg = '0' then
        if is_break = '1' then
          halted_reg <= '1';
        else
          pc_reg <= pc_next;
        end if;
      end if;
    end if;
  end process;

  u_imem: entity work.instruction_memory
    generic map (
      PROG_FILE => PROG_FILE
    )
    port map (
      addr  => pc_reg,
      instr => instr
    );

  opcode <= instr(31 downto 26);
  rs     <= instr(25 downto 21);
  rt     <= instr(20 downto 16);
  rd     <= instr(15 downto 11);
  imm16  <= instr(15 downto 0);
  funct  <= instr(5 downto 0);

  u_ctrl: entity work.control_unit
    port map (
      opcode     => opcode,
      funct      => funct,
      reg_dst    => reg_dst,
      alu_src    => alu_src,
      mem_to_reg => mem_to_reg,
      reg_write  => reg_write,
      mem_read   => mem_read,
      mem_write  => mem_write,
      branch     => branch,
      alu_op     => alu_op,
      is_break   => is_break
    );

  u_sign_ext: entity work.sign_ext
    port map (
      imm_in  => imm16,
      imm_out => imm32
    );

  reg_wa   <= rd when reg_dst = '1' else rt;
  reg_wd   <= mem_rd_data when mem_to_reg = '1' else alu_result;
  we_gated <= reg_write and (not rst) and (not halted_reg) and (not is_break);

  u_breg: entity work.banco_reg
    port map (
      clk      => clk,
      rst      => rst,
      we       => we_gated,
      ra1      => rs,
      ra2      => rt,
      wa       => reg_wa,
      wd       => reg_wd,
      rd1      => reg_rd1,
      rd2      => reg_rd2,
      dbg_addr => dbg_reg_addr,
      dbg_data => dbg_reg_data
    );

  u_alu_ctrl: entity work.alu_control
    port map (
      alu_op   => alu_op,
      funct    => funct,
      alu_ctrl => alu_ctrl
    );

  alu_b <= imm32 when alu_src = '1' else reg_rd2;

  u_alu: entity work.alu
    port map (
      a        => reg_rd1,
      b        => alu_b,
      alu_ctrl => alu_ctrl,
      result   => alu_result,
      zero     => alu_zero
    );

  mw_gated <= mem_write and (not rst) and (not halted_reg) and (not is_break);

  u_dmem: entity work.data_memory
    port map (
      clk       => clk,
      rst       => rst,
      mem_write => mw_gated,
      mem_read  => mem_read,
      addr      => alu_result,
      wd        => reg_rd2,
      rd        => mem_rd_data
    );

  hazard_abort <= '0';
  hazard_type  <= "00";
  hazard_pc    <= (others => '0');
  hazard_cycle <= (others => '0');

  done <= '1' when (halted_reg = '1' or (rst = '0' and is_break = '1')) else '0';
  retired <= "01" when (rst = '0' and halted_reg = '0' and is_break = '0') else "00";

  stage_valid(9 downto 1) <= (others => '0');
  stage_valid(0)          <= '1' when (rst = '0' and halted_reg = '0') else '0';

end architecture rtl;
