library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity breathing_pwm_top is
    port (
        clk_4096Hz   : in  std_logic;
        rst          : in  std_logic;
        led_out      : out std_logic;
        cnt_duty_out : out std_logic_vector(4 downto 0)
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

begin

    -- 動態分配上限
    limit_high <= duty_reg;
    limit_low  <= 31 - duty_reg;

    u_counter_HIGH : configurable_counter
        port map (
            clk   => clk_4096Hz,
            rst   => rst,
            en    => en_high,
            limit => limit_high,
            done  => done_high
        );

    u_counter_LOW : configurable_counter
        port map (
            clk   => clk_4096Hz,
            rst   => rst,
            en    => en_low,
            limit => limit_low,
            done  => done_low
        );

    -- FSM 時序同步製程
    process(clk_4096Hz, rst)
    begin
        if rst = '1' then
            current_state <= ST_HIGH;
        elsif rising_edge(clk_4096Hz) then
            current_state <= next_state;
        end if;
    end process;

    -- ?【你提議的 Look-Ahead 核心修改點】FSM 狀態轉移預判
    process(current_state, done_high, done_low, limit_high, limit_low)
    begin
        next_state <= current_state;
        en_high    <= '0';
        en_low     <= '0';

        case current_state is
            when ST_HIGH =>
                en_high <= '1';
                if done_high = '1' then
                    -- ? Look-Ahead 預判：如果對手（低電位時間）上限是 0，代表不需要去低電位，直接留守 ST_HIGH！
                    if limit_low = 0 then
                        next_state <= ST_HIGH;
                    else
                        next_state <= ST_LOW;
                    end if;
                end if;

            when ST_LOW =>
                en_low  <= '1';
                if done_low = '1' then
                    -- ? Look-Ahead 預判：如果對手（高電位時間）上限是 0，代表不需要去高電位，直接留守 ST_LOW！
                    if limit_high = 0 then
                        next_state <= ST_LOW;
                    else
                        next_state <= ST_HIGH;
                    end if;
                end if;
        end case;
    end process;

    -- ?【回歸純淨】led_out 100% 依據狀態決定，完全符合教授要求：高狀態輸出1，低狀態輸出0！
    led_out <= '1' when (current_state = ST_HIGH) else '0';


    -- 亮度調變步進控制
    process(clk_4096Hz, rst)
    begin
        if rst = '1' then
            duty_reg     <= 0;
            my_direction <= '1';
            cnt_8_cycles <= 0;
        elsif rising_edge(clk_4096Hz) then
            
            -- ? 因為用了 Look-Ahead，一個 PWM 週期結束的判定條件要更新：
            -- 狀況 A：正常交替時，LOW 數完代表週期結束 (done_low = '1')
            -- 狀況 B：全亮極端狀態下，HIGH 數完且對手為 0 亦代表週期結束 (done_high = '1' and limit_low = 0)
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

    cnt_duty_out <= std_logic_vector(to_unsigned(duty_reg, 5));

end architecture;