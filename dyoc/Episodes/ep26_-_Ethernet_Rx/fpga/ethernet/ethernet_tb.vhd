library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- This module is a test bench for the Ethernet module.

entity ethernet_tb is
end entity ethernet_tb;

architecture Structural of ethernet_tb is

   -- Controls the traffic input to Ethernet.
   signal data  : std_logic_vector(128*8-1 downto 0);
   signal len   : std_logic_vector(15 downto 0);
   signal start : std_logic;
   signal done  : std_logic;

   -- Connected to DUT
   signal user_clk       : std_logic;  -- 25 MHz
   signal user_wren      : std_logic;
   signal user_addr      : std_logic_vector(15 downto 0);
   signal user_data      : std_logic_vector( 7 downto 0);
   signal user_memio_in  : std_logic_vector(55 downto 0);
   signal user_memio_out : std_logic_vector(55 downto 0);
   signal eth_clk        : std_logic;  -- 50 MHz
   signal eth_rst        : std_logic;
   signal eth_txd        : std_logic_vector(1 downto 0);
   signal eth_txen       : std_logic;
   signal eth_rxd        : std_logic_vector(1 downto 0);
   signal eth_crsdv      : std_logic;

   -- memio config
   signal user_rxdma_start  : std_logic_vector(15 downto 0);    -- Start of buffer.
   signal user_rxdma_end    : std_logic_vector(15 downto 0);    -- End of buffer.
   signal user_rxdma_rdptr  : std_logic_vector(15 downto 0);    -- Current CPU read pointer.
   signal user_rxdma_enable : std_logic;                        -- DMA enable.

   -- memio status
   signal user_dma_wrptr    : std_logic_vector(15 downto 0);
   signal user_cnt_good     : std_logic_vector(15 downto 0);
   signal user_cnt_error    : std_logic_vector( 7 downto 0);
   signal user_cnt_crc_bad  : std_logic_vector( 7 downto 0);
   signal user_cnt_overflow : std_logic_vector( 7 downto 0);

   -- This defines a type containing an array of bytes
   type ram_t is array (0 to 4095) of std_logic_vector(7 downto 0);

   -- Initialize memory contents
   signal ram : ram_t := (others => (others => '0'));

   signal ram_clear : std_logic := '0';

begin

   -- Compose user_memio_in signal
   user_memio_in(15 downto  0) <= user_rxdma_start;
   user_memio_in(31 downto 16) <= user_rxdma_end;
   user_memio_in(47 downto 32) <= user_rxdma_rdptr;
   user_memio_in(48)           <= user_rxdma_enable;
   user_memio_in(55 downto 49) <= (others => '0');

   -- Decompose user_memio_out signal
   user_dma_wrptr    <= user_memio_out(15 downto  0);
   user_cnt_good     <= user_memio_out(31 downto 16);
   user_cnt_error    <= user_memio_out(39 downto 32);
   user_cnt_crc_bad  <= user_memio_out(47 downto 40);
   user_cnt_overflow <= user_memio_out(55 downto 48);

   -- Generate user clock 25 MHz
   proc_user_clk : process
   begin
      user_clk <= '1', '0' after 2 ns;
      wait for 4 ns;
   end process proc_user_clk;

   -- Generate eth clock 50 MHz
   proc_eth_clk : process
   begin
      eth_clk <= '1', '0' after 1 ns;
      wait for 2 ns;
   end process proc_eth_clk;

   -- Generate eth clock 50 MHz
   proc_eth_rst : process
   begin
      eth_rst <= '1', '0' after 10 ns;
      wait;
   end process proc_eth_rst;


   -- Instantiate RAM
   proc_ram : process (user_clk)
   begin
      if rising_edge(user_clk) then
         if user_wren = '1' then
            assert user_addr(15 downto 12) = X"2";
            ram(conv_integer(user_addr(11 downto 0))) <= user_data;
         end if;
         if ram_clear = '1' then
            ram <= (others => (others => 'X'));
         end if;
      end if;
   end process proc_ram;

   -- Instantiate traffic generator
   inst_sim_tx : entity work.sim_tx
   port map (
      clk_i      => eth_clk,
      rst_i      => eth_rst,
      data_i     => data,
      len_i      => len,
      start_i    => start,
      done_o     => done,
      eth_txd_o  => eth_rxd,
      eth_txen_o => eth_crsdv
   );


   -- Instantiate DUT
   inst_ethernet : entity work.ethernet
   port map (
      user_clk_i   => user_clk,
      user_wren_o  => user_wren,
      user_addr_o  => user_addr,
      user_data_o  => user_data,
      user_memio_i => user_memio_in,
      user_memio_o => user_memio_out,
      eth_clk_i    => eth_clk,
      eth_txd_o    => eth_txd,
      eth_txen_o   => eth_txen,
      eth_rxd_i    => eth_rxd,
      eth_rxerr_i  => '0',
      eth_crsdv_i  => eth_crsdv,
      eth_intn_i   => '0',
      eth_mdio_io  => open,
      eth_mdc_o    => open,
      eth_rstn_o   => open,
      eth_refclk_o => open
   );
   
   proc_test : process
   begin
      -- Clear RAM
      ram_clear <= '1';
      wait until user_clk = '1';
      ram_clear <= '0';

      -- Prepare for DMA configuration
      user_rxdma_enable <= '0';
      wait until user_clk = '1';

      -- Configure DMA
      user_rxdma_start <= X"2000";
      user_rxdma_end   <= X"2000" + 200;
      user_rxdma_rdptr <= X"2000";
      wait until user_clk = '1';
      user_rxdma_enable <= '1';
      wait until user_clk = '1';

      assert user_dma_wrptr = X"2000";

      -- Wait while test runs
      for i in 0 to 127 loop
         data(8*i+7 downto 8*i) <= std_logic_vector(to_unsigned(i+32, 8));
      end loop;
      len   <= X"0011";
      start <= '1';
      wait until done = '1';

      wait for 60 ns;
      assert user_cnt_good     = 0;
      assert user_cnt_error    = 0;
      assert user_cnt_crc_bad  = 0;
      assert user_cnt_overflow = 1;

   end process proc_test;

end Structural;
