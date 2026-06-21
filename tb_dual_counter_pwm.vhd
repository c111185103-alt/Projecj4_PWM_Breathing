library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_dual_counter_pwm is
-- 測試平台不需要 Port
end tb_dual_counter_pwm;

architecture Behavioral of tb_dual_counter_pwm is

    -- 【步驟 1】宣告待測的頂層元件 (Component)
    component breathing_pwm_top is
        port (
            clk_4096Hz   : in  std_logic;
            rst          : in  std_logic;
            led_out      : out std_logic;
            cnt_duty_out : out std_logic_vector(4 downto 0)
        );
    end component;

    -- 【步驟 2】宣告與待測元件對接的測試訊號
    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal led_out      : std_logic;
    signal cnt_duty_out : std_logic_vector(4 downto 0);

    -- 時脈週期計算：1 / 4096 Hz ? 244.14 us
    constant clk_period : time := 244.14 us;

begin

    -- 【步驟 3】實例化待測電路 (UUT - Unit Under Test)
    uut: breathing_pwm_top
        port map (
            clk_4096Hz   => clk,
            rst          => rst,
            led_out      => led_out,
            cnt_duty_out => cnt_duty_out
        );

    -- 【步驟 4】產生 4096 Hz 的標準時脈波形
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- 【步驟 5】測試激勵行程 (Stimulus Process)
    stim_proc: process
    begin		
        -- 1. 保持重置狀態 1 ms，確保所有暫存器都清空
        rst <= '1';
        wait for 1 ms;	
        
        -- 2. 解除重置，讓雙計數器狀態機開始交替運作
        rst <= '0';
        
        -- 3. 讓模擬持續執行。
        -- 因為完整呼吸週期大約需要 3.75 秒，建議你在 Vivado 模擬執行時間設定為 4s 以上
        wait;
    end process;

end Behavioral;