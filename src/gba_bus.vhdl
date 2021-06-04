library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gba_bus is
    port( -- GBA ports
          not_chip_select : in std_logic;
          not_read_enable : in std_logic;
          address_low_data : inout std_logic_vector(15 downto 0);
          address_high : std_logic_vector(7 downto 0);

          -- AXI Control Ports
          ACLK : in std_logic;
          ARESETn : in std_logic;

          -- AXI Read Address Ports
          ARVALID : out std_logic;
          ARREADY : in std_logic;
          ARADDR : out std_logic_vector(31 downto 0);

          -- AXI Read Data Ports
          RVALID : in std_logic;
          RREADY : out std_logic;
          RDATA : in std_logic_vector(31 downto 0)
          );
end gba_bus;

architecture behavior of gba_bus is
    signal address : unsigned(23 downto 0);
    signal last_address : unsigned(23 downto 0);
    signal data : unsigned(15 downto 0);
    signal bus_data : std_logic_vector(15 downto 0);
    signal axi_bus_data : std_logic_vector(31 downto 0);
    
    signal chip_select_n : std_logic_vector(1 downto 0);
    signal read_enable_n : std_logic_vector(1 downto 0);

    -- Define state machine for accessing AXI bus
    type axi_state_t is (state_start_read_addr, 
                         state_wait_addr_ready,
                         state_wait_read_data,
                         state_wait_read_data_valid,
                         state_end_read_data,
                         state_wait);
    signal current_axi_state : axi_state_t; 
begin

    -- Logic to control tri-state status of the lower address bits
    -- TODO validate that the FPGA drives the lower address biits when
    -- chip select is enabled
    address_low_data <= std_logic_vector(data) when (chip_select_n(0) = '0')
                                               else (others => 'Z');

    -- Logic to sample chip select and read enable
    sample_proc: process(ARESETn, ACLK)
    begin
        if ARESETn = '0' then
            chip_select_n <= (others => '1');
            read_enable_n <= (others => '1');
        elsif rising_edge(ACLK) then
            chip_select_n(1) <= chip_select_n(0);
            chip_select_n(0) <= not_chip_select;

            read_enable_n(1) <= read_enable_n(0);
            read_enable_n(0) <= not_read_enable;
        end if;
    end process sample_proc;

    -- Logic to control latching and incrementing the address
    address_proc: process(ARESETn, ACLK)
    begin
        if ARESETn = '0' then
            -- Initalize last_address and address with a fixed starting
            -- value so they both contain the exact same value
            last_address <= to_unsigned(123, address'length);
            address <= to_unsigned(123, address'length);       
        elsif rising_edge(ACLK) then
            -- If this is the falling edge of chip select then we want
            -- to latch in the address coming from the GBA bus
            if chip_select_n = "10" then
                last_address <= address;
                address <= unsigned(address_high & address_low_data);

            -- If this is the falling edge of the read enable then we
            -- we want to increment the internal address counter and
            -- output data we we read from the AXI bus
            elsif read_enable_n = "10" then
                last_address <= address;
                address <= address + to_unsigned(1, address'length); 
                data <= unsigned(bus_data);
            end if;
        end if;
    end process address_proc;

    -- Logic to move data from IO
    comb_proc: process(axi_bus_data)
    begin
        -- Since AXI is 32bit, and the GBA has a 16bit bus
        -- We need to figure out which half of the 32bit data
        -- the GBA is trying to read
        if address(0) = '0' then
            bus_data <= axi_bus_data(15 downto 0);
        else
            bus_data <= axi_bus_data(31 downto 16);
        end if;
    end process comb_proc;

    -- Logic for AXI state machine
    axi_proc: process(ACLK, ARESETn)
    begin
        if ARESETn = '0' then
            current_axi_state <= state_wait;
            ARVALID <= '0';
            RREADY <= '0';
        elsif rising_edge(ACLK) then
            case current_axi_state is
                -- When the state is wait, we wait until the address the GBA requested is different
                -- then we start the AXI state machine to make a read request from memory
                when state_wait =>
                    if last_address /= address then
                        current_axi_state <= state_start_read_addr;
                    end if;
                when state_start_read_addr =>
                    -- TODO add logic to add offset to ARADDR value
                    -- Zero out bottom two bits, so we are always reading a valid 32bit address
                    ARADDR <= std_logic_vector(address(23 downto 2)) & "00";
                    ARVALID <= '1';

                    -- Memory may be ready to read the address immediatley, in this case
                    -- we want to jump right to the data phase on the same clock cycle, instead
                    -- of waiting an extra clock cycle for the ARREADY signal to be asserted
                    if ARREADY = '1' then
                        current_axi_state <= state_wait_read_data;
                    else
                        current_axi_state <= state_wait_addr_ready;
                    end if;
                when state_wait_addr_ready =>
                    if ARREADY = '1' then
                        current_axi_state <= state_wait_read_data;
                    end if;
                when state_wait_read_data =>
                    -- Here we deassert the ARVALID signal so memory does not think
                    -- another address request is incoming. we also tell AXI
                    -- we are ready to read the data
                    ARVALID <= '0';
                    RREADY <= '1';
                    -- Valid may be asserted on the same clock cycle so check if
                    -- read data bus is valid right now
                    if RVALID = '1' then
                        axi_bus_data <= RDATA;
                        current_axi_state <= state_end_read_data;
                    else
                        current_axi_state <= state_wait_read_data_valid;
                    end if;
                when state_wait_read_data_valid =>
                    if RVALID = '1' then
                        axi_bus_data <= RDATA;
                        current_axi_state <= state_end_read_data;
                    end if;
                when state_end_read_data =>
                    -- We are now done the AXI transaction, put ourselves back
                    -- into the wait state, so that we are prepared for the next
                    -- request coming from the GBA
                    RREADY <= '0';
                    current_axi_state <= state_wait;
            end case;
        end if;
    end process axi_proc;
end behavior;
