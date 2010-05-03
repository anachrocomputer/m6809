; bas09 --- BASIC for the 6809
; Copyright (c) 2006 BJ, Froods Software Development

; Will need three "methods" for each keyword:
;  Run, List, Tokenise

del             equ     127
sp              equ     32
cr              equ     13
lf              equ     10
bs              equ     8
bel             equ     7
eos             equ     0
eol             equ     0

MAXLINE         equ     80                ; Length of line input buffer

DATASEG         equ     $0000             ; Data segment begins at address 0000
BASICTEXT       equ     $0100             ; Start of BASIC program in internal form
TOPOFRAM        equ     $7fff             ; Top of 32k RAM
UK101BAS        equ     $a000             ; Compukit UK101 BASIC ROM $A000-$BFFF

SEP             equ     ':'               ; Multi-statement lines use the colon separator
PRINTABBR       equ     '?'               ; Abbreviation for PRINT is question-mark

; Tokens for all the BASIC keywords
; Must be in same order as table 'rwordtab'
TLET            equ     $80
TCONST          equ     $81
TVAR            equ     $82
TGOTO           equ     $83
TGOSUB          equ     $84
TRETURN         equ     $85
TREM            equ     $86
TPRINT          equ     $87
TEND            equ     $88
TSTOP           equ     $89
TIF             equ     $8a
TTHEN           equ     $8b
TFOR            equ     $8c
TTO             equ     $8d
TNEXT           equ     $8e
TSTEP           equ     $8f
TINPUT          equ     $90
TREAD           equ     $91
TDATA           equ     $92
TRESTORE        equ     $93
TPOKE           equ     $94
TDIM            equ     $95
TDEF            equ     $96
TON             equ     $97

                org     DATASEG
cmdbuf          rmb     MAXLINE
decbuf          rmb     16
progbase        fdb     0                 ; Base pointer for BASIC program
progtop         fdb     0
scalars         fdb     var0              ; Base pointer for scalar variables
nscalar         fdb     3
tempw           fdb     0                 ; Temporary word location
ptr1            fdb     0                 ; Temporary pointer
lnum            fdb     0                 ; Line number
lintext         fdb     0                 ; Pointer to text of line

                org     BASICTEXT         ; BASIC text storage

line10          fdb     line20            ; Small dummy BASIC program for development only
                fdb     10                ; Line number
                fcb     TLET              ; Token for LET
                fcb     'A'               ; Variable name in ASCII
                fdb     varA              ; Pointer to variable's value
                fcb     TCONST            ; Token for constant         
                fdb     256               ; Constant's value  
                fcb     eol               ; End of line
line20          fdb     line30            ; Link pointer to next line
                fdb     20                ; Line number
                fcb     TFOR
                fcb     'B'
                fdb     varB
                fcb     TCONST
                fdb     1
                fcb     TTO
                fcb     TVAR              ; Token for single letter variable
                fcb     'A'
                fdb     varA
                fcc     '+'
                fcb     TCONST
                fdb     1       
                fcb     eol
line30          fdb     line40            ; Link pointer to next line
                fdb     30
                fcb     TGOSUB
                fdb     50
                fdb     line50
                fcb     SEP
                fcb     TNEXT
                fcb     eol
line40          fdb     line50
                fdb     40
                fcb     TIF
                fcb     TVAR
                fcc     'A'
                fdb     varA
                fcc     '='
                fcb     TCONST
                fdb     42
                fcb     TTHEN
                fcb     TSTOP
                fcb     eol
line50          fdb     line60
                fdb     50
                fcb     TREM
                fcc     'Subroutines'
                fcb     eol
line60          fdb     line70
                fdb     60
                fcb     TPRINT
                fcc     '"HELLO"'
                fcb     SEP
                fcb     TRETURN
                fcb     eol
line70          fdb     sentinel
                fdb     70
                fcb     TGOTO
                fdb     10
                fdb     line10
                fcb     eol
sentinel        fdb     0                 ; End-of-program sentinel
fakeprogtop

; The scalar variables, normally built by the pre-run module
var0            fcb     'A'
                fcb     0
varA            fdb     0                 ; 42 decimal
                fdb     42
                fcb     'B'
                fcb     0
varB            fdb     1                 ; 65536 decimal
                fdb     0
                fcb     'X'
                fcb     '1'
varX1           fdb     $ffff             ; -1 decimal
                fdb     $ffff

; Unused RAM from here upwards

                org     TOPOFRAM
RAMTOP          rmb     1
                
                org     UK101BAS          ; Interpreter code at same address as ROM in UK101
                
RESET           orcc    #%01010000        ; Disable interrupts
                lds     #RAMTOP           ; Set up initial stack pointer
                lda     #3                ; SIM Into CBREAK mode
                swi                       ; SIM
                clra                      ; Initialise all CPU registers
                clrb
                tfr     d,x
                tfr     d,y
                tfr     d,u
                tfr     a,dp              ; Set up Direct Page register
                
                ldx     #BASICTEXT        ; Initialise program base pointer
                stx     progbase
                ldx     #fakeprogtop      ; Initial BASIC program is non-empty
                stx     progtop           ; Change this when dummy BASIC is removed
                
                ldx     #vermsg           ; Print version message on start-up
                jsr     prtmsg

cmdloop         lda     #MAXLINE
                ldx     #cmdbuf           ; Command-level line buffer
                jsr     getlin
                cmpa    #0
                beq     cmdloop           ; Ignore blank lines
                jsr     skipbl
                lda     ,x                ; Look for line numbers
                jsr     isdigit
                bne     lnumseen
;               jsr     prtmsg
;               jsr     crlf
                clra                      ; Must be immediate command
                ldb     #(cmdtabend-cmdtab)/2
                ldu     #kwtab            ; Pointer to keyword table
kwsrch          ldy     ,u++
                jsr     strequc
                beq     kwfound
                inca
                decb                      ; Next keyword
                bne     kwsrch
                ldx     #difmsg
                jsr     prtmsg
                bra     cmdloop
kwfound         ;jsr     hex2ou
;               ldx     #sammsg 
;               jsr     prtmsg
                asla                      ; Multiply by two for indexing
                ldy     #cmdtab
                jsr     [a,y]             ; Dispatch to command-line routines
                bra     cmdloop
                
lnumseen        jsr     atoi16u           ; Convert line number to binary
                lbcs    lnumovf           ; Overflow?
                tfr     d,y               ; Stash in Y
                jsr     skipbl            ; Skip trailing blanks
                lda     ,x
                bne     insline
                jsr     delline           ; User wants to delete a line
                bra     cmdloop           ; Go back for another command line
insline         jsr     tokenise
                cmpa    #0                ; Zero length means error
                beq     cmdloop
                stx     lintext           ; Remember where the line text begins
;               jsr     prtdec8           ; DB
;               jsr     space             ; DB
                jsr     delline           ; New line is OK, so delete old one
                tfr     a,b
                clra
                addd    #5                ; Additional five bytes for line number, link and terminator
                std     tempw             ; Amount to add to each pointer
                jsr     findtop           ; Find sentinel after deletion but before modifying linked list
                stx     progtop           ; Save for later
                sty     lnum
                tfr     y,d               ; Get line number into D
;               ldx     #insmsg           ; DB
;               jsr     prtmsg            ; DB
;               jsr     prtdec16          ; DB Echo line number
                jsr     findins           ; Find insertion point (in X)
                stx     ptr1              ; Remember line pointer for later
;               tfr     x,d               ; DB
;               jsr     space             ; DB
;               jsr     hex4ou            ; DB
;               jsr     crlf              ; DB
;               jsr     space             ; DB
;               ldd     tempw             ; DB
;               jsr     prtdec16          ; DB Print size of gap to open up
;               jsr     crlf              ; DB
ins1            ldd     ,x                ; Load link to be modified
                beq     ins2   
                tfr     d,y               ; Save original link
;               jsr     hex4ou            ; DB Print link target address
;               jsr     space             ; DB
                addd    tempw             ; Add length of inserted line
                std     ,x                ; Write it back
                tfr     y,x               ; Follow old link
                bra     ins1
ins2            ldx     progtop           ; Address of sentinel in X
                tfr     x,d               ; Into D for arithmetic
                subd    ptr1              ; Subtract address where line will be inserted
                addd    #2                ; Add length of sentinel
;               jsr     prtdec16          ; DB
;               jsr     crlf              ; DB
                tfr     d,y               ; Count into Y
                ldd     tempw             ; Offset into D
                ldx     progtop           ; Get address of sentinel
                leax    1,x               ; Start one byte higher
ins3            lda     ,x
                sta     b,x
                leax    -1,x              ; Work backwards
                leay    -1,y
                cmpy    #0
                bne     ins3
                ldx     ptr1              ; Load insertion point address
                tfr     x,d
                addd    tempw
                std     ,x++              ; Store link to next line
                ldd     lnum              ; Fetch line number
                std     ,x++              ; Store it
                ldy     lintext           ; Get ready to copy line test into place
ins4            lda     ,y+
                sta     ,x+
                bne     ins4              ; Copy terminating zero byte
                jmp     cmdloop

lnumovf         ldx     #ovfmsg           ; Line number too big
                jsr     prtmsg
                jmp     cmdloop

; DELLINE
; Delete a line from the BASIC program
; Entry: line number in Y register
; Exit: line deleted, no return value
delline         pshs    d,x,y
                jsr     findtop           ; Address of sentinel in X
                stx     progtop           ; Save for later
                tfr     y,d               ; Get line number back
;               ldx     #delmsg           ; DB
;               jsr     prtmsg            ; DB
;               jsr     prtdec16          ; DB Echo line number
;               jsr     space             ; DB
                jsr     findln            ; Find line in memory
                cmpx    #0                ; Did we find it?
                beq     deldone           ; ...no
                tfr     x,d
;               jsr     hex4ou            ; DB
; X -> line in memory
; Y = line number
                stx     ptr1              ; Remember line pointer for later
                stx     tempw             ; Save line address for now
                ldd     ,x
                subd    tempw
                std     tempw             ; Amount to subtract from each pointer
;               jsr     space             ; DB
;               jsr     prtdec16          ; DB Print size of gap to close up
;               jsr     crlf              ; DB
                ldx     ,x                ; Follow link in line to be deleted
del1            ldd     ,x                ; Load link to be modified
                beq     del2   
                tfr     d,y               ; Save original link
;               jsr     hex4ou            ; DB Print link target address
;               jsr     space             ; DB
                subd    tempw             ; Subract length of deleted line
                std     ,x                ; Write it back
                tfr     y,x               ; Follow old link
                bra     del1
del2            ldx     progtop           ; Address of sentinel in X
                tfr     x,d               ; Into D for arithmetic
                subd    ptr1              ; Subtract address of line to be deleted
                subd    tempw             ; Subtract length of line
                addd    #2                ; Add length of sentinel
;               jsr     prtdec16          ; DB
;               jsr     crlf       
                tfr     d,y               ; Count into Y
                ldd     tempw             ; Offset into D
                ldx     ptr1              ; Get address of line to be deleted
del3            lda     b,x
                sta     ,x+
                leay    -1,y
                cmpy    #0
                bne     del3
deldone         puls    d,x,y,pc
                
; TOKENISE
; Convert BASIC keywords to single byte tokens
; Entry: X -> first non-blank char in source line, after line number
; Exit: X unchanged, points to tokenised line. A = length of line
tokenise        pshs    x,y
                clra
tok1            ldb     ,x+
                beq     tok2
                cmpb    #PRINTABBR
                bne     tok3
                ldb     #TPRINT
                stb     -1,x
tok3            inca
                bra     tok1
tok2            puls    x,y,pc

; EXIT
; Exit from BASIC and return to OS (should clean up)
; Entry: none
; Exit: does not return
exit            lda     #4                ; SIM Out of CBREAK mode
                swi                       ; SIM
                lda     #0                ; SIM Terminate
                swi                       ; SIM
here            jmp     here

LLET            jsr     lrword
                jsr     space
                lda     ,x+               ; Get variable name
                jsr     t1ou
                leax    2,x               ; Skip variable address
                jsr     space
                lda     #'='
                jsr     t1ou
                jsr     space
                rts
LCONST          ldd     ,x++              ; Get value of constant
                jsr     prtdec16
                rts
LVAR            lda     ,x+               ; Get variable name
                jsr     t1ou
                leax    2,x               ; Skip variable address
                rts
LGOTO           jsr     lrword
                jsr     space
                ldd     ,x++              ; Get line number
                jsr     prtdec16          ; Print in decimal
                lda     #'['              ; DB
                jsr     t1ou              ; DB
                ldd     ,x++              ; Skip line pointer
                jsr     hex4ou            ; DB
                lda     #']'              ; DB
                jsr     t1ou              ; DB
                rts
LGOSUB          bra     LGOTO
                rts
LRETURN         jmp     lrword
LREM            jsr     lrword
                jmp     space
LPRINT          jsr     lrword
                jmp     space
LEND            jmp     lrword
LSTOP           jmp     lrword
LIF             jsr     lrword
                jmp     space
LTHEN           jsr     space
                jsr     lrword
                jmp     space
LFOR            jsr     lrword
                jsr     space
                lda     ,x+               ; Get variable name
                jsr     t1ou
                leax    2,x               ; Skip variable address
                jsr     space
                lda     #'='
                jsr     t1ou
                jsr     space
                rts
LTO             jsr     space
                jsr     lrword
                jmp     space
LNEXT           jmp     lrword
LSTEP           jmp     lrword
LINPUT          jmp     lrword
LREAD           jmp     lrword
LDATA           jmp     lrword
LRESTORE        jmp     lrword
LPOKE           jmp     lrword
LDIM            jsr     lrword
                jmp     space
LDEF            jsr     lrword
                jmp     space
LON             jsr     lrword
                jmp     space

; LRWORD
; List a reserved word
; Entry: A=token offset
; Exit: Registers unchanged
lrword          pshs    a,x
                ldx     #rwordtab
                ldx     a,x
lrw1            lda     ,x+
                beq     lrw2
                jsr     t1ou
                bra     lrw1
lrw2            puls    a,x,pc
                
; LIST --- needs start/end line numbers
LIST            ldx     progbase
listln          ldd     ,x++              ; Read link to next line
                beq     listdn            ; Reached end-of-program sentinel?
                pshs    d                 ; DB
                lda     #'['              ; DB
                jsr     t1ou              ; DB
                tfr     x,d               ; DB
                subd    #2                ; DB
                jsr     hex4ou            ; DB
                lda     #']'              ; DB
                jsr     t1ou              ; DB
                puls    d                 ; DB
                tfr     d,u               ; Save pointer to next line
                ldd     ,x++              ; Get line number
                jsr     prtdec16          ; Print in decimal
                jsr     space
listch          lda     ,x+               ; Read first token of line
                beq     listeol
                bpl     listasc
                anda    #$7F              ; Strip top bit
                asla                      ; Double it
                ldy     #listtab          ; Get address of call table
                jsr     [a,y]             ; Call routine for this token
                bra     listch            ; Go back for next byte
listasc         cmpa    #SEP
                beq     listsep
                jsr     t1ou
                bra     listch
listsep         jsr     t1ou              ; Print statement separator
                bra     listch
listeol         jsr     crlf              ; End of BASIC line
                tfr     u,x               ; Transfer saved pointer to X
                bra     listln
listdn          rts

; VLIST --- list variable names and values
VLIST           ldx     nscalar           ; Load number of scalar variables
                ldy     scalars           ; Load pointer to scalars
vl1             cmpx    #0                ; Check for zero
                beq     vlistdn
                lda     ,y+               ; Get first char of variable name
                jsr     t1ou              ; Print it
                lda     ,y+               ; Get second char
                bne     vl2
                lda     #sp
vl2             jsr     t1ou              ; Print second char or space
                jsr     space
                ldd     ,y++              ; Get variable value (hi)
                jsr     hex4ou
                ldd     ,y++              ; Get variable value (lo)
                jsr     hex4ou
                jsr     crlf
                leax    -1,x              ; Decrement X
                bra     vl1
vlistdn         rts
                
; RUN --- execute program, from start or from given line
RUN             bra     runfromstart      ; Temporary: until parser works
                jsr     skipbl            ; Skip blanks
                lda     ,x                ; Look for line number
                beq     runfromstart
                jsr     isdigit
                beq     runline
                ldx     #lnummsg
                jsr     prtmsg
                bra     rundn
runline         jsr     atoi16u           ; Grab line number
                bcs     runlnerr          ; Overflow?
                tfr     d,y               ; Save in Y for now
                jsr     skipbl            ; Skip trailing blanks
                lda     ,x                ; Make sure we have EOL
                bne     runsynerr         ; Syntax error
                tfr     y,d               ; Recover saved line number
                bra     dorun
runfromstart    ldd     #50
dorun           jsr     findln
                tfr     x,d
                jsr     hex4ou
                jsr     crlf
rundn           rts
runlnerr        ldx     #ovfmsg
                jsr     prtmsg
                bra     rundn
runsynerr       ldx     #synmsg
                jsr     prtmsg
                bra     rundn

; PDUMP --- dump program area in hex for debugging
PDUMP           jsr     findtop           ; Find the address of the sentinel
                tfr     x,d
                subd    progbase          ; Subract base address to get
                tfr     d,x               ; program length in bytes
                leax    2,x               ; We want to show the two zero bytes (sentinel)
                ldy     progbase
                ldb     #0                ; B reg counts bytes per row (0..15)
                bra     dump1
dump4           jsr     crlf
dump1           pshs    d
                tfr     y,d
                jsr     hex4ou            ; Print address
                puls    d
dump2           jsr     space
                lda     ,y+
                jsr     hex2ou            ; Print bytes of program memory
                leax    -1,x
                cmpx    #0
                beq     dump3
                incb
                andb    #$0f
                beq     dump4             ; Go back and print CR/LF and address
                bra     dump2
dump3           jsr     crlf
                rts
                
; VDUMP --- dump variable area in hex for debugging
VDUMP           ldy     #vdumptab
vdump1          ldx     ,y++              ; Load pointer to string
                beq     vdump2
                jsr     prtmsg
                ldx     ,y++              ; Load pointer to data word
                ldd     ,x                ; Load data word
                jsr     hex4ou
                jsr     crlf
                bra     vdump1
vdump2          rts
                
; MEM --- print memory usage information
MEM             jsr     findtop
                tfr     x,d
                subd    progbase          ; Subract base address to get
                jsr     prtdec16
                ldx     #memmsg
                jsr     prtmsg
                rts
                
; CONT --- continue execution after STOP or BREAK
CONT            ldx     #contmsg
                jsr     prtmsg
                rts
                
; NEW --- delete all program lines
NEW             ldx     #BASICTEXT
                stx     progbase
                ldd     #0
                std     ,x
                std     progtop
                std     scalars
                std     nscalar
                rts
                
; LOAD --- load program from storage
LOAD            ldx     #playmsg
                jsr     prtmsg
                rts
                
; SAVE --- save program to storage
SAVE            nop
                rts

; SYSTEM --- exit from BASIC back to OS
SYSTEM          jmp     exit              ; Doesn't clean up the stack

; FINDLN
; Find address of a line, given line number
; Entry: D=Line number
; Exit: X=Line pointer (NULL if not found)
findln          pshs    y
                ldx     progbase
findln1         ldy     ,x                ; Load link to next line
                cmpy    #0                ; At end-of-program sentinel?
                beq     findnot
                cmpd    2,x               ; Compare with next word
                beq     finddn            ; If equal, we're done
                tfr     y,x               ; Follow link
                bra     findln1
findnot         ldx     #0                ; We didn't find the line
finddn          puls    y,pc
                
; FINDINS
; Find insertion point for new line
; Entry: D=Line number
; Exit: X=Address to insert new line
findins         pshs    y
                ldx     progbase
findin1         ldy     ,x                ; Load link to next line
                cmpy    #0                ; At end-of-program sentinel?
                beq     findidn
                cmpd    2,x               ; Compare with next word
                blo     findidn           ; If higher, we're done
                tfr     y,x               ; Follow link
                bra     findin1
findidn         puls    y,pc
                
; FINDTOP
; Find top of program area
; Entry: none
; Exit: Address of end-of-program sentinel in X
findtop         pshs    y
                ldx     progbase
findtop1        ldy     ,x      
                beq     findtop2
                tfr     y,x
                bra     findtop1
findtop2        puls    y,pc
                
; 32-bit addition
; Entry: X, Y pointers to parameters
; Exit: Result in D and X
add32           pshs    y
                ldd     2,x
                addd    2,y
                tfr     d,u
                ldd     ,x
                addd    ,y                ; Use adcd on 6309
                tfr     d,x
                puls    y,pc              ; Restore registers and return
                
; STREQ
; Compare two strings for equality
; Entry: X, Y: pointers to two NUL-terminated strings
; Exit: Zero if equal, non-zero otherwise
streq           pshs    a,x,y
seqloop         lda     ,x+               ; Fetch chars from first string
                beq     seqdone
                cmpa    ,y+               ; Compare with second string
                beq     seqloop
                bra     seqfail
seqdone         lda     ,y                ; If we're at EOS, they're equal
seqfail         puls    a,x,y,pc

; SKIPBL
; Skip over blanks in a string
; Entry: X=pointer to string
; Exit: X=incremented to point to first non-blank
skipbl          pshs    a
skip2           lda     ,x                ; Fetch ASCII
                cmpa    #sp               ; Look for space
                bne     skip1
                leax    1,x               ; Inc X to skip blanks
                bra     skip2
skip1           puls    a,pc
                
; STREQUC
; Compare two strings for equality, mapping to upper case
; Entry: X, Y: pointers to two NUL-terminated strings
; Exit: Zero if equal, non-zero otherwise
strequc         pshs    a,x,y
seqloopuc       lda     ,x+               ; Fetch chars from first string
                beq     seqdoneuc
                jsr     toupper           ; Map to upper case
                cmpa    ,y+               ; Compare with second string
                beq     seqloopuc
                bra     seqfailuc
seqdoneuc       lda     ,y                ; If we're at EOS, they're equal
seqfailuc       puls    a,x,y,pc

; GETLIN
; Get characters from the terminal, delimited by CR
; Entry: A=buffer length, X=buffer address
; Exit: A=number of bytes, X=unchanged
getlin          pshs    b,x               ; Save B and X
                leas    -2,s              ; Allocate two local vars
                clr     0,s               ; curlen=0
                deca                      ; Allow for terminator
                sta     1,s               ; maxlen=A
get0            jsr     t1in              ; Get a character
                cmpa    #cr               ; Check for CR
                beq     get1
                cmpa    #lf               ; Check for LF
                beq     get1
                cmpa    #bs               ; Check for BS
                beq     get2
                cmpa    #del              ; Check for DEL
                beq     get2
                ldb     0,s               ; Get curlen
                cmpb    1,s               ; Compare with maxlen
                beq     get3              ; Full?
                jsr     t1ou              ; Echo
                sta     ,x+               ; Store in buffer
                inc     0,s               ; Inc curlen
                bra     get0
get3            lda     #bel              ; Buffer full, beep
                jsr     t1ou
                bra     get0
get2            ldb     0,s               ; Get curlen
                beq     get3              ; Buffer empty, beep
                dec     0,s               ; curlen--
                leax    -1,x              ; X--
                lda     #bs               ; Load BS in case user hit DEL
                jsr     t1ou              ; Echo BS
                jsr     space             ; Send a space
                jsr     t1ou
                bra     get0              ; Go back again
get1            clr     ,x                ; Terminate buffer
                jsr     crlf              ; Echo newline
                lda     0,s               ; A=curlen
                leas    2,s               ; Deallocate local vars
                puls    b,x,pc            ; Restore registers and return
                
; PRTMSG
; Print message pointed to by X, terminated by zero byte
prtmsg          pshs    a,x               ; Save A and X registers
prtmsg1         lda     ,x+
                beq     prtmsg2
                jsr     t1ou
                bra     prtmsg1
prtmsg2         puls    a,x,pc            ; Restore A and X, then return

; Hex output routines

; HEX1OU --- print a single hex digit
; Entry: 4 bit value in A
; Exit:  registers unchanged
hex1ou          pshs    a,x
                anda    #$0f
                ldx     #hexdig
                lda     a,x
                jsr     t1ou
                puls    a,x,pc

; HEX2OU
; Entry: 8 bit value in A
; Exit:  registers unchanged
hex2ou          pshs    a
                asra
                asra
                asra
                asra
                jsr     hex1ou            ; Print high nybble...
                puls    a
                jsr     hex1ou            ; then low nybble
                rts
                
; HEX4OU
; Entry: 16 bit value in D
; Exit:  registers unchanged
hex4ou          pshs    d
                jsr     hex2ou
                puls    d
                pshs    d
                tfr     b,a
                jsr     hex2ou
                puls    d,pc
                
; CRLF --- print CR and LF
; Entry: no parameters
; Exit:  registers unchanged
crlf            pshs    a
                lda     #cr
                jsr     t1ou
                lda     #lf
                jsr     t1ou
                puls    a,pc
                
hexdig          fcc     '0123456789ABCDEF'

; Hex input routines

; HEX1IN --- read a single hex digit from the keyboard
; Entry: no parameters
; Exit:  4-bit value in A
hex1in          jsr     t1in              ; Read one ASCII character
                jsr     t1ou              ; Echo it
                jsr     toupper
                cmpa    #'0'
                blo     hexerr
                cmpa    #'9'
                bhi     hexalph
                suba    #'0'
                bra     hexdone
hexalph         cmpa    #'A'
                blo     hexerr
                cmpa    #'F'
                bhi     hexerr
                suba    #'A'-10
hexdone         rts
hexerr          lda     #'?'
                jsr     t1ou
                clra
                bra     hexdone
                
; HEX2IN --- read two hex digits from the keyboard
; Entry: no parameters
; Exit:  8-bit value in A, flags set
hex2in          jsr     hex1in
                asla
                asla
                asla
                asla
                pshs    a
                jsr     hex1in
                ora     ,s+
                rts

; HEX4IN --- read four hex digits from the keyboard
; Entry: no parameters
; Exit:  16-bit value in D
hex4in          jsr     hex2in
                tfr     a,b
                jsr     hex2in
                exg     a,b
                rts
               
prtdec16        pshs    d,x,y
                ldx     #decbuf
                jsr     bn2dec
                ldx     #decbuf+1
                jsr     prtmsg
                puls    d,x,y,pc
                
; PRTDEC8
; Print 8-bit number in decimal
; Entry: number in A
; Exit: registers unchanged
prtdec8         pshs    d
                tfr     a,b
                clra
                jsr     prtdec16
                puls    d,pc

; I/O routines

; SPACE --- print a space
; Entry: no parameters
; Exit:  registers unchanged
space           pshs    a
                lda     #sp
                jsr     t1ou
                puls    a,pc
                
; TOUPPER --- map an ASCII character to upper case
; Entry: ASCII character in A
; Exit: uppercase ASCII character in A, other registers unchanged
toupper         cmpa    #'a'
                blo     uprrtn
                cmpa    #'z'
                bhi     uprrtn
                suba    #'a'-'A'
uprrtn          rts

; TOLOWER --- map an ASCII character to lower case
; Entry: ASCII character in A
; Exit: lowercase ASCII character in A, other registers unchanged
tolower         cmpa    #'A'
                blo     lowrtn
                cmpa    #'Z'
                bhi     lowrtn
                adda    #'a'-'A'
lowrtn          rts

; ISDIGIT --- test if ASCII char in A is a digit
; Entry: ASCII character in A
; Exit: Non-zero if A contains a digit, all other registers unchanged
isdigit         cmpa    #'0'
                blo     nondig
                cmpa    #'9'
                bhi     nondig
                andcc   #$fb              ; Clear Zero flag for TRUE
                rts
nondig          orcc    #$04              ; Set Zero flag for FALSE
                rts

atoi16u         pshs    y
                jsr     DECCON
                pshs    cc
                leax    -1,x
                puls    cc,y,pc
                
;===============================================================
;= DECCON   ASCII decimal to unsigned 16-bit conversion.
;===============================================================
;JOB        To convert an unsigned ASCII decimal string held in
;           memory to a 16-bit binary value in registers, or
;           return overflow information.
;ACTION     On 16-bit overflow: [ Set overflow flag. Exit. ]
;           Clear 16-bit partial result accumulator.
;           Get 1st character and address next.
;           WHILE character is ASCII digit;
;           [ Strip ASCII digits hi-nibble.
;             Partial result = partial result * 10 + digit.
;             Get character and adress next. ]
;---------------------------------------------------------------
;CPU        6809
;HARDWARE   Memory containing ASCII decimal number.
;SOFTWARE   None.
;---------------------------------------------------------------
;INPUT      X addresses the 1st (high order) byte of the ASCII
;           decimal number string. The string must terminate
;           with any non-digit character.
;OUTPUT     Y is changed.
;           C = 1: overflow has occurred. X and D unknown.
;           C = 0: conversion successfully completed.
;             D contains the binary equivalent.
;             X addresses the byte following the terminator.
;ERRORS     None.
;REG USE    CC D X Y
;STACK USE  2
;RAM USE    None.
;LENGTH     34
;CYCLES     38+73 8 number of digits.
;           (Non-overflow and excluding leading zeros).
;---------------------------------------------------------------
;CLASS 2     -discreet      *interruptable      *promable
;-*****      *reentrant     *relocatable        *robust
;===============================================================
;
DECCON          clra                      ; Zeroise binary result
                clrb
;
nxtdgt          tfr     d,y               ; Move partial result to Y
                clra                      ; Clear acc hi-byte, get next ASCII
                ldb     ,x+               ; digit in lo-byte, indexing next.
                subb    #$30              ; Strip off ASCII digits hi-nybble
                cmpb    #$0a              ; and test for valid decimal digit.
                exg     d,y               ; Digit to Y, part result to D.
                bcc     exit2             ; Exit conversion done if not digit.
                bita    #$e0              ; Else test if * 10 by shifting will
                bne     exit2             ; overflow and exit if so, carry set.
                lslb                      ; Shift partial result up one bit
                rola                      ; for partial result * 2, and add
                leay    d,y               ; to new digit in Y.
                lslb                      ; Second shift gives
                rola                      ; partial result * 4
                lslb                      ; Third shift gives 
                rola                      ; partial result * 8 in D.
                pshs    y                 ; Put part result * 2 + new digit on
                addd    ,s++              ; stack and add in, clearing stack.
                bcc     nxtdgt            ; Repeat if no overflow from add.
;
exit2           rts                       ; Exit okay (C = 0), overflow (C = 1)


bn2dec          std     1,x               ; Save data in buffer
;               bpl     cnvert            ; Branch if data positive
;               ldd     #0                ; else take positive value
;               subd    1,x
; Initialise string length to zero
cnvert          clr     ,x                ; String length = 0
; Divide binary data by 10 by subtracting powers of ten
div10           ldy     #-1000            ; Start quotient at -1000
; Find number of thousands in quotient
thousd          leay    1000,y            ; Add 1000 to quotient
                subd    #10000            ; Subtract 10000 from dividend
                bcc     thousd            ; Branch if difference still positive
                addd    #10000            ; Else add back last 10000
; Find number of hundreds in quotient
                leay    -100,y            ; Start number of hundreds at -1
hundd           leay    100,y             ; Add 100 to quotient
                subd    #1000             ; Subtract 1000 from dividend
                bcc     hundd             ; Branch if difference still positive
                addd    #1000             ; Else add back last 1000
; Find number of tens in quotient
                leay    -10,y             ; Start number of tens at -1
tensd           leay    10,y              ; Add 10 to quotient
                subd    #100              ; Subtract 100 from dividend
                bcc     tensd             ; Branch if difference still positive
                addd    #100              ; Else add back last 100
; Find number of ones in quotient
                leay    -1,y              ; Start number of ones at -1
onesd           leay    1,y               ; Add 1 to quotient
                subd    #10               ; Subtract 10 from dividend
                bcc     onesd             ; Branch if difference still positive
                addd    #10               ; Else add back last 10
                stb     ,-s               ; Save remainder in stack
                inc     ,x                ; Add 1 to length byte
                tfr     y,d               ; Make quotient into new dividend
                cmpd    #0                ; Check if dividend zero
                bne     div10             ; Branch if not - divide by 10 again
; Check if original binary data was negative
; If so, put ASCII - at front of buffer
                lda     ,x+               ; Get length byte (not including sign)
;               ldb     ,x                ; Get high byte of data
;               bpl     bufload           ; Branch if data positive
;               ldb     #'-'              ; Otherwise, get ASCII minus sign
;               stb     ,x+               ; Store minus sign in buffer
;               inc     -2,x              ; Add 1 to length byte for sign
; Move string of digits from stack to buffer
; Most significant digit is at top of stack
; Convert digits to ASCII by adding ASCII 0
bufload         ldb     ,s+               ; Get next digit from stack, moving right
                addb    #'0'              ; Convert digit to ASCII
                stb     ,x+               ; Save digit in buffer
                deca                      ; Decrement byte counter
                bne     bufload           ; Loop if more bytes left
                clr     ,x                ; Add terminator to buffer
                rts

; T1OU
; Entry: A=ASCII char to print
; Exit:  registers unchanged
t1ou            pshs    a,b               ; SIM Save A & B
                tfr     a,b               ; SIM
                lda     #5                ; SIM
                swi                       ; SIM
                puls    a,b,pc            ; SIM
                
; T1IN
; Entry: no parameters
; Exit:  A=ASCII char read in, all other registers unchanged
t1in            nop
                lda     #6                ; SIM
                swi                       ; SIM
                rts

kwtab           fdb     klist
                fdb     kvlist
                fdb     krun
                fdb     knew
                fdb     kcont
                fdb     kload
                fdb     ksave
                fdb     ksystem
                fdb     kpdump
                fdb     kvdump
                fdb     kmem
                
cmdtab          fdb     LIST
                fdb     VLIST
                fdb     RUN
                fdb     NEW
                fdb     CONT
                fdb     LOAD
                fdb     SAVE
                fdb     SYSTEM
                fdb     PDUMP
                fdb     VDUMP
                fdb     MEM
cmdtabend
                
; Table of routines for LIST
; Must be in same order as tokens
listtab         fdb     LLET
                fdb     LCONST
                fdb     LVAR
                fdb     LGOTO
                fdb     LGOSUB
                fdb     LRETURN
                fdb     LREM
                fdb     LPRINT
                fdb     LEND
                fdb     LSTOP
                fdb     LIF
                fdb     LTHEN
                fdb     LFOR
                fdb     LTO
                fdb     LNEXT
                fdb     LSTEP
                fdb     LINPUT
                fdb     LREAD
                fdb     LDATA
                fdb     LRESTORE
                fdb     LPOKE
                fdb     LDIM
                fdb     LDEF
                fdb     LON
listtabend

; Table of BASIC reserved words
; Must be in same order as tokens
rwordtab        fdb     klet
                fdb     kconst
                fdb     kvar
                fdb     kgoto
                fdb     kgosub
                fdb     kreturn
                fdb     krem
                fdb     kprint
                fdb     kend
                fdb     kstop
                fdb     kif
                fdb     kthen
                fdb     kfor
                fdb     kto
                fdb     knext
                fdb     kstep
                fdb     kinput
                fdb     kread
                fdb     kdata
                fdb     krestore
                fdb     kpoke
                fdb     kdim
                fdb     kdef
                fdb     kon
rwordtabend

klist           fcc     'LIST'
                fcb     eos
kvlist          fcc     'VLIST'
                fcb     eos
krun            fcc     'RUN'
                fcb     eos
knew            fcc     'NEW'
                fcb     eos
kcont           fcc     'CONT'
                fcb     eos
kload           fcc     'LOAD'
                fcb     eos
ksave           fcc     'SAVE'
                fcb     eos
ksystem         fcc     'SYSTEM'
                fcb     eos
kpdump          fcc     'PDUMP'
                fcb     eos
kvdump          fcc     'VDUMP'
                fcb     eos
kmem            fcc     'MEM'
                fcb     eos

klet            fcc     'LET'
                fcb     eos
kconst          fcc     '<const>'
                fcb     eos
kvar            fcc     '<var>'
                fcb     eos
kprint          fcc     'PRINT'
                fcb     eos
kfor            fcc     'FOR'
                fcb     eos
kto             fcc     'TO'
                fcb     eos
kstep           fcc     'STEP'
                fcb     eos
knext           fcc     'NEXT'
                fcb     eos
kif             fcc     'IF'
                fcb     eos
kthen           fcc     'THEN'
                fcb     eos
kgoto           fcc     'GOTO'
                fcb     eos
kgosub          fcc     'GOSUB'
                fcb     eos
kreturn         fcc     'RETURN'
                fcb     eos
kon             fcc     'ON'
                fcb     eos
kdata           fcc     'DATA'
                fcb     eos
kread           fcc     'READ'
                fcb     eos
krestore        fcc     'RESTORE'
                fcb     eos
kinput          fcc     'INPUT'
                fcb     eos
kstop           fcc     'STOP'
                fcb     eos
kend            fcc     'END'
                fcb     eos
kdef            fcc     'DEF'
                fcb     eos
kdim            fcc     'DIM'
                fcb     eos
kpoke           fcc     'POKE'
                fcb     eos
krem            fcc     'REM'
                fcb     eos

;sammsg          fcc     ' keyword found'
;                fcb     cr,lf,eos
difmsg          fcc     'Mistake'
                fcb     cr,lf,eos
synmsg          fcc     'Syntax error'
                fcb     cr,lf,eos
lnummsg         fcc     'Line number expected'
                fcb     cr,lf,eos
;unsupmsg        fcc     'That function is not yet supported'
;                fcb     cr,lf,eos
ovfmsg          fcc     'Line number too big'
                fcb     cr,lf,eos
contmsg         fcc     'Cant continue'
                fcb     cr,lf,eos
;delmsg          fcc     'Delete line: '
;                fcb     eos
insmsg          fcc     'Insert line: '
                fcb     eos
playmsg         fcc     'Press play on tape'
                fcb     cr,lf,eos
memmsg          fcc     ' bytes used'
                fcb     cr,lf,eos
vermsg          fcc     '6809 BASIC version 0.1'
                fcb     cr,lf,eos

vd1             fcc     'progbase: '
                fcb     eos
vd2             fcc     'progtop:  '
                fcb     eos
vd3             fcc     'scalars:  '
                fcb     eos
vd4             fcc     'nscalar:  '
                fcb     eos
vd5             fcc     'tempw:    '
                fcb     eos

vdumptab        fdb     vd1,progbase
                fdb     vd2,progtop
                fdb     vd3,scalars
                fdb     vd4,nscalar
                fdb     vd5,tempw
                fdb     0,0
                

RESET           end
