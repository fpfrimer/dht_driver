library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dht_d10_lite_test_top is
    port(
        MAX10_CLK1_50   :   in      std_logic;
        KEY             :   in      std_logic_vector(1 downto 0);
        GPIO            :   inout   std_logic_vector(26 downto 26);
        HEX5            :   out     std_logic_vector(0 to 7);
        HEX4            :   out     std_logic_vector(0 to 7);
        HEX3            :   out     std_logic_vector(0 to 7);
        HEX2            :   out     std_logic_vector(0 to 7);
        HEX1            :   out     std_logic_vector(0 to 7);
        HEX0            :   out     std_logic_vector(0 to 7);
        LEDR            :   out     std_logic_vector(5 downto 0);
        SW              :   in      std_logic_vector(0 downto 0);
        ARDUINO_IO      :   out     std_logic_vector(0 downto 0)
    );
end entity;

architecture arch of dht_d10_lite_test_top is

    function bcd_to_7seg(
		data	:	std_logic_vector(3 downto 0); dot : std_logic)
	return std_logic_vector is
	begin
	
        case data is
            when "0000" => return "0000001" & not dot; -- "0"     
            when "0001" => return "1001111" & not dot; -- "1" 
            when "0010" => return "0010010" & not dot; -- "2" 
            when "0011" => return "0000110" & not dot; -- "3" 
            when "0100" => return "1001100" & not dot; -- "4" 
            when "0101" => return "0100100" & not dot; -- "5" 
            when "0110" => return "0100000" & not dot; -- "6" 
            when "0111" => return "0001111" & not dot; -- "7" 
            when "1000" => return "0000000" & not dot; -- "8"     
            when "1001" => return "0000100" & not dot; -- "9"
            when "1010" => return "0001000" & not dot; -- a
            when "1011" => return "1100000" & not dot; -- b
            when "1100" => return "0110001" & not dot; -- C                
            when "1101" => return "1000010" & not dot; -- d
            when "1110" => return "0110000" & not dot; -- E
            when "1111" => return "0111000" & not dot; -- F
            when others => return "1111111" & not dot;			
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

    signal it       :   integer range 0 to 40;

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

        HEX5 <= bcd_to_7seg(std_logic_vector(to_unsigned(d,4)),'0');
        HEX4 <= bcd_to_7seg(std_logic_vector(to_unsigned(u,4)),'0');
        
    end process ; -- it_process


    
    display : process( sel, reading )
        variable data   :   integer range 0 to 65535;
        variable c, d, u, dec   :   integer range 0 to 9;
        variable temp   :   integer range 0 to 9999;
    begin
        case( sel ) is
        
            when '0' => -- RH
                data := to_integer(unsigned(reading(31 downto 16)));
                c := data / 1000;
                temp := data - c*1000;
                d := temp / 100;
                temp := temp - d*100;
                u := temp / 10;
                dec := temp mod 10;

                HEX3 <= bcd_to_7seg(std_logic_vector(to_unsigned(c,4)),'0');
                HEX2 <= bcd_to_7seg(std_logic_vector(to_unsigned(d,4)),'0');
                HEX1 <= bcd_to_7seg(std_logic_vector(to_unsigned(u,4)),'1');
                HEX0 <= bcd_to_7seg(std_logic_vector(to_unsigned(dec,4)),'0');
                
            
            when '1' => -- Temp
                data := to_integer(unsigned(reading(15 downto 0)));
                if reading(15) = '0' then
                    c := data / 1000;
                    temp := data - c*1000;
                    d := temp / 100;
                    temp := temp - d*100;
                    u := temp / 10;
                    dec := temp mod 10;

                    HEX3 <= bcd_to_7seg(std_logic_vector(to_unsigned(c,4)),'0');
                    HEX2 <= bcd_to_7seg(std_logic_vector(to_unsigned(d,4)),'0');
                    HEX1 <= bcd_to_7seg(std_logic_vector(to_unsigned(u,4)),'1');
                    HEX0 <= bcd_to_7seg(std_logic_vector(to_unsigned(dec,4)),'0');

                else
                    c := data / 1000;
                    temp := data - c*1000;
                    d := temp / 100;
                    temp := temp - d*100;
                    u := temp / 10;
                    dec := temp mod 10;

                    HEX3 <= "00000010"; -- Negative
                    HEX2 <= bcd_to_7seg(std_logic_vector(to_unsigned(d,4)),'0');
                    HEX1 <= bcd_to_7seg(std_logic_vector(to_unsigned(u,4)),'1');
                    HEX0 <= bcd_to_7seg(std_logic_vector(to_unsigned(dec,4)),'0');
                    
                end if;
                
        
            when others =>
                null;
        end case ;
    end process ; -- display

end arch ; -- arch