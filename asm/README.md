# asm #

The Frankenstein Assembler for the 6809.
Needs updating for modern Linux systems which no longer have /usr/tmp.
Probably needs other updating too.

## Building the program ##

We will need the basic compiler, inker and libraries:

`sudo apt-get install build-essential`

The parser for the assembler was written using Lex and Yacc,
so we'll need their modern equivalents:

`sudo apt-get install bison flex`

Once those are installed, we can simply:

`make`

## Building the Documentation ##

We'll need the macro packages for 'groff':

`sudo apt-get install groff`

Then, to see the documentation formatted for the screen:

`groff -mm -Tascii base.doc | more`
`groff -mm -Tascii as6809.doc | more`
`groff -man -Tascii as6809.1 | more`

Try these for HTML or PDF:

`groff -mm -Tpdf base.doc >base.pdf`
`groff -mm -Tpdf base.html >base.html`
