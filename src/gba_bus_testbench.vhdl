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
    signal reset : std_logic;
begin
    gba_bus_0 : entity work.gba_bus 
                port map( not_chip_select => not_chip_select,
                          not_read_enable => not_read_enable,
                          address_low_data => address_low_data,
                          address_high => address_high,
                          bus_address => bus_address,
                          bus_data => bus_data,
                          reset => reset);

    test_proc: process
        type memory_t is array(0 to 15) of std_logic_vector(15 downto 0);
        variable cart_rom : memory_t := 
                                        (0 => x"0010",
                                         1 => x"0011",
                                         2 => x"0012",
                                         3 => x"0001",
                                         others => x"0000");
        constant test_addr : unsigned(23 downto 0) := to_unsigned(2, bus_address'length);
        constant period : time := 1 ns;
    begin
        not_chip_select <= '1';
        not_read_enable <= '1';
        reset <= '1';
        wait for period;
        reset <= '0';
        wait for period;
        address_low_data <= std_logic_vector(test_addr(15 downto 0));
        address_high <= std_logic_vector(test_addr(23 downto 16));
        wait for period;
        not_chip_select <= '0';
        wait for period;
        assert (unsigned(bus_address) = test_addr); 
        bus_data <= cart_rom(to_integer(unsigned(bus_address(15 downto 0))));
        address_low_data <= (others => 'Z');
        not_read_enable <= '0';
        wait for period;
        assert (unsigned(bus_address) = (test_addr+1));
        not_read_enable <= '1';
        wait for period;
        report "data bus_data=" & to_hstring(bus_data) & 
               " address_low_data=" & to_hstring(address_low_data);
        assert (address_low_data = bus_data);
        bus_data <= cart_rom(to_integer(unsigned(bus_address(15 downto 0))));
        wait for period;
        -- Test the we read incremented array when read is pulsed again
        not_read_enable <= '0';
        wait for period;
        assert (unsigned(bus_address) = (test_addr+2));
        not_read_enable <= '1';
        wait for period;
        report "data bus_data=" & to_hstring(bus_data) & 
               " address_low_data=" & to_hstring(address_low_data);
        assert (address_low_data = bus_data);
        bus_data <= cart_rom(to_integer(unsigned(bus_address(15 downto 0))));
        finish;
    end process test_proc;
end behavior;
