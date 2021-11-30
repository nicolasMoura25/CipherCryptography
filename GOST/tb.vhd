--------------------------------------
-- Library
--------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;

--------------------------------------
-- Entity
--------------------------------------
entity tb is
end entity;

--------------------------------------
-- Architecture
--------------------------------------
architecture tb of tb is
  -- Clock definition
  constant clk_period : time := 20 ns;

  -- Input signals
  signal clk : std_logic := '1';
  signal reset_n : std_logic := '0';
  signal key_word_in : std_logic_vector(31 downto 0) := (others => '0');
  signal encryption, key_valid, data_valid : std_logic := '0';
  signal data_word_in : std_logic_vector (31 downto 0) := (others => '0');

  -- Output signals
  signal data_ready : std_logic;
  signal data_word_out : std_logic_vector (31 downto 0);

  -- Internal signals
  signal data_bkp : std_logic_vector (63 downto 0) := (others => '0');

begin
  clk <= not clk after clk_period/2;

  DUT: entity work.gost_top
  port map(
    clk           => clk,
    reset_n       => reset_n,
    encryption    => encryption,
    key_valid     => key_valid,
    key_word_in   => key_word_in,
    data_valid    => data_valid,
    data_word_in  => data_word_in,
    data_word_out => data_word_out,
    data_ready    => data_ready
  );

  STIM: process
  begin
    reset_n      <= '0';
    wait for 4*clk_period;
    encryption   <= '1';  -- Set to Encryption 
    reset_n      <= '1';
    wait for clk_period;
    key_valid    <= '1';
    key_word_in  <= x"DEADBEEF";
    wait for clk_period;
    key_word_in  <= x"01234567";
    wait for clk_period;
    key_word_in  <= x"89ABCDEF";
    wait for clk_period;
    key_word_in  <= x"DEADBEEF";
    wait for clk_period;
    key_word_in  <= x"DEADBEEF";
    wait for clk_period;
    key_word_in  <= x"01234567";
    wait for clk_period;
    key_word_in  <= x"89ABCDEF";
    wait for clk_period;
    key_word_in  <= x"DEADBEEF";
    wait for clk_period;
    key_valid    <= '0';
    key_word_in  <= x"00000000";
    data_valid   <= '1';
    data_word_in <= x"A5A5A5A5";
    wait for clk_period;
    data_word_in <= x"01234567";
    wait for clk_period;
    data_valid   <= '0';
    data_word_in <= x"00000000";
    wait until data_ready = '1';
    wait for clk_period;
    data_bkp(63 downto 32) <= data_word_out;
    wait for clk_period;
    data_bkp(31 downto 0)  <= data_word_out;
    -----------------------------------------------------------------
    wait for 4*clk_period;
    reset_n      <= '0';
    wait for clk_period;
    encryption   <= '0';  -- Set to Decryption 
    reset_n      <= '1';
    wait for clk_period;
    key_valid    <= '1';
    key_word_in  <= x"DEADBEEF";
    wait for clk_period;
    key_word_in  <= x"01234567";
    wait for clk_period;
    key_word_in  <= x"89ABCDEF";
    wait for clk_period;
    key_word_in  <= x"DEADBEEF";
    wait for clk_period;
    key_word_in  <= x"DEADBEEF";
    wait for clk_period;
    key_word_in  <= x"01234567";
    wait for clk_period;
    key_word_in  <= x"89ABCDEF";
    wait for clk_period;
    key_word_in  <= x"DEADBEEF";
    wait for clk_period;
    key_valid    <= '0';
    key_word_in  <= x"00000000";
    data_valid   <= '1';
    data_word_in <= data_bkp(63 downto 32);
    wait for clk_period;
    data_word_in <= data_bkp(31 downto 0);
    wait for clk_period;
    data_valid   <= '0';
    data_word_in <= x"00000000";
    wait until data_ready = '1';
    wait for clk_period;
    data_bkp(63 downto 32) <= data_word_out;
    wait for clk_period;
    data_bkp(31 downto 0)  <= data_word_out;
    wait;
  end process;

end architecture;