; mon63.asm -- 6309 monitor ROM for 6309 winch controller board
; Copyright (c) 2005 BJ, Froods Software Development

; Modification:
; 26/06/2005 BJ  Initial coding
; 28/06/2005 BJ  Added Intel format checksum loader

eos             equ     $00
nul             equ     $00
cr              equ     $0d
lf              equ     $0a
sp              equ     $20
pad             equ     $ff               ; Padding unused EPROM space
romcksum        equ     $2900
cksumpad        equ     $9f

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

; Registers in Philips SCC2692 UART chip
uartmr1a        equ     comport+0         ; Mode Register A (read/write)
uartsra         equ     comport+1         ; Status Register A (read)
uartcsra        equ     comport+1         ; Clock Select Register A (write)
uartcra         equ     comport+2         ; Command Register A (write)
uartrhra        equ     comport+3         ; Receive Holding Register A (read)
uartthra        equ     comport+3         ; Transmit Holding Register A (write)
uartipcr        equ     comport+4         ; Input Port Change Register (read)
uartacr         equ     comport+4         ; Aux Control Register (write)
uartisr         equ     comport+5         ; Interrupt Status Register (read)
uartimr         equ     comport+5         ; Interrupt Mask Register (write)
uartctu         equ     comport+6         ; Counter/Timer Upper Value (read)
uartctur        equ     comport+6         ; Counter/Timer Upper Preset (write)
uartctl         equ     comport+7         ; Counter/Timer Lower Value (read)
uartctlr        equ     comport+7         ; Counter/Timer Lower Preset (write)
uartmr1b        equ     comport+8         ; Mode Register B (read/write)
uartsrb         equ     comport+9         ; Status Register B (read)
uartcsrb        equ     comport+9         ; Clock Select Register B (write)
uartcrb         equ     comport+10        ; Command Register B (write)
uartrhrb        equ     comport+11        ; Receive Holding Register B (read)
uartthrb        equ     comport+11        ; Transmit Holding Register B (write)
uartreserved    equ     comport+12        ; Reserved
uartip          equ     comport+13        ; Input Ports (read)
uartopcr        equ     comport+13        ; Output Port Conf Register (write)
uartstcc        equ     comport+14        ; Start Counter Command (read)
uartsopb        equ     comport+14        ; Set Output Port Bits Command (write)
uartspcc        equ     comport+15        ; Stop Counter Command (read)
uartropb        equ     comport+15        ; Reset Output Port Bits Command (write)

                org     ram
freeram         rmb     1

                org     $9fc0
initstack       rmb     2
                rmb     10
govec           rmb     2                 ; Address for 'Go' command
rega            rmb     1                 ; Saved register contents
regb            rmb     1
rege            rmb     1
regf            rmb     1
regcc           rmb     1
regdp           rmb     1
regmd           rmb     1
                rmb     1
regv            rmb     2
regx            rmb     2
regy            rmb     2
regu            rmb     2
regs            rmb     2
illvec          rmb     2                 ; Illegal instruction trap vector
swi3vec         rmb     2                 ; Interrupt vectors
swi2vec         rmb     2
swivec          rmb     2
irqvec          rmb     2
firqvec         rmb     2
nmivec          rmb     2
t1ouvec         rmb     2                 ; I/O call vectors
t1invec         rmb     2
spare1vec       rmb     2
spare2vec       rmb     2
spare3vec       rmb     2
spare4vec       rmb     2
spare5vec       rmb     2
spare6vec       rmb     2
cksum           rmb     1
ramtop          rmb     1                 ; Last byte in RAM

                org     eprom
reset           orcc    #%01010000        ; Disable interrupts
                lds     #initstack        ; Set up initial stack pointer
                fcb     $11,$3d,$01       ; ldmd #$01 Into 6309 mode
;                lda     #3                ; SIM Into CBREAK mode
;                swi                       ; SIM
                clra
                clrb
                tfr     d,x
                tfr     d,y
                tfr     d,u
                tfr     a,dp              ; Set up Direct Page register

; Reset the SCC2692 UART and select 19200 baud, 8 bit, no parity
; without calling a subroutine and hence using the stack
                lda     #$00              ; All interrupts off
                sta     uartimr           ; Write to IMR
                lda     #$80
                sta     uartacr           ; Write to ACR
                lda     #$13
                sta     uartmr1a          ; Write to MR1A
                lda     #$07
                sta     uartmr1a          ; Write to MR2A
                lda     #$cc              ; Select 19200 baud (Tx and Rx)
                sta     uartcsra          ; Write to CSRA
                lda     #$05              ; Enable Tx and Rx
                sta     uartcra           ; Write to CRA
                
                ldx     #rstmsg           ; Print sign-on banner
                jsr     prtmsg
                
; ROM checksum
                ldy     #eprom            ; Y->start of monitor ROM
                ldd     #0                ; Start with D=0
romloop         addb    ,y+               ; Add one ROM byte into the checksum
                adca    #0
                cmpy    #0                ; See if we've reached the top of ROM yet
                bne     romloop           ; Exit when Y wraps around
                cmpd    #romcksum         ; Correct sum should be 0
                bne     romerr
                ldx     #romokmsg         ; ROM OK
                jsr     prtmsg
                bra     romdone
romerr          ldx     #romerrmsg        ; ROM checksum error
                jsr     prtmsg
                tfr     d,u               ; Save actual checksum in U
                ldd     #romcksum
                ldx     #expmsg           ; "expected"
                jsr     prtmsg
                jsr     hex4ou            ; Print expected checksum from A
                ldx     #readmsg          ; "read"
                jsr     prtmsg
                tfr     u,d               ; Value read back is in U
                jsr     hex4ou

romdone         jsr     crlf

; RAMTEST --- do the write-write-read-read memory test
                ldy     #freeram          ; Start address of test in Y
rtloop          lda     #0                ; Test with $00
                ldb     #$ff
                stb     ,y                ; Store inverted bit-pattern
                sta     ,y                ; Store true bit-pattern
                lda     ,y                ; Read it back into A
                ldb     ,y                ; Read again, into B
                cmpa    #0                ; Compare with original
                bne     rtfail1
                cmpb    #0                ; Compare with original again
                bne     rtfail2

                lda     #$aa              ; Test with $AA
                ldb     #$55
                stb     ,y                ; Store inverted bit-pattern
                sta     ,y                ; Store true bit-pattern
                lda     ,y                ; Read it back into A
                ldb     ,y                ; Read again, into B
                cmpa    #$aa              ; Compare with original
                bne     rtfail3
                cmpb    #$aa              ; Compare with original again
                bne     rtfail4

                lda     #$55              ; Test with $55
                ldb     #$aa
                stb     ,y                ; Store inverted bit-pattern
                sta     ,y                ; Store true bit-pattern
                lda     ,y                ; Read it back into A
                ldb     ,y                ; Read again, into B
                cmpa    #$55              ; Compare with original
                bne     rtfail5
                cmpb    #$55              ; Compare with original again
                bne     rtfail6

                lda     #$ff              ; Test with $FF
                ldb     #$00
                stb     ,y                ; Store inverted bit-pattern
                sta     ,y                ; Store true bit-pattern
                lda     ,y                ; Read it back into A
                ldb     ,y                ; Read again, into B
                cmpa    #$ff              ; Compare with original
                bne     rtfail7
                cmpb    #$ff              ; Compare with original again
                bne     rtfail8

                leay    1,y               ; Add one to Y
                cmpy    #ramtop           ; Check for top of RAM
                blt     rtloop
                ldx     #memokmsg         ; RAM test passed
                jsr     prtmsg
                bra     rtdone            ; Jump over failure logic
; Eight separate failure cases...
rtfail1         tfr     a,b               ; Failed byte was in A
                lda     #0                ; We were expecting to read 0
                bra     rtf1
rtfail3         tfr     a,b               ; Failed byte was in A
                lda     #$aa              ; We were expecting to read $AA
                bra     rtf1
rtfail5         tfr     a,b               ; Failed byte was in A
                lda     #$55              ; We were expecting to read $55
                bra     rtf1
rtfail7         tfr     a,b               ; Failed byte was in A
                lda     #$ff              ; We were expecting to read $FF
rtf1            ldx     #memfail1         ; X->first read failure message
                bra     rtf
rtfail2         lda     #0                ; We were expecting to read 0
                bra     rtf2
rtfail4         lda     #$aa              ; We were expecting to read $AA
                bra     rtf2
rtfail6         lda     #$55              ; We were expecting to read $55
                bra     rtf2
rtfail8         lda     #$ff              ; We were expecting to read $FF
rtf2            ldx     #memfail2         ; X->second read failure message
;rtf             ldu     #rtrtn            ; Set up return address
;                jmp     putlin_ns         ; Call special 'putlin' with no stack use
;rtrtn           lds     #$7fff            ; Fix the stack (TEMP)
rtf             jsr     prtmsg
                pshs    d                 ; Save A and B
                tfr     y,d               ; Print address of failure
                jsr     hex4ou
                puls    d
                ldx     #expmsg           ; "expected"
                jsr     prtmsg
                jsr     hex2ou            ; Print value stored in RAM from A
                ldx     #readmsg          ; "read"
                jsr     prtmsg
                tfr     b,a               ; Value read back is in B
                jsr     hex2ou

rtdone          jsr     crlf

;; TODO: Memory addressing test
;
;                lda     #15
;                sta     $4000
;                deca
;                sta     $2000
;                deca
;                sta     $1000
;                deca
;                sta     $0800
;                deca
;                sta     $0400
;                deca
;                sta     $0200
;                deca
;                sta     $0100
;                deca
;                sta     $0080
;                deca
;                sta     $0040
;                deca
;                sta     $0020
;                deca
;                sta     $0010
;                deca
;                sta     $0008
;                deca
;                sta     $0004
;                deca
;                sta     $0002
;                deca
;                sta     $0001
;                deca
;                sta     $0000
;
;                lda     #15
;                cmpa    $4000
;                bne     aderr
;                deca
;                cmpa    $2000
;                bne     aderr
;                deca
;                cmpa    $1000
;                bne     aderr
;                deca
;                cmpa    $0800
;                bne     aderr
;                deca
;                cmpa    $0400
;                bne     aderr
;                deca
;                cmpa    $0200
;                bne     aderr
;                deca
;                cmpa    $0100
;                bne     aderr
;                deca
;                cmpa    $0081             ; err
;                bne     aderr
;                deca
;                cmpa    $0040
;                bne     aderr
;                deca
;                cmpa    $0020
;                bne     aderr
;                deca
;                cmpa    $0010
;                bne     aderr
;                deca
;                cmpa    $0008
;                bne     aderr
;                deca
;                cmpa    $0004
;                bne     aderr
;                deca
;                cmpa    $0002
;                bne     aderr
;                deca
;                cmpa    $0001
;                bne     aderr
;                deca
;                cmpa    $0000
;                bne     aderr
;
;                ldx     #adrokmsg
;                jsr     putlin
;                bra     addone
;aderr           ldx     #adrerrmsg
;                jsr     putlin
;
addone          ldx     #intrtn           ; Initialise interrupt vector table
                stx     illvec
                stx     swi3vec
                stx     swi2vec
                stx     swivec
                stx     irqvec
                stx     firqvec
                stx     nmivec
                ldx     #t1ou
                stx     t1ouvec
                ldx     #t1in
                stx     t1invec
                ldx     #jsrrtn
                stx     spare1vec
                stx     spare2vec
                stx     spare3vec
                stx     spare4vec
                stx     spare5vec
                stx     spare6vec

; TODO: More hardware initialisation, hardware self-tests
                
                jmp     monitor
                
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
                
; T1OU
; Entry: A=ASCII char to send to serial port
; Exit:  registers unchanged
;t1ou            pshs    a,b               ; SIM Save A & B
;                tfr     a,b               ; SIM
;                lda     #5                ; SIM
;                swi                       ; SIM
;                puls    a,b,pc            ; SIM
t1ou            pshs    a                 ; Save char in A
t1ou1           lda     uartsra           ; Read UART status (Channel A)
                anda    #$04              ; Transmit ready? (TxRDY)
                beq     t1ou1
                puls    a                 ; Restore A
                sta     uartthra          ; Send char to THRA
                rts
                
; T1IN
; Entry:
; Exit:  A=ASCII char from UART
t1in            lda     uartsra           ; Read UART status (Channel A)
                anda    #$01              ; Check RxRDY bit
                beq     t1in
                lda     uartrhra          ; Get ASCII byte from RHRA
                rts

; DLY100U
; Delay for 100us
dly100u         pshs    a                 ; 6
                lda     #35               ; 2
dlyloop         deca                      ; 2 * 35
                bne     dlyloop           ; 3 * 35
                puls    a,pc              ; 8
                
; DLY1MS
; Delay for one millisecond
dly1ms          bsr     dly100u
                bsr     dly100u
                bsr     dly100u
                bsr     dly100u
                bsr     dly100u
                bsr     dly100u
                bsr     dly100u
                bsr     dly100u
                bsr     dly100u
                bsr     dly100u
                rts

rstmsg          fcb     cr,lf
                fcc     'HD6309 Monitor'
                fcb     cr,lf,eos
romokmsg        fcc     'ROM checksum OK'
                fcb     eos
romerrmsg       fcc     'ROM checksum error,'
                fcb     eos
memokmsg        fcc     'Memory OK'
                fcb     eos
memfail1        fcc     "RAM test fail1 at $"
                fcb     eos
memfail2        fcc     "RAM test fail2 at $"
                fcb     eos
expmsg          fcc     " expected $"
                fcb     eos
readmsg         fcc     ", read $"
                fcb     eos
adrokmsg        fcc     'Memory Addressing OK'
                fcb     cr,lf,eos
adrerrmsg       fcc     'Memory Addressing FAIL'
                fcb     cr,lf,eos
hexdig          fcc     '0123456789ABCDEF'
helpmsg         fcb     cr,lf
                fcc     'Monitor commands:'
                fcb     cr,lf
                fcc     '@ - open location for editing'
                fcb     cr,lf
                fcc     'l - load checksum hex format'
                fcb     eos
chkmsg          fcc     " checksum errors"
                fcb     eos
                
decbuf          fcc     '42'
                fcb     eos

cmdtab          fdb     atcmd, acmd, bcmd
                fdb     ccmd, dcmd, ecmd
                fdb     fcmd, gcmd, hcmd 
                fdb     icmd, jcmd, kcmd
                fdb     lcmd, mcmd, ncmd
                fdb     ocmd, pcmd, qcmd
                fdb     rcmd, scmd, tcmd
                fdb     ucmd, vcmd, wcmd
                fdb     xcmd, ycmd, zcmd

; Monitor command interpreter
cmderr          lda     #'?'
                jsr     t1ou
                jsr     crlf
monitor         lda     #'>'              ; Monitor command-level prompt
                jsr     t1ou
                jsr     t1in
                jsr     t1ou
;                cmpa    #42               ; SIM
;                beq     exit              ; SIM
                jsr     toupper
                cmpa    #'@'
                blo     cmderr
                cmpa    #'Z'
                bls     cmdok
                bra     cmderr
cmdok           suba    #'@'
                asla
                ldx     #cmdtab
                jsr     [a,x]
                jsr     crlf
                bra     monitor
;
;exit            lda     #4                ; SIM Out of CBREAK mode
;                swi                       ; SIM
;                lda     #0                ; SIM Terminate
;                swi                       ; SIM
;here            jmp     here

; Monitor command routines
; @ - open memory for editing
; A - edit Accumulator
; B - breakpoint
; C - continue from last breakpoint
; D - dump memory in hex
; E - eliminate breakpoint
; F - fill memory
; G - go
; H - hex calculator
; I - print address and registers from last breakpoint
; J - print string (my own extension)
; K - edit stack pointer
; L - load (checksum)
; M - move memory
; N - search for hex string
; O - print overflow from hex calculator
; P - edit status register
; Q - disassemble
; R - relocate
; S - save (checksum)
; T - breakpoint table
; U - spare
; V - view cassette
; W - search for ASCII string
; X - edit X reg
; Y - edit Y reg
; Z - spare
atcmd           jsr     hex4in
                tfr     d,x
atcmd5          lda     #'='
                jsr     t1ou
atcmd1          lda     ,x                ; Fetch byte from specified address
                jsr     hex2ou            ; Print it in hex
                jsr     space
                jsr     t1in              ; Get a command
                jsr     t1ou
                cmpa    #sp               ; SPACE->exit
                beq     atcmdx
                cmpa    #'/'              ; SLASH->re-read byte
                beq     atcmd1
                cmpa    #cr               ; CR->next address
                bne     atcmd2
                leax    1,x
                bra     atcmd3
atcmd2          cmpa    #'^'              ; ^->previous address
                bne     atcmd4
                leax    -1,x
atcmd3          jsr     crlf
                tfr     x,d
                jsr     hex4ou            ; Print address
                bra     atcmd5
atcmd4          cmpa    #'+'              ; +->increment byte
                bne     atcmd6
                inc     ,x
                bra     atcmd1
atcmd6          cmpa    #'-'              ; +->decrement byte
                bne     atcmd7                   
                dec     ,x    
                bra     atcmd1
atcmd7          cmpa    #'"'              ; "->display as ASCII
                bne     atcmd8
                lda     ,x
                jsr     t1ou
                jsr     space
                bra     atcmd1
atcmd8          nop                       ; Test for hex here
atcmdx          rts
                
acmd            lda     #$5A
                jsr     hex2ou
                rts
bcmd            lda     #$A5
                jsr     hex2ou
                rts
ccmd            ldd     #$BABE
                jsr     hex4ou
                rts
dcmd            jsr     hex4in
                tfr     d,x
                jsr     crlf
                clra
                ldb     #16
dcmd2           jsr     hex1ou
                jsr     space
                jsr     space
                inca
                decb
                bne     dcmd2
                jsr     crlf
                tfr     x,d
                jsr     hex4ou
                rts
ecmd            ldd     #$DEAD
                jsr     hex4ou
                rts
fcmd            jsr     hex2in
                jsr     crlf
                jsr     hex2ou
                rts
; Go
gcmd            jsr     hex4in            ; Get address
                jsr     crlf
                std     govec             ; Save address in RAM
                lda     rega              ; Load up all registers from RAM
                ldb     regb
                fcb     $11,$b6           ; lde rege
                fdb     rege
                fcb     $11,$f6           ; ldf regf
                fdb     regf
                ldx     regv
                fcb     $1f,$17           ; tfr x,v Can't load V directly
                ldx     regx
                ldy     regy
                ldu     regu
;               lds     regs              ; Can't load S
                jsr     [govec]           ; Call user program as subroutine
                sta     rega              ; Save 'em all again
                stb     regb
                tfr     cc,a              ; Can't store CC directly
                sta     regcc
                tfr     dp,a              ; Can't store DP directly
                sta     regdp
;               tfr     md,a              ; Can't store MD directly
;               sta     regmd
                fcb     $11,$b7           ; ste rege
                fdb     rege
                fcb     $11,$f7           ; stf regf
                fdb     regf
                stx     regx
                fcb     $1f,$71           ; tfr v,x Can't store V directly
                stx     regv
                sty     regy
                stu     regu
                sts     regs
                rts
; Help
hcmd            ldx     #helpmsg
                jsr     prtmsg
                rts
icmd            jsr     hex4in
                tfr     d,x
                lda     #','
                jsr     t1ou
                jsr     hex4in
                tfr     d,y
                jsr     crlf
                tfr     x,d
                jsr     hex4ou
                jsr     space
iloop           lda     ,x
                jsr     hex2ou
                jsr     space
                rts
jcmd            ldx     #decbuf
                jsr     prtmsg
                lda     #'='
                jsr     t1ou
                ldx     #decbuf
                jsr     DECCON
                jsr     hex4ou
                rts
kcmd            rts
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

mcmd            rts
ncmd            rts
ocmd            rts
pcmd            rts
qcmd            rts
; Register dump
rcmd            jsr     crlf
                lda     rega
                ldb     #'A'
                bsr     regprt2
                lda     regb
                ldb     #'B'
                bsr     regprt2
                lda     rege
                ldb     #'E'
                bsr     regprt2
                lda     regf
                ldb     #'F'
                bsr     regprt2
                lda     #'C'
                jsr     t1ou
                lda     regcc
                ldb     #'C'
                bsr     regprt2
                lda     #'D'
                jsr     t1ou
                lda     regdp
                ldb     #'P'
                bsr     regprt2
                lda     #'M'
                jsr     t1ou
                lda     regmd
                ldb     #'D'
                bsr     regprt2
                jsr     crlf
                ldx     regx
                lda     #'X'
                bsr     regprt4
                ldx     regy
                lda     #'Y'
                bsr     regprt4
                ldx     regu
                lda     #'U'
                bsr     regprt4
                ldx     regs
                lda     #'S'
                bsr     regprt4
                ldx     regv
                lda     #'V'
                bsr     regprt4
                rts
                
regprt2         exg     a,b
                jsr     t1ou
                lda     #':'
                jsr     t1ou
                exg     a,b
                jsr     hex2ou
                jsr     space
                rts
regprt4         jsr     t1ou
                lda     #':'
                jsr     t1ou
                tfr     x,d 
                jsr     hex4ou
                jsr     space
                rts
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
; Test switch port
tcmd            rts
t1              lda     sw1port           ; Read Switch Port 1
                sta     ledport           ; Write to LEDs
                bra     t1
; Print U register
ucmd            ldd     regu
                jsr     hex4ou
                rts
; Print V register
vcmd            ldd     regv
                jsr     hex4ou
                rts
; Print W register
wcmd            ldd     rege
                jsr     hex4ou
                rts
; Print X register
xcmd            ldd     regx
                jsr     hex4ou
                rts
; Print Y register
ycmd            ldd     regy
                jsr     hex4ou
                rts
                
; Test LED and 'page' ports
zcmd            lda     #$20
                clrb
                fcb     $11,$4f           ; clre
loop            stb     ledport
                fcb     $11,$b7           ; ste pageport
                fdb     pageport
                incb
                fcb     $11,$4a           ; dece
                jsr     dly1ms
                jsr     dly1ms
                jsr     dly1ms
                jsr     dly1ms
                cmpb    #0
                bne     loop
                jsr     t1ou              ; Send to UART
                inca
                cmpa    #$7f
                bne     loop
                lda     #$20
                bra     loop
                
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
                
;; PUTLIN_NS
;; Entry: X->string, U contains return address
;; Exit:  X modified, other registers unchanged
;putlin_ns       tfr     d,s               ; Save A and B in stack pointer
;putlin_ns2      lda     ,x+               ; Fetch char
;                beq     putlin_ns1        ; Test for '\0'
;                tfr     a,b               ; SIM
;                lda     #5                ; SIM
;                swi                       ; SIM
;                bra     putlin_ns2
;putlin_ns1      tfr     s,d               ; Get saved A and B back from stack pointer
;                jmp     ,u                ; Special return via U
                
;===============================================================
;; ACIARST
;; Reset a 6850 ACIA and select divide-by-16 mode
;aciarst         pshs    a
;                lda     #$03
;                sta     acias
;                lda     #$11              ; Divide-by-16 mode
;                sta     acias
;                puls    a,pc

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

; TOUPPER --- map an ASCII character to upper case
; Entry: ASCII character in A
; Exit uppercase ASCII character in A, other registers unchanged
toupper         cmpa    #'a'
                blo     uprrtn
                cmpa    #'z'
                bhi     uprrtn
                suba    #'a'-'A'
uprrtn          rts

illjmp          jmp     [illvec]          ; Table of indirect jumps to ISRs
swi3jmp         jmp     [swi3vec]
swi2jmp         jmp     [swi2vec]
swijmp          jmp     [swivec]
irqjmp          jmp     [irqvec]
firqjmp         jmp     [firqvec]
nmijmp          jmp     [nmivec]
intrtn          rti
jsrrtn          rts

                fcb     cksumpad          ; Balance ROM checksum

                org     $ffd0
spare6jmp       jmp     [spare6vec]       ; A few placeholders for
spare5jmp       jmp     [spare5vec]       ; future use.  Note that jump
spare4jmp       jmp     [spare4vec]       ; indirect on the 6809 is
spare3jmp       jmp     [spare3vec]       ; four bytes long
spare2jmp       jmp     [spare2vec]
spare1jmp       jmp     [spare1vec]
t1injmp         jmp     [t1invec]         ; t1in
t1oujmp         jmp     [t1ouvec]         ; t1ou
; ROM vectors
ill             fdb     illjmp            ; Reserved by Motorola
swi3            fdb     swi3jmp
swi2            fdb     swi2jmp
firq            fdb     firqjmp
irq             fdb     irqjmp
swi             fdb     swijmp
nmi             fdb     nmijmp
                fdb     reset
