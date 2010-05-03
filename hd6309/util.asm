; util.asm -- 6309 utility routines                            13/07/2005
; Copyright (c) 2005 BJ, Froods Software Development

; Modification:
; 13/07/2005 BJ  Initial coding

eos             equ     $00
nul             equ     $00
bel             equ     $07
bs              equ     $08
cr              equ     $0d
lf              equ     $0a
esc             equ     $1b
sp              equ     $20

; Addresses in ROM monitor
t1in            equ     $ffe8
t1ou            equ     $ffec

; Addresses on winch controller board
memcard         equ     $0000             ; Memory card
ioarea          equ     $4000             ; I/O ports in two blocks
ram             equ     $8000             ; 8k RAM appears twice
eprom           equ     $c000             ; 16k EPROM

kbport          equ     $4000
ledport         equ     $4020
lcdport         equ     $4040
convport        equ     $4060
ad1port         equ     $4080
pageport        equ     $40a0
sw1port         equ     $40c0
ad2port         equ     $40e0

rtcport         equ     $5000
prtport         equ     $5020
latport         equ     $5040
parport         equ     $5060
sw2port         equ     $5080
comport         equ     $50a0
wdport          equ     $50c0
spareport       equ     $50e0

buflen          equ     40

                org     ram
main            ldx     #msg
                jsr     prtmsg
loop            lda     #buflen
                ldx     #buf
                jsr     getlin
                jsr     hex2ou            ; Print number of chars in hex
                jsr     crlf              ; New line
                jsr     prtmsg            ; Print the buffer
                jsr     crlf              ; New line
                pshs    x                 ; Save X
l1              lda     ,x                ; Get character from buffer
                beq     l2
                jsr     tolower           ; Map to lower case
                sta     ,x+               ; Write back into buffer
                bra     l1
l2              puls    x                 ; Restore X
                jsr     prtmsg            ; Print buffer again
                jsr     crlf
                lda     ,x                ; Get first character of buffer
                jsr     isdigit           ; Test for 0-9
                bne     l3
                ldx     #notdigmsg        ; X->message
                jsr     prtmsg
                bra     loop
l3              jsr     DECCON            ; Convert decimal to binary
                jsr     hex4ou            ; Print 16-bit result
                jsr     crlf
                ldx     #buf
                jsr     bn2dec            ; Convert value in D to decimal
                ldx     #buf+1            ; Skip length byte
                jsr     prtmsg
                jsr     crlf
                bra     loop

msg             fcc     "6809 Utility Test Program"
                fcb     cr,lf,eos
notdigmsg       fcc     "Not a numeric string"
                fcb     cr,lf,eos
                
buf             rmb     buflen

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
