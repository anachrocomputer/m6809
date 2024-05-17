# makefile for 6809 BASIC

# We build the hex file with two different assemblers, the Frankenstein
# Assembler and Ciaran Anscomb's 6309-capable assembler from 6809.org.uk.

AS63=asm6809
AS63FLAGS=--6309

FAS=as6809

all: bas09.hex bas09.srec bas09f.hex

# Generate Intel Hex file
bas09.hex: bas09.asm
	$(AS63) $(AS63FLAGS) -H -o bas09.hex -l bas09.lst bas09.asm

# Generate Motorola S-record file
bas09.srec: bas09.asm
	$(AS63) $(AS63FLAGS) -S -o bas09.srec -l bas09.lst bas09.asm

# We need to change 'endif' into 'endi' to convert
# from asm6809 into Frankenstein Assembler. We also need to comment-out
# the 'setdp' directive, fix the 'end' directive, and switch to 6809 code.
bas09f.asm: bas09.asm
	sed -e s/endif/endi/ <bas09.asm | sed -e '/HD6309 *equ *1/s/1/0/' | sed -e '/   end *RESET/cRESET end' | sed -e '/setdp/s/ /;/' >bas09f.asm

# Assemble M6809 version
bas09f.hex: bas09f.asm
	$(FAS) -o bas09f.hex -l bas09f.lst bas09f.asm

tdd1.out: tdd1.in bas09.hex
	sim6809 -g -n -q bas09.hex <tdd1.in >tdd1.out

test: tdd1.in tdd1.ok tdd1.out bas09.hex
	diff -q tdd1.ok tdd1.out

