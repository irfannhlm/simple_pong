library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity TopLevelSistem is
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
end TopLevelSistem;

architecture behavioral of TopLevelSistem is
    type game_modes is (idle, one_player, two_player);
    signal game_mode : game_modes; 

    component TwoPlayerGame is
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

    end component TwoPlayerGame;

    component OnePlayerGame is
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
    end component OnePlayerGame;

    signal vga_red1, vga_green1, vga_blue1 : std_logic_vector(3 downto 0) := (others => '0');
    signal vga_red2, vga_green2, vga_blue2 : std_logic_vector(3 downto 0) := (others => '0');
    signal vga_hsync1, vga_hsync2, vga_vsync1, vga_vsync2 : std_logic;
    signal switch1, switch2 : std_logic_vector(9 downto 0);
    signal keys1, keys2 : std_logic_vector(3 downto 0);
    signal led_red1, led_red2 : std_logic_vector(9 downto 0); 
    signal led_green1, led_green2 : std_logic_vector(7 downto 0);
begin
    oneplayergame_inst: OnePlayerGame
    port map (
        clock     => clock,
        switch    => switch1,
        keys      => keys1,
        led_red   => led_red1,
        led_green => led_green1,
        vga_red   => vga_red1,
        vga_green => vga_green1,
        vga_blue  => vga_blue1,
        vga_hsync => vga_hsync1,
        vga_vsync => vga_vsync1
    );

    twoplayergame_inst: TwoPlayerGame
    port map (
        clock     => clock,
        switch    => switch2,
        keys      => keys2,
        led_red   => led_red2,
        led_green => led_green2,
        vga_red   => vga_red2,
        vga_green => vga_green2,
        vga_blue  => vga_blue2,
        vga_hsync => vga_hsync2,
        vga_vsync => vga_vsync2
    );
    modes_controller : process(clock)
    begin
        if rising_edge(clock) then
            case game_mode is
                when idle =>
                    if (switch(9) = '1') then
                        game_mode <= one_player;
                    elsif (switch(8) = '1') then
                        game_mode <= two_player;
                    end if;
                when one_player =>
                    if (switch(9) = '0') then
                        game_mode <= idle;
                    end if;

                    switch1 <= switch;
                    keys1 <= keys;
                    led_red <= led_red1;
                    led_green <= led_green1;
                    vga_red <= vga_red1;
                    vga_green <= vga_green1;
                    vga_blue <= vga_blue1;
                    vga_hsync <= vga_hsync1;
                    vga_vsync <= vga_vsync1;
                when two_player =>
                    if (switch(8) = '0') then
                        game_mode <= idle;
                    end if;

                    switch2 <= switch;
                    keys2 <= keys;
                    led_red <= led_red2;
                    led_green <= led_green2;
                    vga_red <= vga_red2;
                    vga_green <= vga_green2;
                    vga_blue <= vga_blue2;
                    vga_hsync <= vga_hsync2;
                    vga_vsync <= vga_vsync2;

            end case;
        end if;
    end process modes_controller;
end architecture behavioral;
