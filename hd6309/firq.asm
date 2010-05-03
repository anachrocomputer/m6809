; firq.asm -- 6309 FIRQ handler for serial port                08/07/2005
; Copyright (c) 2005 BJ, Froods Software Development

; Modification:
; 08/07/2005 BJ  Initial coding

eos             equ     $00
nul             equ     $00
cr              equ     $0d
lf              equ     $0a
esc             equ     $1b
sp              equ     $20
pad             equ     $ff               ; Padding unused EPROM space

rxbufsiz        equ     8
txbufsiz        equ     16
rxbufmask       equ     rxbufsiz-1
txbufmask       equ     txbufsiz-1

; Addresses in ROM monitor
firqvec         equ     $9fea             ; FIRQ vector in RAM
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

main            ldx     #firqhdlr         ; Get address of FIRQ handler
                stx     firqvec           ; Point vector at handler routine
                
                clra                      ; Set up buffer pointers
                sta     rxhead
                sta     rxtail
                sta     txhead
                sta     txtail
                                          ; Initialise UART

                lda     #$02              ; Enable RxRDYA interrupt
                sta     uartimr           ; Set bit in Interrupt Mask Reg
                                          
                andcc   #$bf              ; Enable FIRQ

                ldx     #msg              ; Test with a longer message to
                jsr     prtmsg            ; ensure "buffer full" correct
                
loop            jsr     firqin
                jsr     hex2ou
                cmpa    #esc
                bne     loop
                
                clra                      ; Disable all UART interrupts
                sta     uartimr

                rts

; FIRQIN
; Get a character from the UART, via the circular buffer
; Entry: No parameters
; Exit: A=ASCII char received
firqin          pshs    x                 ; Save X
in1             lda     rxtail            ; Get tail pointer
                cmpa    rxhead            ; Compare with head pointer
                beq     in1               ; If head=tail, buffer is empty
                inca                      ; Add one to tail pointer
                anda    #rxbufmask        ; Wrap around within buffer size
                sta     rxtail            ; Store tail pointer
                ldx     #rxbuf            ; Pointer to Rx buffer
                lda     a,x               ; Get character from buffer
                puls    x,pc              ; Restore X and return
                
; FIRQOUT
; Send a character to the UART, via the circular buffer
; Entry: A=ASCII char to send
; Exit: registers unchanged
firqout         pshs    b,x               ; Save B and X
                ldb     txhead            ; Get head pointer
                incb                      ; Add one to head pointer
                andb    #txbufmask        ; Wrap around within buffer size
ou1             cmpb    txtail            ; Compare with tail pointer
                beq     ou1               ; If head+1=tail, buffer is full
                ldx     #txbuf            ; Pointer to Tx buffer
                sta     b,x               ; Store character in buffer
                stb     txhead            ; Store incremented head pointer
                ldb     #$03              ; Enable TxRDYA and RxRDYA interrupts
                stb     uartimr
                puls    b,x,pc            ; Restore B, X and return
                
; FIRQHDLR
; Handler for FIRQ interrupt, called by UART
firqhdlr        pshs    a,b,x             ; Only PC and CC have been saved
                ldb     uartisr           ; Read UART's Interrupt Status Reg
                bitb    #$01              ; Check TxRDYA bit
                beq     f1
                lda     txtail            ; Get head pointer
                cmpa    txhead            ; Compare with head pointer
                beq     distxint          ; If head=tail, disable interrupt
                inca                      ; Increment tail pointer
                anda    #txbufmask        ; Wrap around within buffer
                sta     txtail            ; Store tail pointer
                ldx     #txbuf            ; Get buffer base address
                ldb     a,x               ; Get byte to be sent
                stb     uartthra          ; Send byte
                bra     txdone
distxint        lda     #$02              ; TxRDYA bit cleared
                sta     uartimr           ; Switch off Tx interrupt
txdone          ldb     uartisr           ; Reload B from ISR
f1              bitb    #$02              ; Check RxRDYA bit
                beq     f2
                lda     rxhead            ; Get head pointer
                inca                      ; Add one to head pointer
                anda    #rxbufmask        ; Wrap around within buffer size
                sta     rxhead            ; Store head pointer
                ldb     uartrhra          ; Get received byte
                ldx     #rxbuf
                stb     a,x               ; Store new byte in buffer
                ldb     uartisr           ; Reload B from ISR
f2              puls    a,b,x             ; Restore registers
                rti
                
rxbuf           rmb     rxbufsiz
rxhead          rmb     1
rxtail          rmb     1
txbuf           rmb     txbufsiz
txhead          rmb     1
txtail          rmb     1
                
msg             fcc     "Hello, world from the interrupt-driven UART"
                fcb     cr,lf,eos
                
; PRTMSG
; Print message pointed to by X, terminated by zero byte
prtmsg          pshs    a,x               ; Save A and X registers
prtmsg1         lda     ,x+
                beq     prtmsg2
                jsr     firqout
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
                jsr     firqout
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
                jsr     firqout
                lda     #lf
                jsr     firqout
                puls    a,pc
                
hexdig          fcc     '0123456789ABCDEF'
chkmsg          fcc     " checksum errors"
                fcb     eos
; Hex input routines

; HEX1IN --- read a single hex digit from the keyboard
; Entry: no parameters
; Exit:  4-bit value in A
hex1in          jsr     t1in              ; Read one ASCII character
                jsr     firqout              ; Echo it
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
                jsr     firqout
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
                jsr     firqout
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
