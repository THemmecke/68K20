http://wiki.osdev.org/ATA_PIO_Mode
http://src.gnu-darwin.org/src/sys/sys/ata.h.html

*******************************************************************************
*                         680xx Grundprogramm ideio                           *
*                             2014 Jens Mewes                                 *
*                               V 7.10 Rev 6                                  *
*                                15.02.2014                                   *
*                            IDE-Disk-Routinen                                *
*******************************************************************************


idetest:                        * Test, ob Laufwerk vorhanden
                                * d4 enthaelt Laufwerk
 btst.b #5,keydil(a5)           * IDE vorhanden ?
 beq.s hderr                    * Nein, dann Fehler
 tst.b d4
 beq.s hderr                    * Kein LW angegeben
 and.b #$0f, d4
 movem.l d1-d4/a1/a6, -(a7)
 cmp.b #1, d4
 bne.s idt01
 lea idemgeo(a5), a6            * Variablenspeicher LW1
 move #$a0, d4                  * d4 jetzt Master-Flag
 bra.s idt02
idt01:                          * Slave-Laufwerk
 cmp.b #2, d4
 bne.s idterr                   * kein gueltiges Laufwerk
 lea idesgeo(a5), a6            * Variablenspeicher Slave
 move #$b0, d4                  * d4 jetzt Slave-Flag
idt02:
 bsr ideid                      * LW Identifizieren
 tst d0
 bmi.s idterr                   * Fehler bei Identifizieren
 bsr ideinit                    * LW initialisieren
 tst d0
 bmi.s idterr                   * Fehler beim Initialisieren
 movea.l a6, a0
 movem.l (a7)+, d1-d4/a1/a6
bra carres

idterr:
 movem.l (a7)+, d1-d4/a1/a6
 bra.s hderr

ideid:                          * Identifiziert ein Laufwerk
 move.b d4, idesdh.w            * Master / Slave
idlp01:
 clr numcyl(a6)                 * LW-Parameter löschen
 clr.b numhead(a6)
 clr.b numsec(a6)
 bsr idewr
 tst d0
 bmi idlp20
 move.b #cmdident, idecmd.w     * LW Identifizierung
 bsr idewd                      * Daten bereit?
 tst d0
 bmi idlp20                     * nein, dann Fehler
 lea idebuff(a5),a0             * Puffer für Transfer
 lea idedat.w, a1
 move #512-1, d3
idlp04:
 move.b (a1), (a0)+             * Ident-Daten einlesen
 dbra d3, idlp04
 bsr idewr                      * LW fertig?
 tst d0
 bmi idlp20                     * nein, dann Fehler
 lea idebuff(a5),a0             * Puffer für Transfer
 clr.l d0
 move.b 3(a0), d0               * Zylinder High-Byte
 lsl #8, d0
 move.b 2(a0), d0               * Zylinder Low-Byte
 move d0, numcyl(a6)            * speichern
 clr.l d0
 move.b 6(a0), numhead(a6)      * Anzahl der Köpfe
 move.b 12(a0), numsec(a6)      * Anzahl der Sektoren/Spur
 movea.l a6, a1
 adda.l #idename, a1            * a1 auf LW-Name-Speicher
 adda.l #54, a0                 * A0 auf Namensquelle
 move #12-1, d3                 * nur die ersten 24 Zeichen
idlp10:
 move.b 1(a0), (a1)+            * Transfer mit Byteswap
 move.b 0(a0), (a1)+
 addq.l #2, a0
 dbra d3, idlp10
 move #$0, (a1)+                * noch ne 0 zum Abschluss
 clr d0
 bra.b idex
idlp20:
 move #-1, d0
idex:
 rts

ideinit:                        * Initialisiert das Laufwerk
 move.b #6, idedor.w
 move.l #255, d3
ideilp01:
 dbra d3, ideilp01              * ein bisschen warten
 move.b #2, idedor.w
 bsr idewr                      * LW bereit?
 tst d0
 beq.b ideilp03                 * ja
 bra ideierr
ideilp03:
 move.b numsec(a6), idescnt.w   * Anzahl Sektoren
 move.b numcyl+1(a6), ideclo.w  * Zylinder Low-Byte
 move.b numcyl(a6), idechi.w    * Zylinder High-Byte
 move.b numhead(a6), d0         * Anzahl Köpfe
 subq.b #1, d0                  * -1
 or.b d4, d0                    * mit LW Kennung verodert
 move.b d0, idesdh.w            * und ausgeben
 move.b #cmdinit, idecmd.w      * nun weis das LW was es ist ;)
ideiex:
 clr d0
 rts
ideierr:
 move #-1, d0
 rts

idediski:                       * interne IDE IO-Routine
 moveq #1, d0                   * 1024 BPS
 bra.s idedisk1

idedisk:                        * IDE IO-Routine
 moveq #0, d0                   * 512 BPS
idedisk1:
 btst.b #5,keydil(a5)           * IDE vorhanden ?
 beq hderr                      * Nein, dann Fehler
 movem.l d1-d5/a0-a3/a6, -(a7)
 bsr.s idecomm                  * Hauptroutine aufrufen
 movem.l (a7)+, d1-d5/a0-a3/a6
rts

idebeftab:                      * Tabelle der Befehle
 dc.w ideok-idebeftab           * Auf Track 0
 dc.w idebef1-idebeftab         * Sektor lesen (d2.l/d3.b/a0.l)
 dc.w idebef2-idebeftab         * Sektor schreiben (d2.l/d3.b/a0.l)
 dc.w idenok-idebeftab          * Sektor + ECC lesen (d2.l/a0.l)
 dc.w idenok-idebeftab          * Sektor + ECC schreiben (d2.l/a0.l)
 dc.w ideok-idebeftab           * Mode auswählen (d2.b/a0.l)
 dc.w ideok-idebeftab           * Parameter des Laufwerks lesen (d2.b/d3.b/a0.l)
 dc.w ideok-idebeftab           * Sektor suchen (d2.l)
 dc.w idebef8-idebeftab         * Laufwerk breit ?
 dc.w ideok-idebeftab           * Park
 dc.w ideok-idebeftab           * Unpark
 dc.w idenok-idebeftab          * Sektor lesen (d2.l/d3.w/a0.l)
 dc.w idenok-idebeftab          * Sektor schreiben (d2.l/d3.w/a0.l)
 dc.w idenok-idebeftab          * Buffer lesen (d2.w/a0.l)
 dc.w idenok-idebeftab          * Buffer schreiben (d2.w/a0.l)
 dc.w ideok-idebeftab           * Einheit reservieren (d2.w/d3.w/a0.l)
 dc.w ideok-idebeftab           * Einheit freigeben (d2.w)
 dc.w idenok-idebeftab          * Sektoren schreiben und prüfen (d2.l/d3.w/a0.l)
 dc.w idenok-idebeftab          * Sektor prüfen (d2.l/d3.w)
 dc.w ideok-idebeftab           * Diagnostic senden
 dc.w idenok-idebeftab          * Sektor suchen (d2.l)
 dc.w ideok-idebeftab           * Zähler-Statistik lesen (a0.l)
 dc.w idebef22-idebeftab        * Größe der Platte lesen (d2.l/d3.b/a0.l)
 dc.w idenok-idebeftab          * Internen Test durchführen
 dc.w idebef24-idebeftab        * Laufwerksnamen lesen (a0.l)
 dc.w ideok-idebeftab           * Liste der Defekte lesen (d2.b/d3.w/a0.l)
 dc.w ideok-idebeftab           * Neue defekte Blöcke schreiben (a0.l)
 dc.w ideok-idebeftab           * Fehler lesen
 dc.w ideok-idebeftab           * Formatieren (d2.b/d3.w/a0.l)

idecomm:
 cmp #29, d1
 beq ideok                      * keine Eigenen Befehle
 bhi hderr                      * Wert zu gross
 and #$0f, d4
 cmp #1, d4                     * Master?
 bne.s idec1                    * nö
 lea idemgeo(a5), a6
 bra.s idec2
idec1:
 cmp #2, d4                     * Slave?
 bne.s idenok                   * nö
 lea idesgeo(a5), a6
idec2:
 add d1, d1                     * mal 2 da Wort
 move idebeftab(pc,d1.w), d1    * Sprungwert laden
 jsr idebeftab(pc,d1.w)
 cmp #-1, d0
 beq carset                     * Fehler
 bra carres

ideok:                          * liefert nur ein OK zurück
 clr d0
 bra carres

idenok:                         * liefert einen Fehler zurück
 moveq #-1, d0
 rts

idebef1:                        * Sektoren lesen
 cmp #1, d4                     * Master LW?
 bne.s idb1a                    * nein
 move #$a0, d4
 bra.s idb1b
idb1a:
 cmp #2, d4                     * Slave LW?
 bne idb1err                    * nein, dann Fehler
 move #$b0, d4
idb1b:
 asl.l d0, d2                   * Startsektor *2, falls 1024 BPS
 asl.l d0, d3                   * Anzahl * 2, falls 1024 BPS
 move.l d2, d0                  * Startsektor
 move d3, d1                    * Anzahl
 tst d1                         * Null?
 bne.s idb1e                    * NEIN! dann keine 512 Sektoren
 move.l #256, d2
 bra.s idb1f
idb1e:
 cmp #256, d1                   * < 256?
 blt.s idb1c                    * ja
idb1d:
 clr.l d2
 lsr #1, d1                     * Anzahl /2, da 2 Aufrufe
 move d1, d2                    * sichern
idb1f:
 move.l d0, d3                  * sichern
 bsr iderdsek                   * 1. Lesen, bei mehr als 256 Sektoren
 tst d0
 bne.s idb1err
 move.l d3, d0                  * Startsektor zurück
 add.l d2, d0                   * um Anzahl Sektoren erhöhen
 mulu #512, d2                  * Anzahl * Grösse
 adda.l d2, a0                  * Puffer erhöhen
idb1c:
 bsr iderdsek                   * Lesen, zum 2. bei Sektoren > 256
 tst d0
 beq.s idb1ex
idb1err:
 move #-1, d0
idb1ex:
 rts

idebef2:                        * Sektoren schreiben
 cmp #1, d4                     * Master LW?
 bne.s idb2a                    * nein
 move #$a0, d4
 bra.s idb2b
idb2a:
 cmp #2, d4                     * Slave LW?
 bne idb2err                    * nein, dann Fehler
 move #$b0, d4
idb2b:
 asl.l d0, d2                   * Startsektor *2, falls 1024 BPS
 asl.l d0, d3                   * Anzahl * 2, falls 1024 BPS
 move.l d2, d0                  * Startsektor
 move d3, d1                    * Anzahl
 tst d1                         * Null?
 bne.s idb2e                    * NEIN! dann keine 512 Sektoren
 move.l #256, d2
 bra.s idb2f
idb2e:
 cmp #256, d1                   * < 256?
 blt.s idb2c                    * ja
idb2d:
 clr.l d2
 lsr #1, d1                     * Anzahl /2, da 2 Aufrufe
 move d1, d2                    * sichern
 addq #1, d2                    * Anzahl + 1 (1...n)
idb2f:
 move.l d0, d3                  * sichern
 bsr idewrsek                   * 1. Schreiben, bei mehr als 256 Sektoren
 tst d0
 bne.s idb2err
 move.l d3, d0                  * Startsektor zurück
 add.l d2, d0                   * um Anzahl Sektoren erhöhen
 mulu #512, d2                  * Anzahl * Grösse
 adda.l d2, a0                  * Puffer erhöhen
idb2c:
 bsr idewrsek                   * Schreiben, zum 2. bei Sektoren > 256
 tst d0
 beq.s idb2ex
idb2err:
 move #-1, d0
idb2ex:
 rts

idebef8:                        * Laufwerk bereit?
 btst.b #7, idecmd.w            * Busy-Flag abfragen
 beq.s idb8a
 move.l #4, d0                  * und entsprechend SCSI setzen
 bra.s idb8ex
idb8a:
 clr.l d0                       * oder löschen
idb8ex:
 rts

idebef22:                       * Kapazität lesen
 clr.l d2
 move.b numsec(a6), d2
 move.l #512, d1                * 512 Byte/Sektor
 cmp #1, d3                     * Sektoren pro Spur
 bne.s idb22a                   * nein
 lsr.l d0, d2                   * /2 da 1024 Byte pro Sektor
 asl.l d0, d1                   * auf 1024 Bytes setzen
 bra.s idb22ex
idb22a:
 move.b numhead(a6), d3
 mulu d3, d2                    * Köpfe * Sektoren
 move numcyl(a6), d3
 mulu d3, d2                    * Köpfe * Sektoren * Spuren
 lsr.l d0, d2                   * /2 da 1024 Byte pro Sektor
 asl.l d0, d1                   * auf 1024 Bytes setzen
idb22ex:
 move.l d2, 0(a0)
 move.l d1, 4(a0)
 clr.l d0
 rts

idebef24:                       * LW Name lesen
 move #36-1, d3                 * 36 Byte Buffer
 movea.l a0, a1
idb24a:
 clr.b (a1)+                    * löschen
 dbra d3, idb24a
 move.b #1, 3(a0)               * ??? aus SCSI Bescheibung übernommen
 move.b #$3d, 4(a0)             * ??? aus SCSI Bescheibung übernommen
 move #24-1, d3                 * 24 Byte übertragen
 movea.l a6, a1                 * ide_geo
 adda.l #idename, a1
 adda.l #8, a0
idb24b:
 move.b (a1)+, (a0)+            * Name kopieren
 dbra d3, idb24b
 clr.l d0
 rts


iderdsek:                * Sektor(en) lesen D0=Sektornr., D1=Anzahl, A0=Puffer
 movem.l d1-d5/a1-a2, -(a7)
 move.l d0, d2                          * sichern
 move.l d1, d5                          * sichern
 bsr idewr                              * LW bereit?
 tst d0
 beq.b rdlp01                           * ja
 bra rderr                              * sonst Fehler
rdlp01:
 move.b d5, idescnt.w                   * d5 Sektor(en)
 move.l d2, d0                          * Sektor zurück
 bsr lba2chs                            * nach CHS umrechnen
 move.b d2, idesnum.w                   * Start-Sektor
 move.b d3, ideclo.w                    * Start Spur Low-Byte
 lsr #8, d3
 move.b d3, idechi.w                    * Start-Spur High-Byte
 or.b d4, d1                            * Anzahl Köpfe mit LW verodert
rdlp10:
 move.b d1, idesdh.w                    * und übergeben
 tst d5                                 * Sektorenanzahl=0?
 bne.s rdlp11                           * nein
 move #256, d5                          * sonst = 256
 
rdlp11:
 move #10-1, d2                         * 10 Versuche
 movea.l a0, a2                         * retten
 subq #1, d5                            * als Zähler
 move d5, d4                            * retten
 lea idedat.w, a1                       * Transferadresse nach a1
 
 
rdlp12:
 move d4, d5                            * wiederherstellen
 movea.l a2, a0                         * dito
 move sr, -(a7)                 * Status sichern
 ori #$0700, sr                 * Interrupts aus
 move.b #cmdrd, idecmd.w                * Lese-Befehl
rdlp12a:
 move #512-1, d3                    * Anzahl Bytes -1
 bsr idewd                              * Daten bereit?
 tst d0
 beq.s rdlp13                           * ja, kein Fehler
 move (a7)+, sr                 * Status zurück
 bra.s rderr                            * Fehler
rdlp13:
 move.b (a1), (a0)+                     * lesen
 dbra d3, rdlp13                        * nächstes Byte
 dbra d5, rdlp12a                       * nächsten Sektor
 move (a7)+, sr                 * Status zurück
 bsr idewr                              * LW fertig?
 tst d0
 bne rderr                              * nein, dann Fehler
 move.b idecmd.w, d0
 and.b #%10001001, d0                   * irgend welche weiteren Fehler?
 beq.b rdlp20                           * nö, dann fertig
 dbra d2, rdlp12                        * sonst nochmal
rderr:
 moveq #-1, d0
 bra.b rdex
rdlp20:
 clr d0
rdex:
 movem.l (a7)+, d1-d5/a1-a2
 rts


idewrsek:            * Sektor(en) schreiben D0=Sektornr., d1=Anzahl, A0=Puffer
 movem.l d1-d5/a1-a2, -(a7)
 move.l d0, d2                          * sichern
 move.l d1, d5
 bsr idewr
 tst d0
 beq.b wrlp01
 bra wrerr
 
wrlp01:
 move.b d5, idescnt.w                   * d5 Sektor(en)
 move.l d2, d0                          * Sektor zurück
 bsr lba2chs                            * in CHS umrechnen
 move.b d2, idesnum.w
 move.b d3, ideclo.w
 lsr #8, d3
 move.b d3, idechi.w
 or.b d4, d1
 move.b d1, idesdh.w
 tst d5
 bne.s wrlp11
 move #256, d5
wrlp11:
 move #10-1, d2                         * 10 Versuche
 movea.l a0, a2                         * retten
 subq #1, d5                            * -1 als Zähler
 move d5, d4                            * retten
 lea idedat.w, a1
wrlp12:
 move d4, d5                            * wiederherstellen
 movea.l a2, a0
 move sr, -(a7)                 * Status sichern
 ori #$0700, sr                 * Interrupts aus
 move.b #cmdwr, idecmd.w
 
 
wrlp12a:
 move #512-1,d3                     * Anzahl Bytes -1
 /*bsr idewd*/
 bsr idewr					* BSY ?
 tst d0
 bne.s wrlp13                           * kein Fehler
 move (a7)+, sr                 * Staus zurück 
 bra.s wrerr
wrlp13:
 bsr idewd
 tst d0
 bne.s wrlp14
 move (a7)+, sr                 * Staus zurück 
 bra.s wrerr
wrlp14:
 bra.s *+4					
 move.b (a0)+, (a1)                     * schreiben
 dbra d3, wrlp14                        * nächstes Byte
 dbra d5, wrlp12a                       * nächster Sektor
 move (a7)+, sr                 * Staus zurück
 bsr idewr
 tst d0
 bne wrerr
 move.b idecmd.w, d0
 and.b #%00100001, d0                   * irgend welche Fehler? 
 beq.b wrlp20                           * nö, fertig
 dbra d2, wrlp12                        * sonst noch'n Versuch
wrerr:
 moveq #-1, d0
 bra.b wrex
wrlp20:
 clr d0
wrex:
 bsr idefl
 movem.l (a7)+, d1-d5/a1-a2
 rts


lba2chs:                        * Rechenet LBA (d0.l) in Head (d1.b),
                                * Sektor (d2.b) und Zylinder (d3.w) um
                                * a6 = Master/Slave-Buffer
 clr.l d1
 move.b numsec(a6), d1
 divu d1, d0                            * log. Sektor / Sektoren pro Spur
 swap d0                                * nur der Rest
 move.b d0, d2                          * Sektor
 addq.b #1, d2                          * +1
 clr d0
 swap d0                                * Divisionsergebnis
 move.b numhead(a6), d1
 divu d1, d0                            * durch Anzahl der Köpfe
 move d0, d3                            * Zylinder
 swap d0                                * Köpfe
 move.b d0, d1
 rts

idewr:                                  * Warten bis Laufwerk ready
 move.l #idedel*cpu, d0                 * Delaywert laden
iwr01:
 subq.l #1, d0
 bmi iwr02                              * Abbruch
 btst.b #7, idecmd.w                    * Busy?
 bne.b iwr01                            * ja!
 clr d0                                 * ist ready
 bra.b iwrex
iwr02:
 move #-1, d0                           * ist NICHT ready
iwrex:
 rts

idewd:                                  * Warten bis LW bereit für Daten
 move.l #idedel*cpu, d0                 * Delaywert laden
iwd01:
 subq.l #1, d0
 bmi iwd02                              * Abbruch
 btst.b #3, idecmd.w                    * bereit für Datentransfer?
 beq.b iwd01                            * ja
 clr d0                                 * Daten bereit
 bra.b iwdex
iwd02:
 move #-1, d0                           * Daten NICHT bereit
iwdex:
 rts

idefl:
 move.b #cmdflush,idecmd.w			* flush cache
 bsr idewr
 rts

numcyl     equ 0
numhead    equ 2
numsec     equ 3
nkcmode    equ 4
idename    equ 8

idedel     equ 80000

cmdrd      equ $20
cmdwr      equ $30
cmdinit    equ $91
cmdident   equ $ec
cmdflush   equ $E7


sets2i:                         * SCSI nach IDE/SD Umleitung setzen
 move.b d0, scsi2ide(a5)
 clr d0
 rts

gets2i:                         * SCSI nach IDE/SD Umleitung laden
 move.b scsi2ide(a5), d0
 rts
