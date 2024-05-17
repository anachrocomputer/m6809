# bas #

BASIC interpreter for the 6809.
Inspired by P. J. Brown's
*Writing Interactive Compilers and Interpreters*
(1979) but far from finished.

## Assembling ##

The code is assembled with Ciaran Anscomb's 6809 assembler,
available from: http://www.6809.org.uk/asm6809/

Also uses the Frankenstein Assembler 'as6809',
elsewhere in this repo.

Once those tools are installed,
simply type:

`make`

to build the two HEX files and an SREC file.

## Running With The Simulator ##

A command-line like:

`sim6809 -n -g -q bas09.hex`

will start the simulator and run the BASIC interpreter.
Note that the simulator will only accept Intel HEX files,
not Motorola S-Record files.

Type `system` to exit the interpreter and return to the operating system.

## Testing ##

Rudimentary test files 'tdd1.in' and 'tdd1.ok'.
