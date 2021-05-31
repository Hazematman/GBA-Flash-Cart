library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gba_bus is
    port( not_chip_select : in std_logic;
          not_read_enable : in std_logic;
          address_low_data : inout std_logic_vector(15 downto 0);
          address_high : std_logic_vector(7 downto 0);
          bus_address : out std_logic_vector(23 downto 0);
          bus_data : in std_logic_vector(15 downto 0);
          reset : in std_logic);
end gba_bus;

architecture behavior of gba_bus is
    signal address : unsigned(23 downto 0);
    signal data : unsigned(15 downto 0);
begin

    address_low_data <= std_logic_vector(data) when (not_chip_select = '0')
                                               else (others => 'Z');

    -- Logic to control latching and incrementing the address
    address_proc: process(reset, not_chip_select, not_read_enable)
    begin
        if(reset = '1') then
            address <= to_unsigned(0, address'length);
        elsif(falling_edge(not_chip_select)) then
            address <= unsigned(address_high & address_low_data);
        elsif(falling_edge(not_read_enable)) then
            address <= address + to_unsigned(1, address'length); 
            data <= unsigned(bus_data);
        end if;
    end process address_proc;

    -- Logic to move data from IO
    comb_proc: process(address)
    begin
        bus_address <= std_logic_vector(address);
    end process comb_proc;
end behavior;
