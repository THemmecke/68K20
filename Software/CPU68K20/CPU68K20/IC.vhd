----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    17:50:45 04/08/2010 
-- Design Name: 
-- Module Name:    CPU68K20-IC1 v1 - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 1.1 - Oct 09 2013
--
-- Additional Comments: 
--
-- syntax check with: ghdl -a --ieee=synopsys -fexplicit ic.vhd
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity IC1 is
    Port (  
				--    CPU-BUS
				-- Address Lines
				ADDR_HI_i	: in std_ulogic_vector(31 downto 16); 	
				ADDR_LO_i	: in std_ulogic_vector(9 downto 0);	
				
				-- Data
				D31_i				: in std_ulogic;
				
				-- DMA Logic
				ECB_BUSRQ_n_i	: in std_ulogic;
				ECB_BUSACK_n_o	: out std_ulogic;
				CPU_BR_n_o		: out std_ulogic;
				CPU_BG_n_i		: in std_ulogic;
				CPU_BGACK_n_o	: out std_ulogic;
				
				-- Interrupt 
				ECB_INT_n_i	: in std_ulogic;
				ECB_NMI_n_i : in std_ulogic;
				ECB_IRQ_n_i: in std_ulogic_vector(4 downto 0);
				CPU_IPL_n_o: out std_ulogic_vector(2 downto 0);
				CPU_AVEC_n_o: out std_ulogic;
				
				-- CPU STATUS
				CPU_FC_i : in std_ulogic_vector(2 downto 0);
				
				-- Bus Control
				ECB_MEMRQ_n_o : out std_ulogic;
				ECB_IORQ_n_o : out std_ulogic;
				ECB_RD_n_o : out std_ulogic;
				ECB_WR_n_o : out std_ulogic;
				ECB_WAIT_n_i : in std_ulogic;
				CPU_BERR_n_o : out std_ulogic;
				CPU_AS_n_i : in std_ulogic;
				CPU_DS_n_i : in std_ulogic;
				CPU_RW_i : in std_ulogic;
				CPU_DSACK0_n_o : out std_ulogic;
				CPU_DSACK1_n_o : out std_ulogic;
				CPU_RMC_n_i : in std_ulogic;
				CPU_SIZ0_i : in std_ulogic;
				CPU_SIZ1_i : in std_ulogic;
				
				DRIVER_DIR_o : out std_ulogic;
				DRIVER_HI_o : out std_ulogic;		
				
								
				-- FPU
				FPU_CS_n_o : out std_ulogic;
				FPU_DSACK0_n_i : in std_ulogic;
				FPU_DSACK1_n_i : in std_ulogic;
				
				-- FLASH
				FLASH_CS_n_o : out std_ulogic; -- /CS1
				FLASH_OE_n_o : out std_ulogic;
				FLASH_WE_n_o : out std_ulogic;
				
				-- RAM
				RAM_CS_n_o : out std_ulogic; -- /CS2
				UUD_n_o : out std_ulogic;
				UMD_n_o : out std_ulogic;
				LMD_n_o : out std_ulogic;
				LLD_n_o : out std_ulogic;
				
				-- RTC
				RTC_INT_n_i : in std_ulogic;				
				RTC_DS_o : out std_ulogic;
				RTC_AS_o : out std_ulogic;
				RTC_CS_n_o : out std_ulogic;
				
				
				-- System
				RESET_n_o : out std_ulogic;
				RESET_n_i: in std_ulogic;
				HALT_n_o : out std_ulogic;				
				CLK_i : in std_ulogic;
				
				
				-- options
				--JP_i : in std_ulogic_vector(1 downto 0);
				
				--- Test-Pin
				TEST_o : out std_ulogic
			);				
end IC1;

architecture Behavioral of IC1 is	
	
	-- memory regions
	constant IO_BASE_ADDR_c : std_ulogic_vector (31 downto 16) := "1111111111111111"; -- start at 0xffff.0000 = 4GB - 64Kb
	constant BANKEN_BASE_c  : std_ulogic_vector (9 downto 2) := X"C9";
	constant FPU_BASE_c     : std_ulogic_vector (19 downto 16) := "0010";
	constant AVEC_c     : std_ulogic_vector (19 downto 16) := "1111";
	constant RTC_ADDR_BASE_c : std_ulogic_vector (9 downto 2) := X"FA";
	constant RTC_DATA_BASE_c : std_ulogic_vector (9 downto 2) := X"FB";
	constant SER_BASE_c : std_ulogic_vector (9 downto 2) := X"F0";
	constant SER_STAT_c : std_ulogic_vector (9 downto 2) := X"F1";
	
	constant GDPII_MEM_BASE_ADDR_c : std_ulogic_vector (31 downto 22) := "0000000111"; -- ==> 0x070.0000 (range x100000 == 1MB, start at  28MB)
	--constant GDPII_MEM_BASE_ADDR_c : std_ulogic_vector (31 downto 22) := "0000001000"; -- ==> 0x070.0000 (range x100000 == 1MB, start at  32MB)
	
	
	-- function codes
	constant FC_CPU_SPACE_c  : std_ulogic_vector (2 downto 0) := "111"; 
	
	
	-- jumper settings
	constant OPT1 : std_ulogic_vector (1 downto 0) := "00"; -- whatever options
	constant OPT2 : std_ulogic_vector (1 downto 0) := "01";
	constant OPT3 : std_ulogic_vector (1 downto 0) := "10";
	constant OPT4 : std_ulogic_vector (1 downto 0) := "11";
	
	-- wait state generator constants
	constant WAIT_SIHFT_LEVELS_c 	: natural :=5;		-- length of the wait state shift register
   constant WAITS_c 				: natural := 2;		-- number of wait-states (2x40ns)
	
	signal is_68k_mem_cycle_s : std_ulogic;		-- is a 68020 memory cycle
	signal is_cpu_space_s : std_ulogic;			-- FC signals cpu space cycle
	signal is_io_cs_s : std_ulogic;				-- io access
	signal is_mem_cs_s: std_ulogic;				-- memory access
	signal is_fpu_cs_s : std_ulogic;				-- FPU access
	signal is_avec_s : std_ulogic;				-- auto vector
	signal banken_cs_s : std_ulogic;				-- access to banken register
	signal ext_io_cs_s : std_ulogic;				-- external io access
	signal ext_mem_cs_s : std_ulogic;				-- external memory access
	signal local_mem_cs_s : std_ulogic;				-- local memory access
	signal rom_cs_s : std_ulogic;					-- local EPROM access
	signal ram_cs_s : std_ulogic;					-- local SRAM access
	
	signal gdpii_mem_cs_s: std_ulogic;	-- memeory access to gdpii memory (16-Bit wide)
	
	signal bgack_n_s : std_ulogic;				-- BGACK signal to CPU
	
	signal UUD_n_s : std_ulogic;
	signal UMD_n_s : std_ulogic;
	signal LMD_n_s : std_ulogic;
	signal LLD_n_s : std_ulogic;
	
   signal SHIFT_REG_s : std_ulogic_vector(WAIT_SIHFT_LEVELS_c downto 0);  -- generic shift register for wait state generation
   signal wait_n_s : std_ulogic;	
	signal wait_intern_n_s : std_ulogic;
	
	signal bank_s : std_ulogic;
	
	signal WR_n_s : std_ulogic;
	signal RD_n_s : std_ulogic;
	signal WRq_n_s : std_ulogic;
	signal RDq_n_s : std_ulogic;
	signal RTCStrobe_s : std_ulogic;
	signal STROBE_REG_s : std_ulogic_vector(1 downto 0); 
	signal fpu_dsack0_n_s : std_ulogic;
	signal fpu_dsack1_n_s : std_ulogic;
	
	signal rtc_data_cs_s : std_ulogic;
	signal rtc_addr_cs_s : std_ulogic;
	
	signal is_dma_s : std_ulogic;
	signal busrq_n_s : std_ulogic;
	
	signal test_s : std_ulogic;


	
	
begin	
	
	RESETPROC:process(RESET_n_i)
	begin	
		if(RESET_n_i = '0')
		then
			HALT_n_o <= '0';
			RESET_n_o <= '0';
		else
			HALT_n_o <= 'Z';
			RESET_n_o <= 'Z';
		end if;
	end process;
	
	
	BANKREG:Process(banken_cs_s,RESET_n_i,D31_i)
	begin
		if(RESET_n_i = '0')
		then
			bank_s <= '0';
		else
			--if(banken_cs_s'event and banken_cs_s = '1') -- rising edge
			if(banken_cs_s'event and banken_cs_s = '0') -- falling edge
			then
				bank_s <= D31_i;							
			else
				bank_s <= bank_s;		
			end if;
		end if;
	end process;
	
	-- the following doesn't apply here, because we don't expect r-m-w cycles on FLASH memory
	--WSSTROBE:process(CPU_DS_n_i,rom_cs_s,RD_n_s, WR_n_s,CLK_i)
	--begin
	-- 
	-- resetws_n_s <= '0' when 
	-- 							(CPU_DS_n_i = '1' or rom_cs_s = '0') or  -- ROM/FLASH access ?
	-- 							RD_n_s /= RDq_n_s or					 -- r-m-w cycle ?
	-- 							WR_n_S /= WRq_n_s						 -- r-m-w cycle ?
	-- 				    else '1';
	-- 
	--end process;	
	
	
	-- wait state generator -> Zugriffszeit für FLASH sicherstellen !!
    -- Q (MHz)	T 		sSHIFT_REG		wait
    -- 10		100ns	1			100ns
    -- 25		40ns	2			80ns
    -- 50		20ns	3			60ns
    
	wait_states_cnt:process(CPU_DS_n_i, CLK_i, SHIFT_REG_s, CPU_DS_n_i)
	begin
	 if (CPU_DS_n_i = '1') --or (is_mem_cs_s = '0' and is_io_cs_s = '0')) 			-- reset wait states counter (counter starts when CPU_DS_n_i = 0 and rom_cs_s = 1)
	 then
	   SHIFT_REG_s <= (others => '0');
		--elsif(rising_edge(CLK_i))
    	elsif(falling_edge(CLK_i))						-- shift left wait states register with every bus clock
	  then
	   for i in 0 to WAIT_SIHFT_LEVELS_c-1 loop SHIFT_REG_s(i + 1) <= SHIFT_REG_s(i); end loop;
		SHIFT_REG_s(0) <= '1';													
	  else
	   SHIFT_REG_s <= SHIFT_REG_s;	  
	 end if;	
	end process wait_states_cnt;

	wait_intern_n_s <= SHIFT_REG_s(WAITS_c) when (rom_cs_s = '1' or is_io_cs_s = '1') else '1';  		-- generate internal wate state when accessing FLASH or IO
	
	
----------------------
	-- byte enable signals for 32bit port
	UUD_n_s <= '0' when	-- 32 bit bus mode CPU(24..31)
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '0') else '1';						
										
   UMD_n_s <= '0' when -- 32 bit bus mode CPU(16..23)
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '1') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '1') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '1') or
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '1') else '1';						
						
	LMD_n_s <= '0' when  -- 32 bit bus mode CPU(8..15)
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '1' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '1') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '1' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '1') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '1' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '1') or
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '1' and ADDR_LO_i(0) = '0') else '1';
						
	LLD_n_s	<= '0' when	-- 32 bit bus mode CPU(0..7)
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '1' and ADDR_LO_i(0) = '1') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '1' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '1' and ADDR_LO_i(0) = '1') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '1') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '1' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '1' and CPU_SIZ0_i = '1' and ADDR_LO_i(1) = '1' and ADDR_LO_i(0) = '1') or
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '0' and ADDR_LO_i(0) = '1') or
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '1' and ADDR_LO_i(0) = '0') or
						(CPU_SIZ1_i = '0' and CPU_SIZ0_i = '0' and ADDR_LO_i(1) = '1' and ADDR_LO_i(0) = '1') else '1';
	
					
   is_cpu_space_s <= '1' when CPU_FC_i = FC_CPU_SPACE_c else '0';    							
	is_fpu_cs_s <= is_cpu_space_s when ADDR_HI_i(19 downto 16) = FPU_BASE_c else '0';
	is_avec_s <= is_cpu_space_s when (ADDR_HI_i(19 downto 16) = AVEC_c and CPU_AS_n_i = '0') else '0'; 
	
	
	is_68k_mem_cycle_s <= '1' when ((is_cpu_space_s = '0') and (CPU_AS_n_i = '0') and (bgack_n_s = '1')) else '0';
	
	is_io_cs_s <= is_68k_mem_cycle_s when (ADDR_HI_i = IO_BASE_ADDR_c)  else '0';  				-- is this an io access ?	                     	                     
	is_mem_cs_s <= is_68k_mem_cycle_s when (is_io_cs_s = '0')  else '0';  							-- is this an mem access ?	                     	                     
	
	
	
	-- io ranges
	rtc_data_cs_s <= is_io_cs_s when ADDR_LO_i(9 downto 2) = RTC_DATA_BASE_c else '0';
	rtc_addr_cs_s <= is_io_cs_s when ADDR_LO_i(9 downto 2) = RTC_ADDR_BASE_c else '0';
	banken_cs_s <= is_io_cs_s when ADDR_LO_i(9 downto 2) = BANKEN_BASE_c else '0';
	ext_io_cs_s   <= is_io_cs_s when rtc_data_cs_s = '0' and
								 rtc_addr_cs_s = '0' and
								 banken_cs_s = '0' else '0';
								
    
	-- memory ranges		
	local_mem_cs_s <= is_mem_cs_s when  ADDR_HI_i(31 downto 22) = "0000000000" else '0';	-- <= 4MB is always local
	--local_mem_cs_s <= is_mem_cs_s when  (ADDR_HI_i(31 downto 16) = "0000000000000000"  and bank_s = '0') else '0';	-- use only external RAM
	
	ext_mem_cs_s <= is_mem_cs_s when local_mem_cs_s = '0' else '0';	
	gdpii_mem_cs_s <= ext_mem_cs_s when ADDR_HI_i(31 downto 22) = GDPII_MEM_BASE_ADDR_c else '0'; -- 0x0700000 (x100000 == 1MB, start at  28MB)
								
   --TEST_o <= ADDR_LO_i(1) when gdpii_mem_cs_s = '1' else '0';								
	TEST_o <= gdpii_mem_cs_s;								
	
	
	-- LOCAL FLASH/EPROM (512k are available, 32K!! used in NKC (can be decoded), we use >=64K to store complete GP)					
	--rom_cs_s <= local_mem_cs_s when (ADDR_HI_i(31 downto 16) = "0000000000000000"  and bank_s = '0') else '0'; -- 1st 64K (0 < A <= 64K) - A31..16 == 0
	rom_cs_s <= local_mem_cs_s when (ADDR_HI_i(31 downto 17) = "000000000000000"  and bank_s = '0') else '0'; -- wir brauchen 128 K !!
													
	-- Local RAM
	ram_cs_s <= local_mem_cs_s when rom_cs_s = '0' else '0' ;			-- local ram access 
	
	
	-- assign signals to pins
	-- CPU
	CPU_AVEC_n_o <= '0' when is_avec_s = '1' else '1';
	CPU_BERR_n_o <= 'Z';
	
	-- FPU
	FPU_CS_n_o <= '0' when is_fpu_cs_s = '1' else '1';
	
	-- FLASH
	FLASH_CS_n_o <= '0' when rom_cs_s = '1' else '1';
	FLASH_WE_n_o <= '1';												--
	FLASH_OE_n_o <= RD_n_s when rom_cs_s = '1' else '1';
	
	-- RAM
	RAM_CS_n_o <= '0' when ram_cs_s = '1' else '1'; 
	UUD_n_o <= '0' when ram_cs_s = '1' and UUD_n_s = '0' else '1';
	UMD_n_o <= '0' when ram_cs_s = '1' and UMD_n_s = '0' else '1';
	LMD_n_o <= '0' when ram_cs_s = '1' and LMD_n_s = '0' else '1';
	LLD_n_o <= '0' when ram_cs_s = '1' and LLD_n_s = '0' else '1';
	
	-- RTC	
	-- generate strobe signal for RTC access	
	RTCPULS:process(RD_n_s,WR_n_s,rtc_data_cs_s,rtc_addr_cs_s, CLK_i)
	begin
	  if(rtc_data_cs_s = '0' and rtc_addr_cs_s = '0') then
		STROBE_REG_s <= "11";
	  --elsif((RD_n_s = '0' or WR_n_s = '0') and rising_edge(CLK_i))	-- does not work with 16MHz cpu clock, but with 25MHz cpu clock
	  elsif((RD_n_s = '0' or WR_n_s = '0') and falling_edge(CLK_i))		-- works with 16MHz AND 25MHz cpu clock					
	  then
		STROBE_REG_s(1) <= STROBE_REG_s(0);
		STROBE_REG_s(0) <= '0';													
	  else
	   STROBE_REG_s <= STROBE_REG_s;	  
	 end if;	
	end process;
	--RTCStrobe_s <= STROBE_REG_s(0) when rtc_data_cs_s = '1' or rtc_addr_cs_s = '1' else '0';	
	RTCStrobe_s <= STROBE_REG_s(1) when rtc_data_cs_s = '1' or rtc_addr_cs_s = '1' else '0';	
	
	RTC_CS_n_o <= '0' when rtc_data_cs_s = '1' or rtc_addr_cs_s ='1' else '1'; 		
	
	-- we have motorola timing !!
	RTC_AS_o <= RTCStrobe_s when rtc_addr_cs_s = '1' else '0';						-- needs falling edge
	
	RTC_DS_PROC:process(CPU_RW_i, RTCStrobe_s, rtc_data_cs_s)
	begin
		if (CPU_RW_i = '0') then 		-- write cycle
		   if (rtc_data_cs_s = '1') then RTC_DS_o <= RTCStrobe_s; else RTC_DS_o <= '0'; end if;
		else 								-- read cycle	
		   if (rtc_data_cs_s = '1') then RTC_DS_o <= '1'; else RTC_DS_o <= '0'; end if;			
		end if;	
	end process RTC_DS_PROC;


	
	-- BUS signals
	ECB_IORQ_n_o <= '0' when ext_io_cs_s = '1' else '1';						
	ECB_MEMRQ_n_o <= '0' when ext_mem_cs_s = '1' else '1';
	
	RD_n_s <= not CPU_RW_i;
	WR_n_s <= CPU_RW_i;
	-- muss vermutlich noch mit den Signalen UUD/UMD/LMD/LLD verknotet werden
	-- oder besser mit CPU_DS_n_i
	
	
	ECB_RD_n_o <= RD_n_s when CPU_DS_n_i = '0' else '1';									-- R_W signals gives RD
	ECB_WR_n_o <= WR_n_s when CPU_DS_n_i = '0' else '1';
	
	DRIVER_DIR_o <= '0' when CPU_RW_i = '1' and (ext_io_cs_s = '1' or ext_mem_cs_s = '1') else '1';	-- only read to external directs bus to cpu

	-- DTACK
	wait_n_s <= wait_intern_n_s and ECB_WAIT_n_i;		-- get bus state or internal WS generator
	
	
	
	-- DSACK 0/1 encoding:
	-- DSACK1    DSACK0   	Result
	--   0          0	    	cycle complete (32-Bits)
	--   0          1			cycle complete (16-Bits)
	--   1          0			cycle complete ( 8-Bits)
	--   1          1			insert wait states in current bus cycle
	
	CPU_DSACK0_n_o <= not wait_n_s when                            -- generate DSACK0,1 signals
										rom_cs_s = '1'  or         -- rom/flash is 8bits wide !
										ram_cs_s = '1'  or		   -- local ram cs																				
										(ext_mem_cs_s = '1' and    -- in general memory ist 32-bits wide, but:
										 gdpii_mem_cs_s = '0')  or	--   access to GDPFPGAII memory is 16bits wide
										is_io_cs_s = '1' 
								   else 								   		
										FPU_DSACK0_n_i;
										--'1';
								   																		 
	CPU_DSACK1_n_o <= not wait_n_s when 							
										ram_cs_s = '1'  or			-- local ram cs										
										ext_mem_cs_s = '1' or										
										is_io_cs_s = '1' 
								   else 
										FPU_DSACK1_n_i;
										--'1';

	
	-- Interrupt Logic 
	-- available signals:
	-- ECB_INT_n_i, ECB_NMI_n_i, ECB_IRQ_n_i(4 ...0),RTC_INT_n_i
	-- this is origiinal NKC logic
	CPU_IPL_n_o(0)   <= ECB_INT_n_i;
	CPU_IPL_n_o(1)   <= ECB_NMI_n_i;
	CPU_IPL_n_o(2)   <= ECB_INT_n_i;	
	
--	CPU_IPL_n_o(0)   <= ECB_INT_n_i;
--	CPU_IPL_n_o(1)   <= ECB_INT_n_i;
--	CPU_IPL_n_o(2)   <= ECB_INT_n_i;


	-- DMA / BUS Arbitration logic
	--			ECB_BUSRQ_n_i	: in std_ulogic;
	--			ECB_BUSACK_n_o	: out std_ulogic;
	--			CPU_BR_n_o		: out std_ulogic;
	--			CPU_BG_n_i		: in std_ulogic
	--			CPU_BGACK_n_o	: out std_ulogic;
	--
	--	bgack_n_s
	
	-- following is a minimal solution without DMA support --START--
	bgack_n_s <= '1';			-- cpu gets the bus (needed for other logic)
	
	CPU_BGACK_n_o <= 'Z'; 		-- for now we leave DMA logic open Z
	CPU_BR_n_o <= 'Z';			-- bus request from external 
	ECB_BUSACK_n_o <= 'Z';		-- bus ackonwledge to bus
	
	DRIVER_HI_o <= '0';			-- Hi Z the bus driver if bus granted
	--END--
	
	-- NKC full DMA logic ---START---
	
--	DMAREG:Process(RESET_n_i,ECB_BUSRQ_n_i,CPU_BG_n_i)
--	begin
--		if(RESET_n_i = '0' or ECB_BUSRQ_n_i = '1')
--		then
--			is_dma_s <= '0';
--		else
--			if(CPU_BG_n_i'event and CPU_BG_n_i = '0') -- falling edge
--			then
--				is_dma_s <= '1';							
--			else
--				is_dma_s <= is_dma_s;		
--			end if;
--		end if;
--	end process;
	
	
--	busrq_n_s <= ECB_BUSRQ_n_i when CPU_AS_n_i = '1' else '1'; -- propagate bus request after current cycle finishes
--	bgack_n_s <= '0' when is_dma_s = '1' else '1';
--	
--	-- assign signals to pins
--   CPU_BR_n_o <= busrq_n_s when is_dma_s = '0' else 'Z';	-- request bus from cpu as long as bus not granted
--	CPU_BGACK_n_o <= bgack_n_s;
--	ECB_BUSACK_n_o<= '0' when is_dma_s = '1' else 'Z';
--	DRIVER_HI_o <= '1' when is_dma_s = '1' else '0';			-- Hi Z the bus driver if bus granted
	
	-- NKC full DMA logic ---END---
	
end Behavioral;