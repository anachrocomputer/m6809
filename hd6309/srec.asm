; srec.asm -- 6309 S-Record loader                             03/07/2005
; Copyright (c) 2005 BJ, Froods Software Development

; Modification:
; 03/07/2005 BJ  Initial coding

eos             equ     $00
nul             equ     $00
cr              equ     $0d
lf              equ     $0a
sp              equ     $20
pad             equ     $ff               ; Padding unused EPROM space

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

                org     ram
; Load Intel-format checksum hex
lcmd            jsr     crlf
                ldu     #0                ; Initialise error count
l1              ldy     #0                ; Initialise checksum
                jsr     t1in              ; Read, looking for start of record
                jsr     t1ou              ; Echo it
                cmpa    #':'              ; Colon for Intel format
                beq     lintel
                cmpa    #'S'              ; S for Motorola S-Record
                beq     lsrec
                cmpa    #';'              ; Semicolon for MOS Technologies
                lbeq    lmostech
                bra     l1                ; Unrecognised record starter
lintel          jsr     hex2in            ; Read length
                leay    a,y               ; Add to checksum
                pshs    a                 ; Save length
                jsr     hex4in            ; Read start address
                leay    a,y               ; Add to checksum
                leay    b,y               ; Add to checksum
                tfr     d,x               ; Address into X
                puls    b                 ; Get length back into B
                jsr     hex2in            ; Read record type
                bne     li4
                leay    a,y               ; Add to checksum
l2              jsr     hex2in            ; Read data byte
                sta     ,x+               ; Store into memory
                leay    a,y               ; Add to checksum
                decb                      ; Decrement loop counter
                bne     l2                ; Go back for next byte
                jsr     hex2in            ; Read checksum from input
                leay    a,y               ; Add to computed checksum
                tfr     y,d               ; LSB should be 0
                cmpb    #0                ; B contains LSB
                beq     l3
                leau    1,u               ; Increment error counter
l3              bra     l1                ; Go back for next line
li4             jsr     hex2in            ; Dummy read checksum
                bra     ldone
lsrec           jsr     t1in              ; Read record type
                jsr     t1ou              ; Echo
                cmpa    #'1'
                beq     ls1
                cmpa    #'9'              ; Check for EOF
                beq     ls4
                bra     l1                ; Ignore unknown record types
ls1             jsr     hex2in            ; Read length
                leay    a,y               ; Add to checksum
                suba    #3                ; Allow for 3 byte header
                pshs    a                 ; Save length
                jsr     hex4in            ; Read start address
                leay    a,y               ; Add to checksum
                leay    b,y               ; Add to checksum
                tfr     d,x               ; Address into X
                puls    b                 ; Get length back into B
ls2             jsr     hex2in            ; Read data byte
                sta     ,x+               ; Store into memory
                leay    a,y               ; Add to checksum
                decb                      ; Decrement loop counter
                bne     ls2               ; Go back for next byte
                tfr     y,d               ; LSB into B
                comb                      ; Form one's complement of LSB
                stb     cksum             ; Save in memory
                jsr     hex2in            ; Read checksum from input
                cmpa    cksum             ; Compare computed and read-in
                beq     ls3
                leau    1,u               ; Increment error counter
ls3             lbra    l1                ; Go back for next line
ls4             jsr     hex2in            ; Dummy read length
                jsr     hex4in            ; Dummy read address
                jsr     hex2in            ; Dummy read checksum
                bra     ldone
lmostech        nop
                bra     ldone
ldone           tfr     u,d               ; Get error count into D
                jsr     crlf
                jsr     hex4ou
                ldx     #chkmsg
                jsr     prtmsg
                rts

cksum           fcb     0

; Save as hex checksum
scmd            rts
;scmd            jsr     hex4in            ; Save
;                tfr     d,x
;                lda     #','
;                jsr     t1ou
;                jsr     hex4in
;                tfr     d,y
;                jsr     crlf
;                ; Send S9 record
;                rts

; sblk --- write a single block of S-Record data
; X: start address, Y: length
;sblk            lda     #'S'
;                jsr     t1ou
;                lda     #'1'
;                jsr     t1ou
;                tfr     b,a               ; Get length
;                adda    #3                ; Add three for address & checksum bytes
;                jsr     hex2ou            ; Send length
;                tfr     x,d
;                jsr     hex4ou            ; Block start address
;sloop           lda     ,x
;                jsr     hex2ou            ; Payload bytes
;                leay    -1,y
;                bne     sloop
;                tfr     b,a               ; Get checksum
;                jsr     hex2ou            ; Checksum
;                jsr     crlf
;                rts

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
chkmsg          fcc     " checksum errors"
                fcb     eos
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
