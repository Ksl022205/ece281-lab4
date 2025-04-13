library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Lab 4
entity top_basys3 is
    port(
        -- inputs
        clk     :   in std_logic; -- native 100MHz FPGA clock
        sw      :   in std_logic_vector(15 downto 0);
        btnU    :   in std_logic; -- master_reset
        btnL    :   in std_logic; -- clk_reset
        btnR    :   in std_logic; -- fsm_reset
        
        -- outputs
        led :   out std_logic_vector(15 downto 0);
        -- 7-segment display segments (active-low cathodes)
        seg :   out std_logic_vector(6 downto 0);
        -- 7-segment display active-low enables (anodes)
        an  :   out std_logic_vector(3 downto 0)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is

    -- signal declarations
    signal w_slow_clk : std_logic;
    signal w_floor1, w_floor2 : std_logic_vector(3 downto 0);
    signal w_tdm_data : std_logic_vector(3 downto 0);
    signal w_tdm_sel : std_logic_vector(3 downto 0);
    signal w_reset_fsm : std_logic; -- Signal for combined FSM reset
    
    -- constant for clock divider (0.5s period at 100MHz)
    -- 0.5s = 50,000,000 cycles, divide by 2 for toggle
    constant k_CLK_DIV : natural := 25000000;
    
    -- constant for 'F' display
    constant k_F_DISPLAY : std_logic_vector(3 downto 0) := x"F";

    -- component declarations
    component sevenseg_decoder
        port (
            i_Hex : in STD_LOGIC_VECTOR (3 downto 0);
            o_seg_n : out STD_LOGIC_VECTOR (6 downto 0)
        );
    end component;
    
    component elevator_controller_fsm
        port (
            i_clk        : in  STD_LOGIC;
            i_reset      : in  STD_LOGIC;
            is_stopped   : in  STD_LOGIC;
            go_up_down   : in  STD_LOGIC;
            o_floor : out STD_LOGIC_VECTOR (3 downto 0)           
        );
    end component;
    
    component TDM4
        generic ( constant k_WIDTH : natural := 4); -- bits in input and output
        port ( 
            i_clk        : in  STD_LOGIC;
            i_reset      : in  STD_LOGIC; -- asynchronous
            i_D3         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            i_D2         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            i_D1         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            i_D0         : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            o_data       : out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            o_sel        : out STD_LOGIC_VECTOR (3 downto 0) -- selected data line (one-cold)
        );
    end component;
     
    component clock_divider
        generic ( constant k_DIV : natural := 2); -- How many clk cycles until slow clock toggles
        port (  
            i_clk    : in std_logic;
            i_reset  : in std_logic;           -- asynchronous
            o_clk    : out std_logic           -- divided (slow) clock
        );
    end component;

begin
    -- CONCURRENT STATEMENTS ----------------------------
    
    -- Combine FSM reset signals (btnR or btnU)
    w_reset_fsm <= btnR or btnU;
    
    -- PORT MAPS ----------------------------------------
    
    -- Clock divider for 0.5s period
    clk_div: clock_divider
        generic map (
            k_DIV => k_CLK_DIV
        )
        port map (
            i_clk => clk,
            i_reset => btnL,
            o_clk => w_slow_clk
        );
    
    -- First elevator FSM
    elev1_fsm: elevator_controller_fsm
        port map (
            i_clk => w_slow_clk,
            i_reset => w_reset_fsm,
            is_stopped => sw(0),
            go_up_down => sw(1),
            o_floor => w_floor1
        );
    
    -- Second elevator FSM
    elev2_fsm: elevator_controller_fsm
        port map (
            i_clk => w_slow_clk,
            i_reset => w_reset_fsm,
            is_stopped => sw(14),
            go_up_down => sw(15),
            o_floor => w_floor2
        );
    
    -- Time-division multiplexer for 7-segment displays
    tdm: TDM4
        generic map (
            k_WIDTH => 4
        )
        port map (
            i_clk => clk,
            i_reset => btnU,
            i_D3 => k_F_DISPLAY,    -- Display 3 shows 'F'
            i_D2 => w_floor2,       -- Display 2 shows elevator 2 floor
            i_D1 => k_F_DISPLAY,    -- Display 1 shows 'F'
            i_D0 => w_floor1,       -- Display 0 shows elevator 1 floor
            o_data => w_tdm_data,
            o_sel => w_tdm_sel
        );
    
    -- Seven-segment decoder
    seg_decoder: sevenseg_decoder
        port map (
            i_Hex => w_tdm_data,
            o_seg_n => seg
        );
    
    -- Connect TDM select to anode signals
    an <= w_tdm_sel;
    
    -- LED 15 gets the FSM slow clock signal. The rest are grounded.
    led(15) <= w_slow_clk;
    led(14 downto 0) <= (others => '0');
    
    -- Unused switches (sw(13 downto 2)) are left unconnected

end top_basys3_arch;
