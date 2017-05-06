library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all; 
use ieee.numeric_std.all;


entity rom is
   port (sel : in std_logic;
         address : in std_logic_vector(9 downto 2);
         data    : inout std_logic_vector(31 downto 0));
end rom;

architecture program1 of rom is               
    signal data_out : std_logic_vector(31 downto 0);          

begin
   
   data <= data_out when sel='1'
      else "ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ";

    process(address)
    begin
         CASE address(9 downto 2) IS
            WHEN "00000000" => data_out <= x"80000004";
            WHEN "00000001" => data_out <= x"81000002";
            WHEN "00000010" => data_out <= x"52100000";
            WHEN "00000100" => data_out <= x"00000000";
            WHEN OTHERS => data_out <= x"00000000";
           end case;
    end process;
end program1;