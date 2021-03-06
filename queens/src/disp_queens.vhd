--------------------------------------------------------------------------------
-- Company: 	    Granbo
-- Engineer:	    Michael Jørgensen
--
-- Create Date:    
-- Design Name:    
-- Module Name:     disp_cells
-- Project Name:   
-- Target Device:  
-- Tool versions:  
-- Description:	    Generates a background VGA image.
--
--------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.bitmap_pkg.ALL;

entity disp_queens is
    generic (
        NUM_QUEENS: integer
        );
    port (
        vga_clk_i : in  std_logic; -- Currently not used

        hcount_i  : in  std_logic_vector(11 downto 0);
        vcount_i  : in  std_logic_vector(11 downto 0);
        blank_i   : in  std_logic;

        board_i   : in  std_logic_vector(NUM_QUEENS*NUM_QUEENS-1 downto 0);
        vga_o     : out std_logic_vector(11 downto 0)
		);
end disp_queens;

architecture Behavioral of disp_queens is

    constant OFFSET_X : integer := 450;
    constant OFFSET_Y : integer := 150;

    type bitmaps_vector is array(natural range <>) of bitmap_t;
    constant bitmaps : bitmaps_vector(0 to 9) := (
        bitmap_grey, bitmap_1, bitmap_2, bitmap_3, bitmap_4,
        bitmap_5, bitmap_6, bitmap_7, bitmap_8, bitmap_9);

begin

    gen_vga : process (hcount_i, vcount_i, blank_i, board_i) is

        constant SIZE   : integer := 32;

        variable hcount : integer range 0 to 1688;
        variable vcount : integer range 0 to 1066;
        variable col    : integer range 0 to NUM_QUEENS;
        variable row    : integer range 0 to NUM_QUEENS;
        variable xdiff  : integer range 0 to SIZE-1;
        variable ydiff  : integer range 0 to SIZE-1;
        variable bitmap : bitmap_t;

    begin
        hcount := conv_integer(hcount_i);
        vcount := conv_integer(vcount_i);
        col    := 0;
        row    := 0;
        xdiff  := 0;
        ydiff  := 0;
        vga_o  <= (others => '0');

        if blank_i = '0' then -- in the active screen
            if hcount >= offset_x and hcount < offset_x + SIZE * NUM_QUEENS
            and vcount >= offset_y and vcount < offset_y + SIZE * NUM_QUEENS then
                col   := (hcount - OFFSET_X) / SIZE;
                row   := (vcount - OFFSET_Y) / SIZE;
                xdiff := (hcount - OFFSET_X) - col*SIZE;
                ydiff := (vcount - OFFSET_Y) - row*SIZE;
                if (row rem 2) = (col rem 2) then
                    vga_o <= "101010101010";  -- light grey
                else
                    vga_o <= "010101010101";  -- dark grey
                end if;
                if board_i(row*NUM_QUEENS + col) = '1' then
                    case bitmap_queen((ydiff/2)*16 + (xdiff/2)) is
                        when "01"   => vga_o <= "110011001100";
                        when "00"   => vga_o <= "001000100010";
                        when others => null;
                    end case;
                end if;
            end if;

            if hcount >= offset_x and hcount <= offset_x + SIZE * NUM_QUEENS + 1
            and vcount >= offset_y and vcount <= offset_y + SIZE * NUM_QUEENS + 1 then
                col   := (hcount - OFFSET_X) / SIZE;
                row   := (vcount - OFFSET_Y) / SIZE;
                xdiff := (hcount - OFFSET_X) - col*SIZE;
                ydiff := (vcount - OFFSET_Y) - row*SIZE;

                if xdiff = 0 or xdiff = 1 then
                    vga_o <= "111111111111"; -- white
                end if;   

                if ydiff = 0 or ydiff = 1 then
                    vga_o <= "111111111111"; -- white
                end if;   
            end if;   
        end if;   

    end process gen_vga;

end Behavioral;

