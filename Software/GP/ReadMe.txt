GP/BIOS

g710r5a.bin		  - GP 7.10 R5A (Memsize 100MB, loaded to end of 4MB on borad sdram)  IDEIO v712r0.ASM
GP20-130903.bin   - GP 68020 7.10, loads to 28MB (with MEM expansion card) JADOS, SDCARD

GRUND20LD.BIN     - GP 68020 6.xx (old version), with loader, no SDCARD, no clock

MOVE20.ASM        - GP loader: loader @0x0, GP @0x100 in EPROM/FLASH
MOVE20D.ASM       - GP loader with debug output to SER, loader @0x0, GP @ 0x200 in EPROM/FLASH

SDIO-v712r0.ASM   - SD card routines v7.12r0
SDIO-v710r6.ASM   - SD card routines v7.10r6
ideio_v712r0.ASM  - IDE card routines v7.12r0
ideio_v710r6.ASM  - IDE card routines v7.10r6

The 7.12 versions correctly handle the on chip cache of the 68020/30 while accessing SD/IDE cards.
When compiling a new GP, the files sdio.asm and ideio.asm of version 7.10x must be replaced with the 7.12 version.