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

  signal cycle_cnt   : unsigned(31 downto 0) := to_unsigned(1, 32);
  signal done_reg    : std_logic := '0';
  signal abort_reg   : std_logic := '0';
  signal htype_reg   : std_logic_vector(1 downto 0)  := "00";
  signal hpc_reg     : std_logic_vector(31 downto 0) := (others => '0');
  signal hcycle_reg  : unsigned(31 downto 0)         := (others => '0');

  signal done_comb   : std_logic;
  signal abort_comb  : std_logic;
  signal htype_comb  : std_logic_vector(1 downto 0);
  signal hpc_comb    : std_logic_vector(31 downto 0);
  signal hcycle_comb : unsigned(31 downto 0);
  signal freeze_pipe : std_logic;

  -- Estagio 1: IF
  signal pc_reg          : std_logic_vector(31 downto 0) := (others => '0');
  signal pc_plus_4       : std_logic_vector(31 downto 0);
  signal if_instr        : std_logic_vector(31 downto 0);
  signal if_valid        : std_logic;
  signal if_is_break     : std_logic;
  signal break_in_flight : std_logic;

  -- Estagio 2: ID
  signal id_valid      : std_logic := '0';
  signal id_pc         : std_logic_vector(31 downto 0) := (others => '0');
  signal id_instr      : std_logic_vector(31 downto 0) := (others => '0');
  signal id_opcode     : std_logic_vector(5 downto 0);
  signal id_rs         : std_logic_vector(4 downto 0);
  signal id_rt         : std_logic_vector(4 downto 0);
  signal id_rd         : std_logic_vector(4 downto 0);
  signal id_funct      : std_logic_vector(5 downto 0);
  signal id_imm16      : std_logic_vector(15 downto 0);
  signal id_imm32      : std_logic_vector(31 downto 0);
  signal id_reg_dst    : std_logic;
  signal id_alu_src    : std_logic;
  signal id_mem_to_reg : std_logic;
  signal id_reg_write  : std_logic;
  signal id_mem_read   : std_logic;
  signal id_mem_write  : std_logic;
  signal id_branch     : std_logic;
  signal id_alu_op     : std_logic_vector(1 downto 0);
  signal id_is_break   : std_logic;
  signal id_rd1        : std_logic_vector(31 downto 0);
  signal id_rd2        : std_logic_vector(31 downto 0);
  signal id_wa         : std_logic_vector(4 downto 0);
  signal id_uses_rs    : std_logic;
  signal id_uses_rt    : std_logic;

  -- Estagio 3: EX
  signal ex_valid      : std_logic := '0';
  signal ex_pc         : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_rd1        : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_rd2        : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_imm32      : std_logic_vector(31 downto 0) := (others => '0');
  signal ex_wa         : std_logic_vector(4 downto 0)  := (others => '0');
  signal ex_funct      : std_logic_vector(5 downto 0)  := (others => '0');
  signal ex_alu_src    : std_logic := '0';
  signal ex_alu_op     : std_logic_vector(1 downto 0)  := "00";
  signal ex_mem_to_reg : std_logic := '0';
  signal ex_reg_write  : std_logic := '0';
  signal ex_mem_read   : std_logic := '0';
  signal ex_mem_write  : std_logic := '0';
  signal ex_branch     : std_logic := '0';
  signal ex_is_break   : std_logic := '0';
  signal ex_alu_b      : std_logic_vector(31 downto 0);
  signal ex_alu_ctrl   : std_logic_vector(3 downto 0);
  signal ex_alu_result : std_logic_vector(31 downto 0);
  signal ex_alu_zero   : std_logic;
  signal ex_take_branch: std_logic;

  -- Estagio 4: MEM
  signal mem_valid      : std_logic := '0';
  signal mem_pc         : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_alu_result : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_rd2        : std_logic_vector(31 downto 0) := (others => '0');
  signal mem_wa         : std_logic_vector(4 downto 0)  := (others => '0');
  signal mem_mem_to_reg : std_logic := '0';
  signal mem_reg_write  : std_logic := '0';
  signal mem_mem_read   : std_logic := '0';
  signal mem_mem_write  : std_logic := '0';
  signal mem_is_break   : std_logic := '0';
  signal mem_rd_data    : std_logic_vector(31 downto 0);
  signal mem_mw_gated   : std_logic;

  -- Estagio 5: WB
  signal wb_valid      : std_logic := '0';
  signal wb_pc         : std_logic_vector(31 downto 0) := (others => '0');
  signal wb_alu_result : std_logic_vector(31 downto 0) := (others => '0');
  signal wb_mem_data   : std_logic_vector(31 downto 0) := (others => '0');
  signal wb_wa         : std_logic_vector(4 downto 0)  := (others => '0');
  signal wb_mem_to_reg : std_logic := '0';
  signal wb_reg_write  : std_logic := '0';
  signal wb_is_break   : std_logic := '0';
  signal wb_wd         : std_logic_vector(31 downto 0);
  signal wb_we_gated   : std_logic;

  -- Deteccao de Hazards
  signal raw_hazard_ex  : std_logic;
  signal raw_hazard_mem : std_logic;
  signal raw_hazard     : std_logic;
  signal struct_hazard  : std_logic;
  signal ctrl_hazard    : std_logic;
  signal any_hazard     : std_logic;

begin

  -- =========================================================================
  -- 1. ESTAGIO IF
  -- =========================================================================
  pc_plus_4 <= std_logic_vector(unsigned(pc_reg) + 4);

  u_imem: entity work.instruction_memory
    generic map (PROG_FILE => PROG_FILE)
    port map (addr => pc_reg, instr => if_instr);

  if_is_break <= '1' when (if_instr(31 downto 26) = "000000" and if_instr(5 downto 0) = "001101") else '0';

  -- Assim que o break entra em ID, EX, MEM ou WB, IF deixa de validar novas buscas
  -- para esvaziar o pipeline ate que o break alcance WB.
  break_in_flight <= (id_valid  and id_is_break) or
                     (ex_valid  and ex_is_break) or
                     (mem_valid and mem_is_break) or
                     (wb_valid  and wb_is_break);

  if_valid <= '1' when (rst = '0' and done_reg = '0' and abort_reg = '0' and break_in_flight = '0') else '0';

  -- =========================================================================
  -- 2. ESTAGIO ID
  -- =========================================================================
  id_opcode <= id_instr(31 downto 26);
  id_rs     <= id_instr(25 downto 21);
  id_rt     <= id_instr(20 downto 16);
  id_rd     <= id_instr(15 downto 11);
  id_imm16  <= id_instr(15 downto 0);
  id_funct  <= id_instr(5 downto 0);

  u_ctrl: entity work.control_unit
    port map (
      opcode     => id_opcode,
      funct      => id_funct,
      reg_dst    => id_reg_dst,
      alu_src    => id_alu_src,
      mem_to_reg => id_mem_to_reg,
      reg_write  => id_reg_write,
      mem_read   => id_mem_read,
      mem_write  => id_mem_write,
      branch     => id_branch,
      alu_op     => id_alu_op,
      is_break   => id_is_break
    );

  u_sign_ext: entity work.sign_ext
    port map (imm_in => id_imm16, imm_out => id_imm32);

  id_wa <= id_rd when id_reg_dst = '1' else id_rt;

  -- Quais instrucoes em ID leem rs e/ou rt (tudo em std_logic)
  id_uses_rs <= id_valid and (not id_is_break);
  id_uses_rt <= id_valid and (not id_is_break) and (id_reg_dst or id_mem_write or id_branch);

  wb_wd       <= wb_mem_data when wb_mem_to_reg = '1' else wb_alu_result;
  wb_we_gated <= wb_valid and wb_reg_write and (not wb_is_break) and
                 (not rst) and (not freeze_pipe);

  u_breg: entity work.banco_reg
    port map (
      clk      => clk,
      rst      => rst,
      we       => wb_we_gated,
      ra1      => id_rs,
      ra2      => id_rt,
      wa       => wb_wa,
      wd       => wb_wd,
      rd1      => id_rd1,
      rd2      => id_rd2,
      dbg_addr => dbg_reg_addr,
      dbg_data => dbg_reg_data
    );

  -- =========================================================================
  -- 3. ESTAGIO EX
  -- =========================================================================
  u_alu_ctrl: entity work.alu_control
    port map (alu_op => ex_alu_op, funct => ex_funct, alu_ctrl => ex_alu_ctrl);

  ex_alu_b <= ex_imm32 when ex_alu_src = '1' else ex_rd2;

  u_alu: entity work.alu
    port map (a => ex_rd1, b => ex_alu_b, alu_ctrl => ex_alu_ctrl, result => ex_alu_result, zero => ex_alu_zero);

  ex_take_branch <= ex_valid and ex_branch and ex_alu_zero;

  -- =========================================================================
  -- 4. ESTAGIO MEM
  -- =========================================================================
  mem_mw_gated <= mem_valid and mem_mem_write and (not mem_is_break) and
                  (not rst) and (not freeze_pipe);

  u_dmem: entity work.data_memory
    port map (
      clk       => clk,
      rst       => rst,
      mem_write => mem_mw_gated,
      mem_read  => mem_mem_read,
      addr      => mem_alu_result,
      wd        => mem_rd2,
      rd        => mem_rd_data
    );

  -- =========================================================================
  -- 5. UNIDADE DE DETECCAO DE HAZARDS (Issues #7, #8, #9 e #10)
  -- =========================================================================
  raw_hazard_ex <= '1' when (ex_valid = '1' and ex_reg_write = '1' and unsigned(ex_wa) /= 0 and
                            ((id_uses_rs = '1' and id_rs = ex_wa) or
                             (id_uses_rt = '1' and id_rt = ex_wa))) else '0';

  raw_hazard_mem <= '1' when (mem_valid = '1' and mem_reg_write = '1' and unsigned(mem_wa) /= 0 and
                             ((id_uses_rs = '1' and id_rs = mem_wa) or
                              (id_uses_rt = '1' and id_rt = mem_wa))) else '0';

  raw_hazard <= raw_hazard_ex or raw_hazard_mem;

  struct_hazard <= '1' when (MEM_UNIFICADA and if_valid = '1' and mem_valid = '1' and
                             (mem_mem_read = '1' or mem_mem_write = '1')) else '0';

  ctrl_hazard <= '1' when (ex_take_branch = '1' and (id_valid = '1' or if_valid = '1')) else '0';

  any_hazard <= '1' when (rst = '0' and done_reg = '0' and abort_reg = '0' and
                          (ctrl_hazard = '1' or raw_hazard = '1' or struct_hazard = '1')) else '0';

  process(abort_reg, htype_reg, hpc_reg, hcycle_reg,
          any_hazard, ctrl_hazard, raw_hazard, struct_hazard,
          ex_pc, id_pc, pc_reg, cycle_cnt)
  begin
    if abort_reg = '1' then
      abort_comb  <= '1';
      htype_comb  <= htype_reg;
      hpc_comb    <= hpc_reg;
      hcycle_comb <= hcycle_reg;
    elsif any_hazard = '1' then
      abort_comb  <= '1';
      hcycle_comb <= cycle_cnt;
      if ctrl_hazard = '1' then
        htype_comb <= "11";
        hpc_comb   <= ex_pc;
      elsif raw_hazard = '1' then
        htype_comb <= "01";
        hpc_comb   <= id_pc;
      else
        htype_comb <= "10";
        hpc_comb   <= pc_reg;
      end if;
    else
      abort_comb  <= '0';
      htype_comb  <= "00";
      hpc_comb    <= (others => '0');
      hcycle_comb <= (others => '0');
    end if;
  end process;

  -- Em O2, o programa conclui quando o break chega valido ao estagio WB
  done_comb <= '1' when (done_reg = '1' or
                         (rst = '0' and abort_comb = '0' and wb_valid = '1' and wb_is_break = '1'))
               else '0';

  freeze_pipe <= done_comb or abort_comb;

  -- =========================================================================
  -- 6. ATUALIZACAO DOS REGISTRADORES ENTRE ESTAGIOS (Borda de Subida)
  -- =========================================================================
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cycle_cnt  <= to_unsigned(1, 32);
        pc_reg     <= (others => '0');
        done_reg   <= '0';
        abort_reg  <= '0';
        htype_reg  <= "00";
        hpc_reg    <= (others => '0');
        hcycle_reg <= (others => '0');
        id_valid   <= '0';
        ex_valid   <= '0';
        mem_valid  <= '0';
        wb_valid   <= '0';
      else
        done_reg   <= done_comb;
        abort_reg  <= abort_comb;
        htype_reg  <= htype_comb;
        hpc_reg    <= hpc_comb;
        hcycle_reg <= hcycle_comb;

        if freeze_pipe = '0' then
          cycle_cnt <= cycle_cnt + 1;

          -- PC avanca enquanto estiver buscando instrucoes normais; estaciona no break
          if if_valid = '1' and if_is_break = '0' then
            pc_reg <= pc_plus_4;
          end if;

          -- Registrador IF/ID
          id_valid <= if_valid;
          id_pc    <= pc_reg;
          id_instr <= if_instr;

          -- Registrador ID/EX (o break propaga com valid='1' ate WB para esvaziar o pipeline)
          ex_valid      <= id_valid;
          ex_pc         <= id_pc;
          ex_rd1        <= id_rd1;
          ex_rd2        <= id_rd2;
          ex_imm32      <= id_imm32;
          ex_wa         <= id_wa;
          ex_funct      <= id_funct;
          ex_alu_src    <= id_alu_src;
          ex_alu_op     <= id_alu_op;
          ex_mem_to_reg <= id_mem_to_reg;
          ex_reg_write  <= id_reg_write;
          ex_mem_read   <= id_mem_read;
          ex_mem_write  <= id_mem_write;
          ex_branch     <= id_branch;
          ex_is_break   <= id_is_break;

          -- Registrador EX/MEM
          mem_valid      <= ex_valid;
          mem_pc         <= ex_pc;
          mem_alu_result <= ex_alu_result;
          mem_rd2        <= ex_rd2;
          mem_wa         <= ex_wa;
          mem_mem_to_reg <= ex_mem_to_reg;
          mem_reg_write  <= ex_reg_write;
          mem_mem_read   <= ex_mem_read;
          mem_mem_write  <= ex_mem_write;
          mem_is_break   <= ex_is_break;

          -- Registrador MEM/WB
          wb_valid      <= mem_valid;
          wb_pc         <= mem_pc;
          wb_alu_result <= mem_alu_result;
          wb_mem_data   <= mem_rd_data;
          wb_wa         <= mem_wa;
          wb_mem_to_reg <= mem_mem_to_reg;
          wb_reg_write  <= mem_reg_write;
          wb_is_break   <= mem_is_break;
        end if;
      end if;
    end if;
  end process;

  -- =========================================================================
  -- 7. SAIDAS DA INTERFACE R3
  -- =========================================================================
  done         <= done_comb;
  hazard_abort <= abort_comb;
  hazard_type  <= htype_comb;
  hazard_pc    <= hpc_comb;
  hazard_cycle <= hcycle_comb;

  retired <= "01" when (rst = '0' and abort_comb = '0' and done_reg = '0' and
                        wb_valid = '1' and wb_is_break = '0')
             else "00";

  stage_valid(9 downto 5) <= (others => '0');
  stage_valid(4)          <= wb_valid  when (rst = '0' and abort_reg = '0' and done_reg = '0') else '0';
  stage_valid(3)          <= mem_valid when (rst = '0' and abort_reg = '0' and done_reg = '0') else '0';
  stage_valid(2)          <= ex_valid  when (rst = '0' and abort_reg = '0' and done_reg = '0') else '0';
  stage_valid(1)          <= id_valid  when (rst = '0' and abort_reg = '0' and done_reg = '0') else '0';
  stage_valid(0)          <= if_valid  when (rst = '0' and abort_reg = '0' and done_reg = '0') else '0';

end architecture rtl;
