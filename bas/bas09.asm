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

SEP             equ     ':'

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

                org     $80
cmdbuf          rmb     80
decbuf          rmb     16

                org     $0100             ; Just above "zero-page"

reset           orcc    #%01010000        ; Disable interrupts
                lds     #$7fff            ; Set up initial stack pointer
                lda     #3                ; SIM Into CBREAK mode
                swi                       ; SIM
                clra
                clrb
                tfr     d,x
                tfr     d,y
                tfr     d,u
                tfr     a,dp              ; Set up Direct Page register

                ldx     #vermsg
                jsr     prtmsg

cmdloop         lda     #80
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
                ldb     #7                ; Number of keywords
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
                bcs     lnumovf           ; Overflow?
                tfr     d,y               ; Stash in Y
                jsr     skipbl            ; Skip trailing blanks
                lda     ,x
                beq     delline           ; User wants to delete a line
                ldx     #unsupmsg
                jsr     prtmsg
                bra     cmdloop
lnumovf         ldx     #ovfmsg           ; Line number too big
                jsr     prtmsg
                bra     cmdloop
delline         nop
                tfr     y,d               ; Get line number back
                ldx     #delmsg
                jsr     prtmsg
                jsr     prtdec16          ; Echo line number
                jsr     crlf
                bra     cmdloop
                
exit            lda     #4                ; SIM Out of CBREAK mode
                swi                       ; SIM
                lda     #0                ; SIM Terminate
                swi                       ; SIM
here            jmp     here

; LIST --- needs start/end line numbers
LIST            ldx     #line0
listln          cmpx    #0                ; End of list?
                beq     listdn
                lda     #'['              ; DB
                jsr     t1ou              ; DB
                tfr     x,d               ; DB
                jsr     hex4ou            ; DB
                lda     #']'              ; DB
                jsr     t1ou              ; DB
                ldd     ,x++              ; Read link to next line
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
                
; RUN --- needs start line number
RUN             ldd     #50
                jsr     findln
                tfr     x,d
                jsr     hex4ou
                jsr     crlf
                rts

; SYSTEM
SYSTEM          jmp     exit              ; Doesn't clean up the stack

CONT            ldx     #contmsg
                jsr     prtmsg
                rts
NEW             nop
                rts
LOAD            ldx     #playmsg
                jsr     prtmsg
                rts
SAVE            nop
                rts

; FINDLN
; Entry: A=Line number
; Exit: X=Line pointer (NULL if not found)
findln          ldx     #line0
findln1         cmpx    #0
                beq     finddn
                cmpd    2,x               ; Compare with next word
                beq     finddn            ; If equal, we're done
                ldx     ,x                ; Follow pointer
                bra     findln1
finddn          rts
                
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
                
; HEX2IN --- read a two hex digits from the keyboard
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

; HEX4IN --- read a two hex digits from the keyboard
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
; Exit uppercase ASCII character in A, other registers unchanged
toupper         cmpa    #'a'
                blo     uprrtn
                cmpa    #'z'
                bhi     uprrtn
                suba    #'a'-'A'
uprrtn          rts

; TOLOWER --- map an ASCII character to lower case
; Entry: ASCII character in A
; Exit lowercase ASCII character in A, other registers unchanged
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
                fdb     krun
                fdb     ksystem
                fdb     knew
                fdb     kcont
                fdb     kload
                fdb     ksave
                
cmdtab          fdb     LIST
                fdb     RUN
                fdb     SYSTEM
                fdb     NEW
                fdb     CONT
                fdb     LOAD
                fdb     SAVE
                
; Table of routines for LIST
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

; Table of BASIC reserved words
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

klist           fcc     'LIST'
                fcb     eos
krun            fcc     'RUN'
                fcb     eos
ksystem         fcc     'SYSTEM'
                fcb     eos
knew            fcc     'NEW'
                fcb     eos
kcont           fcc     'CONT'
                fcb     eos
kload           fcc     'LOAD'
                fcb     eos
ksave           fcc     'SAVE'
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
unsupmsg        fcc     'That function is not yet supported'
                fcb     cr,lf,eos
ovfmsg          fcc     'Line number too big'
                fcb     cr,lf,eos
contmsg         fcc     'Cant continue'
                fcb     cr,lf,eos
delmsg          fcc     'Delete line: '
                fcb     eos
playmsg         fcc     'Press play on tape'
                fcb     cr,lf,eos
vermsg          fcc     '6809 BASIC version 0.1'
                fcb     cr,lf,eos

line0
line10          fdb     line20            ; Pointer to next line
                fdb     10                ; Line number
                fcb     TLET              ; Token for LET
                fcb     'A'               ; Variable name in ASCII
                fdb     varA              ; Pointer to variable's value
                fcb     TCONST            ; Token for constant         
                fdb     256               ; Constant's value  
                fcb     eol               ; End of line
line20          fdb     line30            ; Link
                fdb     20    
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
line30          fdb     line40            ; Link
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
line70          fdb     0
                fdb     70
                fcb     TGOTO
                fdb     10
                fdb     line10
                fcb     eol

varA            rmb     4
varB            rmb     4
