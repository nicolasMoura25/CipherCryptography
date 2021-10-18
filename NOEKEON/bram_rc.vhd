--------------------------------------
-- Library
--------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

--------------------------------------
-- Entity
--------------------------------------
entity bram_sub_keys is
  port (
    clk     : in  std_logic;
    we      : in  std_logic;
    addr    : in  std_logic_vector(4 downto 0);
    data_i  : in  std_logic_vector(7 downto 0);
    data_o  : out std_logic_vector(7 downto 0)
  );
end entity;

--------------------------------------
-- Architecture
--------------------------------------
architecture bram_sub_keys of bram_sub_keys is
  type ram_type is array (0 to 16) of std_logic_vector(7 downto 0);
  signal RAM : ram_type := (
   x"80",x"1b",x"36",x"6c",
	 x"d8",x"ab",x"4d",x"9a",
	 x"2f",x"5e",x"bc",x"63",
	 x"c6",x"97",x"35",x"6a",
	 x"d4"
);

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
