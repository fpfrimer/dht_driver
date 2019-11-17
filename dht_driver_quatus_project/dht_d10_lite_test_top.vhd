library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dht_d10_lite_test_top is
    port(
        MAX10_CLK1_50   :   in      std_logic;
        KEY             :   in      std_logic_vector(1 downto 0);
        GPIO            :   inout   std_logic_vector(26 downto 26);
        HEX5            :   out     std_logic_vector(0 to 6);
        HEX4            :   out     std_logic_vector(0 to 6);
        HEX3            :   out     std_logic_vector(0 to 6);
        HEX2            :   out     std_logic_vector(0 to 6);
        HEX1            :   out     std_logic_vector(0 to 6);
        HEX0            :   out     std_logic_vector(0 to 6);
        LEDR            :   out     std_logic_vector(5 downto 0);
        SW              :   in      std_logic_vector(0 downto 0);
        ARDUINO_IO      :   out     std_logic_vector(0 downto 0)
    );
end entity;

architecture arch of dht_d10_lite_test_top is

    function bcd_to_7seg(
		data	:	std_logic_vector(3 downto 0)) 
	return std_logic_vector is
	begin
	
		case data is
			when "0000" => return "0000001"; -- "0"     
			when "0001" => return "1001111"; -- "1" 
			when "0010" => return "0010010"; -- "2" 
			when "0011" => return "0000110"; -- "3" 
			when "0100" => return "1001100"; -- "4" 
			when "0101" => return "0100100"; -- "5" 
			when "0110" => return "0100000"; -- "6" 
			when "0111" => return "0001111"; -- "7" 
			when "1000" => return "0000000"; -- "8"     
            when "1001" => return "0000100"; -- "9"
            when "1010" => return "0001000"; -- a
            when "1011" => return "1100000"; -- b
            when "1100" => return "0110001"; -- C                
            when "1101" => return "1000010"; -- d
            when "1110" => return "0110000"; -- E
            when "1111" => return "0111000"; -- F
			when others => return "1111111";			
		end case;	
	end function;

    alias clk : std_logic is MAX10_CLK1_50;
    alias rst : std_logic is KEY(0);
    alias req : std_logic is KEY(1);
    alias data : std_logic is GPIO(26);
    alias busy : std_logic is LEDR(0);
    alias isvalid : std_logic is LEDR(1);
    alias sel : std_logic is SW(0);
    alias debug :std_logic is ARDUINO_IO(0);
    alias state : std_logic_vector(3 downto 0) is LEDR(5 downto 2);

    signal reading : std_logic_vector(31 downto 0);

    alias rh_int   : std_logic_vector(7 downto 0) is reading(31 downto 24);
    alias rh_dec   : std_logic_vector(7 downto 0) is reading(23 downto 16);
    alias tp_int   : std_logic_vector(7 downto 0) is reading(15 downto 8);
    alias tp_dec   : std_logic_vector(7 downto 0) is reading(7 downto 0);

    signal it       :   integer range 0 to 39;

    signal clk1 :   std_logic;
    

begin

    u1: entity work.dht_driver(main)
        generic map(50_000_000)
        port map(clk1, rst, data, req, busy, isvalid, reading, state, debug, it);
    u2: entity work.pll(SYN) port map(clk, clk1);

    it_process : process( it )
        variable d, u : integer range 0 to 9;
    begin

        d := it/10;
        u := it mod 10;

        HEX5 <= bcd_to_7seg(std_logic_vector(to_unsigned(d,4)));
        HEX4 <= bcd_to_7seg(std_logic_vector(to_unsigned(u,4)));
        
    end process ; -- it_process
    
    
    display : process( sel, reading )
    begin
        case( sel ) is
        
            when '0' =>
                HEX3 <= bcd_to_7seg(rh_int(7 downto 4));
                HEX2 <= bcd_to_7seg(rh_int(3 downto 0));
                HEX1 <= bcd_to_7seg(rh_dec(7 downto 4));
                HEX0 <= bcd_to_7seg(rh_dec(3 downto 0));
            
            when '1' =>
                HEX3 <= bcd_to_7seg(tp_int(7 downto 4));
                HEX2 <= bcd_to_7seg(tp_int(3 downto 0));
                HEX1 <= bcd_to_7seg(tp_dec(7 downto 4));
                HEX0 <= bcd_to_7seg(tp_dec(3 downto 0));
        
            when others =>
                null;
        end case ;
    end process ; -- display

end arch ; -- arch