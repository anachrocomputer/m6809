# Makefile for UK109

# We build the hex file with two different assemblers, the Frankenstein
# Assembler and the 6309-capable assembler from 6809.org.uk.

AS63=asm6809
AS63FLAGS=--6309

FAS=as6809

CC=gcc
CFLAGS=

all: uk109.hex uk109.srec uk109f.hex pbm2fcb demoapp.srec

pbm2fcb: pbm2fcb.c
	$(CC) $(CFLAGS) -o pbm2fcb pbm2fcb.c

splash.asm: splash.pbm
	./pbm2fcb splash.pbm >splash.asm

# We need to change 'endif' into 'endi' to convert
# from asm6809 into Frankenstein Assembler. We also need to
# comment-out the 'setdp' directive and switch to 6809 code.
uk109f.asm: uk109.asm
	sed -e s/endif/endi/ <uk109.asm | sed -e '/HD6309 *equ *1/s/1/0/' | sed -e '/setdp/s/ /;/' >uk109f.asm

# Assemble M6809 version
uk109f.hex: uk109f.asm uk101.asm splash.asm
	$(FAS) -o uk109f.hex -l uk109f.lst uk109f.asm

# Generate Intel Hex file
uk109.hex: uk109.asm uk101.asm splash.asm
	$(AS63) $(AS63FLAGS) -H -o uk109.hex -l uk109.lst uk109.asm

# Generate Motorola S-record file
uk109.srec: uk109.asm uk101.asm splash.asm
	$(AS63) $(AS63FLAGS) -S -o uk109.srec -l uk109.lst uk109.asm

# Generate Motorola S-record file for loadable demo app
demoapp.srec: demoapp.asm uk101.asm
	$(AS63) $(AS63FLAGS) -S -o demoapp.srec -l demoapp.lst demoapp.asm
