--------------------------------------
-- Author: Nicolas Silva Moura
-- Created: 10/17/2021
-- Implementation of NOEKEON block cipher with 128 bits  block lenth and 128 key lenth
-- Codebases as refereences: https://github.com/rochavinicius/cryptography-algorithms/blob/main/algorithms/NOEKEON/
--------------------------------------

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
entity noekeon_top is
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
architecture noekeon_top of noekeon_top is
	--FSM
	signal st 			: integer range 0 to 12; --std_logic_vector (3 downto 0);
	signal st_cnt 		: std_logic_vector(7 downto 0);
	signal st_stage 	: std_logic_vector(6 downto 0); --integer range 0 to 5;
	signal st_data 		: std_logic; -- 0 high, 1 low
	signal st_rounds	: integer range 0 to 76;

	--Temporary signals
	type PDATA is array (0 to 3) of std_logic_vector(31 downto 0);
	signal data_word 	: PDATA;
	signal first_join	: std_logic;
	signal end_encrypt	: std_logic;

	--ENC Loop signals
	signal data_lp, data_rp : std_logic_vector (31 downto 0);
	signal ss1, ss2, sout1, sout2 : std_logic_vector (31 downto 0);
	signal counter : integer range 0 to 16; --Counting to control loop reading

	--DEC Loop signals
	signal counterd : integer range 1 to 17;

	--RAM signals	
	signal p_data_o   : std_logic_vector(31 downto 0)	:= (others => '0');
	signal max_keys   : std_logic_vector(2 downto 0)	:= (others => '0');
	signal key_cnt    : std_logic_vector(2 downto 0)	:= (others => '0');
	signal key_addr   : std_logic_vector(2 downto 0)	:= (others => '0');
	signal key_data_o : std_logic_vector(31 downto 0)	:= (others => '0');
  
	signal rc_addr		: std_logic_vector(6 downto 0)	:= (others => '0');
	signal rc_addr_out	: std_logic_vector(6 downto 0):= (others => '0');
	signal rc_data_o	: std_logic_vector(63 downto 0)	:= (others => '0');
  
	--Simon variables
	signal encrypt_block_0 		: std_logic_vector(31 downto 0);
	signal encrypt_block_1 		: std_logic_vector(31 downto 0);
	signal encrypt_block_2 		: std_logic_vector(31 downto 0);
	signal encrypt_block_3 		: std_logic_vector(31 downto 0);
	signal key_temp_0 		: std_logic_vector(31 downto 0);
	signal key_temp_1  		: std_logic_vector(31 downto 0);
	signal key_temp_2  		: std_logic_vector(31 downto 0);
	signal key_temp_3  		: std_logic_vector(31 downto 0);
	signal temporary_block 		: std_logic_vector(31 downto 0);
  
	constant 	c	: std_logic_vector(63 downto 0) := x"fffffffffffffffc";
	constant 	one	: std_logic_vector(63 downto 0) := x"0000000000000001";
	signal 		z	: std_logic_vector(63 downto 0) := x"7369f885192c0ef5";
	signal		y,l,k,x	: std_logic_vector(63 downto 0) := (others => '0');
	
	-- NOEKEON variables 
	signal nr_rounds : integer range 0 to 15;
	
	-- temporary variables
	signal end_block, end_round, first_entry : std_logic;
	
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
	
	BRAM_RC: entity work.bram_rc
	port map(
		clk     => clk,
		we      => '0',
		addr    => rc_addr,
		data_i  => (others => '0'),
		data_o  => rc_data_o
	);


	------------------------------------
	-- Assignments
	------------------------------------
	key_addr <= key_cnt when (st = 2) else st_cnt(2 downto 0);
  
	sub_key_addr <= sub_key_addr_in when (st = 2) else sub_key_addr_out;

	--Set max round of keys
	max_keys <= "111" when key_length = "10" else --256bit
				"101" when key_length = "01" else --192bit
				"011"; --default 128bit key

	data_ready    <= '1' when (st = 6) else '0';
	data_word_out <= data_word(conv_integer(st_cnt(1 downto 0))) when (st = 6) else (others => '0');

	------------------------------------
	-- Processes
	------------------------------------
  
	-- FSM: Finite State Machine
	FSM: process (clk, reset_n)
	begin
		if reset_n = '0' then
			st       <= 0;
			st_data  <= '0';
			st_cnt   <= (others => '0');
			st_stage <= (others => '0');
			first_join <= '1';
		elsif rising_edge(clk) then
			case st is
			-- Load key data input
				when 0 =>
					if key_valid = '1' then
						if st_cnt = max_keys then
							st     <= st + 1;
							st_cnt <= (others => '0');
						else
							st_cnt <= st_cnt + 1;
						end if;
			end if;

        -- Load ciphertext input
        when 1 =>
          if data_valid = '1' then
            if st_cnt = 3 then
              st     <= st + 1;
              st_cnt <= (others => '0');
            else
              st_cnt <= st_cnt + 1;
            end if;
          end if;
			
				-- Encrypt rounds 
				when 2 =>
          if st_rounds = 16 then
            st     <= st + 1;
            st_rounds <= 0;
          else
						if end_block = '1' then
							st_rounds <= 1;
						end if;
          end if;	

        -- Start to process the encryption/decryption
        when 3 =>
          if end_encrypt = '1' then
            st     <= st + 1;
            st_rounds <= 0;
          else
            st_rounds <= 1;
          end if;

        -- 4: conversion_complete
        when 4 =>
          st       <= st + 1;

        -- 5: verify if 64-bits or 128-bits 
        when 5 =>
          st_data  <= not st_data;
          st_stage <= (others => '0');
          if st_data = '0' then
            st     <= 3;
          else
            st     <= st + 1;
          end if;

        when 6 =>
          if st_cnt = 3 then
            st     <= 0;
            st_cnt <= (others => '0');
            st_stage <= (others => '0');
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

			if data_valid = '1' then
				data_word(conv_integer(st_cnt(1 downto 0))) <= data_word_in;
			end if;
	
			if st = 4 then
				data_word(0) <= encrypt_block_0;
				data_word(1) <= encrypt_block_1;
				data_word(2) <= encrypt_block_2;
				data_word(3) <= encrypt_block_3;
				
			end if;
		end if;
	end process;
	
	-- Encrypt rounds
	EncryptionBlock: process (clk, reset_n)
	begin
		if reset_n = '0' then
			end_block = '0';
		elsif rising_edge(clk) then
			
			if st = 2 then
				case nr_rounds is
					when 0 =>
						rc_addr_passed <= (others => '0');
						if end_round = '1' then
							nr_rounds <= nr_rounds + 1;
						end if;
						
					when 1 to 16 =>
						rc_addr_passed <= std_logic_vector(unsigned(rc_addr_passed) + 1);
						if end_round = '1' then
							if nr_rounds = 16 then
								end_block = '1';
							else
								nr_rounds <= nr_rounds + 1;
							end if;
						end if;
					
					when others => null;
				end case;
		end if;
	end process;

	--Process the SIMON encryption rounds
	EncryptionRound: process (clk, reset_n)
	begin
		if reset_n = '0' then
			encrypt_block_0 <= (others => '0');
			encrypt_block_1 <= (others => '0');
			encrypt_block_2 <= (others => '0');
			encrypt_block_3 <= (others => '0');
			first_entry = '1';
		elsif rising_edge(clk) then
			if st = 2 then
				if encryption = '1' then
					case st_rounds is
						when 0 =>
							rc_addr 	<= rc_addr_passed;
							key_addr 	<= (others => '0');
							end_round = '0';
							if first_entry then
								encrypt_block_0 <= data_word(0);
								encrypt_block_1 <= data_word(1);
								encrypt_block_2 <= data_word(2);
								encrypt_block_3 <= data_word(3);
								first_entry = '0';
							end if;
							
						when 1 =>
							rc_addr 				<= std_logic_vector(unsigned(rc_addr) + 1);
							key_addr 				<= std_logic_vector(unsigned(key_addr) + 1);
							encrypt_block_0 <= encrypt_block_0 xor rc_data_o;
							key_temp_0 			<= key_data_o;
							
						when 2 =>
							key_addr 				<= std_logic_vector(unsigned(key_addr) + 1);
							key_temp_1 			<= key_data_o;
							temporary_block <= encrypt_block_0 xor encrypt_block_2;
							
							
						when 3 =>
							key_addr 				<= std_logic_vector(unsigned(key_addr) + 1);
							key_temp_2 			<= key_data_o;
							temporary_block <= temporary_block xor 
																	temporary_block(7 downto 0) & temporary_block(31 downto 8) xor
																	temporary_block(23 downto 0) & temporary_block(31 downto 24);
						when 4 =>
							key_temp_3 			<= key_data_o;
							encrypt_block_1 <= encrypt_block_1 xor temporary_block;
							encrypt_block_3 <= encrypt_block_3 xor temporary_block;
							
						when 5 =>
							encrypt_block_0 <= encrypt_block_0 xor key_temp_0;
							encrypt_block_1 <= encrypt_block_1 xor key_temp_1;
							encrypt_block_2 <= encrypt_block_2 xor key_temp_2;
							encrypt_block_3 <= encrypt_block_3 xor key_temp_3;
							
						when 6 =>
							temporary_block <= encrypt_block_1 xor encrypt_block_3;
							
						when 7 =>
							temporary_block <= temporary_block xor 
																	temporary_block(7 downto 0) & temporary_block(31 downto 8) xor
																	temporary_block(23 downto 0) & temporary_block(31 downto 24);
						when 8 =>
							encrypt_block_0 <= encrypt_block_0 xor temporary_block;
							encrypt_block_2 <= encrypt_block_2 xor temporary_block;
						
						when 9 =>
							encrypt_block_0 <= encrypt_block_0 xor x"00000000";
							
						when 10 => 
							encrypt_block_1 <= encrypt_block_1(30 downto 0) & encrypt_block_1(31 downto 31);
							encrypt_block_2 <= encrypt_block_2(26 downto 0) & encrypt_block_2(31 downto 27);
							encrypt_block_3 <= encrypt_block_3(29 downto 0) & encrypt_block_3(31 downto 30);
							
						when 11 =>
							encrypt_block_1 <= encrypt_block_1 xor (not encrypt_block_3) and (not encrypt_block_2);
							
						when 12 =>
							encrypt_block_0 <= encrypt_block_0 xor encrypt_block_2 and encrypt_block_1;
														
						when 13 =>
							encrypt_block_0	<= encrypt_block_3;
							encrypt_block_3	<= encrypt_block_0;
							
						when 14 =>
							encrypt_block_2 <= encrypt_block_2 xor encrypt_block_0 xor encrypt_block_1 xor encrypt_block_3;
							
						when 15 =>
							encrypt_block_1 <= encrypt_block_1 xor (not encrypt_block_3) and (not encrypt_block_2);
							
						when 16 =>
							encrypt_block_0 <= encrypt_block_0 xor encrypt_block_2 and encrypt_block_1;
							
						when 17 =>
							encrypt_block_1 <= encrypt_block_1(0 downto 0) & encrypt_block_1(31 downto 1);
							encrypt_block_2 <= encrypt_block_2(5 downto 0) & encrypt_block_2(31 downto 6);
							encrypt_block_3 <= encrypt_block_3(1 downto 0) & encrypt_block_3(31 downto 2);
							end_round = '1';
							
						when others => null;		
					end case;
				else 
					case st_rounds is
						when 0 =>
													
						when others => null;						
							
					end case;
				end if;
			end if;
		end if;
	end process;

end architecture;
