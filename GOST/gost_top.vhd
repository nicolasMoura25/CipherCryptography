--------------------------------------
-- Library
--------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.Numeric_std.all;

--------------------------------------
-- Entity
--------------------------------------
entity gost_top is
	port (
		-- Clock and active low reset
		clk           : in  std_logic;
		reset_n       : in  std_logic;
		-- Switch to enable encryption or decryption, 1 for encryption 0 for decryption
		encryption    : in  std_logic;
		-- Length of input key, 0, 1 or 2 for 128, 192 or 256 respectively
		key_length    : in  std_logic_vector(1 downto 0);
		-- Flag to enable key input
		key_valid     : in  std_logic;
		-- Key input, one 32-bit word at a time
		key_word_in   : in  std_logic_vector(31 downto 0);
		-- Flag to enable ciphertext input
		data_valid    : in  std_logic;
		-- Data input, one 32-bit word at a time
		data_word_in  : in  std_logic_vector(31 downto 0);
		-- Ciphertext output, one 64-bit word
		data_word_out : out std_logic_vector(31 downto 0);
		-- Flag to indicate the beginning of ciphertext output
		data_ready    : out std_logic
	);
end entity;

--------------------------------------
-- Architecture
--------------------------------------
architecture gost_top of gost_top is
	--FSM
	signal st 			: integer range 0 to 5; --std_logic_vector (3 downto 0);
	signal st_cnt 		: std_logic_vector(6 downto 0);
	signal st_round 	: integer range 0 to 12;
	signal st_encrypt 	: integer range 0 to 31; 

	--Temporary signals
	type PDATA is array (0 to 3) of std_logic_vector(31 downto 0);
	signal data_word 	: PDATA;

	--Result variables 
	signal N1,N2,R,CM1 	: std_logic_vector (31 downto 0);

	--RAM signals
	signal max_keys   	: std_logic_vector(2 downto 0);
	signal key_cnt    	: std_logic_vector(2 downto 0);
	signal key_addr   	: std_logic_vector(2 downto 0);
	signal key_data_o 	: std_logic_vector(31 downto 0);
	signal s0_addr    	: std_logic_vector(6 downto 0);
	signal s0_data_o  	: std_logic_vector(3 downto 0);
  
begin
	------------------------------------
	-- BRAMs
	------------------------------------
	BRAM_KEY: entity work.bram_key
	port map(
		clk     => clk,
		we      => key_valid,
		addr    => key_addr,
		data_i  => key_word_in,
		data_o  => key_data_o
	);

	BRAM_0: entity work.bram_s0
	port map(
		clk     => clk,
		we      => '0',
		addr    => s0_addr,
		data_i  => (others => '0'),
		data_o  => s0_data_o
	);

	------------------------------------
	-- Assignments
	------------------------------------
	key_addr <= st_cnt(2 downto 0) when st = 0 else key_cnt;

	--Set max round of keys
	max_keys <= "111" when key_length = "10" else --256bit
              "101" when key_length = "01" else --192bit
              "011"; --default 128bit key

	data_ready    <= '1' when (st = 5) else '0';
	data_word_out <= data_word(conv_integer(st_cnt(1 downto 0))) when (st = 5) else (others => '0');

	------------------------------------
	-- Processes
	------------------------------------
  
	-- FSM: Finite State Machine
	FSM: process (clk, reset_n)
	begin
		if reset_n = '0' then
			st       <= 0;
			st_cnt   <= (others => '0');
			key_cnt  <= (others => '0');
			st_encrypt <= 0;
		elsif rising_edge(clk) then
			case st is
			-- Load key data input
			when 0 =>
				if key_valid = '1' then
					if st_cnt = max_keys then
						st	<= st + 1;
						st_cnt <= (others => '0');
					else
						st_cnt <= st_cnt + 1;
					end if;
				end if;

			-- Load ciphertext input
			when 1 =>
				if data_valid = '1' then
					if st_cnt = 1 then
						st	<= st + 1;
						st_cnt <= (others => '0');
					else
						st_cnt <= st_cnt + 1;
					end if;
				end if;
		  
			when 2 =>
				st       <= st + 1;

			-- Start to process the encryption/decryption
			when 3 =>
				if st_encrypt = 31 and st_round = 12 then
					st_round <= 0;
					st_encrypt <= 0;
					st	<= st + 1;
				else
					if st_round < 12 then
						st_round <= st_round +1;
					else
						st_round <= 0;
						st_encrypt <= st_encrypt +1;
					end if;
				end if;
			
				if encryption = '1' and st_round = 0 then
					if st_encrypt = 0 or st_encrypt = 8 or st_encrypt = 16 then
						key_cnt <= "000";
					elsif st_encrypt = 24 then
						key_cnt <= "111";
					elsif st_encrypt < 24 then
						key_cnt <= std_logic_vector(unsigned(key_cnt) + 1);
					else
						key_cnt <= std_logic_vector(unsigned(key_cnt) - 1);
					end if;
				elsif encryption = '0' and st_round = 0 then
					if st_encrypt = 0  then
						key_cnt <= "000";
					elsif st_encrypt = 8 or st_encrypt = 16 or st_encrypt = 24 then
						key_cnt <= "111";
					elsif st_encrypt < 8 then
						key_cnt <= std_logic_vector(unsigned(key_cnt) + 1);
					else
						key_cnt <= std_logic_vector(unsigned(key_cnt) - 1);
					end if;
				else
					key_cnt <= key_cnt;
				end if;

			-- 10: conversion_complete
			when 4 =>
				st       <= st + 1;

			when 5 =>
				if st_cnt = 3 then
					st     <= 0;
					st_cnt <= (others => '0');
				else
					st_cnt <= st_cnt + 1;
				end if;

			when others => null;
			end case;
		end if;
	end process;

	-- IO data flow
	IO_DATA_FLOW: process (clk, reset_n)
	begin
		if reset_n = '0' then
			data_word <= (others => (others => '0'));
		elsif rising_edge(clk) then

			--if st = 1 then
			if data_valid = '1' then
				data_word(conv_integer(st_cnt(1 downto 0))) <= data_word_in;
			end if;
			--end if;

			if st = 4 then				
				data_word(0) <= N1;
				data_word(1) <= N2;
			end if;
		end if;
	end process;

	--Process the GOST encryption rounds
	EncryptionRound: process (clk, reset_n)
	begin
		if reset_n = '0' then
			R 		<= (others => '0');
			s0_addr	<= (others => '0');
			CM1		<= (others => '0');
			N1 		<= (others => '0');
			N2 		<= (others => '0');
		elsif rising_edge(clk) then
			if st = 2 then 
				N1 <= data_word(1);
				N2 <= data_word(0);
			elsif st = 3 then		
				case st_round is
					when 0 => -- need wait 1 round to N1 and Key_data_o be populated 
					when 1 =>
						CM1 <=  std_logic_vector((unsigned(N1) + unsigned(key_data_o))); 
					when 2 =>
						s0_addr <= "000" & CM1(31 downto 28);
					when 3 => 
						R(31 downto 28) <= s0_data_o;
						s0_addr <= "001" & CM1(27 downto 24);  -- sum 16 to increment line
					when 4 => 
						R(27 downto 24) <= s0_data_o;
						s0_addr <= "010" & CM1(23 downto 20);
					when 5 => 
						R(23 downto 20) <= s0_data_o;
						s0_addr <= "011" & CM1(19 downto 16);
					when 6 => 
						R(19 downto 16) <= s0_data_o;
						s0_addr <= "100" & CM1(15 downto 12);
					when 7 => 
						R(15 downto 12) <= s0_data_o;
						s0_addr <= "101" & CM1(11 downto 8);
					when 8 => 
						R(11 downto 8) 	<= s0_data_o;
						s0_addr <= "110" & CM1(7 downto 4);
					when 9 => 
						R(7 downto 4) 	<= s0_data_o;
						s0_addr <= "111" & CM1(3 downto 0);
					when 10 => 
						R(3 downto 0) 	<= s0_data_o;
					when 11 =>
						-- ciclical shift right 21
						R <= R(20 downto 0) & R(31 downto 21);
					when 12 =>
						N2 <= N1;
						N1 <= R xor N2;
				end case;
			end if;		
		end if;
	end process;
end architecture;
