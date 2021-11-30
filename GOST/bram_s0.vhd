-- FILE NAME : bram_s0.vhd
-- STATUS    : Implementation of BRAM block used at GOST block cipher
-- AUTHORS   : Nicolas Silva Moura
-- E-mail    : nicolas.moura@edu.pucrs.br
--------------------------------------------------------------------------------
-- RELEASE HISTORY
-- VERSION   DATE         DESCRIPTION
-- 1.0       2021-10-10   Initial version of the BRAM.
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
entity bram_s0 is
  port (
    clk    : in  std_logic;
    we     : in  std_logic;
    addr   : in  std_logic_vector(6 downto 0);
    data_i : in  std_logic_vector(3 downto 0);
    data_o : out std_logic_vector(3 downto 0)
  );
end entity;

--------------------------------------
-- Architecture
--------------------------------------
architecture bram_s0 of bram_s0 is
  type ram_type is array (0 to 127) of std_logic_vector(3 downto 0);
  signal RAM : ram_type := (
   x"4",x"A",x"9",x"2",x"D",x"8",x"0",x"E",x"6",x"B",x"1",x"C",x"7",x"F",x"5",x"3",
   x"E",x"B",x"4",x"C",x"6",x"D",x"F",x"A",x"2",x"3",x"8",x"1",x"0",x"7",x"5",x"9",
   x"5",x"8",x"1",x"D",x"A",x"3",x"4",x"2",x"E",x"F",x"C",x"7",x"6",x"0",x"9",x"B",
   x"7",x"D",x"A",x"1",x"0",x"8",x"9",x"F",x"E",x"4",x"6",x"C",x"B",x"2",x"5",x"3",
   x"6",x"C",x"7",x"1",x"5",x"F",x"D",x"8",x"4",x"A",x"9",x"E",x"0",x"3",x"B",x"2",
   x"4",x"B",x"A",x"0",x"7",x"2",x"1",x"D",x"3",x"6",x"8",x"5",x"9",x"C",x"F",x"E",
   x"D",x"B",x"4",x"1",x"3",x"F",x"5",x"9",x"0",x"A",x"E",x"7",x"6",x"8",x"2",x"C",
   x"1",x"F",x"D",x"0",x"5",x"7",x"A",x"4",x"9",x"2",x"3",x"E",x"6",x"B",x"8",x"C");

begin

  process (clk)
  begin
    if falling_edge(clk) then
      if (we = '1') then
        RAM(conv_integer(addr)) <= data_i;
      end if;
    end if;
  end process;

  data_o <= RAM(conv_integer(addr));

end architecture;