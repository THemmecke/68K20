*********************************************************
*                      GC.ASM                           *
* transportiert das GP an´s RAM-Ende                    *
*********************************************************


* KONSTANTEN

cpu     equ     4		* 1=68008, 2=68000, 4=68020
bank    equ     $ffffffc9*cpu   * Bankenregister

gpziel	equ	$3C0000		* fuer 68020 (4MB Vollausbau in NKC - 128K GP + 128KRAM hinter GP)
*gpziel	equ $....		* bei Verwendung der RAM Erweiterung und entsprechendem GP

bbziel   equ     $30000       * Zielbereich (RAM-Start) )für BBOOT Code (muss im RAM liegen)
							* RAM beginnt bei $20000 (>128KB)
				
gpstart equ     $100         * Startadresse des GP im EPROM (Offset $100 im EPROM)
gpsize  equ     $FFFE		* Laenge des GP in Worten(16Bit) = (128KB)


* Konstanten f. Seriell:
serbase         equ $FFFFFFF0*cpu
control         equ $FFFFFFF3*cpu
command         equ $FFFFFFF2*cpu
status          equ $FFFFFFF1*cpu
transmit        equ $FFFFFFF0*cpu
receive         equ $FFFFFFF0*cpu


*****

      ORG $0              	  * code fuer $0 erzeugen (EPROM)
      
      DC.L $11FFE              * dummy stack
      DC.L start                  * reset vector
       
start:

********* GP in's RAM kopieren **************
          		
        move.w #gpsize,d3
        lea gpziel,a0
        lea gpstart,a1         * Start Adresse des GPs im EPROM
gpmove:
        move.w (a1)+,(a0)+
        dbra d3,gpmove
        
        

*********************************************************
*                      BBOOT.ASM                        *
* bootet das GP im hinteren RAM Bereich und             *
* blendet das EPROM aus                                 *
*********************************************************

bboot:
        move #ende-anf-1,d3
        lea bbziel,a0
        lea anf(pc),a1

transport:
        move.b (a1)+,(a0)+
        dbra d3,transport
        
        
        jmp bbziel

anf:
boot:

        move.b #$80,bank
        


        
        lea gpziel,a0
loop:
        cmp.l #$5aa58001,(a0)
        beq.s gefunden
        adda.l #$4,a0
        bra.s loop

gefunden:




        cmp #$6000,$20(a0)
        bne.s loop
        cmp #$6000,$24(a0)
        bne.s loop
        jmp $24(a0)
        

ende:

