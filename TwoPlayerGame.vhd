library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity TwoPlayerGame is 
    port(
        clock : in std_logic;
        switch : in std_logic_vector(9 downto 0);
        keys : in std_logic_vector(3 downto 0);
        led_red : out std_logic_vector(9 downto 0);
        led_green : out std_logic_vector(7 downto 0);
        vga_red : out std_logic_vector(3 downto 0);
        vga_green : out std_logic_vector(3 downto 0);
        vga_blue : out std_logic_vector(3 downto 0);
        vga_hsync : out std_logic;
        vga_vsync : out std_logic
    );
end TwoPlayerGame;

architecture behavioral of TwoPlayerGame is
    constant clock_frequency : natural := 50e6; -- 50 MHz
    constant balls_frequency : natural := 150; -- 150 Hz
    constant players_frequency : natural := 200; -- 200 Hz

    constant leftmost_pixel, topmost_pixel : natural := 0;
    constant bottommost_pixel : natural := 480;
    constant rightmost_pixel : natural := 640;

    type box_attr is array(0 to 3) of natural; -- (<length>, <width>, <posx>, <posy>)

    signal box1_attr : box_attr;  -- Player 1 (left)
    signal box2_attr : box_attr; -- Player 2 (right)
    signal box3_attr : box_attr; -- Ball 1
    signal box4_attr : box_attr; -- Ball 2

    constant box1_defattr : box_attr := (25, 90, 10, 240);
    constant box2_defattr : box_attr := (25, 90, 605, 240);
    constant box3_defattr : box_attr := (25, 25, 150, 100);
    constant box4_defattr : box_attr := (25, 25, 300, 250);
    

    signal box3_dir : std_logic_vector(0 to 1) := "11";
    signal box4_dir : std_logic_vector(0 to 1) := "10";

    constant box1_color : std_logic_vector(11 downto 0) := x"f00";
    constant box2_color : std_logic_vector(11 downto 0) := x"00f";
    constant box3_color : std_logic_vector(11 downto 0) := x"f0f";
    constant box4_color : std_logic_vector(11 downto 0) := x"0ff";

    signal player1_score, player2_score : std_logic_vector(7 downto 0);

    type game_states is (init, idle, play);
    signal game_state : game_states := init;

    signal start_key, reset_key, up_key1, down_key1, up_key2, down_key2: std_logic;

    component vga is
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
    end component vga;
    
    component ClockDiv is
        generic(div_frequency, clock_frequency : natural);
        port(
            clock: in std_logic;
            div_out: buffer bit
        );
    end component ClockDiv;

    signal green_value, red_value, blue_value : std_logic_vector(3 downto 0);
    signal red_on, green_on, blue_on : std_logic;
    signal pixel_x, pixel_y : std_logic_vector(9 downto 0);
    signal RGB_value : std_logic_vector(11 downto 0);
    signal clock_balls, clock_players : bit;

    function xcollision(box1, box2 : box_attr) return boolean is
        type box_bound is array(0 to 3) of integer; -- (<left>, <right>, <top>, <bottom>)
        variable box1_bound, box2_bound : box_bound;
    begin
        box1_bound := (box1(2), box1(2) + box1(0), box1(3), box1(3) + box1(1));
        box2_bound := (box2(2), box2(2) + box2(0), box2(3), box2(3) + box2(1));
        return (box1_bound(3) >= box2_bound(2) and box1_bound(2) <= box2_bound(3)) and
        (box1_bound(0) = box2_bound(1) or box1_bound(1) = box2_bound(0));
    end function;

    function ycollision(box1, box2 : box_attr) return boolean is
        type box_bound is array(0 to 3) of integer; -- (<left>, <right>, <top>, <bottom>)
        variable box1_bound, box2_bound : box_bound;
    begin
        box1_bound := (box1(2), box1(2) + box1(0), box1(3), box1(3) + box1(1));
        box2_bound := (box2(2), box2(2) + box2(0), box2(3), box2(3) + box2(1));
        return (box1_bound(1) >= box2_bound(0) and box1_bound(0) <= box2_bound(1)) and
        (box1_bound(2) = box2_bound(3) or box1_bound(3) = box2_bound(2));
    end function;

begin
    vga_inst: vga
    port map (
      i_clk          => clock,
      i_red          => '1',
      i_green        => '1',
      i_blue         => '1',
      o_red          => red_on,
      o_green        => green_on,
      o_blue         => blue_on,
      o_horiz_sync   => vga_hsync,
      o_vert_sync    => vga_vsync,
      o_pixel_column => pixel_x,
      o_pixel_row    => pixel_y
    );

    clockdiv_balls : ClockDiv
    generic map (
      div_frequency   => balls_frequency,
      clock_frequency => clock_frequency
    )
    port map (
      clock   => clock,
      div_out => clock_balls
    );

    clockdiv_players: ClockDiv
    generic map (
      div_frequency   => players_frequency,
      clock_frequency => clock_frequency
    )
    port map (
      clock   => clock,
      div_out => clock_players
    );

    states_controller : process(clock)
        type box_bound is array(0 to 3) of integer; -- (<left>, <right>, <top>, <bottom>)
        variable box3_bound, box4_bound : box_bound;
    begin
        if rising_edge(clock) then
            case game_state is
                when init =>
                    if (start_key = '1') then game_state <= play; end if;
                    player1_score <= (others => '0');
                    player2_score <= (others => '0');
                when idle =>
                    if (start_key = '1') then game_state <= play; end if;
                when play =>
                    if (reset_key = '1') then game_state <= init; end if;

                    box3_bound := (box3_attr(2), box3_attr(2) + box3_attr(0), box3_attr(3), box3_attr(3) + box3_attr(1));
                    box4_bound := (box4_attr(2), box4_attr(2) + box4_attr(0), box4_attr(3), box4_attr(3) + box4_attr(1));
                    if (box3_bound(1) = rightmost_pixel or box4_bound(1) = rightmost_pixel) then -- if player 1 scores
                        player1_score <= player1_score + 1;
                        game_state <= idle;
                    end if;

                    if (box3_bound(0) = leftmost_pixel or box4_bound(0) = leftmost_pixel) then -- if player 2 scores
                        player2_score <= player2_score + 1;
                        game_state <= idle;
                    end if;

            end case;
        end if;
    end process states_controller;
 
    draw_boxes : process(pixel_x, pixel_y)
    begin

        -- draw box 1
        if (pixel_x >= box1_attr(2) and pixel_x <= (box1_attr(2) + box1_attr(0))) and
            (pixel_y >= box1_attr(3) and pixel_y <= (box1_attr(3) + box1_attr(1))) then
            RGB_value <= box1_color;

        -- draw box 2
        elsif (pixel_x >= box2_attr(2) and pixel_x <= (box2_attr(2) + box2_attr(0))) and
            (pixel_y >= box2_attr(3) and pixel_y <= (box2_attr(3) + box2_attr(1))) then
            RGB_value <= box2_color;

        -- draw box 3
        elsif (pixel_x >= box3_attr(2) and pixel_x <= (box3_attr(2) + box3_attr(0))) and
            (pixel_y >= box3_attr(3) and pixel_y <= (box3_attr(3) + box3_attr(1))) then
            RGB_value <= box3_color;

        -- draw box 4
        elsif (pixel_x >= box4_attr(2) and pixel_x <= (box4_attr(2) + box4_attr(0))) and
            (pixel_y >= box4_attr(3) and pixel_y <= (box4_attr(3) + box4_attr(1))) then
            RGB_value <= box4_color;

        else
            RGB_value <= x"000";
        end if;
    end process draw_boxes;

    move_player1 : process(clock_players)
        type box_bound is array(0 to 3) of integer; -- (<left>, <right>, <top>, <bottom>)
        variable box1_bound : box_bound;
    begin
        if (game_state = play) then
            box1_bound := (box1_attr(2), box1_attr(2) + box1_attr(0), box1_attr(3), box1_attr(3) + box1_attr(1));

            if clock_players'event and clock_players = '1' then
                if (up_key1 = '0' and box1_bound(2) >= topmost_pixel and box1_bound(2) >= 1 + topmost_pixel) then -- move up
                    box1_attr(3) <= box1_attr(3) - 1;
                end if;
                if (down_key1 = '0' and box1_bound(3) <= bottommost_pixel and (box1_bound(3) + 1) <= bottommost_pixel) then -- move down
                    box1_attr(3) <= box1_attr(3) + 1;
                end if;
            end if;
        else
            box1_attr <= box1_defattr;
        end if;
    end process move_player1;

    move_player2 : process(clock_players)
        type box_bound is array(0 to 3) of integer; -- (<left>, <right>, <top>, <bottom>)
        variable box2_bound : box_bound;
    begin
        if (game_state = play) then
            box2_bound := (box2_attr(2), box2_attr(2) + box2_attr(0), box2_attr(3), box2_attr(3) + box2_attr(1));

            if clock_players'event and clock_players = '1' then
                if (up_key2 = '0' and box2_bound(2) >= topmost_pixel and box2_bound(2) >= 1 + topmost_pixel) then -- move up
                    box2_attr(3) <= box2_attr(3) - 1;
                end if;
                if (down_key2 = '0' and box2_bound(3) <= bottommost_pixel and (box2_bound(3) + 1) <= bottommost_pixel) then -- move down
                    box2_attr(3) <= box2_attr(3) + 1;
                end if;
            end if;
        else
            box2_attr <= box2_defattr;
        end if;
    end process move_player2;

    move_ball1 : process(clock_balls)
        type box_bound is array(0 to 3) of integer; -- (<left>, <right>, <top>, <bottom>)
        variable box3_bound : box_bound;
    begin
        if (game_state = play) then
            box3_bound := (box3_attr(2), box3_attr(2) + box3_attr(0), box3_attr(3), box3_attr(3) + box3_attr(1));

            if clock_balls'event and clock_balls = '1' then

                -- Collision on x direction
                if (xcollision(box3_attr, box2_attr) or xcollision(box3_attr, box1_attr) or xcollision(box3_attr, box4_attr)) or
                    (box3_bound(0) <= leftmost_pixel or box3_bound(1) >= rightmost_pixel)
                then
                    box3_dir(0) <= not box3_dir(0);
                    if (box3_dir = "11") then
                        box3_attr(2) <= box3_attr(2) + 1;
                        box3_attr(3) <= box3_attr(3) + 1;
                    elsif (box3_dir = "10") then
                        box3_attr(2) <= box3_attr(2) + 1;
                        box3_attr(3) <= box3_attr(3) - 1;
                    elsif (box3_dir = "01") then
                        box3_attr(2) <= box3_attr(2) - 1;
                        box3_attr(3) <= box3_attr(3) + 1;
                    elsif (box3_dir = "00") then
                        box3_attr(2) <= box3_attr(2) - 1;
                        box3_attr(3) <= box3_attr(3) - 1;
                    end if;

                -- Collision on y direction
                elsif (ycollision(box3_attr, box2_attr) or ycollision(box3_attr, box1_attr) or ycollision(box3_attr, box4_attr)) or
                    (box3_bound(2) <= topmost_pixel or box3_bound(3) >= bottommost_pixel)
                then
                    box3_dir(1) <= not box3_dir(1);
                    if (box3_dir = "11") then
                        box3_attr(2) <= box3_attr(2) + 1;
                        box3_attr(3) <= box3_attr(3) + 1;
                    elsif (box3_dir = "10") then
                        box3_attr(2) <= box3_attr(2) + 1;
                        box3_attr(3) <= box3_attr(3) - 1;
                    elsif (box3_dir = "01") then
                        box3_attr(2) <= box3_attr(2) - 1;
                        box3_attr(3) <= box3_attr(3) + 1;
                    elsif (box3_dir = "00") then
                        box3_attr(2) <= box3_attr(2) - 1;
                        box3_attr(3) <= box3_attr(3) - 1;
                    end if;

                -- Move normally if no collision
                elsif (box3_dir = "00") then
                    box3_attr(2) <= box3_attr(2) + 1;
                    box3_attr(3) <= box3_attr(3) + 1;
                elsif (box3_dir = "01") then
                    box3_attr(2) <= box3_attr(2) + 1;
                    box3_attr(3) <= box3_attr(3) - 1;
                elsif (box3_dir = "10") then
                    box3_attr(2) <= box3_attr(2) - 1;
                    box3_attr(3) <= box3_attr(3) + 1;
                elsif (box3_dir = "11") then
                    box3_attr(2) <= box3_attr(2) - 1;
                    box3_attr(3) <= box3_attr(3) - 1;
                end if;
            end if;
        else
            box3_attr <= box3_defattr;
        end if;
    end process move_ball1;

    move_ball2 : process(clock_balls)
        type box_bound is array(0 to 3) of integer; -- (<left>, <right>, <top>, <bottom>)
        variable box4_bound : box_bound;
    begin
        if (game_state = play) then
            box4_bound := (box4_attr(2), box4_attr(2) + box4_attr(0), box4_attr(3), box4_attr(3) + box4_attr(1));

            if clock_balls'event and clock_balls = '1' then

                -- Collision on x direction
                if (xcollision(box4_attr, box2_attr) or xcollision(box4_attr, box3_attr) or xcollision(box4_attr, box1_attr)) or
                    (box4_bound(0) <= leftmost_pixel or box4_bound(1) >= rightmost_pixel)
                then
                    box4_dir(0) <= not box4_dir(0);
                    if (box4_dir = "11") then
                        box4_attr(2) <= box4_attr(2) + 1;
                        box4_attr(3) <= box4_attr(3) + 1;
                    elsif (box4_dir = "10") then
                        box4_attr(2) <= box4_attr(2) + 1;
                        box4_attr(3) <= box4_attr(3) - 1;
                    elsif (box4_dir = "01") then
                        box4_attr(2) <= box4_attr(2) - 1;
                        box4_attr(3) <= box4_attr(3) + 1;
                    elsif (box4_dir = "00") then
                        box4_attr(2) <= box4_attr(2) - 1;
                        box4_attr(3) <= box4_attr(3) - 1;
                    end if;

                -- Collision on y direction
                elsif (ycollision(box4_attr, box2_attr) or ycollision(box4_attr, box3_attr) or ycollision(box4_attr, box1_attr)) or
                    (box4_bound(2) <= topmost_pixel or box4_bound(3) >= bottommost_pixel)
                then
                    box4_dir(1) <= not box4_dir(1);
                    if (box4_dir = "11") then
                        box4_attr(2) <= box4_attr(2) + 1;
                        box4_attr(3) <= box4_attr(3) + 1;
                    elsif (box4_dir = "10") then
                        box4_attr(2) <= box4_attr(2) + 1;
                        box4_attr(3) <= box4_attr(3) - 1;
                    elsif (box4_dir = "01") then
                        box4_attr(2) <= box4_attr(2) - 1;
                        box4_attr(3) <= box4_attr(3) + 1;
                    elsif (box4_dir = "00") then
                        box4_attr(2) <= box4_attr(2) - 1;
                        box4_attr(3) <= box4_attr(3) - 1;
                    end if;

                -- Move normally if no collision
                elsif (box4_dir = "00") then
                    box4_attr(2) <= box4_attr(2) + 1;
                    box4_attr(3) <= box4_attr(3) + 1;
                elsif (box4_dir = "01") then
                    box4_attr(2) <= box4_attr(2) + 1;
                    box4_attr(3) <= box4_attr(3) - 1;
                elsif (box4_dir = "10") then
                    box4_attr(2) <= box4_attr(2) - 1;
                    box4_attr(3) <= box4_attr(3) + 1;
                elsif (box4_dir = "11") then
                    box4_attr(2) <= box4_attr(2) - 1;
                    box4_attr(3) <= box4_attr(3) - 1;
                end if;
            end if;
        else
            box4_attr <= box4_defattr;
        end if;
    end process move_ball2;

    up_key1 <= keys(3);
    down_key1 <= keys(2);
    up_key2 <= keys(1);
    down_key2 <= keys(0);

    start_key <= switch(1);
    reset_key <= switch(0);

    led_red <= "00" & player1_score;
    led_green <= player2_score;

    red_value <= RGB_value(11 downto 8);
    green_value <= RGB_value(7 downto 4);
    blue_value <= RGB_value(3 downto 0);

    process(red_on, green_on, blue_on, red_value, green_value, blue_value)
    begin
        if (red_on = '1') then
            vga_red <= red_value;
        else
            vga_red <= x"0";
        end if;

        if (green_on = '1') then
            vga_green <= green_value;
        else
            vga_green <= x"0";
        end if;

        if (blue_on = '1') then
            vga_blue <= blue_value;
        else
            vga_blue <= x"0";
        end if;

    end process;

end behavioral;
