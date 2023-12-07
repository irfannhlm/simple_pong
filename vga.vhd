library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity vga is
    port(
        i_clk : in std_logic;
        i_red : in std_logic;
        i_green : in std_logic;
        i_blue : in std_logic;
        o_red : out std_logic;
        o_green : out std_logic;
        o_blue : out std_logic;
        o_horiz_sync : out std_logic;
        o_vert_sync : out std_logic;
        o_pixel_column : out std_logic_vector(9 downto 0);
        o_pixel_row : out std_logic_vector(9 downto 0)
    );
end vga;

architecture behavioral of vga is
    constant TH : integer := 800;
    constant THB1 : integer := 660;
    constant THB2 : integer := 756;
    constant THD : integer := 640;
    
    constant TV : integer := 525;
    constant TVB1 : integer := 494;
    constant TVB2 : integer := 495;
    constant TVD : integer := 480;

    signal clock_25MHz : std_logic;
    signal horiz_sync : std_logic;
    signal vert_sync : std_logic;
    signal video_on : std_logic;
    signal video_on_h : std_logic;
    signal video_on_v : std_logic;
    signal h_count : std_logic_vector(9 downto 0) := (others => '0');
    signal v_count : std_logic_vector(9 downto 0) := (others => '0');

begin

    video_on <= video_on_h and video_on_v;
    o_red <= i_red and video_on;
    o_green <= i_green and video_on;
    o_blue <= i_blue and video_on;

    o_horiz_sync <= horiz_sync;
    o_vert_sync <= vert_sync;

    process(i_clk)
    begin
        if rising_edge(i_clk) then
            if (clock_25MHz = '0') then
                clock_25MHz <= '1';
            else
                clock_25MHz <= '0';
            end if;
        end if;
    end process;

    process(clock_25MHz)
    begin
        if rising_edge(clock_25MHz) then
            if (h_count = TH - 1) then
                h_count <= (others => '0');
            else
                h_count <= h_count + 1;
            end if;

            if (h_count <= THB2 - 1) and (h_count >= THB1 - 1) then
                horiz_sync <= '0';
            else
                horiz_sync <= '1';
            end if;
                
            if (v_count >= TV - 1) and (h_count >= TH - 1) then
                v_count <= (others => '0');
            elsif (h_count = TH - 1) then
                v_count <= v_count + 1;
            end if;

            if (v_count <= TVB2 - 1) and (v_count >= TVB1 - 1) then
                vert_sync <= '0';
            else
                vert_sync <= '1';
            end if;

            if (h_count <= THD - 1) then
                video_on_h <= '1';
                o_pixel_column <= h_count;
            else
                video_on_h <= '0';
            end if;

            if (v_count <= TVD - 1) then
                video_on_v <= '1';
                o_pixel_row <= v_count;
            else
                video_on_v <= '0';
            end if;

        end if;
    end process;

end behavioral;