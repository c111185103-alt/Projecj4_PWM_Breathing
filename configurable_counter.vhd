library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity configurable_counter is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        en    : in  std_logic;
        limit : in  integer range 0 to 31; -- ¤W­­§ï¬° 31
        done  : out std_logic
    );
end entity;

architecture Behavioral of configurable_counter is
    signal count : integer range 0 to 31 := 0;
begin
    process(clk, rst)
    begin
        if rst = '1' then
            count <= 0;
        elsif rising_edge(clk) then
            if en = '1' then
                if limit = 0 or count >= limit - 1 then
                    count <= 0;
                else
                    count <= count + 1;
                end if;
            else
                count <= 0;
            end if;
        end if;
    end process;

    done <= '1' when (en = '1' and (limit = 0 or count = limit - 1)) else '0';
end architecture;