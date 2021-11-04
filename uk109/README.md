# uk109 #

Replacement monitor ROMs for the Compukit UK101 fitted with a 6809 CPU in
place of its original 6502.
Another machine-code monitor, some memory-mapped VDU routines, and a
Matrix style display hack that looks great on a green-screen CRT monitor.

The modified UK101 has a Hitachi HD6309 CPU,
so it should be possible to use the extended features of that chip.

This was the real goal of my efforts for RetroChallenge 2021-10: get this
code working again on the modified UK101.
To do that, I'll need to get the assembler working, connect the PC to a
Stag PP42 EPROM programmer (the green-screen CRT monitor in the original
Stag PPZ failed some time ago), burn some EPROMs, and run them on
real hardware.
Then, I can think about writing new 6809 code.

