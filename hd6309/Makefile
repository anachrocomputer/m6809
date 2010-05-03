# Makefile for 6809 code
#
all: mon63.hex firq.hex srec.hex util.hex world.hex

mon63.hex: mon63.asm
	as6809 -o mon63.hex -l mon63.lst mon63.asm

firq.hex: firq.asm
	as6809 -o firq.hex -l firq.lst firq.asm

srec.hex: srec.asm
	as6809 -o srec.hex -l srec.lst srec.asm

util.hex: util.asm
	as6809 -o util.hex -l util.lst util.asm

world.hex: world.asm
	as6809 -o world.hex -l world.lst world.asm
