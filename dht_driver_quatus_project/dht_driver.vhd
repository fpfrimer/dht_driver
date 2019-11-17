-- To do: header

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dht_driver is
    generic(
        f_in        :   integer := 50_000_000                           -- Input frequency generic        
    );
    port (        
        clk, rst    :   in      std_logic;                              -- Clock and reset        
        data        :   inout   std_logic;                              -- DHT data pin        
        req         :   in      std_logic;                              -- Requisition pin
        busy        :   out     std_logic;                              -- Busy flag 
        isvalid     :   out     std_logic;                              -- Checksum verification flag
        reading     :   out     std_logic_vector(31 downto 0)           -- Binary output result data                            
    ) ;
end dht_driver;

architecture main of dht_driver is

    -----------------------------------------------------------------------------------------------
    -- Constants
    -----------------------------------------------------------------------------------------------
    constant f_op        :   integer := 500_000;                             -- Operation frequency
    
    -----------------------------------------------------------------------------------------------
    -- DHT state machine types and signals
    -----------------------------------------------------------------------------------------------

    -- DHT state machine type and signal:
    type dht_state_t is (
        START, 
        WAIT_RQ, 
        START_SIGNAL_L, 
        START_SIGNAL_H,
        DHT_RESPONSE_L,
        DHT_RESPONSE_H,
        DHT_RECEIVE_ZERO,
        DHT_RECEIVE_DATA,
        DHT_CHECKSUM
    );
    signal dht_state : dht_state_t;
    signal enable  :    std_logic;

begin
    
    -- Clock management
    clock_management : process( clk )
        variable i : integer range 0 to f_in / f_op;
    begin
        if rising_edge(clk) then
            if i = f_in / f_op - 1 then
                enable <= '1';
                i := 0;
            else
                enable <= '0';
                i := i + 1;
            end if;
        end if;
    end process ; -- clock_management

    -- DHT data pin control process
    data_control : process( dht_state )
    begin
        case( dht_state ) is
        
            when START_SIGNAL_L =>
                data <= '0';

            when START_SIGNAL_H =>
                data <= '1';
        
            when others =>
                data <= 'Z';
        
        end case ;
    end process ; -- data_control
    
    -- Busy flag control process
    busy_control : process( dht_state )
    begin
        case( dht_state ) is
        
            when WAIT_RQ =>
                busy <= '0';
        
            when others =>
                busy <= '1';
        end case ;
    end process ; -- busy_control

    -----------------------------------------------------------------------------------------------
    -- DHT state machine
    -----------------------------------------------------------------------------------------------
    
    -- State machine only process
    dht_sm : process( clk, rst, data, req )
        variable i : integer range 0 to 2*f_in := 0; -- Counter
        variable n : integer range 0 to 40 := 0;
        variable bit_stream : unsigned(39 downto 0);

        alias rh_int   : unsigned(7 downto 0) is bit_stream(39 downto 32);
        alias rh_dec   : unsigned(7 downto 0) is bit_stream(31 downto 24);
        alias tp_int   : unsigned(7 downto 0) is bit_stream(23 downto 16);
        alias tp_dec   : unsigned(7 downto 0) is bit_stream(15 downto 8);
        alias checksum : unsigned(7 downto 0) is bit_stream(7 downto 0);
    begin
        if rst = '0' then
            i := 0;            
            n := 0;
            bit_stream := (others => '0');
            reading <= (others => '0');
            dht_state <= START;
            isvalid <= '0';            
        elsif rising_edge(clk) then
            if enable = '1' then
                case( dht_state ) is
                
                    when START =>
                        if i = f_op*2 then  -- Wait ~2 s
                            i := 0;
                            dht_state <= WAIT_RQ;
                        else
                            i := i + 1;
                            dht_state <= START;
                        end if;                    
                    
                    when WAIT_RQ =>                    
                        if req = '0' then                        
                            isvalid <= '0';
                            dht_state <= START_SIGNAL_L; 
                        else
                            dht_state <= WAIT_RQ;                    
                        end if ;

                    when START_SIGNAL_L => 
                        isvalid <= '0';
                        if i = f_op/50 then -- Wait ~20 ms
                            i := 0;
                            dht_state <= START_SIGNAL_H;
                        else
                            i := i + 1;
                            dht_state <= START_SIGNAL_L;                      
                        end if ;

                    when START_SIGNAL_H =>                    
                        if i = f_op/50_000 then -- Wait ~20 us
                            i := 0;
                            dht_state <= DHT_RESPONSE_L;
                        else
                            i := i + 1;
                            dht_state <= START_SIGNAL_H;
                        end if;                    
                    
                    when DHT_RESPONSE_L =>
                        
                        if i = f_op/20000 then -- Wait ~50 us 
                            if data = '1' then
                                i := 0;
                                dht_state <= DHT_RESPONSE_H;
                            end if;
                        else
                            i := i + 1;
                            dht_state <= DHT_RESPONSE_L;
                        end if;

                    when DHT_RESPONSE_H =>
                        
                        
                        if data = '0' then
                            dht_state <= DHT_RECEIVE_ZERO;
                        else
                            dht_state <= DHT_RESPONSE_H;
                        end if;
                        

                    when DHT_RECEIVE_ZERO =>
                        
                        if data = '1' then                
                            dht_state <= DHT_RECEIVE_DATA;
                        else
                            dht_state <= DHT_RECEIVE_ZERO;
                        end if;
                                            
                    when DHT_RECEIVE_DATA =>
                        dht_state <= DHT_CHECKSUM;                                                                            
                        if data = '0' then
                            n := n + 1;                     
                            dht_state <= DHT_RECEIVE_ZERO;                                                                          
                            if i < f_op/25_000 then  -- ~40 us
                                bit_stream := bit_stream (38 downto 0) & '0';                            
                            elsif i < f_op/4_000 then -- 80 us
                                bit_stream := bit_stream (38 downto 0) & '1';                            
                            end if;
                            i := 0;
                        else
                            i := i + 1;
                            dht_state <= DHT_RECEIVE_DATA;
                            if i > f_op/2_000 then                                
                                reading <= std_logic_vector(bit_stream(39 downto 8));
                                bit_stream := (others => '0');
                                if n = 40 then
                                    dht_state <= DHT_CHECKSUM;
                                else
                                    dht_state <= START;
                                end if;
                                i := 0;
                                n := 0;
                            end if;

                        end if;

                    when DHT_CHECKSUM =>                    
                        if checksum = rh_int+rh_dec+tp_int+tp_dec then                                 
                            isvalid <= '1';
                        else 
                            isvalid <= '0';
                        end if; 
                        dht_state <= START;

                    when others =>
                        null;
                
                end case ;
            end if;
        end if;
    end process ; -- dht_sm
end main ; -- main