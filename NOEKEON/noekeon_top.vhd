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
	signal st_rounds	: integer range 0 to 76;
	signal nr_rounds : integer range 0 to 16;

	--Temporary signals
	type PDATA is array (0 to 3) of std_logic_vector(31 downto 0);
	signal data_word 	: PDATA;

	--RAM signals	
	signal max_keys   	: std_logic_vector(2 downto 0)	:= (others => '0');
	signal key_addr   	: std_logic_vector(2 downto 0)	:= (others => '0');
	signal key_data_o 	: std_logic_vector(31 downto 0)	:= (others => '0');
  signal key_addr_out	: std_logic_vector(2 downto 0)	:= (others => '0');
	signal rc_addr			: std_logic_vector(4 downto 0)	:= (others => '0');
	signal rc_data_o		: std_logic_vector(7 downto 0)	:= (others => '0');
  
	--Simon variables
	signal crypt_block_0 		: std_logic_vector(31 downto 0):= (others => '0');
	signal crypt_block_1 		: std_logic_vector(31 downto 0):= (others => '0');
	signal crypt_block_2 		: std_logic_vector(31 downto 0):= (others => '0');
	signal crypt_block_3 		: std_logic_vector(31 downto 0):= (others => '0');
	signal key_temp_0 				: std_logic_vector(31 downto 0):= (others => '0');
	signal key_temp_1  				: std_logic_vector(31 downto 0):= (others => '0');
	signal key_temp_2  				: std_logic_vector(31 downto 0):= (others => '0');
	signal key_temp_3  				: std_logic_vector(31 downto 0):= (others => '0');
	signal temporary_block 		: std_logic_vector(31 downto 0):= (others => '0');
  
	
	
	-- temporary variables
	signal first_entry : std_logic;
	signal rc_addr_passed : std_logic_vector(4 downto 0);	
	
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
	key_addr <= key_addr_out when (st = 2) else st_cnt(2 downto 0);

	--Set max round of keys
	max_keys <= "111" when key_length = "10" else --256bit
				"101" when key_length = "01" else --192bit
				"011"; --default 128bit key

	data_ready    <= '1' when (st = 4) else '0';
	data_word_out <= data_word(conv_integer(st_cnt(1 downto 0))) when (st = 4) else (others => '0');

	------------------------------------
	-- Processes
	------------------------------------
  
	-- FSM: Finite State Machine
	FSM: process (clk, reset_n)
	begin
		if reset_n = '0' then
			st       <= 0;
			st_cnt   <= (others => '0');
			nr_rounds <= 0;
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
			
				-- Start to process the encryption/decryption 
				when 2 =>
					if encryption = '1' then
						case nr_rounds is
							when 0 =>
								rc_addr_passed <= (others => '0');
								if st_rounds = 17 then
									nr_rounds <= nr_rounds + 1;
									st_rounds <= 0;
									rc_addr_passed <= std_logic_vector(unsigned(rc_addr_passed) + 1);
								else
									st_rounds <= st_rounds + 1;
								end if;
						
							when 1 to 15 =>
								if nr_rounds = 15 then
									if st_rounds = 26 then
										st <= st + 1;
										nr_rounds <= 0;
										st_rounds <= 0;
									else 
										st_rounds <= st_rounds + 1;
									end if;
								else
									if st_rounds = 17 then
										nr_rounds <= nr_rounds + 1;
										st_rounds <= 0;
										rc_addr_passed <= std_logic_vector(unsigned(rc_addr_passed) + 1);
									else
										st_rounds <= st_rounds + 1;
									end if;
								end if;
								
							when others => null;
						end case;
					else
						case nr_rounds is
							when 0 =>
								rc_addr_passed <= "10000";
								if st_rounds = 27 then
									nr_rounds <= nr_rounds + 1;
									st_rounds <= 11;
									rc_addr_passed <= std_logic_vector(unsigned(rc_addr_passed) - 1);
								else
									st_rounds <= st_rounds + 1;
								end if;
						
							when 1 to 15 =>
								if nr_rounds = 15 then
									if st_rounds = 35 then
										st <= st + 1;
										nr_rounds <= 0;
										st_rounds <= 0;
									else 
										st_rounds <= st_rounds + 1;
									end if;
								else
									if st_rounds = 27 then
										nr_rounds <= nr_rounds + 1;
										st_rounds <= 11;
										rc_addr_passed <= std_logic_vector(unsigned(rc_addr_passed) - 1);
									else
										st_rounds <= st_rounds + 1;
									end if;
								end if;
								
							when others => null;
						end case;	
					end if;					
					
        -- 3: conversion_complete
        when 3 =>
          st       <= st + 1;

			-- 4: Data Ready
        when 4 =>
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

			if data_valid = '1' then
				data_word(conv_integer(st_cnt(1 downto 0))) <= data_word_in;
			end if;
	
			if st = 3 then
				data_word(0) <= crypt_block_0;
				data_word(1) <= crypt_block_1;
				data_word(2) <= crypt_block_2;
				data_word(3) <= crypt_block_3;
				
			end if;
		end if;
	end process;

	--Process the SIMON encryption
	EncryptionRound: process (clk, reset_n)
	begin
		if reset_n = '0' then
			crypt_block_0 <= (others => '0');
			crypt_block_1 <= (others => '0');
			crypt_block_2 <= (others => '0');
			crypt_block_3 <= (others => '0');
			temporary_block <= (others => '0');
			key_temp_0 <= (others => '0');
			key_temp_1 <= (others => '0');
			key_temp_2 <= (others => '0');
			key_temp_3 <= (others => '0');
			first_entry <= '1';
		elsif rising_edge(clk) then
			if st = 2 then
				if encryption = '1' then
					case st_rounds is
						when 0 =>
							rc_addr 	<= rc_addr_passed;
							key_addr_out 	<= (others => '0');
							if first_entry = '1' then
								crypt_block_0 <= data_word(0);
								crypt_block_1 <= data_word(1);
								crypt_block_2 <= data_word(2);
								crypt_block_3 <= data_word(3);
								first_entry <= '0';
							end if;
							
						when 1 =>
							key_addr_out 		<= std_logic_vector(unsigned(key_addr_out) + 1);
							crypt_block_0 	<= crypt_block_0 xor (x"000000" & rc_data_o);
							key_temp_0 			<= key_data_o;
							
						when 2 =>
							-- start theta function here
							key_addr_out 				<= std_logic_vector(unsigned(key_addr_out) + 1);
							key_temp_1 			<= key_data_o;
							temporary_block <= crypt_block_0 xor crypt_block_2;
							
							
						when 3 =>
							key_addr_out 				<= std_logic_vector(unsigned(key_addr_out) + 1);
							key_temp_2 			<= key_data_o;
							temporary_block <= temporary_block xor 
																	temporary_block(7 downto 0) & temporary_block(31 downto 8) xor
																	temporary_block(23 downto 0) & temporary_block(31 downto 24);
						when 4 =>
							key_temp_3 			<= key_data_o;
							crypt_block_1 <= crypt_block_1 xor temporary_block;
							crypt_block_3 <= crypt_block_3 xor temporary_block;
							
						when 5 =>
							crypt_block_0 <= crypt_block_0 xor key_temp_0;
							crypt_block_1 <= crypt_block_1 xor key_temp_1;
							crypt_block_2 <= crypt_block_2 xor key_temp_2;
							crypt_block_3 <= crypt_block_3 xor key_temp_3;
							
						when 6 =>
							temporary_block <= crypt_block_1 xor crypt_block_3;
							
						when 7 =>
							temporary_block <= temporary_block xor 
																	temporary_block(7 downto 0) & temporary_block(31 downto 8) xor
																	temporary_block(23 downto 0) & temporary_block(31 downto 24);
						when 8 =>
						-- end theta function
							crypt_block_0 <= crypt_block_0 xor temporary_block;
							crypt_block_2 <= crypt_block_2 xor temporary_block;
						
						when 9 =>
							crypt_block_0 <= crypt_block_0 xor x"00000000";
							
						when 10 => 
							-- pi1
							crypt_block_1 <= crypt_block_1(30 downto 0) & crypt_block_1(31 downto 31);
							crypt_block_2 <= crypt_block_2(26 downto 0) & crypt_block_2(31 downto 27);
							crypt_block_3 <= crypt_block_3(29 downto 0) & crypt_block_3(31 downto 30);
							
						when 11 =>
							crypt_block_1 <= crypt_block_1 xor ((not crypt_block_3) and (not crypt_block_2));
							
						when 12 =>
							crypt_block_0 <= crypt_block_0 xor (crypt_block_2 and crypt_block_1);
														
						when 13 =>
							crypt_block_0	<= crypt_block_3;
							crypt_block_3	<= crypt_block_0;
							
						when 14 =>
							crypt_block_2 <= crypt_block_2 xor crypt_block_0 xor crypt_block_1 xor crypt_block_3;
							
						when 15 =>
							crypt_block_1 <= crypt_block_1 xor ((not crypt_block_3) and (not crypt_block_2));
							
						when 16 =>
							crypt_block_0 <= crypt_block_0 xor (crypt_block_2 and crypt_block_1);
							
							
						when 17 =>
							-- pi2
							crypt_block_1 <= crypt_block_1(0 downto 0) & crypt_block_1(31 downto 1);
							crypt_block_2 <= crypt_block_2(4 downto 0) & crypt_block_2(31 downto 5);
							crypt_block_3 <= crypt_block_3(1 downto 0) & crypt_block_3(31 downto 2);
							
						when 18 =>
							rc_addr 	<= rc_addr + 1;
							
						when 19 =>
							crypt_block_0 <= crypt_block_0 xor (x"000000" & rc_data_o);
							
						when 20 =>
							-- this step bellow need be triggered only on the round 16
							temporary_block <= crypt_block_0 xor crypt_block_2;
						
						when 21 =>
							temporary_block <=  temporary_block xor 
																	temporary_block(7 downto 0) & temporary_block(31 downto 8) xor
																	temporary_block(23 downto 0) & temporary_block(31 downto 24);
																	
						when 22 =>
							crypt_block_1 <= crypt_block_1 xor temporary_block;
							crypt_block_3 <= crypt_block_3 xor temporary_block;
							
						when 23 =>
							crypt_block_0 <= crypt_block_0 xor key_temp_0;
							crypt_block_1 <= crypt_block_1 xor key_temp_1;
							crypt_block_2 <= crypt_block_2 xor key_temp_2;
							crypt_block_3 <= crypt_block_3 xor key_temp_3;
						
						when 24 =>
							temporary_block <= crypt_block_1 xor crypt_block_3;
							
						when 25 =>
							temporary_block <= temporary_block xor 
																	temporary_block(7 downto 0) & temporary_block(31 downto 8) xor
																	temporary_block(23 downto 0) & temporary_block(31 downto 24);
						
						when 26 =>
							crypt_block_0 <= crypt_block_0 xor temporary_block;
							crypt_block_2 <= crypt_block_2 xor temporary_block;
							
						when others => null;		
					end case;
				else 
					case st_rounds is
						when 0 =>
							key_addr_out	<= (others => '0');
							crypt_block_0 <= data_word(0);
							crypt_block_1 <= data_word(1);
							crypt_block_2 <= data_word(2);
							crypt_block_3 <= data_word(3);
						
						when 1 =>
							key_addr_out 				<= std_logic_vector(unsigned(key_addr_out) + 1);
							key_temp_0 			<= key_data_o;
							
						when 2 =>
							key_addr_out 				<= std_logic_vector(unsigned(key_addr_out) + 1);
							key_temp_1 			<= key_data_o;
						
						when 3 =>
							key_addr_out 				<= std_logic_vector(unsigned(key_addr_out) + 1);
							key_temp_2 			<= key_data_o;
						
						when 4 =>
							key_temp_3 			<= key_data_o;
							temporary_block	<= key_temp_0	xor key_temp_2;
							
						when 5 =>
							temporary_block <= temporary_block xor 
																	(temporary_block(7 downto 0) & temporary_block(31 downto 8)) xor
																	(temporary_block(23 downto 0) & temporary_block(31 downto 24));
							
						when 6 =>
							key_temp_1	<= key_temp_1 xor temporary_block;
							key_temp_3	<= key_temp_3 xor temporary_block;
							
						when 7 =>
							key_temp_0	<= key_temp_0 xor x"00000000";
							key_temp_1 	<= key_temp_1 xor x"00000000";
							key_temp_2 	<= key_temp_2 xor x"00000000";
							key_temp_3 	<= key_temp_3 xor x"00000000";
							
						when 8 =>
							temporary_block <= key_temp_1 xor key_temp_3;
						
						when 9 => 
							temporary_block <= temporary_block xor 
																	temporary_block(7 downto 0) & temporary_block(31 downto 8) xor
																	temporary_block(23 downto 0) & temporary_block(31 downto 24);
									
						when 10 =>
							key_temp_0 <= key_temp_0 xor temporary_block;
							key_temp_2 <= key_temp_2 xor temporary_block;
							
						when 11 =>
							-- start decryption
							rc_addr 	<= rc_addr_passed;
							crypt_block_0 <= crypt_block_0 xor x"00000000";
						
						when 12 =>
							--start theta 
							temporary_block <= crypt_block_0 xor crypt_block_2;
							
						when 13 =>
							temporary_block <= temporary_block xor 
																	temporary_block(7 downto 0) & temporary_block(31 downto 8) xor
																	temporary_block(23 downto 0) & temporary_block(31 downto 24);
																	
						when 14 => 
							crypt_block_1 <= crypt_block_1 xor temporary_block;
							crypt_block_3 <= crypt_block_3 xor temporary_block;
							
						when 15 =>
							crypt_block_0 <= crypt_block_0 xor key_temp_0;
							crypt_block_1 <= crypt_block_1 xor key_temp_1;
							crypt_block_2 <= crypt_block_2 xor key_temp_2;
							crypt_block_3 <= crypt_block_3 xor key_temp_3;
							
						when 16 =>
							temporary_block <=  crypt_block_1 xor crypt_block_3;
							
						when 17 =>
							temporary_block <= temporary_block xor 
																	temporary_block(7 downto 0) & temporary_block(31 downto 8) xor
																	temporary_block(23 downto 0) & temporary_block(31 downto 24);
																	
						when 18 =>
							--end theta
							crypt_block_0 <= crypt_block_0 xor temporary_block;
							crypt_block_2 <= crypt_block_2 xor temporary_block;
							
						when 19 =>
							crypt_block_0 	<= crypt_block_0 xor (x"000000" & rc_data_o);
							
						when 20 =>
							-- pi1
							crypt_block_1 <= crypt_block_1(30 downto 0) & crypt_block_1(31 downto 31);
							crypt_block_2 <= crypt_block_2(26 downto 0) & crypt_block_2(31 downto 27);
							crypt_block_3 <= crypt_block_3(29 downto 0) & crypt_block_3(31 downto 30);
							
						when 21 =>
							-- gamma
							crypt_block_1 <= crypt_block_1 xor ((not crypt_block_3) and (not crypt_block_2));
							
						when 22 =>
							crypt_block_0 <= crypt_block_0 xor (crypt_block_2 and crypt_block_1);
														
						when 23 =>
							crypt_block_0	<= crypt_block_3;
							crypt_block_3	<= crypt_block_0;
							
						when 24 =>
							crypt_block_2 <= crypt_block_2 xor crypt_block_0 xor crypt_block_1 xor crypt_block_3;
							
						when 25 =>
							crypt_block_1 <= crypt_block_1 xor ((not crypt_block_3) and (not crypt_block_2));
							
						when 26 =>
							-- end gamma
							crypt_block_0 <= crypt_block_0 xor (crypt_block_2 and crypt_block_1);
							
						when 27 =>
							-- end round
							crypt_block_1 <= crypt_block_1(0 downto 0) & crypt_block_1(31 downto 1);
							crypt_block_2 <= crypt_block_2(4 downto 0) & crypt_block_2(31 downto 5);
							crypt_block_3 <= crypt_block_3(1 downto 0) & crypt_block_3(31 downto 2);
							
						when 28 =>
							temporary_block <= crypt_block_0 xor crypt_block_2;
							
						when 29 =>
							temporary_block <= temporary_block xor 
																	temporary_block(7 downto 0) & temporary_block(31 downto 8) xor
																	temporary_block(23 downto 0) & temporary_block(31 downto 24);
						
						when 30 =>
							crypt_block_1 <= crypt_block_1 xor temporary_block;
							crypt_block_3 <= crypt_block_3 xor temporary_block;
							
						when 31 =>
							crypt_block_0 <= crypt_block_0 xor key_temp_0;
							crypt_block_1 <= crypt_block_1 xor key_temp_1;
							crypt_block_2 <= crypt_block_2 xor key_temp_2;
							crypt_block_3 <= crypt_block_3 xor key_temp_3;
							
						when 32 =>
							temporary_block <= crypt_block_1 xor crypt_block_3;
							
						when 33 =>
							temporary_block <= temporary_block xor 
																	temporary_block(7 downto 0) & temporary_block(31 downto 8) xor
																	temporary_block(23 downto 0) & temporary_block(31 downto 24);
																	
						when 34 =>
							crypt_block_0 <= crypt_block_0 xor temporary_block;
							crypt_block_2 <= crypt_block_2 xor temporary_block;
							rc_addr 		<= std_logic_vector(unsigned(rc_addr) - 1);
							
						when 35 =>
							crypt_block_0	<= crypt_block_0 xor (x"000000" & rc_data_o);
							
						when others => null;							
					end case;
				end if;
			end if;
		end if;
	end process;

end architecture;
