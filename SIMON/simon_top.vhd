--------------------------------------
-- Library
--------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

--------------------------------------
-- Entity
--------------------------------------
entity simon_top is
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
architecture simon_top of simon_top is
	--FSM
	signal st 			: integer range 0 to 12; --std_logic_vector (3 downto 0);
	signal st_cnt 		: std_logic_vector(7 downto 0);
	signal st_stage 	: std_logic_vector(6 downto 0); --integer range 0 to 5;
	signal st_data 		: std_logic; -- 0 high, 1 low
	signal st_rounds	: integer range 0 to 72;

	--Temporary signals
	type PDATA is array (0 to 3) of std_logic_vector(31 downto 0);
	signal data_word : PDATA;

	--ENC Loop signals
	signal data_lp, data_rp : std_logic_vector (31 downto 0);
	signal ss1, ss2, sout1, sout2 : std_logic_vector (31 downto 0);
	signal counter : integer range 0 to 16; --Counting to control loop reading

	--DEC Loop signals
	signal counterd : integer range 1 to 17;
	signal s_sout1, s_sout2 : std_logic_vector(31 downto 0);

	--RAM signals	
	type PKEYS is array (0 to 17) of std_logic_vector(31 downto 0); 
	signal p_data_ram : PKEYS;
	signal p_data_o   : std_logic_vector(31 downto 0);
	signal max_keys   : std_logic_vector(2 downto 0);
	signal key_cnt    : std_logic_vector(2 downto 0);
	signal key_addr   : std_logic_vector(2 downto 0);	
	signal key_data_o : std_logic_vector(31 downto 0);
  
	signal sub_key_valid		: std_logic;
	signal sub_key_addr		: std_logic_vector(6 downto 0);
	signal sub_key_addr_in	: std_logic_vector(6 downto 0);
	signal sub_key_addr_out	: std_logic_vector(6 downto 0);	
	signal sub_key_word_in	: std_logic_vector(63 downto 0);
	signal sub_key_data_o		: std_logic_vector(63 downto 0);
  
	--Simon variables
	signal sub_key_first,sub_key_second,sub_key_third, sub_key_fourth : std_logic_vector(63 downto 0);
  
	constant 	c	: std_logic_vector(63 downto 0) := x"fffffffffffffffc";
	constant 	one	: std_logic_vector(63 downto 0) := x"0000000000000001";
	signal 		z	: std_logic_vector(63 downto 0) := x"7369f885192c0ef5";
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
	
	BRAM_SUB_KEY: entity work.bram_sub_key
	port map(
		clk     => clk,
		we      => sub_key_valid,
		addr    => sub_key_addr,
		data_i  => sub_key_word_in,
		data_o  => sub_key_data_o
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

	data_ready    <= '1' when (st = 12) else '0';
	data_word_out <= data_word(conv_integer(st_cnt(1 downto 0))) when (st = 12) else (others => '0');

	------------------------------------
	-- Processes
	------------------------------------
  
    -- SIMON GENERATE SUB KEYS
	SIMON_SUB_KEYS: process (clk, reset_n) 
	begin
    if reset_n = '0' then
		sub_key_first 	<= (others => '0');
		sub_key_second	<= (others => '0');
		z				<= x"7369f885192c0ef5";
    elsif rising_edge(clk) then
		if st = 2 then
			case st_rounds is
				when 0 =>
					key_cnt <= "000";
					
				when 1 =>
					key_cnt <= "001"
					sub_key_first(63 downto 32) <= key_data_o;
					
				when 2 =>
					key_cnt 		<= "010"
					sub_key_first(31 downto 0) <= key_data_o;
					
				when 3 =>
					key_cnt <= "011";
					sub_key_addr_in <= "0000001";
					sub_key_word_in <= sub_key_first;
					sub_key_valid 	<= '1';
					sub_key_second(63 downto 32) <= key_data_o;
					
				when 4 =>
					sub_key_second(31 downto 0) <= key_data_o;
					
				when 5 =>
					sub_key_addr_in <= "0000000";
					sub_key_word_in <= sub_key_second;
					sub_key_valid 	<= '1';
					
				when 6 =>
					sub_key_valid 	<= '1';
					sub_key_addr_in <= "0000010";
					z 				<= "0" & z(31 downto 1);					
					sub_key_word_in <= c xor (x"000000000000000"& "00" & z(1 downto 0))
										xor sub_key_first 
										xor (sub_key_second(2 downto 0) & sub_key_second(63 downto 3) 
										xor (sub_key_second(3 downto 0) & sub_key_second(63 downto 4);
					
				when 7 to 70 =>
					sub_key_first 	<= sub_key_second;
					sub_key_valid 	<= '1';
					z 				<= "0" & z(31 downto 1);
					sub_key_addr_in <= std_logic_vector(unsigned(sub_key_addr_in) + 1);
					sub_key_word_in <= c xor (x"000000000000000"& "00" & z(1 downto 0)) 
										xor sub_key_first 
										xor (sub_key_second(2 downto 0) & sub_key_second(63 downto 3) 
										xor (sub_key_second(3 downto 0) & sub_key_second(63 downto 4);
					sub_key_second 	<= c xor (x"000000000000000"& "00" & z(1 downto 0)) 
										xor sub_key_first 
										xor (sub_key_second(2 downto 0) & sub_key_second(63 downto 3) 
										xor (sub_key_second(3 downto 0) & sub_key_second(63 downto 4);					
					
				when 71 =>
					sub_key_addr_in <= std_logic_vector(unsigned(sub_key_addr_in) + 1);
					sub_key_first 	<= sub_key_second;
					sub_key_valid 	<= '1';
					sub_key_word_in <= c xor one 
										xor sub_key_first 
										xor (sub_key_second(2 downto 0) & sub_key_second(63 downto 3) 
										xor (sub_key_second(3 downto 0) & sub_key_second(63 downto 4);
					sub_key_second 	<= c xor one 
										xor sub_key_first 
										xor (sub_key_second(2 downto 0) & sub_key_second(63 downto 3) 
										xor (sub_key_second(3 downto 0) & sub_key_second(63 downto 4);
					
				when 72 =>
					sub_key_first 	<= sub_key_second;
					sub_key_addr_in <= "0000000";
					sub_key_valid 	<= '1';
					sub_key_word_in <= c xor sub_key_first 
										xor (sub_key_second(2 downto 0) & sub_key_second(63 downto 3) 
										xor (sub_key_second(3 downto 0) & sub_key_second(63 downto 4);
					sub_key_second 	<= c xor sub_key_first 
										xor (sub_key_second(2 downto 0) & sub_key_second(63 downto 3) 
										xor (sub_key_second(3 downto 0) & sub_key_second(63 downto 4);
				
			end case;		
		end if;
    end if;
	end process;
  
  
  -- FSM: Finite State Machine
  FSM: process (clk, reset_n)
  begin
    if reset_n = '0' then
      st       <= 0;
      st_data  <= '0';
      st_cnt   <= (others => '0');
      st_stage <= (others => '0');
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
		  
		-- Generate subkeys
		when 2 =>
			if st_rounds = 68 then
              st     <= st + 1;
              st_rounds <= (others => '0');
            else
              st_rounds <= st_cnt + 1;
            end if;

        -- Start to process the encryption/decryption
        when 3 =>
          if st_cnt = 10 then
            st     <= st + 1;
            st_cnt <= (others => '0');
          else
            st_cnt <= st_cnt + 1;
          end if;

        when 4 =>
          if st_stage = 3 then
             st     <= st + 1;
             st_stage <= (others => '0');
          else
            st_stage <= st_stage + 1;
          end if;

        -- 5: conversion_complete
        when 5 =>
          st       <= st + 1;

        -- 5: verify if 64-bits or 128-bits 
        when 6 =>
          st_data  <= not st_data;
          st_stage <= (others => '0');
          if st_data = '0' then
            st     <= 2;
          else
            st     <= st + 1;
          end if;

        when 7 =>
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

      --if st = 1 then
      if data_valid = '1' then
        data_word(conv_integer(st_cnt(1 downto 0))) <= data_word_in;
      end if;
      --end if;

      if st = 5 then
        if st_data = '0' then
          if encryption = '1' then
            data_word(0) <= sout1;
            data_word(1) <= sout2;
          else
            data_word(0) <= s_sout2;
            data_word(1) <= s_sout1;
          end if;
        else
          if encryption = '1' then
            data_word(2) <= sout1;
            data_word(3) <= sout2;
          else
            data_word(2) <= s_sout2;
            data_word(3) <= s_sout1;
          end if;
        end if;
      end if;

    end if;
  end process;

	--Process the blowfish encryption rounds
	EncryptionRound: process (clk, reset_n)
	begin
		if reset_n = '0' then
			k <= (others => '0');
			l <= (others => '0');
			x <= (others => '0');
			y <= (others => '0');
			sub_key_first	<= (others => '0');
			sub_key_second	<= (others => '0');
		elsif rising_edge(clk) then
			if st = 3 then
				case st_rounds is
				
				when 0 =>
					x <= data_word(0);
					y <= data_word(1);
					sub_key_addr_out 	<=	"0000000";
					
				when 1 =>
					sub_key_addr_out 	<= std_logic_vector(unsigned(sub_key_addr_out) + 1);
					sub_key_first		<= sub_key_data_o;
					
				when 2 =>
					sub_key_addr_out 	<= std_logic_vector(unsigned(sub_key_addr_out) + 1);
					sub_key_first		<= sub_key_data_o;
					sub_key_second		<= sub_key_first;
					
				when 3 to 76 =>
					sub_key_addr_out 	<= std_logic_vector(unsigned(sub_key_addr_out) + 1);
					sub_key_first		<= sub_key_data_o;
					sub_key_second		<= sub_key_first;
					y <= (y xor ((x(62 downto 0) & x(63 downto 63) and x(55 downto 0) & x(63 downto 56))
							xor x(61 downto 0) & x(63 downto 61)))
							xor k;
					x <= ;
				
				end case;
			end if;
		end if;
	end process;

end architecture;
