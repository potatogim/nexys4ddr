library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

-- This module connects to the LAN8720A Ethernet PHY. The PHY supports the RMII specification.
--
-- From the NEXYS 4 DDR schematic
-- RXD0/MODE0   : External pull UP
-- RXD1/MODE1   : External pull UP
-- CRS_DV/MODE2 : External pull UP
-- RXERR/PHYAD0 : External pull UP
-- MDIO         : External pull UP
-- LED2/NINTSEL : According to note on schematic, the PHY operates in REF_CLK in Mode (ETH_REFCLK = 50 MHz). External pull UP.
-- LED1/REGOFF  : Floating (LOW)
-- NRST         : External pull UP
--
-- This means:
-- MODE    => All capable. Auto-negotiation enabled.
-- PHYAD   => SMI address 1
-- REGOFF  => Internal 1.2 V regulator is ENABLED.
-- NINTSEL => nINT/REFCLKO is an active low interrupt output.
--            The REF_CLK is sourced externally and must be driven
--            on the XTAL1/CLKIN pin.
--
-- All signals are connected to BANK 16 of the FPGA, except: eth_rstn_o and eth_clkin_o are connected to BANK 35.
--
-- When transmitting, packets must be preceeded by an 8-byte preamble
-- in hex: 55 55 55 55 55 55 55 D5
-- Each byte is transmitted with LSB first.
-- Frames are appended with a 32-bit CRC, and then followed by 12 bytes of interpacket gap (idle).

entity ethernet is

   port (
      clk50_i      : in    std_logic;        -- Must be 50 MHz

      -- Pulling interface
      data_i       : in    std_logic_vector(7 downto 0);
      sof_i        : in    std_logic;
      eof_i        : in    std_logic;
      empty_i      : in    std_logic;
      rden_o       : out   std_logic;

      -- Connected to PHY
      eth_txd_o    : out   std_logic_vector(1 downto 0);
      eth_txen_o   : out   std_logic;
      eth_rxd_i    : in    std_logic_vector(1 downto 0);
      eth_rxerr_i  : in    std_logic;
      eth_crsdv_i  : in    std_logic;
      eth_intn_i   : in    std_logic;
      eth_mdio_io  : inout std_logic;
      eth_mdc_o    : out   std_logic;
      eth_rstn_o   : out   std_logic;
      eth_refclk_o : out   std_logic         -- Connected to XTAL1/CLKIN. Must be driven to 50 MHz.
                                             -- All RMII signals are syunchronous to this clock.
   );
end ethernet;

architecture Structural of ethernet is

   signal eth_txen   : std_logic := '0';
   signal eth_mdc    : std_logic := '0';  -- Not used at the moment.
   signal eth_rstn   : std_logic := '0';  -- Assert reset by default.

   -- Minimum reset assert time is 25 ms. At 50 MHz (= 20 ns) this is approx 10^6 clock cycles.
   -- Here we have 21 bits, corresponding to approx 2*10^6 clock cycles, i.e. 40 ms.
--   signal rst_cnt    : std_logic_vector(20 downto 0) := (others => '1');   -- Set to all-ones, to start the count down.
   signal rst_cnt    : std_logic_vector(20 downto 0) := (others => '0');   -- Set to all-ones, to start the count down.

   -- State machine to control the MAC framing
   type t_fsm_state is (IDLE_ST, PRE1_ST, PRE2_ST, PAYLOAD_ST, CRC_ST, IFG_ST);
   signal fsm_state : t_fsm_state := IDLE_ST;

   signal byte_cnt   : integer range 0 to 12;
   signal cur_byte   : std_logic_vector(7 downto 0) := X"00";
   signal twobit_cnt : std_logic_vector(1 downto 0) := "00";

begin

   -- Generate PHY reset
   proc_eth_rstn : process (clk50_i)
   begin
      if rising_edge(clk50_i) then
         if rst_cnt /= 0 then
            rst_cnt <= rst_cnt - 1;
         else
            eth_rstn <= '1';              -- Clear reset
         end if;
      end if;
   end process proc_eth_rstn;

   -- Generate MAC framing
   proc_mac : process (clk50_i)
   begin
      if rising_edge(clk50_i) then
         rden_o   <= '0';

         twobit_cnt <= twobit_cnt + 1;
         cur_byte   <= "00" & cur_byte(7 downto 2);

         if twobit_cnt = 0 then        -- Only change state on a byte boundary.
            case fsm_state is
               when IDLE_ST    =>
                  eth_txen <= '0';
                  if empty_i = '0' then
                     assert sof_i = '1' report "Missing SOF" severity failure;
                     byte_cnt  <= 7;
                     cur_byte  <= X"55";
                     fsm_state <= PRE1_ST;
                     eth_txen  <= '1';
                  end if;

               when PRE1_ST    =>
                  cur_byte  <= X"55";
                  if byte_cnt = 1 then
                     byte_cnt  <= 1;
                     cur_byte  <= X"D5";
                     fsm_state <= PRE2_ST;
                  else
                     byte_cnt <= byte_cnt - 1;
                  end if;

               when PRE2_ST    =>
                  cur_byte  <= data_i;
                  rden_o    <= '1';
                  fsm_state <= PAYLOAD_ST;

                  -- Abort! Data not available yet.
                  if empty_i = '1' then
                     fsm_state <= IFG_ST;
                     rden_o    <= '0';
                  end if;

               when PAYLOAD_ST =>
                  cur_byte <= data_i;
                  rden_o   <= '1';
                  if eof_i = '1' then
                     byte_cnt  <= 4;
                     fsm_state <= CRC_ST;
                  end if;

                  -- Abort! Data not available yet.
                  if empty_i = '1' then
                     fsm_state <= IFG_ST;
                     rden_o    <= '0';
                  end if;

               when CRC_ST     =>
                  cur_byte  <= X"55";           -- TBD
                  if byte_cnt = 1 then
                     byte_cnt  <= 11;           -- Only 11 octets, because the next state is always the idle state.
                     fsm_state <= IFG_ST;
                     eth_txen  <= '0';
                  else
                     byte_cnt <= byte_cnt - 1;
                  end if;

               when IFG_ST     =>
                  if byte_cnt = 1 then
                     fsm_state <= IDLE_ST;
                  else
                     byte_cnt <= byte_cnt - 1;
                  end if;

            end case;
         end if;
      end if;
   end process proc_mac;


   -- Drive output signals
   eth_refclk_o <= clk50_i;
   eth_txd_o    <= cur_byte(1 downto 0);
   eth_txen_o   <= eth_txen;
   eth_mdc_o    <= eth_mdc;
   eth_rstn_o   <= eth_rstn;

end Structural;

