-- FILE NAME : noekeon_top.vhd
-- STATUS    : Implementation of NOEKEON block cipher with 128 bits block length
--             and 128 key length
-- AUTHORS   : Nicolas Silva Moura; Rafael Garibotti
-- E-mail    : nicolas.moura@edu.pucrs.br; rafael.garibotti@pucrs.br
--------------------------------------------------------------------------------
-- RELEASE HISTORY
-- VERSION   DATE         DESCRIPTION
-- 1.0       2021-10-17   Initial version of the top.
-- 1.1       2021-11-13   Module reorganization aiming at area reduction and
--                        energy efficiency.
--------------------------------------------------------------------------------

--------------------------------------
-- Library
--------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

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
    -- Flag to enable key input
    key_valid     : in  std_logic;
    -- Key input, one 32-bit word at a time
    key_word_in   : in  std_logic_vector(31 downto 0);
    -- Flag to enable data input
    data_valid    : in  std_logic;
    -- Data input, one 32-bit word at a time
    data_word_in  : in  std_logic_vector(31 downto 0);
    -- Ciphertext output, one 32-bit word at a time
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
  signal st              : integer range 0 to 3;
  signal st_cnt          : std_logic_vector(1 downto 0);
  signal st_rounds       : integer range 0 to 29;
  signal nr_rounds       : integer range 0 to 15;

  --Temporary signals
  type PDATA is array (0 to 3) of std_logic_vector(31 downto 0);
  signal data_word       : PDATA;
  signal key_word        : PDATA;

  --RAM signals
  signal rc_addr         : std_logic_vector(4 downto 0);
  signal rc_data_o       : std_logic_vector(7 downto 0);

  --Simon variables
  signal temporary_block : std_logic_vector(31 downto 0);

  -- temporary variables
  signal rc_addr_passed  : std_logic_vector(4 downto 0);    

begin
  ------------------------------------
  -- BRAMs
  ------------------------------------    
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
  data_ready    <= '1' when (st = 3) else '0';
  data_word_out <= data_word(conv_integer(st_cnt)) when (st = 3) else (others => '0');

  ------------------------------------
  -- Processes
  ------------------------------------
  -- FSM: Finite State Machine
  FSM: process (clk, reset_n)
  begin
    if reset_n = '0' then
      st        <= 0;
      st_cnt    <= (others => '0');
      nr_rounds <= 0;
      rc_addr_passed <= (others => '0');
    elsif rising_edge(clk) then
      case st is
        -- Load key data input
        when 0 =>
          if key_valid = '1' then
            st_cnt <= st_cnt + 1;
            if st_cnt = 3 then --default 128bit key
              st   <= st + 1;
            end if;
          end if;

        -- Load ciphertext input
        when 1 =>
          if data_valid = '1' then
            st_cnt <= st_cnt + 1;
            if st_cnt = 3 then
              st   <= st + 1;
            end if;
          end if;

        -- Start to process the encryption/decryption 
        when 2 =>
          if encryption = '1' then
            case nr_rounds is
              when 0 =>
                rc_addr_passed <= (others => '0');
                if st_rounds = 16 then
                  st_rounds <= 0;
                  nr_rounds <= nr_rounds + 1;
                  rc_addr_passed <= rc_addr_passed + 1;
                else
                  st_rounds <= st_rounds + 1;
                end if;

              when 1 to 14 =>
                if st_rounds = 16 then
                  st_rounds <= 0;
                  nr_rounds <= nr_rounds + 1;
                  rc_addr_passed <= rc_addr_passed + 1;
                else
                  st_rounds <= st_rounds + 1;
                end if;

              when 15 =>
                if st_rounds = 25 then
                  st <= st + 1;
                  st_rounds <= 0;
                  nr_rounds <= 0;
                else 
                  st_rounds <= st_rounds + 1;
                end if;

              when others => null;
            end case;
          else
            case nr_rounds is
              when 0 =>
                rc_addr_passed <= "10000";
                if st_rounds = 21 then
                  st_rounds <= 6;
                  nr_rounds <= nr_rounds + 1;
                  rc_addr_passed <= rc_addr_passed - 1;
                else
                  st_rounds <= st_rounds + 1;
                end if;

              when 1 to 14 =>
                if st_rounds = 21 then
                  st_rounds <= 6;
                  nr_rounds <= nr_rounds + 1;
                  rc_addr_passed <= rc_addr_passed - 1;
                else
                  st_rounds <= st_rounds + 1;
                end if;

              when 15 =>
                if st_rounds = 29 then
                  st <= st + 1;
                  st_rounds <= 0;
                  nr_rounds <= 0;
                else 
                  st_rounds <= st_rounds + 1;
                end if;

              when others => null;
            end case;    
          end if;                    

        -- 3: Data Ready
        when 3 =>
          st_cnt <= st_cnt + 1;
          if st_cnt = 3 then
            st     <= 0;
          end if;

        when others => null;
      end case;
    end if;
  end process;

  --Process the SIMON encryption
  EncryptionRound: process (clk, reset_n)
  begin
    if reset_n = '0' then
      temporary_block <= (others => '0');
      rc_addr   <= (others => '0');
      key_word  <= (others => (others => '0'));
      data_word <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if st = 0 then
        -- IO data flow
        if key_valid = '1' then
          key_word(conv_integer(st_cnt)) <= key_word_in;
        end if;
      elsif st = 1 then
        -- IO data flow
        if data_valid = '1' then
          data_word(conv_integer(st_cnt)) <= data_word_in;
        end if;
      elsif st = 2 then
        if encryption = '1' then
          case st_rounds is
            when 0 =>
              rc_addr <= rc_addr_passed;

            when 1 =>
              data_word(0)   <= data_word(0) xor (x"000000" & rc_data_o);

            when 2 =>
              -- start theta function here
              temporary_block <= data_word(0) xor data_word(2);

            when 3 =>
              temporary_block <= temporary_block xor temporary_block(7 downto 0) &
                                 temporary_block(31 downto 8) xor temporary_block(23 downto 0) &
                                 temporary_block(31 downto 24);

            when 4 =>
              data_word(1) <= data_word(1) xor temporary_block;
              data_word(3) <= data_word(3) xor temporary_block;

            when 5 =>
              data_word(0) <= data_word(0) xor key_word(0);
              data_word(1) <= data_word(1) xor key_word(1);
              data_word(2) <= data_word(2) xor key_word(2);
              data_word(3) <= data_word(3) xor key_word(3);

            when 6 =>
              temporary_block <= data_word(1) xor data_word(3);

            when 7 =>
              temporary_block <= temporary_block xor temporary_block(7 downto 0) &
                                 temporary_block(31 downto 8) xor temporary_block(23 downto 0) &
                                 temporary_block(31 downto 24);

            when 8 =>
              -- end theta function
              data_word(0) <= data_word(0) xor temporary_block;
              data_word(2) <= data_word(2) xor temporary_block;

            when 9 =>
              -- pi1
              data_word(1) <= data_word(1)(30 downto 0) & data_word(1)(31 downto 31);
              data_word(2) <= data_word(2)(26 downto 0) & data_word(2)(31 downto 27);
              data_word(3) <= data_word(3)(29 downto 0) & data_word(3)(31 downto 30);

            when 10 =>
              data_word(1) <= data_word(1) xor ((not data_word(3)) and (not data_word(2)));

            when 11 =>
              data_word(0) <= data_word(0) xor (data_word(2) and data_word(1));

            when 12 =>
              data_word(0) <= data_word(3);
              data_word(3) <= data_word(0);

            when 13 =>
              data_word(2) <= data_word(2) xor data_word(0) xor data_word(1) xor data_word(3);

            when 14 =>
              data_word(1) <= data_word(1) xor ((not data_word(3)) and (not data_word(2)));

            when 15 =>
              data_word(0) <= data_word(0) xor (data_word(2) and data_word(1));

            when 16 =>
              -- pi2
              data_word(1) <= data_word(1)(0 downto 0) & data_word(1)(31 downto 1);
              data_word(2) <= data_word(2)(4 downto 0) & data_word(2)(31 downto 5);
              data_word(3) <= data_word(3)(1 downto 0) & data_word(3)(31 downto 2);

            when 17 =>
              rc_addr <= rc_addr + 1;

            when 18 =>
              data_word(0) <= data_word(0) xor (x"000000" & rc_data_o);

            when 19 =>
              -- this step bellow need be triggered only on the round 16
              temporary_block <= data_word(0) xor data_word(2);

            when 20 =>
              temporary_block <= temporary_block xor temporary_block(7 downto 0) &
                                 temporary_block(31 downto 8) xor temporary_block(23 downto 0) &
                                 temporary_block(31 downto 24);

            when 21 =>
              data_word(1) <= data_word(1) xor temporary_block;
              data_word(3) <= data_word(3) xor temporary_block;

            when 22 =>
              data_word(0) <= data_word(0) xor key_word(0);
              data_word(1) <= data_word(1) xor key_word(1);
              data_word(2) <= data_word(2) xor key_word(2);
              data_word(3) <= data_word(3) xor key_word(3);

            when 23 =>
              temporary_block <= data_word(1) xor data_word(3);

            when 24 =>
              temporary_block <= temporary_block xor temporary_block(7 downto 0) &
                                 temporary_block(31 downto 8) xor temporary_block(23 downto 0) &
                                 temporary_block(31 downto 24);

            when 25 =>
              data_word(0) <= data_word(0) xor temporary_block;
              data_word(2) <= data_word(2) xor temporary_block;

            when others => null;        
          end case;
        else
          case st_rounds is                        
            when 0 =>
              temporary_block <= key_word(0) xor key_word(2);

            when 1 =>
              temporary_block <= temporary_block xor (temporary_block(7 downto 0) &
                                 temporary_block(31 downto 8)) xor (temporary_block(23 downto 0) &
                                 temporary_block(31 downto 24));

            when 2 =>
              key_word(1) <= key_word(1) xor temporary_block;
              key_word(3) <= key_word(3) xor temporary_block;

            when 3 =>
              temporary_block <= key_word(1) xor key_word(3);

            when 4 => 
              temporary_block <= temporary_block xor temporary_block(7 downto 0) &
                                 temporary_block(31 downto 8) xor temporary_block(23 downto 0) &
                                 temporary_block(31 downto 24);

            when 5 =>
              key_word(0) <= key_word(0) xor temporary_block;
              key_word(2) <= key_word(2) xor temporary_block;

            when 6 =>
              -- start decryption
              rc_addr     <= rc_addr_passed;
              --start theta 
              temporary_block <= data_word(0) xor data_word(2);

            when 7 =>
              temporary_block <= temporary_block xor temporary_block(7 downto 0) &
                                 temporary_block(31 downto 8) xor temporary_block(23 downto 0) &
                                 temporary_block(31 downto 24);

            when 8 => 
              data_word(1) <= data_word(1) xor temporary_block;
              data_word(3) <= data_word(3) xor temporary_block;

            when 9 =>
              data_word(0) <= data_word(0) xor key_word(0);
              data_word(1) <= data_word(1) xor key_word(1);
              data_word(2) <= data_word(2) xor key_word(2);
              data_word(3) <= data_word(3) xor key_word(3);

            when 10 =>
              temporary_block <= data_word(1) xor data_word(3);

            when 11 =>
              temporary_block <= temporary_block xor temporary_block(7 downto 0) &
                                 temporary_block(31 downto 8) xor temporary_block(23 downto 0) &
                                 temporary_block(31 downto 24);

            when 12 =>
              --end theta
              data_word(0) <= data_word(0) xor temporary_block;
              data_word(2) <= data_word(2) xor temporary_block;

            when 13 =>
              data_word(0) <= data_word(0) xor (x"000000" & rc_data_o);

            when 14 =>
              -- pi1
              data_word(1) <= data_word(1)(30 downto 0) & data_word(1)(31 downto 31);
              data_word(2) <= data_word(2)(26 downto 0) & data_word(2)(31 downto 27);
              data_word(3) <= data_word(3)(29 downto 0) & data_word(3)(31 downto 30);

            when 15 =>
              -- gamma
              data_word(1) <= data_word(1) xor ((not data_word(3)) and (not data_word(2)));

            when 16 =>
              data_word(0) <= data_word(0) xor (data_word(2) and data_word(1));

            when 17 =>
              data_word(0) <= data_word(3);
              data_word(3) <= data_word(0);

            when 18 =>
              data_word(2) <= data_word(2) xor data_word(0) xor data_word(1) xor data_word(3);

            when 19 =>
              data_word(1) <= data_word(1) xor ((not data_word(3)) and (not data_word(2)));

            when 20 =>
              -- end gamma
              data_word(0) <= data_word(0) xor (data_word(2) and data_word(1));

            when 21 =>
              -- end round
              data_word(1) <= data_word(1)(0 downto 0) & data_word(1)(31 downto 1);
              data_word(2) <= data_word(2)(4 downto 0) & data_word(2)(31 downto 5);
              data_word(3) <= data_word(3)(1 downto 0) & data_word(3)(31 downto 2);

            when 22 =>
              temporary_block <= data_word(0) xor data_word(2);

            when 23 =>
              temporary_block <= temporary_block xor temporary_block(7 downto 0) &
                                 temporary_block(31 downto 8) xor temporary_block(23 downto 0) &
                                 temporary_block(31 downto 24);

            when 24 =>
              data_word(1) <= data_word(1) xor temporary_block;
              data_word(3) <= data_word(3) xor temporary_block;

            when 25 =>
              data_word(0) <= data_word(0) xor key_word(0);
              data_word(1) <= data_word(1) xor key_word(1);
              data_word(2) <= data_word(2) xor key_word(2);
              data_word(3) <= data_word(3) xor key_word(3);

            when 26 =>
              temporary_block <= data_word(1) xor data_word(3);

            when 27 =>
              temporary_block <= temporary_block xor temporary_block(7 downto 0) &
                                 temporary_block(31 downto 8) xor temporary_block(23 downto 0) &
                                 temporary_block(31 downto 24);

            when 28 =>
              data_word(0) <= data_word(0) xor temporary_block;
              data_word(2) <= data_word(2) xor temporary_block;
              rc_addr      <= rc_addr - 1;

            when 29 =>
              data_word(0) <= data_word(0) xor (x"000000" & rc_data_o);

            when others => null;                            
          end case;
        end if;
      end if;
    end if;
  end process;

end architecture;