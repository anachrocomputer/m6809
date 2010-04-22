# makefile for 6809 BASIC

bas09.hex: bas09.asm
	as6809 -o bas09.hex -l bas09.lst bas09.asm

tdd1.out: tdd1.in bas09.hex
	sim6809 -g bas09.hex <tdd1.in >tdd1.out

test: tdd1.in tdd1.ok tdd1.out bas09.hex
	diff -q tdd1.ok tdd1.out
