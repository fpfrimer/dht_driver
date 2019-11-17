-- To do: header

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dht_driver is
    generic(f_in        :   integer := 50_000_000);
    port (
        -- Clock and reset:
        clk, rst    :   in      std_logic;

        -- DHT data pin:
        data        :   inout   std_logic;

        -- Requisition pin
        req         :   in      std_logic;

        busy        :   out     std_logic;

        isvalid     :   out     std_logic;

        reading     :   out     std_logic_vector(31 downto 0);

        state       :   out     std_logic_vector(3 downto 0);

        debug       :   out     std_logic;

        it          :   out     integer range 0 to 39

        -- Displays for debuging:
        --HEX3        :   out     std_logic_vector(0 to 6);
        --HEX2        :   out     std_logic_vector(0 to 6);
        --HEX1        :   out     std_logic_vector(0 to 6);
        --HEX0        :   out     std_logic_vector(0 to 6)        
                      
    ) ;
end dht_driver;

architecture main of dht_driver is
    
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

    
    

    signal debug_t :    std_logic;


begin
    
    debug <= debug_t;

    with dht_state select
        state <= x"0" when START,
                 x"1" when WAIT_RQ,
                 x"2" when START_SIGNAL_L,
                 x"3" when START_SIGNAL_H,
                 x"4" when DHT_RESPONSE_L,
                 x"5" when DHT_RESPONSE_H,
                 x"6" when DHT_RECEIVE_ZERO,
                 x"7" when DHT_RECEIVE_DATA,
                 x"8" when DHT_CHECKSUM,
                 x"F" when others;

    
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
    
    dth_sm : process( clk, rst, data, req )
        variable i,j,k,l,m : integer range 0 to 2*50_000_000 := 0; -- Counter
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
            j := 0;
            k := 0;
            l := 0;
            m := 0;
            n := 0;
            bit_stream := (others => '0');
            reading <= (others => '0');
            dht_state <= START;
            isvalid <= '0';            
        elsif rising_edge(clk) then
            
            case( dht_state ) is
            
                when START =>
                    if j = f_in*2 then  -- Wait ~2 s
                        j := 0;
                        dht_state <= WAIT_RQ;
                    else
                        j := j + 1;
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
                    if k = f_in/50 then -- Wait ~20 ms
                        k := 0;
                        dht_state <= START_SIGNAL_H;
                    else
                        k := k + 1;
                        dht_state <= START_SIGNAL_L;                      
                    end if ;

                when START_SIGNAL_H =>                    
                    if l = f_in/40_000 then -- Wait ~25 us
                        l := 0;
                        dht_state <= DHT_RESPONSE_L;
                    else
                        l := l + 1;
                        dht_state <= START_SIGNAL_H;
                    end if;                    
                
                when DHT_RESPONSE_L =>
                    
                    if m = f_in/20000 then -- Wait ~50 us 
                        if data = '1' then
                            m := 0;
                            dht_state <= DHT_RESPONSE_H;
                        end if;
                    else
                        m := m + 1;
                        dht_state <= DHT_RESPONSE_L;
                    end if;

                when DHT_RESPONSE_H =>
                    
                    --if i = f_in/20000 then -- Wait ~50 us
                        if data = '0' then
                            --i := 0;
                            --n := 0;
                            dht_state <= DHT_RECEIVE_ZERO;
                        else
                            dht_state <= DHT_RESPONSE_H;
                        end if;
                    --else
                    --    i := i + 1;
                    --end if;

                when DHT_RECEIVE_ZERO =>
                    --debug_t <= '0';
                    --if i = f_in/50000 then -- Wait ~20 us
                        if data = '1' then                
                            dht_state <= DHT_RECEIVE_DATA;
                        else
                            dht_state <= DHT_RECEIVE_ZERO;
                        end if;
                        
                    --else
                    --    i := i + 1;
                    --end if;
                    
                when DHT_RECEIVE_DATA =>
                    debug_t <= '0';
                    dht_state <= DHT_CHECKSUM;                                                                            
                    if data = '0' then
                        n := n + 1;
                        it <= n; 
                        --it <= to_integer(bit_stream(31 downto 24));
                        dht_state <= DHT_RECEIVE_ZERO;                                                                          
                        if i < f_in/25_000 then  -- ~40 us
                            --debug_t <= '0';
                            --bit_stream(39 - n) := '0';
                            bit_stream := bit_stream (38 downto 0) & '0';
                            --bit_stream <= '1' & bit_stream (39 downto 1);
                        elsif i < f_in/4_000 then -- 80 us
                            
                            --debug_t <= '1';
                            --bit_stream(39 - n) := '0';
                            bit_stream := bit_stream (38 downto 0) & '1';
                            --bit_stream <= '0' & bit_stream (39 downto 1);               
                            
                        end if;
                        i := 0;
                    else
                        i := i + 1;
                        dht_state <= DHT_RECEIVE_DATA;
                        if i > f_in/2_000 then
                            i := 0;
                            debug_t <= '1';
                            n := 0;
                            reading <= std_logic_vector(bit_stream(39 downto 8));
                            bit_stream := (others => '0');
                            dht_state <= DHT_CHECKSUM;
                        end if;

                    end if;
                    
                    

                when DHT_CHECKSUM =>
                    --debug_t <= '0';
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
    end process ; -- dth_sm
end main ; -- main