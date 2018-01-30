*********************************************************
*                      GC.ASM                           *
* transportiert das GP an´s RAM-Ende                    *
* D = Debug Version, gibt Meldungen an SER aus          *
*********************************************************


* KONSTANTEN

cpu     equ     4		* 1=68008, 2=68000, 4=68020
bank    equ     $ffffffc9*cpu   * Bankenregister

gpziel	equ	$3C0000		* fuer 68020 (4MB Vollausbau in NKC - 128K GP + 128KRAM hinter GP)
*gpziel	equ $....		* bei Verwendung der RAM Erweiterung und entsprechendem GP

bbziel   equ     $30000       * Zielbereich (RAM-Start) )für BBOOT Code (muss im RAM liegen)
							* RAM beginnt bei $20000 (>128KB)
				
gpstart equ     $200         * Startadresse des GP im EPROM (Offset $200 im EPROM)
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

					
initser:						* Iinitialisiert Serielle Schnittstelle (DEBUG)

        move.b #$1E,control       * 8N1,9600 init
        move.b #$0B,command       * no parity, rec/trans enable, no IRQ, no
        
******************* MELDUNG AN SER AUSGEBEN ********************        
        lea HELLOMSG(pc),a0    * zu sendenden string nach A0

text01_1:  		move.b (A0)+,transmit * ein zeichen an ser ausgeben
        		beq.s text01_3			* ende falls =0

                lea text01_2(pc),a5   * Rücksprungadresse nach a5                
                lea txwait(pc),a1
                jmp (a1)                     * Unterprogramm anspringen (wart
text01_2:
        		bra text01_1
text01_3:        		
**************************************************************************
        
        
********* GP in's RAM kopieren **************
          		
        move.w #gpsize,d3
        lea gpziel,a0
        lea gpstart,a1         * Start Adresse des GPs im EPROM
gpmove:
        move.w (a1)+,(a0)+
        dbra d3,gpmove
        
        
        
******************* MELDUNG AN SER AUSGEBEN ********************        
        		lea STEP1(pc),a0    * zu sendenden string nach A0

text02_1:  		move.b (A0)+,transmit * ein zeichen an ser ausgeben
        		beq.s text02_3			* ende falls =0

                lea text02_2(pc),a5   * Rücksprungadresse nach a5                
                lea txwait(pc),a1
                jmp (a1)                     * Unterprogramm anspringen (wart
text02_2:
        		bra text02_1
text02_3:        		
**************************************************************************
        
        
         jmp bboot

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
        
        

******************* MELDUNG AN SER AUSGEBEN ********************        
        		lea STEP2(pc),a0    * zu sendenden string nach A0

text03_1:  		move.b (A0)+,transmit * ein zeichen an ser ausgeben
        		beq.s text03_3			* ende falls =0

                lea text03_2(pc),a5   * Rücksprungadresse nach a5                
                lea txwait(pc),a1
                jmp (a1)                     * Unterprogramm anspringen (wart
text03_2:
        		bra text03_1
text03_3:        		
**************************************************************************
        
        jmp bbziel

anf:
boot:


******************* MELDUNG AN SER AUSGEBEN ********************        
        		lea STEP3(pc),a0    * zu sendenden string nach A0

text04_1:  		move.b (A0)+,transmit * ein zeichen an ser ausgeben
        		beq.s text04_3			* ende falls =0

                lea text04_2(pc),a5   * Rücksprungadresse nach a5                
                lea txwait(pc),a1
                jmp (a1)                     * Unterprogramm anspringen (wart
text04_2:
        		bra text04_1
text04_3:        		
**************************************************************************

        move.b #$80,bank
        


******************* MELDUNG AN SER AUSGEBEN ********************        
        		lea STEP3(pc),a0    * zu sendenden string nach A0

text05_1:  		move.b (A0)+,transmit * ein zeichen an ser ausgeben
        		beq.s text05_3			* ende falls =0

                lea text05_2(pc),a5   * Rücksprungadresse nach a5                
                lea txwait(pc),a1
                jmp (a1)                     * Unterprogramm anspringen (wart
text05_2:
        		bra text05_1
text05_3:        		
**************************************************************************
        
        lea gpziel,a0
loop:
        cmp.l #$5aa58001,(a0)
        beq.s gefunden
        adda.l #$4,a0
        bra.s loop

gefunden:



******************* MELDUNG AN SER AUSGEBEN ********************        
        		lea STEP5(pc),a0    * zu sendenden string nach A0

text06_1:  		move.b (A0)+,transmit * ein zeichen an ser ausgeben
        		beq.s text06_3			* ende falls =0

                lea text06_2(pc),a5   * Rücksprungadresse nach a5                
                lea txwait(pc),a1
                jmp (a1)                     * Unterprogramm anspringen (wart
text06_2:
        		bra text06_1
text06_3:        		
**************************************************************************

        cmp #$6000,$20(a0)
        bne.s loop
        cmp #$6000,$24(a0)
        bne.s loop
        jmp $24(a0)
        

ende:

txwait: 		btst.b #4,status                * Unterprogramm: warten bis tx leer
                beq txwait
                jmp (a5)    

* Texte

HELLOMSG: DC.B '68020 Bootloader...',$d,$a,0
STEP1:    DC.B 'moving bootstrap...',$d,$a,0
STEP2:	  DC.B 'jump to boostrap...',$d,$a,0
STEP3:    DC.B 'switch BANKENREG...',$d,$a,0
STEP4:    DC.B 'search GP in RAM...',$d,$a,0
STEP5:    DC.B 'found GP , jump...',$d,$a,0

