library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_basys3 is
    port(
        clk     : in std_logic;
        sw      : in std_logic_vector(15 downto 0);
        btnU    : in std_logic;
        btnL    : in std_logic;
        btnR    : in std_logic;
        led     : out std_logic_vector(15 downto 0);
        seg     : out std_logic_vector(6 downto 0);
        an      : out std_logic_vector(3 downto 0)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is

    -- Signals
    signal w_slow_clk : std_logic;
    signal w_floor1, w_floor2 : std_logic_vector(3 downto 0);
    signal w_floor1_digit, w_floor2_digit : std_logic_vector(3 downto 0);
    signal w_tdm_data : std_logic_vector(3 downto 0);
    signal w_tdm_sel : std_logic_vector(3 downto 0);
    signal w_seg_n : std_logic_vector(6 downto 0);
    signal w_tdm_clk   : std_logic := '0';
    signal tdm_counter : integer range 0 to 99999 := 0;

    -- Constants
    constant k_CLK_DIV : natural := 25000000;  -- 0.5s period for FSM
    constant k_BLANK_DISPLAY : std_logic_vector(3 downto 0) := x"0";
    constant k_F_DISPLAY : std_logic_vector(3 downto 0) := x"F";

    -- Components
    component sevenseg_decoder is
        port (
            i_Hex : in STD_LOGIC_VECTOR (3 downto 0);
            o_seg_n : out STD_LOGIC_VECTOR (6 downto 0)
        );
    end component;

    component elevator_controller_fsm is
        port (
            i_clk        : in STD_LOGIC;
            i_reset      : in STD_LOGIC;
            is_stopped   : in STD_LOGIC;
            go_up_down   : in STD_LOGIC;
            o_floor      : out STD_LOGIC_VECTOR (3 downto 0)
        );
    end component;
    component TDM4 is
        generic (constant k_WIDTH : natural := 4);
        Port (
            i_clk    : in STD_LOGIC;
            i_reset  : in STD_LOGIC;
            i_D3     : in STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            i_D2     : in STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            i_D1     : in STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            i_D0     : in STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            o_data   : out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            o_sel    : out STD_LOGIC_VECTOR (3 downto 0)
        );
    end component;

    component clock_divider is
        generic (constant k_DIV : natural := 4);
        port (
            i_clk    : in std_logic;
            i_reset  : in std_logic;
            o_clk    : out std_logic
        );
    end component;

begin

    -- TDM clock divider (~1kHz)
     clk_div1: clock_divider
        generic map (k_DIV => 100000)
        port map (
            i_clk => clk,
            i_reset => btnL,
            o_clk => w_slow_clk
        );

    -- FSM clock divider (for elevator movement)
    clk_div2: clock_divider
        generic map (k_DIV => k_CLK_DIV)
        port map (
            i_clk => clk,
            i_reset => btnL,
            o_clk => w_slow_clk
        );

    -- Elevator FSMs
    elev1_fsm: elevator_controller_fsm
        port map (
            i_clk => w_slow_clk,
            i_reset => btnR,
            is_stopped => sw(0),
            go_up_down => sw(1),
            o_floor => w_floor1
        );

    elev2_fsm: elevator_controller_fsm
        port map (
            i_clk => w_slow_clk,
            i_reset => btnR,
            is_stopped => sw(14),
            go_up_down => sw(15),
            o_floor => w_floor2
        );
    -- Floor digit assignment
    w_floor1_digit <= w_floor1;
    w_floor2_digit <= w_floor2;

    -- Time-Division Multiplexed display
    tdm: TDM4
        generic map (k_WIDTH => 4)
        port map (
            i_clk => w_tdm_clk,
            i_reset => btnU,
            i_D3 => k_F_DISPLAY,
            i_D2 => w_floor2_digit,
            i_D1 => k_F_DISPLAY,
            i_D0 => w_floor1_digit,
            o_data => w_tdm_data,
            o_sel => w_tdm_sel
        );

    -- Seven segment decoder
    seg_decoder: sevenseg_decoder
        port map (
            i_Hex => w_tdm_data,
            o_seg_n => w_seg_n
        );

    -- Segment remapping
    seg(0) <= w_seg_n(0);
    seg(1) <= w_seg_n(1);
    seg(2) <= w_seg_n(2);
    seg(3) <= w_seg_n(3);
    seg(4) <= w_seg_n(4);
    seg(5) <= w_seg_n(5);  -- F → G
    seg(6) <= w_seg_n(6);  -- G → F

    -- Display control
    an <= w_tdm_sel;

    -- LED debug indicators
    led(3 downto 0)   <= w_floor1_digit;
    led(7 downto 4)   <= w_floor2_digit;
    led(15)           <= w_slow_clk;
    led(14 downto 8)  <= (others => '0');

end top_basys3_arch;
