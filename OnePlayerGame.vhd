library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity OnePlayerGame is 
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
end OnePlayerGame;

architecture behavioral of OnePlayerGame is
    constant clock_frequency : natural := 50000000; -- 50 MHz
    constant balls_frequency : natural := 150; -- 50 Hz
    constant players_frequency : natural := 200; -- 25 Hz

    constant leftmost_pixel, topmost_pixel : natural := 0;
    constant bottommost_pixel : natural := 480;
    constant rightmost_pixel : natural := 640;

    type box_attr is array(0 to 3) of natural; -- (<length>, <width>, <posx>, <posy>)

    -- player
    signal box1_attr : box_attr;
    constant box1_defattr : box_attr := (90, 25, 320, 445);
    
    -- ball
    signal box2_attr : box_attr;
    constant box2_defattr : box_attr := (25, 25, 320, 240);

    -- obstacles
    constant box3_attr : box_attr := (50, 25, 40, 50);
    constant box4_attr : box_attr := (50, 25, 40 + 100, 50);
    constant box5_attr : box_attr := (50, 25, 40 + 200, 50);
    constant box6_attr : box_attr := (50, 25, 40 + 300, 50);
    constant box7_attr : box_attr := (50, 25, 40 + 400, 50);
    constant box8_attr : box_attr := (50, 25, 40 + 500, 50);
    constant box9_attr : box_attr := (50, 25, 40, 100);
    constant box10_attr : box_attr := (50, 25, 40 + 100, 100);
    constant box11_attr : box_attr := (50, 25, 40 + 200, 100);
    constant box12_attr : box_attr := (50, 25, 40 + 300, 100);
    constant box13_attr : box_attr := (50, 25, 40 + 400, 100);
    constant box14_attr : box_attr := (50, 25, 40 + 500, 100);


    signal box2_dir : std_logic_vector(0 to 1) := "11";

    constant box1_color : std_logic_vector(11 downto 0) := x"f00";
    constant box2_color : std_logic_vector(11 downto 0) := x"00f";

    signal player_score : std_logic_vector(7 downto 0);

    type game_states is (init, idle, play);
    signal game_state : game_states := init;

    signal start_key, reset_key, left_key, right_key, up_key, down_key : std_logic;

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

    function xCollision(box1, box2 : box_attr) return boolean is
        type box_bound is array(0 to 3) of integer; -- (<left>, <right>, <top>, <bottom>)
        variable box1_bound, box2_bound : box_bound;
    begin
        box1_bound := (box1(2), box1(2) + box1(0), box1(3), box1(3) + box1(1));
        box2_bound := (box2(2), box2(2) + box2(0), box2(3), box2(3) + box2(1));
        return (box1_bound(3) >= box2_bound(2) and box1_bound(2) <= box2_bound(3)) and
        (box1_bound(0) = box2_bound(1) or box1_bound(1) = box2_bound(0));
    end function;

    function yCollision(box1, box2 : box_attr) return boolean is
        type box_bound is array(0 to 3) of integer; -- (<left>, <right>, <top>, <bottom>)
        variable box1_bound, box2_bound : box_bound;
    begin
        box1_bound := (box1(2), box1(2) + box1(0), box1(3), box1(3) + box1(1));
        box2_bound := (box2(2), box2(2) + box2(0), box2(3), box2(3) + box2(1));
        return (box1_bound(1) >= box2_bound(0) and box1_bound(0) <= box2_bound(1)) and
        (box1_bound(2) = box2_bound(3) or box1_bound(3) = box2_bound(2));
    end function;

    function isThereBox(pixel_x, pixel_y : std_logic_vector; box : box_attr) return boolean is
    begin
        return (pixel_x >= box(2) and pixel_x <= (box(2) + box(0))) and
            (pixel_y >= box(3) and pixel_y <= (box(3) + box(1)));
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
        variable box2_bound : box_bound;
    begin
        if rising_edge(clock) then
            case game_state is
                when init =>
                    if (start_key = '1') then game_state <= play; end if;
                    player_score <= (others => '0');
                when idle =>
                    if (start_key = '1') then game_state <= play; end if;
                when play =>
                    if (reset_key = '1') then game_state <= init; end if;

                    box2_bound := (box2_attr(2), box2_attr(2) + box2_attr(0), box2_attr(3), box2_attr(3) + box2_attr(1));
                    if (box2_bound(3) = bottommost_pixel) then
                        player_score <= player_score + 1;
                        game_state <= idle;
                    end if;

            end case;
        end if;
    end process states_controller;
 
    draw_boxes : process(pixel_x, pixel_y)
    begin

        -- draw player
        if isThereBox(pixel_x, pixel_y, box1_attr) then
            RGB_value <= box1_color;

        -- draw ball
        elsif isThereBox(pixel_x, pixel_y, box2_attr) then
            RGB_value <= box2_color;

        -- draw obstacles
        elsif isThereBox(pixel_x, pixel_y, box3_attr) or isThereBox(pixel_x, pixel_y, box4_attr) or isThereBox(pixel_x, pixel_y, box5_attr)
             or isThereBox(pixel_x, pixel_y, box6_attr) or isThereBox(pixel_x, pixel_y, box7_attr) or isThereBox(pixel_x, pixel_y, box8_attr)
              or isThereBox(pixel_x, pixel_y, box9_attr) or isThereBox(pixel_x, pixel_y, box10_attr) or isThereBox(pixel_x, pixel_y, box11_attr)
              or isThereBox(pixel_x, pixel_y, box12_attr) or isThereBox(pixel_x, pixel_y, box13_attr) or isThereBox(pixel_x, pixel_y, box14_attr) then
            RGB_value <= x"fff";

        else
            RGB_value <= x"000";
        end if;
    end process draw_boxes;

    move_player : process(clock_players)
        type box_bound is array(0 to 3) of integer; -- (<left>, <right>, <top>, <bottom>)
        variable box1_bound : box_bound;
    begin
        if (game_state = play) then
            box1_bound := (box1_attr(2), box1_attr(2) + box1_attr(0), box1_attr(3), box1_attr(3) + box1_attr(1));

            if clock_players'event and clock_players = '1' then
                if (left_key = '0' and box1_bound(0) >= leftmost_pixel and box1_bound(0) >= (1 + leftmost_pixel)) then -- move left
                    box1_attr(2) <= box1_attr(2) - 1;
                elsif (right_key = '0' and box1_bound(1) <= rightmost_pixel and (box1_bound(1) + 1) <= rightmost_pixel) then -- move right
                    box1_attr(2) <= box1_attr(2) + 1;
                end if;
                if (up_key = '0' and box1_bound(2) >= topmost_pixel and box1_bound(2) >= 1 + topmost_pixel) then -- move up
                    box1_attr(3) <= box1_attr(3) - 1;
                elsif (down_key = '0' and box1_bound(3) <= bottommost_pixel and (box1_bound(3) + 1) <= bottommost_pixel) then -- move down
                    box1_attr(3) <= box1_attr(3) + 1;
                end if;
            end if;
        else
            box1_attr <= box1_defattr;
        end if;
    end process move_player;

    move_ball : process(clock_balls)
        type box_bound is array(0 to 3) of integer; -- (<left>, <right>, <top>, <bottom>)
        variable box2_bound : box_bound;
    begin
        if (game_state = play) then
            box2_bound := (box2_attr(2), box2_attr(2) + box2_attr(0), box2_attr(3), box2_attr(3) + box2_attr(1));

            if clock_balls'event and clock_balls = '1' then

                -- Collision on x direction
                if (xCollision(box2_attr, box1_attr) or xCollision(box2_attr, box3_attr) or xCollision(box2_attr, box4_attr) or 
                    xCollision(box2_attr, box5_attr) or xCollision(box2_attr, box6_attr) or xCollision(box2_attr, box7_attr) or 
                    xCollision(box2_attr, box8_attr) or xCollision(box2_attr, box9_attr) or xCollision(box2_attr, box10_attr) or 
                    xCollision(box2_attr, box11_attr) or xCollision(box2_attr, box12_attr) or xCollision(box2_attr, box13_attr) or 
                    xCollision(box2_attr, box14_attr)) or 
                    (box2_bound(0) <= leftmost_pixel or box2_bound(1) >= rightmost_pixel)
                then
                    box2_dir(0) <= not box2_dir(0);
                    if (box2_dir = "11") then
                        box2_attr(2) <= box2_attr(2) + 1;
                        box2_attr(3) <= box2_attr(3) + 1;
                    elsif (box2_dir = "10") then
                        box2_attr(2) <= box2_attr(2) + 1;
                        box2_attr(3) <= box2_attr(3) - 1;
                    elsif (box2_dir = "01") then
                        box2_attr(2) <= box2_attr(2) - 1;
                        box2_attr(3) <= box2_attr(3) + 1;
                    elsif (box2_dir = "00") then
                        box2_attr(2) <= box2_attr(2) - 1;
                        box2_attr(3) <= box2_attr(3) - 1;
                    end if;
                end if;

                -- Collision on y direction
                if (yCollision(box2_attr, box1_attr) or yCollision(box2_attr, box3_attr) or yCollision(box2_attr, box4_attr) or 
                    yCollision(box2_attr, box5_attr) or yCollision(box2_attr, box6_attr) or yCollision(box2_attr, box7_attr) or 
                    yCollision(box2_attr, box8_attr) or yCollision(box2_attr, box9_attr) or yCollision(box2_attr, box10_attr) or 
                    yCollision(box2_attr, box11_attr) or yCollision(box2_attr, box12_attr) or yCollision(box2_attr, box13_attr) or 
                    yCollision(box2_attr, box14_attr)) or 
                    (box2_bound(0) <= leftmost_pixel or box2_bound(1) >= rightmost_pixel)
                then
                    box2_dir(1) <= not box2_dir(1);
                    if (box2_dir = "11") then
                        box2_attr(2) <= box2_attr(2) + 1;
                        box2_attr(3) <= box2_attr(3) + 1;
                    elsif (box2_dir = "10") then
                        box2_attr(2) <= box2_attr(2) + 1;
                        box2_attr(3) <= box2_attr(3) - 1;
                    elsif (box2_dir = "01") then
                        box2_attr(2) <= box2_attr(2) - 1;
                        box2_attr(3) <= box2_attr(3) + 1;
                    elsif (box2_dir = "00") then
                        box2_attr(2) <= box2_attr(2) - 1;
                        box2_attr(3) <= box2_attr(3) - 1;
                    end if;

                -- Move normally if no collision
                elsif (box2_dir = "00") then
                    box2_attr(2) <= box2_attr(2) + 1;
                    box2_attr(3) <= box2_attr(3) + 1;
                elsif (box2_dir = "01") then
                    box2_attr(2) <= box2_attr(2) + 1;
                    box2_attr(3) <= box2_attr(3) - 1;
                elsif (box2_dir = "10") then
                    box2_attr(2) <= box2_attr(2) - 1;
                    box2_attr(3) <= box2_attr(3) + 1;
                elsif (box2_dir = "11") then
                    box2_attr(2) <= box2_attr(2) - 1;
                    box2_attr(3) <= box2_attr(3) - 1;
                end if;
            end if;
        else
            box2_attr <= box2_defattr;
        end if;
    end process move_ball;

    start_key <= switch(0);
    reset_key <= switch(1);

    left_key <= keys(3);
    right_key <= keys(0);
    up_key <= keys(2);
    down_key <= keys(1);

    led_red <= "00" & player_score;

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