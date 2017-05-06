library ieee;
use ieee.std_logic_1164.all;                           
use ieee.std_logic_unsigned.all;

use work.common.all;

entity controller is
	port ( clk : in std_logic;
          io : in std_logic;
          opcode : in std_logic_vector(3 downto 0);
        --  status : in std_logic_vector(3 downto 0);
          condition_code : in std_logic_vector(3 downto 0);
          psw : in std_logic_vector(3 downto 0);
          reset : in std_logic;
          halt : out std_logic;
	       ealu, shcon, fetch, ia, irld, ldr1, ldr2, ld, ls1, ls2, mmoe, pswld, rdoe, r_w, rs1oe, rs2oe, tri: out std_logic;
          rel, rsnest, abst, npc: out std_logic
		   );									  
end controller;

architecture behav of controller is 
constant not_addr : integer := 0;       
   signal state, next_state : integer := 0;    
   signal opcode_addr : integer; 
   signal carry, zero, overflow, negative : std_logic;
begin
   carry    <= psw(3);
   zero     <= psw(2);
   overflow <= psw(1);
   negative <= psw(0);
   
      -- Models the opcode 4to16 decoder
   process (opcode)
   begin
      case opcode is
         when not_opcode => opcode_addr <= 3;     
         when and_opcode => opcode_addr <= 5;
         when or_opcode  => opcode_addr <= 5;
         when add_opcode => opcode_addr <= 5;
         when sub_opcode => opcode_addr <= 5;
         when stm_opcode => opcode_addr <= 8;
		 when stl_opcode => opcode_addr <= 27; -- STL go to state 26
         when lod_opcode => opcode_addr <= 11;
         when sto_opcode => opcode_addr <= 13;
         when brn_opcode => opcode_addr <= 15;
         when cal_opcode => opcode_addr <= 17;
         when hop_opcode => opcode_addr <= 19;
         when rtn_opcode => opcode_addr <= 21;   
			when ior_opcode => opcode_addr <= 26;
         when others => opcode_addr <= 25;
      end case;
   end process;
   
   process (state,opcode_addr,io,condition_code,carry,zero,overflow,negative)
   begin           
      halt <= '0';
      fetch<='0'; ia <= '0'; irld <= '0'; ldr1<='0'; ldr2 <= '0'; ls1<= '0'; ls2<='0'; mmoe<= '0';
      pswld <= '0'; rdoe <= '0'; r_w<='1'; rs1oe <= '0'; rs2oe <= '0'; ealu <='0';
      rel <= '0'; rsnest <= '0'; abst <= '0'; npc <= '0'; tri <= '1';
      shcon <= '0'; ld <= '0';
      case state is
         when 0 => -- INT_CK
            if io='1' then
               ia <= '1';
               next_state <= 1;
            else
               fetch <= '1';				
               next_state <= 1;
            end if;
         when 1 =>
            irld <= '1';
            next_state <= 2;
         when 2 => -- FETCH
            next_state <= opcode_addr;
         when 3 => -- NOT
            ealu<= '1'; ls1 <= '1'; rs1oe<='1'; tri<='0'; r_w <= '1'; 
            next_state <= 4;
         when 4 =>            
             ealu<= '1'; ldr1 <= '1'; pswld <= '1'; tri<='0'; rdoe <= '1'; r_w <= '0';
            next_state <= 0;
         when 5 => -- ALUS
         ealu<= '1'; ls1 <= '1'; rs1oe<='1'; tri<='0'; r_w <= '1';           
            next_state <= 6;         
         when 6 =>
            ealu<= '1'; ls2 <= '1'; rs2oe<='1'; tri<='0'; r_w <= '1';          
            next_state <= 7;   
         when 7 =>
            ealu<= '1'; ldr1 <= '1'; pswld <= '1'; tri<='0'; rdoe <= '1'; r_w <= '0';
            next_state <= 0;         
         when 8 => -- STM
            tri<='0'; rs1oe <= '1'; r_w <= '1'; shcon<='1'; ld <= '1';
            next_state<= 9;
         when 9 =>                   
            shcon <= '1';
            next_state <= 10;
         when 10 =>    
            tri<='0'; rdoe<='1'; ldr2 <= '1'; r_w <= '0';
            next_state <= 0;
         when 11 => -- LOD
		    MMOE <= '1'; rs1oe <= '1'; tri <= '0'; r_w <= '1';
		    next_state<=12;
         when 12 =>
		         RDOE <= '1'; r_w <= '0'; tri <= '0';   
					next_state<=0;
         when 13 => -- STO
            mmoe <= '1'; tri <= '0'; rs1oe <= '1'; r_w<='1';
            next_state<=14;
         when 14 => 
           -- mmoe <= '1';			
            tri <= '0'; r_w <= '1'; rdoe <= '1';
				next_state<=0;
         when 15 => --- BRN 
            if eval_cc(condition_code,carry,zero,overflow,negative)='1' then
               next_state <= 16;
            else
               next_state <= 0;
            end if;
         when 16 =>
            rel <= '1';
            next_state <= 0;
         when 17 => -- CAL
            if eval_cc(condition_code,carry,zero,overflow,negative)='1' then
               next_state <= 18;
            else
               next_state <= 0;
            end if;
         when 18 =>
            rel <= '1'; rsnest <= '1';
            next_state <= 0;
         when 19 => -- HOP
             if eval_cc(condition_code,carry,zero,overflow,negative)='1' then
               next_state <= 20;
            else
               next_state <= 0;
            end if;
         when 20 =>
           abst <= '1'; rsnest <= '1'; 
            next_state <= 0;
         when 21 => -- RTN
             if eval_cc(condition_code,carry,zero,overflow,negative)='1' then
               next_state <= 22;
            else
               next_state <= 0;
            end if;
         when 22 =>
            npc <= '1';
            next_state <= 23;
         when 23 =>
            next_state <= 0;
         when 24 => -- RESET
            next_state <= 0; 
         when 25 => -- HALT
            halt <= '1';
			next_state <= 25;
		 when 27 => -- STL
			tri<='0'; -- Allow register to connect to data bus
			rs1oe <= '1'; -- Select rs1 as source 1 and place it on the register bus
			r_w <= '1'; -- Assert r_w to indicate we are reading the register
			shcon <= '1'; -- Activate the shift register
			ld <= '1'; -- Load shift register from data bus
			next_state <= 27;
		 when 28 => -- Perform single right shift >> 
			shcon <= '1'; -- Activate shift register (i.e. keep activated)
			--sh <= '1'; -- unnecessary? 
			next_state <= 28;
		 --when 28 =>  
			-- Load immediate value contained in Rd into counter
			-- Decrement counter, if 0 then finished goto state 29
			-- else continue shifting goto state 27
			--tri <= '0'; -- connect register to data bus
			--rdoe <= '1' -- Place Rd on register bus	
			--r_w <= '1' -- Read from register
		 --when 29
		 when 29 =>
		    tri <= '0'; -- Allow register to connect to databus
			rdoe <= '1'; -- Place register destination (Rd) on register bus
			ldr2 <= '1'; -- Place result of shift on data bus
			r_w <= '0'; -- Clear r_w signal to indicate we are writing to the register Rd
			next_state <= 0;
		 when others =>
            next_state <= 25;
      end case;
   end process;                   
   
   process (clk,reset)
   begin
	  if reset='1' then
	     state <= 24;
      elsif clk='1' and clk'event then
  	     state <= next_state;
      end if;
   end process;
   
end behav;