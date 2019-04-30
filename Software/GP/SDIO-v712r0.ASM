*******************************************************************************
*                          680xx Grundprogramm sdio                           *
*                             2016 Jens Mewes                                 *
*                               V 7.12 Rev 0                                  *
*                                01.01.2016                                   *
*                             SD-Card-Routinen                                *
*******************************************************************************


sdtest:                         * Test, ob Laufwerk vorhanden
                                        * d4 enthält Laufwerk
 movem.l d1-d7/a1-a4/a6, -(a7)
 link a3, #-24
 btst.b #6, keydil(a5)                  * GDP-FPGA da?
 beq.s sdtst00                          * nein, dann Softwarelösung
 bra sd1test
sdtst00:
 and #$0f, d4
 cmp.b #1, d4                           * Card 0?
 bne.s sdtst01                          * nein
 move.b #SPI_CS0, d5                    * d5 = SPI_CS
 lea sd1geo(a5), a6                     * Speicher für Grösse...
 bra.s sdtst02
sdtst01:
 cmp.b #2, d4                           * Card 1?
 bne sdxtster                           * nein, dann Fehler
 move.b #SPI_CS1, d5
 lea sd2geo(a5), a6
sdtst02:
 move.b #$ff, d2                        * d2 = sdout
 move.b #SPI_DI, d4                     * d4 = SPI_DI
 move.b #SPI_DO, d6                     * d6 = SPI_DO
 move.b #SPI_CLK, d7                    * d7 = SPI_CLK
 
 lea sdrdbyte(pc), a4
 move.l a4, SD_RDBYTE(a3)
 lea sdwrbyte(pc), a4
 move.l a4, SD_WRBYTE(a3)
 lea sdcsakt(pc), a4
 move.l a4, SD_CSAKT(a3)
 lea sdcsnakt(pc), a4
 move.l a4, SD_CSNAKT(a3)
 bra.s sdxtst

sd1test:
 and #$0f, d4
 cmp.b #1, d4                           * Card 0?
 bne.s sd1tst01                         * nein
 move.b #SPIH0_CS, d5                   * d5 = SPI_CS
 lea sd1geo(a5), a6                     * Speicher für Grösse...
 bra.s sd1tst02
sd1tst01:
 cmp.b #2, d4                           * Card 1?
 bne sdxtster                           * nein, dann Fehler
 move.b #SPIH1_CS, d5
 lea sd2geo(a5), a6
sd1tst02:
 move.b #$81, d2                        * d2 = sdout 10MHz
 lea sd1rdbyte(pc), a4
 move.l a4, SD_RDBYTE(a3)
 lea sd1wrbyte(pc), a4
 move.l a4, SD_WRBYTE(a3)
 lea sd1csakt(pc), a4
 move.l a4, SD_CSAKT(a3)
 lea sd1csnakt(pc), a4
 move.l a4, SD_CSNAKT(a3)

sdxtst:
 movea.l a6, a1                         * Adresse der Ausgabedaten sichern
 bsr sdinit
 tst.b d0
 bmi sdxtster                           * Fehler SD-Card nicht gefunden
 lea idebuff(a5), a0
 lea spcmd9(pc), a2                     * CSD Kommando
 move #16, d0                           * 16 Byte
 bsr sdrdblk                            * CSD-Register lesen
 lea idebuff(a5), a0
 tst SDART(a6)
 beq.s sdxtst02                         * MMC- oder SDv1-Card
 cmp #3, SDART(a6)
 bne.s sdxtst01
 lea sdhctxt(pc), a2
 bsr sdhcsize                           * SDHC-Card
 bra.s sdxtst05
sdxtst01:
 lea sd2txt(pc), a2
 bsr sdcsize                            * SDv2-Card
 bra.s sdxtst05
sdxtst02:
 move.b 0(a0), d0                       * CSD Struct
 btst.b #7, d0                          * MMC-Card?
 beq.s sdxtst03                         * Ja
 move #1, SDART(a6)                     * sonst SDv1-Card
 lea sdtxt(pc), a2
 bra.s sdxtst04
sdxtst03:
 lea mmctxt(pc), a2
sdxtst04:
 bsr sdcsize
sdxtst05:
 addq.l #SDNAME, a6                     * a6 auf SD-Name
sdxtst06:
 move.b (a2)+, (a6)+
 bne.s sdxtst06
 subq.l #1, a6                          * auf die Null
 cmp #512, d0                           * noch von sdcXXsize
 bne.s sdxtster                         * nicht unterstützte Blockgrösse
 clr.l d0
 lea spcmd10(pc), a2                    * CID Kommando
 move #16, d0                           * 16 Byte
 bsr sdrdblk                            * CID Bytes einlesen
 lea idebuff(a5), a0                    * Puffer zurück
 addq.l #3, a0                          * a0 auch auf Name
 moveq #5-1, d3                         * 5 Bytes
sdxtst07:
 move.b (a0)+, (a6)+
 dbra d3, sdxtst07
 clr.b (a6)+                            * zum Schluß ne Null
 movea.l a1, a0                         * Ausgabepuffer in a0
 clr.l d0                               * Alles OK
 unlk a3
 movem.l (a7)+, d1-d7/a1-a4/a6
 bra carres
sdxtster:
 moveq #-1, d0
 unlk a3
 movem.l (a7)+, d1-d7/a1-a4/a6
 bra carset


sdcsize:
 move.b 6(a0), d0                       * MSB von C_SIZE
 and.b #$03, d0                         * nur Bit 0 und 1
 lsl.l #8, d0                           * 8 Bit nach Links
 move.b 7(a0), d0                       * die nächsten 8 Bit
 lsl.l #8, d0                           * erstmal 8 Bit weiter
 move.b 8(a0), d0                       * hier kommt der Rest
 lsr.l #6, d0                           * wieder 6 Bit zurück
 addq.l #1, d0                          * um 1 erhöhen
 move.l d0, d1                          * C_SIZE nach d1 sichern
 clr.l d0
 move.b 9(a0), d0                       * die beiden MSBs von C_SIZE_MULT
 lsl.w #8, d0                           * jetzt im oberen Byte
 move.b 10(a0), d0                      * das letzte Bit
 lsr.w #7, d0                           * auf Bit 2-0
 and.w #$7, d0                          * nur 3 Bit
 addq.l #2, d0                          * Jetzt korrekter Wert
 asl.l d0, d1                           * (C_SIZE+1)*2^(C_SIZE_MULT+2)
 clr.l d0
 move.b 5(a0), d0                       * READ_BLK_LEN
 and.b #$0f, d0                         * nur unteren 4 Bit
 asl.l d0, d1                   * (C_SIZE+1)*2^(C_SIZE_MULT+2)*2^READ_BLK_LEN
 lsr.l #8, d1
 lsr.l #1, d1                           * /512 => in Sektoren
 move.l d1, SDSIZE(a6)                  * Grösse (in Sektoren) abspeichern
 moveq.l #1, d1
 asl.l d0, d1
 move d1, d0
 move.w d0, SDBPBLK(a6)                 * Bytes pro Block abspeichern
 rts


sdhcsize:
 clr.l d1
 move.b 7(a0), d1                       * MSB
 and.b #$3f, d1                         * obere Bytes nicht
 swap d1                                * jetzt in Byte #16 - #21
 move.b 8(a0), d1
 lsl #8, d1                             * nach Byte #15 - #8
 move.b 9(a0), d1                       * jetzt auch LSB
 move #10, d0
 lsl.l d0, d1                           * *1024 => in Sektoren
 move.l d1, SDSIZE(a6)
 move #512, d0
 move.w d0, SDBPBLK(a6)                 * Bytes pro Block abspeichern
 rts


sdinit:                         * Initialisieren der SD-Card
 movem.l d3/a0/a2, -(a7)
 movea.l SD_CSNAKT(a3), a4
 jsr (a4)
                                        * min. 74 Clocks an SD
 moveq #10-1, d3                        * Anzahl 80 Clocks
 move.b #$ff, d0                        * dummy Daten
 movea.l SD_WRBYTE(a3), a4
sdi02:
 jsr (a4)                               * ein Byte schreiben
 dbra d3, sdi02
 lea spcmd0(pc), a2                     * Kommando 0
 move #TIMEOUT, d1                      * TIMEOUT Versuche
sdi03:
 bsr sdwrcmd                            * Kommando schreiben
 btst.b #R1_IDLE, d0                    * nur Idle?
 bne.s sdi04
 dbra d1, sdi03
 bra sdinite                            * Abbruch
sdi04:
 lea spcmd8(pc), a2                     * Kommando 8
 bsr sdwrcmd
 btst.b #R1_ILL, d0                     * Illegal?
 bne.s sdi06                            * nein, dann SDv2 / SDHC
 clr SDART(a6)                          * MMC oder SDv1
 lea spcmd1(pc), a2                     * Kommando 1
 move #TIMEOUT, d1                      * TIMEOUT Versuche
sdi05:
 bsr sdwrcmd                            * Kommando schreiben
 tst.b d0                               * OK?
 beq sdi90                              * dann Ende
 dbra d1, sdi05
 bra.s sdinite                          * Abbruch
sdi06:
 movea.l SD_RDBYTE(a3), a4
 jsr (a4)
 jsr (a4)
 jsr (a4)
 cmp.b #$01, d0
 bne.s sdinite                          * falsche Spannung
 jsr (a4)
 cmp.b #$aa, d0
 bne.s sdinite                          * falsche Pattern
 move #TIMEOUT, d1                      * TIMEOUT Versuche
sdi07:
 lea spcmd55(pc), a2                    * Kommando 55
 bsr sdwrcmd                            * Kommando schreiben
 bclr.b #R1_IDLE, d0                    * Idle raus
 tst.b d0
 bne.s sdinite                          * Fehler
 lea spacmd41(pc), a2                   * A-Kommando 41
 bsr sdwrcmd
 move.b d0, d1
 bclr.b #R1_IDLE, d0                    * Idle raus
 tst.b d0
 bne.s sdinite                          * Fehler
 tst.b d1
 beq.s sdi08
 dbra d3, sdi07
 bra.s sdinite                          * Fehler
sdi08:
 lea spcmd58(pc), a2                    * Kommando 58
 move #TIMEOUT, d1                      * Retrys
sdi09:
 bsr sdwrcmd
 tst.b d0                               * OK?
 beq.s sdi10                            * Ja
 dbra d1, sdi09
 bra.s sdinite                          * Fehler
sdi10:
 movea.l SD_RDBYTE(a3), a4
 jsr (a4)
 move #2, SDART(a6)                     * SDv2
 btst.b #6, d0
 bne.s sdi11
 move #3, SDART(a6)                     * SDHC
sdi11:
 jsr (a4)
 jsr (a4)
 jsr (a4)
 bra.s sdi90
sdinite:                                * Error
 moveq.l #-1, d0
 bra.s sdinitx
sdi90:                                  * OK, Ende
 clr.l d0
sdinitx:
 movea.l SD_CSNAKT(a3), a4
 jsr (a4)
 movem.l (a7)+, d3/a0/a2
 rts

sdcsakt:
 bclr.b d5, d2                          * CS enabled
 move.b d2, spictrl.w
 rts
 
sdcsnakt:
 bset.b d5, d2                          * CS disabled
 move.b d2, spictrl.w
 rts
 
sd1csakt:
 bset.b d5, d2                          * CS enabled
 move.b d2, spictrl.w
 rts
 
sd1csnakt:
 bclr.b d5, d2                          * CS disabled
 move.b d2, spictrl.w
 rts

sddiski:                       * interne SD IO-Routine
 moveq #1, d0                  * 1024 BPS
 bra.s sddisk1

sddisk:                        * SD IO-Routine
 moveq #0, d0                  * 512 BPS
sddisk1:
 movem.l d1-d7/a0-a4/a6, -(a7)
 bsr.s sdcomm                  * Hauptroutine aufrufen
 movem.l (a7)+, d1-d7/a0-a4/a6
rts

sdbeftab:                      * Tabelle der Befehle
 dc.w sdok-sdbeftab            * Auf Track 0
 dc.w sdbef1-sdbeftab          * Sektor lesen (d2.l/d3.b/a0.l)
 dc.w sdbef2-sdbeftab          * Sektor schreiben (d2.l/d3.b/a0.l)
 dc.w sdnok-sdbeftab           * Sektor + ECC lesen (d2.l/a0.l)
 dc.w sdnok-sdbeftab           * Sektor + ECC schreiben (d2.l/a0.l)
 dc.w sdok-sdbeftab            * Mode auswählen (d2.b/a0.l)
 dc.w sdok-sdbeftab            * Parameter des Laufwerks lesen (d2.b/d3.b/a0.l)
 dc.w sdok-sdbeftab            * Sektor suchen (d2.l)
 dc.w sdok-sdbeftab            * Laufwerk breit ?
 dc.w sdok-sdbeftab            * Park
 dc.w sdok-sdbeftab            * Unpark
 dc.w sdnok-sdbeftab           * Sektor lesen (d2.l/d3.w/a0.l)
 dc.w sdnok-sdbeftab           * Sektor schreiben (d2.l/d3.w/a0.l)
 dc.w sdnok-sdbeftab           * Buffer lesen (d2.w/a0.l)
 dc.w sdnok-sdbeftab           * Buffer schreiben (d2.w/a0.l)
 dc.w sdok-sdbeftab            * Einheit reservieren (d2.w/d3.w/a0.l)
 dc.w sdok-sdbeftab            * Einheit freigeben (d2.w)
 dc.w sdnok-sdbeftab           * Sektoren schreiben und prüfen (d2.l/d3.w/a0.l)
 dc.w sdnok-sdbeftab           * Sektor prüfen (d2.l/d3.w)
 dc.w sdok-sdbeftab            * Diagnostic senden
 dc.w sdnok-sdbeftab           * Sektor suchen (d2.l)
 dc.w sdok-sdbeftab            * Zähler-Statistik lesen (a0.l)
 dc.w sdbef22-sdbeftab         * Größe der Platte lesen (d2.l/d3.b/a0.l)
 dc.w sdnok-sdbeftab           * Internen Test durchführen
 dc.w sdbef24-sdbeftab         * Laufwerksnamen lesen (a0.l)
 dc.w sdok-sdbeftab            * Liste der Defekte lesen (d2.b/d3.w/a0.l)
 dc.w sdok-sdbeftab            * Neue defekte Blöcke schreiben (a0.l)
 dc.w sdok-sdbeftab            * Fehler lesen
 dc.w sdok-sdbeftab            * Formatieren (d2.b/d3.w/a0.l)


sdcomm:
 cmp #29, d1
 beq sdok                       * keine Eigenen Befehle
 bhi sderr                      * Wert zu gross
 and #$0f, d4
 cmp.b #1, d4                   * SD-Card0?
 bne.s sdc1                     * nö
 lea sd1geo(a5), a6
 bra.s sdc2
sdc1:
 cmp.b #2, d4                   * SD-Card1?
 bne.s sdnok                    * nö
 lea sd2geo(a5), a6
sdc2:
 link a3, #-24
 add d1, d1                     * mal 2 da Wort
 btst.b #6, keydil(a5)          * GDP-FPGA da?
 bne.s sdc10                    * ja!
 lea sdrdbyte(pc), a4
 move.l a4, SD_RDBYTE(a3)
 lea sdwrbyte(pc), a4
 move.l a4, SD_WRBYTE(a3)
 lea sdcsakt(pc), a4
 move.l a4, SD_CSAKT(a3)
 lea sdcsnakt(pc), a4
 move.l a4, SD_CSNAKT(a3)
 move sdbeftab(pc,d1.w), d1     * Sprungwert laden
 jsr sdbeftab(pc,d1.w)
 unlk a3
 cmp #-1, d0
 beq carset                     * Fehler
 bra carres
sdc10:
 lea sd1rdbyte(pc), a4
 move.l a4, SD_RDBYTE(a3)
 lea sd1wrbyte(pc), a4
 move.l a4, SD_WRBYTE(a3)
 lea sd1csakt(pc), a4
 move.l a4, SD_CSAKT(a3)
 lea sd1csnakt(pc), a4
 move.l a4, SD_CSNAKT(a3)
 move sdbeftb1(pc,d1.w), d1     * Sprungwert laden
 jsr sdbeftb1(pc,d1.w)
 unlk a3
 cmp #-1, d0
 beq carset                     * Fehler
 bra carres

sdbeftb1:                      * Tabelle der Befehle für Hardware-SPI
 dc.w sdok-sdbeftb1            * Auf Track 0
 dc.w sd1bef1-sdbeftb1         * Sektor lesen (d2.l/d3.b/a0.l)
 dc.w sd1bef2-sdbeftb1         * Sektor schreiben (d2.l/d3.b/a0.l)
 dc.w sdnok-sdbeftb1           * Sektor + ECC lesen (d2.l/a0.l)
 dc.w sdnok-sdbeftb1           * Sektor + ECC schreiben (d2.l/a0.l)
 dc.w sdok-sdbeftb1            * Mode auswählen (d2.b/a0.l)
 dc.w sdok-sdbeftb1            * Parameter des Laufwerks lesen (d2.b/d3.b/a0.l)
 dc.w sdok-sdbeftb1            * Sektor suchen (d2.l)
 dc.w sdok-sdbeftb1            * Laufwerk breit ?
 dc.w sdok-sdbeftb1            * Park
 dc.w sdok-sdbeftb1            * Unpark
 dc.w sdnok-sdbeftb1           * Sektor lesen (d2.l/d3.w/a0.l)
 dc.w sdnok-sdbeftb1           * Sektor schreiben (d2.l/d3.w/a0.l)
 dc.w sdnok-sdbeftb1           * Buffer lesen (d2.w/a0.l)
 dc.w sdnok-sdbeftb1           * Buffer schreiben (d2.w/a0.l)
 dc.w sdok-sdbeftb1            * Einheit reservieren (d2.w/d3.w/a0.l)
 dc.w sdok-sdbeftb1            * Einheit freigeben (d2.w)
 dc.w sdnok-sdbeftb1           * Sektoren schreiben und prüfen (d2.l/d3.w/a0.l)
 dc.w sdnok-sdbeftb1           * Sektor prüfen (d2.l/d3.w)
 dc.w sdok-sdbeftb1            * Diagnostic senden
 dc.w sdnok-sdbeftb1           * Sektor suchen (d2.l)
 dc.w sdok-sdbeftb1            * Zähler-Statistik lesen (a0.l)
 dc.w sdbef22-sdbeftb1         * Größe der Platte lesen (d2.l/d3.b/a0.l)
 dc.w sdnok-sdbeftb1           * Internen Test durchführen
 dc.w sdbef24-sdbeftb1         * Laufwerksnamen lesen (a0.l)
 dc.w sdok-sdbeftb1            * Liste der Defekte lesen (d2.b/d3.w/a0.l)
 dc.w sdok-sdbeftb1            * Neue defekte Blöcke schreiben (a0.l)
 dc.w sdok-sdbeftb1            * Fehler lesen
 dc.w sdok-sdbeftb1            * Formatieren (d2.b/d3.w/a0.l)


sdok:                           * liefert nur ein OK zurück
 clr.l d0
 bra carres

sdnok:                          * liefert einen Fehler zurück
 moveq #-1, d0
 rts

sderr:                          * liefert Fehler und Carry zurück
 moveq #-1, d0
 bra carset

sdbef1:                         * Sektoren lesen
 move.l d2, d1                  * Startsektor
 and.l #$000000ff, d3           * nur Byte gültig
 bne.s sdb1a                    * falls Null, dann 256
 move.l #256, d3
sdb1a:
 asl.l d0, d1                   * Startsektor *2, falls 1024 BPS
 asl.l d0, d3                   * Anzahl * 2, falls 1024 BPS
sdb1b:
 subq.l #1, d3                  * Anzahl-1 als Zähler
 cmp.b #1, d4                   * SD-Card 0?
 bne.s sdb1c                    * nein
 move.b #SPI_CS0, d5            * d5 = SPI_CS
 bra.s sdb1d
sdb1c:
 cmp.b #2, d4                   * SD-Card 1?
 bne.s sdb1er                   * nein, dann Fehler
 move.b #SPI_CS1, d5
sdb1d:
 move.b #$ff, d2                * d2 = sdout
 move.b #SPI_DI, d4             * d4 = SPI_DI
 move.b #SPI_DO, d6             * d6 = SPI_DO
 move.b #SPI_CLK, d7            * d7 = SPI_CLK
sdb1e:
 move.l d1, d0                  * Sektor zurück
 bsr sdrdsec                    * Lesen
 addq.l #1, d1                  * nächsten Sektor
 dbra d3, sdb1e
 clr.l d0
 bra.s sdb1ex
sdb1er:
 moveq #-1, d0
sdb1ex:
 rts

sd1bef1:                        * Sektoren lesen Hardware SPI
 move.l d2, d1                  * Startsektor
 and.l #$000000ff, d3           * nur Byte gültig
 bne.s sd1b1a                   * falls Null, dann 256
 move.l #256, d3
sd1b1a:
 asl.l d0, d1                   * Startsektor *2, falls 1024 BPS
 asl.l d0, d3                   * Anzahl * 2, falls 1024 BPS
sd1b1b:
 subq.l #1, d3                  * Anzahl-1 als Zähler
 cmp.b #1, d4                   * SD-Card 0?
 bne.s sd1b1c                   * nein
 move.b #$81, d2                * d2 = sdout 10MHz
 move.b #SPIH0_CS, d5           * SPI0 Select
 bra.s sd1b1d
sd1b1c:
 cmp.b #2, d4                   * SD-Card 1?
 bne.s sd1b1er                  * nein, dann Fehler
 move.b #$81, d2                * d2 = sdout 10MHz
 move.b #SPIH1_CS, d5           * SPI1 Select
sd1b1d:
 move.l d1, d0                  * Sektor zurück
 bsr sdrdsec                    * Lesen
 addq.l #1, d1                  * nächsten Sektor
 dbra d3, sd1b1d
 clr.l d0
 bra.s sd1b1ex
sd1b1er:
 moveq #-1, d0
sd1b1ex:
 rts

sdbef2:                         * Sektoren schreiben
 movea.l a0, a1                 * Buffer retten
 move.l d2, d1                  * Startsektor
 and.l #$000000ff, d3           * nur Byte gültig
 bne.s sdb2a                    * falls Null, dann 256
 move.l #256, d3
sdb2a:
 asl.l d0, d1                   * Startsektor *2, falls 1024 BPS
 asl.l d0, d3                   * Anzahl * 2, falls 1024 BPS
sdb2b:
 subq.l #1, d3                  * Anzahl-1 als Zähler
 cmp.b #1, d4                   * SD-Card 0?
 bne.s sdb2c                    * nein
 move.b #SPI_CS0, d5            * d5 = SPI_CS
 bra.s sdb2d
sdb2c:
 cmp.b #2, d4                   * SD-Card 1?
 bne.s sdb2er                   * nein, dann Fehler
 move.b #SPI_CS1, d5
sdb2d:
 move.b #$ff, d2                * d2 = sdout
 move.b #SPI_DI, d4             * d4 = SPI_DI
 move.b #SPI_DO, d6             * d6 = SPI_DO
 move.b #SPI_CLK, d7            * d7 = SPI_CLK
 moveq #10-1, d6                * 10 Versuche
sdb2e:
 movea.l a1, a0                 * Buffer zurück
 move.l d1, d0                  * Sektor zurück
 bsr sdwrsec                    * Schreiben
 tst.b d0
 dbeq d6, sdb2e                 * Hat nicht geklappt, nochmal
 bmi.s sdb2er                   * Fehler! Abbruch
 addq.l #1, d1                  * nächsten Sektor
 adda.l #512, a1                * Buffer auch
 dbra d3, sdb2d
 clr.l d0
 movea.l a1, a0
 bra.s sdb2ex
sdb2er:
 moveq #-1, d0
sdb2ex:
 rts

sd1bef2:                        * Sektoren schreiben Hardware SPI
 movea.l a0, a1                 * Buffer retten
 move.l d2, d1                  * Startsektor
 and.l #$000000ff, d3           * nur Byte gültig
 bne.s sd1b2a                   * falls Null, dann 256
 move.l #256, d3
sd1b2a:
 asl.l d0, d1                   * Startsektor *2, falls 1024 BPS
 asl.l d0, d3                   * Anzahl * 2, falls 1024 BPS
sd1b2b:
 subq.l #1, d3                  * Anzahl-1 als Zähler
 cmp.b #1, d4                   * SD-Card 0?
 bne.s sd1b2c                   * nein
 move.b #$81, d2                * d2 = sdout 10MHz
 move.b #SPIH0_CS, d5           * d5 = SPI_CS
 bra.s sd1b2d
sd1b2c:
 cmp.b #2, d4                   * SD-Card 1?
 bne.s sd1b2er                  * nein, dann Fehler
 move.b #$81, d2
 move.b #SPIH1_CS, d5
sd1b2d:
 moveq #10-1, d6                * 10 Versuche
sd1b2e:
 movea.l a1, a0                 * Buffer zurück
 move.l d1, d0                  * Sektor zurück
 bsr sdwrsec                    * Schreiben
 tst.b d0
 dbeq d6, sd1b2e                * Hat nicht geklappt, nochmal
 bmi.s sd1b2er                  * Fehler! Abbruch
 addq.l #1, d1                  * nächsten Sektor
 adda.l #512, a1                * Buffer auch
 dbra d3, sd1b2d
 clr.l d0
 movea.l a1, a0
 bra.s sd1b2ex
sd1b2er:
 move.l #-1, d0
sd1b2ex:
 rts

sdbef22:                        * Kapazität lesen
 clr.l d2
 move.l SDSIZE(a6), d2          * Grösse a 512 Byte
 clr.l d1
 move SDBPBLK(a6), d1           * 512 Byte/Sektor
 lsr.l d0, d2                   * Grösse /2, falls 1024 BPS
 asl.l d0, d1                   * Anzahl * 2, falls 1024 BPS
sdb22ex:
 move.l d2, 0(a0)
 move.l d1, 4(a0)
 clr.l d0
 rts

sdbef24:                        * LW Name lesen
 move #36-1, d3                 * 36 Byte Buffer
 movea.l a0, a1
sdb24a:
 clr.b (a1)+                    * löschen
 dbra d3, sdb24a
 move.b #1, 3(a0)               * ??? aus SCSI Bescheibung übernommen
 move.b #$3d, 4(a0)             * ??? aus SCSI Bescheibung übernommen
 move #15-1, d3                 * 15 Byte übertragen
 movea.l a6, a1                 * sd_geo
 adda.l #SDNAME, a1
 adda.l #8, a0
sdb24b:
 move.b (a1)+, (a0)+            * Name kopieren
 dbra d3, sdb24b
 rts


sdwrcmd:                        * Commando-Bytes an SD-Card ausgeben
 movem.l d1/d3/a0/a2, -(a7)
 movea.l SD_CSNAKT(a3), a4		* CS unablen
 jsr (a4)
 move.b #$ff, d0                        * dummy Daten
 movea.l SD_WRBYTE(a3), a4
 jsr (a4)                               * erzeugt 8 Clockzyklen
 movea.l SD_CSAKT(a3), a4		* CS enablen
 jsr (a4)
 moveq #6-1, d3                         * 6 Bytes
 movea.l SD_WRBYTE(a3), a4
sdwrcmd1:
 move.b (a2)+, d0                       * CMD-Byte
 jsr (a4)                               * Byte schreiben
 dbra d3, sdwrcmd1
 moveq #10, d1                          * Timeout
 movea.l SD_RDBYTE(a3), a4
sdwrcmd2:
 jsr (a4)                               * ein Byte lesen
 cmp.b #-1, d0                          * OK?
 bne.s sdwrcmdx
 dbra d1, sdwrcmd2
sdwrcmdx:
 movem.l (a7)+, d1/d3/a0/a2
 rts

sdwrsec:                        * schreibt einen Sektor (512 Byte) auf die SD
                                * d0.l = Adresse, a0.l = Puffer
 movem.l d3/a2, -(a7)
 lea cmdbuff(a5), a2                    * Adresse CMD-Speicher
 move.b #$58, 0(a2)                     * Commando 24
 clr.b 1(a2)
 clr.b 2(a2)
 clr.b 3(a2)
 clr.b 4(a2)
 move.b #$ff, 5(a2)
 bsr sectocmd
 bsr sdwrcmd                            * Commando schreiben
 tst.b d0
 bne.s sdwrsece                         * Fehler
 movea.l SD_RDBYTE(a3), a4
 jsr (a4)                               * dummylesen für Clock
 move.b #$fe, d0                        * Startbyte
 movea.l SD_WRBYTE(a3), a4
 jsr (a4)                               * senden
 move #512-1, d3                        * 512 Bytes
sdwrsec2:
 move.b (a0)+, d0                       * Datenbyte
 jsr (a4)                               * schreiben
 dbra d3, sdwrsec2
 move.b #$ff, d0                        * dummy CRC
 jsr (a4)
 move.b #$ff, d0                        * dummy CRC
 jsr (a4)
 move #10, d3                           * retrys
 movea.l SD_RDBYTE(a3), a4
sdwrsec6:
 jsr (a4)
 and.b #$1f, d0
 cmp.b #$5, d0
 beq.s sdwrsec3
 dbra d3, sdwrsec6
 bra.s sdwrsece                         * Fehler bei Schreibvorgang
sdwrsec3:
 jsr (a4)
 cmp.b #$ff, d0                         * wenn busy dann <> $ff
 beq.s sdwrsec4
 bra.s sdwrsec3
sdwrsec4:
 clr.l d0
 bra.s sdwrsecx
sdwrsece:
 moveq #-1, d0
sdwrsecx:
 movea.l SD_CSNAKT(a3), a4
 jsr (a4)
 movem.l (a7)+, d3/a2
 rts


sdrdsec:                        * liest einen Sektor (512 Byte) von der SD
                                * d0.l = Adresse, a0.l = Puffer
 movem.l a2, -(a7)
 lea cmdbuff(a5), a2
 move.b #$51, 0(a2)                     * Commando Sektor lesen
 clr.b 1(a2)
 clr.b 2(a2)
 clr.b 3(a2)
 clr.b 4(a2)
 move.b #$ff, 5(a2)
 bsr sectocmd
 move #512, d0
 bsr sdrdblk
 movem.l (a7)+, a2
 rts


sdrdblk:                        * liest einen d0 Byte Block
                                * a0 = Puffer
 movem.l d1, -(a7)
 move d0, d1                            * Byteanzahl sichern
 bsr sdwrcmd                            * Commando schreiben
 tst.b d0
 bne.s sdrdblkx
 movea.l SD_RDBYTE(a3), a4
sdrdblk1:
 jsr (a4)                               * Byte lesen
 cmp.b #$fe, d0                         * auf Startbyte warten
 bne.s sdrdblk1                         * ACHTUNG bei Fehler Endlosschleife!!!
 subq #1, d1                            * d1 als Zähler
sdrdblk2:
 jsr (a4)                               * Datenbyte lesen
 move.b d0, (a0)+                       * in Puffer kopieren
 dbra d1, sdrdblk2
 jsr (a4)                               * Dummy CRC lesen
 jsr (a4)                               * Dummy CRC lesen
 clr d0
sdrdblkx:
 movea.l CS_NAKT(a3), a4
 jsr (a4)
 movem.l (a7)+, d1
 rts


sdrdbyte:                       * liest ein Byte von der SD-Card
 movem.l d3, -(a7)
 move sr, -(a7)                         * Status sichern
 ori #$0700, sr                         * Interrupts aus
 clr d0
 moveq #8-1, d3                         * 8 Bit
sdrdbt1:
 lsl.b #1, d0                           * Bit nach d0
 bclr.b d7, d2                          * Clock auf low
 move.b d2, spictrl.w
 btst.b d4, spictrl.w                   * Datenbit
 beq.s sdrdbt2                          * Daten low
 bset.b #0, d0
sdrdbt2:
 bset.b d7, d2                          * Clock auf high
 move.b d2, spictrl.w
 dbra d3, sdrdbt1
 move (a7)+, sr                         * Staus zurück
 movem.l (a7)+, d3
 rts

sd1rdbyte:                      * liest ein Byte von der SD-Card
 move sr, -(a7)                         * Status sichern
 ori #$0700, sr                         * Interrupts aus
 move.b #$ff, spidata.w                 * Dummybyte
sd1rd1b:
 btst.b #0, spictrl.w                   * OK?
 beq.s sd1rd1b
 move.b spidata.w, d0
 move (a7)+, sr                         * Staus zurück
 rts

sdwrbyte:                       * schreibt ein Byte auf die SD-Card
 movem.l d3, -(a7)
 move sr, -(a7)                         * Status sichern
 ori #$0700, sr                         * Interrupts aus
 moveq #8-1, d3                         * 8 Bit
sdwrbt1:
 lsl.b #1, d0                           * Bit in Carry
 bcs.s sdwrbt2                          * Bit ist high
 bclr.b d6, d2                          * Bit löschen
 move.b d2, spictrl.w
 bra.s sdwrbt3
sdwrbt2:
 bset.b d6, d2                          * Bit setzten
 move.b d2, spictrl.w
sdwrbt3:
 bclr.b d7, d2                          * Clock auf low
 move.b d2, spictrl.w
 bset.b d7, d2                          * Clock auf high
 move.b d2, spictrl.w
 dbra d3, sdwrbt1
 bset.b d6, d2                          * Bit wieder auf high
 move.b d2, spictrl.w
 move (a7)+, sr                         * Staus zurück
 movem.l (a7)+, d3
 rts

sd1wrbyte:                      * schreibt ein Byte auf die SD-Card
 move sr, -(a7)                         * Status sichern
 ori #$0700, sr                         * Interrupts aus
 move.b d0, spidata.w                   * Daten ausgeben
sd1wr1byte:
 btst.b #0, spictrl.w                   * Bereit?
 beq.s sd1wr1byte
 move (a7)+, sr                         * Staus zurück
 rts


sectocmd:
 cmp #3, SDART(a6)
 beq.s stc01                            * SDHC
 lsl.l #1, d0
 move.b d0, 3(a2)
 lsr.l #8, d0
 move.b d0, 2(a2)
 lsr.l #8, d0
 move.b d0, 1(a2)
 bra.s stc02
stc01:
 move.b d0, 4(a2)
 lsr.l #8, d0
 move.b d0, 3(a2)
 lsr.l #8, d0
 move.b d0, 2(a2)
 lsr.l #8, d0
 move.b d0, 1(a2)
stc02:
 rts

SD_WRBYTE	equ	-4
SD_RDBYTE	equ	-8
SD_CSAKT	equ	-12
SD_CSNAKT	equ	-16

SDSIZE          equ     0
SDBPBLK         equ     4
SDART           equ     6               * 0=MMC, 1=SD, 2=SDv2, 3=SDHC
SDNAME          equ     8

SPI_DI          equ     0               * Eingang (74LS245): DAT/DO der SD
SPI_CS0         equ     4               * Ausgang (74LS374): CS der SD0
SPI_CS1         equ     6               * Ausgang (74LS374): CS der SD1
SPI_DO          equ     0               * Ausgang (74LS374): CMD/DI der SD
SPI_CLK         equ     3               * Ausgang (74LS374): CLK/SCLK der SD

SPIH0_CS        equ     5               * CS der ersten Hardware SD
SPIH1_CS        equ     6               * CS der zweiten Hardware SD

* SD-Command Errorbits
R1_IDLE         equ     0
R1_ILL          equ     2

* Timeoutwerte
TIMEOUT         equ     1000*cpu

spcmd0:         dc.b $40, 0, 0, 0, 0, $95       * Reset
spcmd1:         dc.b $41, 0, 0, 0, 0, $ff       * Initialisierung
spcmd8:         dc.b $48, 0, 0, $01, $aa, $87   * "Spannung"
spcmd9:         dc.b $49, 0, 0, 0, 0, $ff       * CSD Auslesen
spcmd10:        dc.b $4a, 0, 0, 0, 0, $ff       * CID Auslesen
spcmd55:        dc.b $77, 0, 0, 0, 0, $ff       * APP_CMD
spcmd58:        dc.b $7a, 0, 0, 0, 0, $ff       * HC?
spacmd41:       dc.b $69, $40, 0, 0, 0, $ff     * OCR


mmctxt:         dc.b 'MMC-Card ', 0
sdtxt:          dc.b 'SDv1-Card ', 0
sd2txt:         dc.b 'SDv2-Card ', 0
sdhctxt:        dc.b 'SDHC-Card ', 0

ds 0
