# Project 4: 基於 FSM 控制雙計數器的 PWM 呼吸燈

本專案使用 **VHDL** 語言在 **Xilinx Vivado** 環境下開發，實現了一個具備硬體優化的 PWM 呼吸燈控制系統。系統核心採用狀態機（FSM）動態控制兩個可配置計數器（`configurable_counter`），並在單一頂層模組內完成時脈除頻、狀態控制與亮度調變。

---

## 專案特點

* **雙計數器獨立控制**：高電位時間與低電位時間分別由兩個獨立的子模組計數器管理，動態載入上限值（Limit）。
* **預判機制**：FSM 在狀態轉換前，會先行檢查下一個狀態的 `limit` 是否為 0。若為 0 則直接保持當前狀態，達到 100% 與 0% Duty Cycle 的乾淨波形輸出。
* **純淨狀態機輸出**：`led_out` 的輸出完全由 FSM 當前狀態（Current State）決定（High 狀態輸出 `1`，Low 狀態輸出 `0`），符合嚴格的同步數位電路設計規範。
* **動態亮度步進**：內建減速器，每 8 個 PWM 週期更新一次亮度分數（0 至 31），呈現平滑的呼吸視覺效果。
* **單一頂層整合設計**：`breathing_pwm_top` 直接以板上 `100MHz` 系統時脈為輸入，內部自行除頻產生約 `4096Hz` 的內部時脈供 FSM／計數器邏輯使用，整個系統只有一個頂層模組。

---

## 一、系統設計與硬體架構

### 1. 系統架構與模組階層 (Module Breakdown)
系統由頂層模組 `breathing_pwm_top` 控制，內部拆解出底層的可配置計數器（`configurable_counter`，重複使用兩份分別管理高、低電位時間）與亮度減速控制邏輯，達到模組化設計。

![Project 4 系統 Breakdown](./Project4_diagram/breakdown.drawio.png)

### 2. 系統電路圖與硬體方塊圖 (Hardware Block Diagram)
電路走線包含 `100MHz` 時脈輸入、內部除頻產生的 `4096Hz` 內部時脈，以及 FSM 與雙計數器之間的動態 Limit 載入總線。

![Project 4 電路圖/方塊圖](./Project4_diagram/電路圖_方塊圖.drawio.png)

### 3. 有限狀態機控制核心 (FSM State Diagram)
FSM 在 `ST_HIGH` 與 `ST_LOW` 之間切換。當 `done` 訊號滿足且預判下一個狀態的上限值不為 0 時跳變；若為極端工作週期（0% 或 100%），則利用預判機制鎖定當前狀態，輸出完美直線。

![Project 4 FSM](./Project4_diagram/FSM.drawio.png)

---

## 二、訊號與時序規範

### 1. 訊號說明

| 端口名稱 | 方向 | 型態 | 功能描述 |
| --- | --- | --- | --- |
| `clk` | Input | `std_logic` | 系統時脈輸入 (100 MHz) |
| `led_out` | Output | `std_logic` | PWM 輸出訊號，用於驅動呼吸燈 LED |

| Generic 名稱 | 型態 | 預設值 | 功能描述 |
| --- | --- | --- | --- |
| `DIV_N` | `integer` | `12207` | 時脈除頻倍率，內部時脈頻率 = 100MHz/(2×DIV_N)，預設值對應約 4096.02Hz |

`rst` 為模組內部訊號，非外部 port：所有暫存器宣告時皆已賦予正確初始值（`duty_reg:=0`、`my_direction:='1'`、`cnt_8_cycles:=0`；`current_state` 依 VHDL 列舉型別預設規則取第一個值 `ST_HIGH`），FPGA 組態載入時即套用這些初始值，故 `rst` 於架構內部固定為 `'0'`，系統開機即進入正常運作，不需外部重置動作。

亮度分數 `duty_reg`（0~31）為架構內部訊號，未對外輸出成 port；模擬時可直接透過 Scope／波形視窗觀察此訊號的即時變化。

### 2. 系統時序規範與約束 (Time Spec)
定義各硬體模組在時脈沿觸發下的建立時間（Setup Time）與保持時間（Hold Time）規範。

![Project 4 Time spec](./Project4_diagram/Timespec.drawio.png)

---

## 三、Testbench 模擬與精確時間軸節點

### 1. Testbench 模擬執行流程 (Activity-on-Vertex, AoV 圖)
描述模擬啟動後，從系統時脈第一個上升沿、進入呼吸循環到單次週期結束的完整生命週期節點。

![Project 4 模擬流程 AoV 圖](./Project4_diagram/AOV.drawio.png)

### 2. 精確功能模擬時間軸節點說明 (Behavioral Timing)

Testbench（`tb_dual_counter_pwm.vhd`）以真實 `100MHz`（週期 `10ns`）驅動 `clk`，並透過 `generic map` 將 `DIV_N` 設為 `2`，使內部時脈 `clk_4096Hz_i` 週期為 `40ns`（即每 `4` 個 `clk` 週期翻轉一次）。以下節點皆以 `clk` 為單位標示（`clk=N` 代表第 `N` 個 `100MHz` 時脈上升沿），單次完整呼吸週期共 **`clk=61504`（615,040 ns）**：

* **`clk=0`**：模擬啟動，所有暫存器套用宣告時的初始值，`current_state=ST_HIGH`，`duty_reg=0`。
* **`clk=1`**：`clk_4096Hz_i` 第一個上升沿，`u_counter_HIGH`／`u_counter_LOW` 開始計數。
* **`clk=124`**：`limit_high+limit_low` 恆為 `31`，第一次 `ST_HIGH`＋`ST_LOW` 完整走完一輪（`31` 個 `clk_4096Hz_i` 週期）。
* **`clk=992`**：減速計數器 `cnt_8_cycles` 累積滿 `8` 次 PWM 週期，亮度分數 `duty_reg` 第一次由 `0` 遞增至 `1`。
* **`clk=30752`**：走完 `31` 階遞增，`duty_reg=31` 到達最頂峰。此時內部預判機制偵測到 `limit_low=0`（全亮），FSM 鎖定當前狀態不切換，**`led_out=1` 保持純淨恆亮直線**。
* **`clk=30752` ~ `clk=61504`**：亮度分數自 `31` 逐級對稱遞減，呼吸燈進入變暗階段。
* **`clk=61504`**：完整走完暗 → 亮 → 暗波形，`duty_reg` 回到 `0`，進入下一次呼吸循環。

---

## 四、模擬與驗證指引 (How to Run)

### 模擬設定

* **開發工具**：Vivado 2022.2（或更高版本）
* **系統時脈週期**：`10 ns`（`100MHz`）
* **模擬用除頻倍率**：`DIV_N=2`（`generic map` 覆寫，硬體實際使用 `12207`）
* **建議模擬時間**：`700 us` 以上，可涵蓋一次完整呼吸週期（`clk=61504`，即 `615,040 ns`）

### 運行步驟

1. 將 `src/breathing_pwm_top.vhd`、`src/configurable_counter.vhd` 加入 Vivado 的 **Design Sources**，`Top Module` 設為 `breathing_pwm_top`。
2. 將 `sim/tb_dual_counter_pwm.vhd` 加入 Vivado 的 **Simulation Sources**。
3. 於 `Settings → Simulation → Simulation` 分頁，將 `xsim.simulate.runtime` 設為 `700us`，使每次執行模擬皆自動涵蓋完整呼吸週期。
4. 執行 **Run Simulation → Run Behavioral Simulation**，觀測理想功能波形（可特別對照 `clk=30752` 附近的恆亮直線）。若需觀察 `duty_reg` 等內部訊號，於左側 `Scope` 面板展開至 `uut` 後，從 `Objects` 面板將訊號加入波形視窗。
5. 套用 `constraints/breathing_pwm_hw.xdc`，執行 `Run Synthesis → Run Implementation → Generate Bitstream`，燒錄至 `EGO-XZ7`。
