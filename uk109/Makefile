# Makefile for UK109

# We build the hex file with two different assemblers, the Frankenstein
# Assembler and the 6309-capable assembler from 6809.org.uk.

AS63=asm6809
AS63FLAGS=--setdp 0 --6809

FAS=as6809

all: uk109.hex uk109.srec uk109f.hex

uk109f.hex: uk109.asm
	$(FAS) -o uk109f.hex -l uk109f.lst uk109.asm

# We need to change 'endi' into 'endif' and 'eq' into '==' to
# convert from Frankenstein Assembler into asm6809
uk109h.asm: uk109.asm
	sed -e s/endi/endif/ -e "s/ eq / == /" <uk109.asm >uk109h.asm

# Generate Intel Hex file
uk109.hex: uk109h.asm
	$(AS63) $(AS63FLAGS) -H -o uk109.hex -l uk109.lst uk109h.asm

# Generate Motorola S-record file
uk109.srec: uk109h.asm
	$(AS63) $(AS63FLAGS) -S -o uk109.srec -l uk109.lst uk109h.asm
