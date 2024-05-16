# m6809 #

Assembler, simulator and assembly-language routines for the Motorola 6809,
recovered from an old Subversion repository in October 2021 for RetroChallenge.

## asm ##

The Frankenstein Assembler for the 6809.
Quite an old K&R C program, but should still work on modern Linux systems.
Can only assemble M6809 code (it does not understand the HD6309 extensions).

## bas ##

BASIC interpreter for the 6809.
Inspired by P. J. Brown's
*Writing Interactive Compilers and Interpreters*
(1979) but far from finished.

## doc ##

Some documents on the Hitachi 6309, an enhanced 6809.
I have a few of these rare chips, but not much software for them.

## hd6309 ##

Software for the 6309 that runs on an obscure winch controller PCB that I
found on eBay years ago.
Support for UART, simple machine-code monitor.

## sim ##

6809 simulator that I used to run the BASIC during development.
Seems to work OK.

## uk109 ##

Replacement monitor ROMs for the Compukit UK101 fitted with a 6809 CPU in
place of its original 6502.
Another machine-code monitor, some memory-mapped VDU routines, and a Matrix
style display hack that looks great on a green-screen CRT monitor.

This is the real goal of my efforts for RetroChallenge 2021-10: get this code
working again on the modified UK101.
To do that, I'll need to get the assembler working, connect the PC to a Stag
PP42 EPROM programmer (the green-screen CRT monitor in the original Stag PPZ
failed some time ago), burn some EPROMs, and run them on real hardware.
Then, I can think about writing new 6809 code.

