library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- breathing_pwm_top 直接吃 100MHz、內部自己除頻，用 DIV_N 這個
-- generic 把除頻倍率調小(從硬體的12207降到2)，不然照真實倍率模擬，
-- 跑完一次完整呼吸週期(~3.75秒)換算成100MHz底下的clk次數會多出
-- 快24000倍，模擬會跑非常久。
entity tb_dual_counter_pwm is
end tb_dual_counter_pwm;

architecture Behavioral of tb_dual_counter_pwm is

    component breathing_pwm_top is
        generic (
            DIV_N : integer := 12207
        );
        port (
            clk          : in  std_logic;
            led_out      : out std_logic
        );
    end component;

    constant DIV_N_TB : integer := 2;   -- 模擬用縮小的除頻倍率

    signal clk          : std_logic := '0';
    signal led_out      : std_logic;

    -- 100MHz，跟這整個系列的專案一致
    constant clk_period : time := 10 ns;

begin

    uut: breathing_pwm_top
        generic map (
            DIV_N => DIV_N_TB
        )
        port map (
            clk          => clk,
            led_out      => led_out
        );

    -- ===== 產生真正的 100MHz 時脈 =====
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period / 2;
        clk <= '1';
        wait for clk_period / 2;
    end process;

    -- ===== 觀察用：沒有 rst，開機組態載入本身就會給所有暫存器
    -- 正確的初始值，直接觀察 duty_reg 有沒有開始一路遞增/遞減 =====
    stim_proc: process
    begin
       
        wait for 700 us;
        report "breathing cycle observation window complete" severity note;
        wait;
    end process;

end Behavioral;