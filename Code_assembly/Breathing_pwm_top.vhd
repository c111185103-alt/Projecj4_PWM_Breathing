library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Project4 呼吸燈。直接吃板上原生的 100MHz，內部自己除頻出約 4096Hz，給 FSM／計數器邏輯用。
--
-- 100MHz 沒辦法整除出剛好 4096Hz (100,000,000/4096=24414.0625，不是
-- 整數)，取最接近的整數 N=12207，每數滿 N 個 clk 就翻轉一次
-- clk_4096Hz_i，翻轉兩次=一個完整週期，實際頻率約
-- 100,000,000/(2*12207)=4096.02Hz，跟真正的 4096Hz 只差約 0.001%。
entity breathing_pwm_top is
    generic (
        DIV_N : integer := 12207    -- 100MHz/(2*DIV_N)，硬體用12207(~4096Hz)，模擬用2。
    );
    port (
        clk          : in  std_logic;    -- Y9, 100MHz
        led_out      : out std_logic                
    );
end entity;

architecture Behavioral of breathing_pwm_top is

    component configurable_counter is
        port (
            clk   : in  std_logic;
            rst   : in  std_logic;
            en    : in  std_logic;
            limit : in  integer range 0 to 31;
            done  : out std_logic
            
        );
    end component;

    type state_type is (ST_HIGH, ST_LOW);
    signal current_state, next_state : state_type;

    signal duty_reg     : integer range 0 to 31 := 0;
    signal my_direction : std_logic := '1';
    signal cnt_8_cycles : integer range 0 to 7 := 0;

    signal en_high, done_high : std_logic;
    signal en_low,  done_low  : std_logic;
    signal limit_high, limit_low : integer range 0 to 31;

    -- rst 內部固定接 '0'。
    signal rst : std_logic := '0';

    -- ===== 100MHz -> 約4096Hz 除頻 =====
    -- DIV_N 是 generic (見上方 entity 宣告)。
    signal div_cnt      : integer range 0 to DIV_N - 1 := 0;
    signal clk_4096Hz_i : std_logic := '0';

begin

    -- ===== 100MHz -> ~4096Hz 除頻 =====
    process(clk)
    begin
        if rising_edge(clk) then
            if div_cnt = DIV_N - 1 then
                div_cnt      <= 0;
                clk_4096Hz_i <= not clk_4096Hz_i;
            else
                div_cnt <= div_cnt + 1;
            end if;
        end if;
    end process;

    -- 動態分配上限
    limit_high <= duty_reg;
    limit_low  <= 31 - duty_reg;

    u_counter_HIGH : configurable_counter
        port map (
            clk   => clk_4096Hz_i,
            rst   => rst,
            en    => en_high,
            limit => limit_high,
            done  => done_high
        );

    u_counter_LOW : configurable_counter
        port map (
            clk   => clk_4096Hz_i,
            rst   => rst,
            en    => en_low,
            limit => limit_low,
            done  => done_low
        );

    -- FSM 時序同步製程
    process(clk_4096Hz_i, rst)
    begin
        if rst = '1' then
            current_state <= ST_HIGH;
        elsif rising_edge(clk_4096Hz_i) then
            current_state <= next_state;
        end if;
        
    end process;

    process(current_state, done_high, done_low, limit_high, limit_low)
    begin
        next_state <= current_state;
        en_high    <= '0';
        en_low     <= '0';

        case current_state is
            when ST_HIGH =>
                en_high <= '1';
                if done_high = '1' then
                    if limit_low = 0 then
                        next_state <= ST_HIGH;
                    else
                        next_state <= ST_LOW;
                    end if;
                end if;

            when ST_LOW =>
                en_low  <= '1';
                if done_low = '1' then
                    if limit_high = 0 then
                        next_state <= ST_LOW;
                    else
                        next_state <= ST_HIGH;
                    end if;
                end if;
        end case;
    end process;

    --led_out 依據狀態決定，高狀態輸出1，低狀態輸出0！
    led_out <= '1' when (current_state = ST_HIGH) else '0';


    -- 亮度調變步進控制
    process(clk_4096Hz_i, rst)
    begin
        if rst = '1' then
            duty_reg     <= 0;
            my_direction <= '1';
            cnt_8_cycles <= 0;
        elsif rising_edge(clk_4096Hz_i) then
            
            if (current_state = ST_LOW and done_low = '1') or 
               (current_state = ST_HIGH and done_high = '1' and limit_low = 0) then
                
                if cnt_8_cycles = 7 then
                    cnt_8_cycles <= 0;
                    
                    if my_direction = '1' then
                        if duty_reg = 31 then
                            my_direction <= '0';
                            duty_reg     <= 30;
                        else
                            duty_reg     <= duty_reg + 1;
                        end if;
                    else
                        if duty_reg = 0 then
                            my_direction <= '1';
                            duty_reg     <= 1;
                        else
                            duty_reg     <= duty_reg - 1;
                        end if;
                    end if;
                else
                    cnt_8_cycles <= cnt_8_cycles + 1;
                end if;
            end if;
        end if;
    end process;

    

end architecture;