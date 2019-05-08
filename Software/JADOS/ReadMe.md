This directory contains a zipped JADOS image for use with sd cards (GDP-FPGA) and the 680x0 SBCs.

block size: 512 byte
blocks:     133320
size:       68.259.840   Byte (65MB)


Copy to sd card with linux:

1) check with lsblk where you sd card is mounted:

$ lsblk 
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
fd0      2:0    1    4K  0 disk 
sda      8:0    0  100G  0 disk 
|-sda1   8:1    0 92.4G  0 part /
|-sda2   8:2    0    1K  0 part 
`-sda5   8:5    0  7.6G  0 part 
sdc      8:32   1 14.1M  0 disk 
`-sdc1   8:33   1 13.6M  0 part 
sr0     11:0    1 1024M  0 rom  



2) write image:

 [sudo] dd bs=512 count=133320 if=jados.img of=/dev/sdc [status=progress]

