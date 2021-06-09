library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

entity gba_bus_testbench is
end gba_bus_testbench;

architecture behavior of gba_bus_testbench is
    signal not_chip_select : std_logic;
    signal not_read_enable : std_logic;
    signal address_low_data : std_logic_vector(15 downto 0);
    signal address_high : std_logic_vector(7 downto 0);
    signal bus_address : std_logic_vector(23 downto 0);
    signal bus_data : std_logic_vector(15 downto 0);

    -- AXI signals
    signal ACLK : std_logic;
    signal ARESETn : std_logic;

    -- AXI Read Address Ports
    signal ARVALID : std_logic;
    signal ARREADY : std_logic;
    signal ARADDR : std_logic_vector(31 downto 0);

    -- AXI Read Data Ports
    signal RVALID : std_logic;
    signal RREADY : std_logic;
    signal RDATA : std_logic_vector(31 downto 0);

    signal ADDR : std_logic_vector(31 downto 0);

    type axi_state_t is (state_wait, state_read_data, state_read_finish);
    signal axi_state : axi_state_t := state_wait;

begin
    gba_bus_0 : entity work.gba_bus 
                port map( not_chip_select => not_chip_select,
                          not_read_enable => not_read_enable,
                          address_low_data => address_low_data,
                          address_high => address_high,
                          ACLK => ACLK,
                          ARESETn => ARESETn,
                          ARVALID => ARVALID,
                          ARREADY => ARREADY,
                          ARADDR => ARADDR,
                          RVALID => RVALID,
                          RREADY => RREADY,
                          RDATA => RDATA
                          );
    

    clock_proc: process
        constant period : time := 10 ns;
    begin
        ACLK <= '0';
        wait for period/2;
        ACLK <= '1';
        wait for period/2;
    end process clock_proc;

    axi_proc: process(ACLK, ARESETn)
        type memory_t is array(0 to 15) of std_logic_vector(31 downto 0);
        variable cart_rom : memory_t := 
                                        (0 => x"0000_0010",
                                         1 => x"DEAD_BEEF",
                                         2 => x"0000_0012",
                                         3 => x"0000_0001",
                                         others => x"0000_0000");
    begin
        if ARESETn = '0' then
        elsif rising_edge(ACLK) then
            case axi_state is
                when state_wait =>
                    ARREADY <= '1';
                    if ARVALID = '1' then
                        ADDR <= ARADDR;
                        axi_state <= state_read_data;
                    end if;
                when state_read_data =>
                    ARREADY <= '0';
                    RDATA <= cart_rom(to_integer(unsigned(ADDR(4 downto 2))));
                    RVALID <= '1';
                    if RREADY <= '1' then
                        axi_state <= state_read_finish;
                    end if;
                when state_read_finish =>
                    RVALID <= '0';
                    axi_state <= state_wait;
            end case;
        end if;
    end process axi_proc;

    test_proc: process
        constant test_addr : unsigned(23 downto 0) := to_unsigned(2, bus_address'length);
        constant period : time := 1000 ns;
    begin
        ARESETn <= '0';
        not_chip_select <= '1';
        not_read_enable <= '1';
        wait for period;
        ARESETn <= '1';
        wait for period;
        address_low_data <= std_logic_vector(test_addr(15 downto 0));
        address_high <= std_logic_vector(test_addr(23 downto 16));
        wait for period;
        not_chip_select <= '0';
        wait for period;
        address_low_data <= (others => 'Z');
        not_read_enable <= '1';
        wait for period;
        not_read_enable <= '0';
        wait for period;
        not_read_enable <= '1';
        wait for period;
        not_read_enable <= '0';
        wait for period;
        not_read_enable <= '1';
        wait for period;
        not_read_enable <= '0';
        wait for period;
        not_read_enable <= '1';
        finish;
    end process test_proc;
end behavior;
