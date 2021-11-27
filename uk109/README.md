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

## 6809 and 6309 ##

The CPU chip in my modified Compukit UK101 is actually a Hitachi
HD6309.
This chip has additional registers and an enhanced instruction set
compared to the original Motorola M6809.

In the source code,
we have a symbol 'HD6309' which can be set to '1' to enable some extra
code for the HD6309 CPU.
The conditional assembly directives are slightly different for the
two assemblers that are supported.

## Building the Assemblers ##

We have two choices for a 6809 assembler: the Frankenstein
Assembler and the 'asm6809' assembler from http://6809.org.uk by
Ciaran Anscomb.

The Frankenstein Assembler is included in this repo,
and can be built from the source code by following the instructions
in the README file in the subdirectory 'asm'.

The 'asm6809' assembler is a much more modern program and also has the
advantage that it can assemble HD6309 instructions.
To build it, first clone the repo:

```git clone https://www.6809.org.uk/git/asm6809.git```

giving you a new subdirectory:

```cd asm6809```

You'll need the 'autoconf' tools:

```sudo apt-get install autoconf```

as well as the 'flex' and 'bison' lexical analyser and parser generators:

```sudo apt-get install flex bison```

Then, run the autoconfigure step:

```./autogen.sh```

Next, configure the code:

```./configure```

Finally, run 'make':

```make```

and you should have an executable file in ```src/asm6809```.
Copy that into a directory which is on your path,
usually ```~/bin```.

## Building the Compukit Code ##

The ```Makefile``` has two targets and a ```sed``` command to convert
the conditional assembly directives from one assembler to the other.
The Frankenstein Assembler does not support the ```SETDP``` directive,
instead just assuming that DP always contains zero (which is a limitation
of this assembler which could be a problem for some programs).
However, the 'asm6809' assembler requires ```SETDP```,
so we use a ```sed``` command to comment it out (doing it that way keeps
the line numbers the same between the two versions).

The resulting Intel HEX file from the Frankenstein Assembler will contain
only M6809 code.
The Intel HEX file from the 'asm6809' assembler will include HD6309
instructions.
The Motorola S-Record file should be equivalent to the HD6309 version.
