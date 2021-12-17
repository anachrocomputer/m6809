; demoapp --- loadable demo app for the UK109 with 6809 CPU    2021-12-07
; Copyright (c) 2021 John Honniball, Froods Software Development

                include "uk101.asm"
                
eos             equ     $00
cr              equ     $0d
lf              equ     $0a

; Addresses in UK109 $A000 ROM
crlf            equ     $a000             ; Print CR/LF
space           equ     $a00c             ; Print a space
prtmsg          equ     $a014             ; Print a nul-terminated string
vduchar         equ     $a020             ; Send one char to the VDU
vduflip         equ     $a0d1             ; Invert VDU with EXOR
vdusave         equ     $a0ed             ; Save VDU into buffer
vdurestore      equ     $a108             ; Restore VDU from buffer
getkey          equ     $a1f6             ; Get a char from the keyboard
getchar         equ     $a252             ; Get char and show cursor
rnd16           equ     $a277             ; Generate 16-bit random number
dly1ms          equ     $a26c             ; Delay for one millisecond

                setdp   0
                org     $0400
main            ldx     #hellostr         ; X->string in RAM
                jsr     prtmsg
                jsr     getkey            ; Wait for a key-press

; Draw diagonal from 31,31 to 0,0
                lda     #31               ; Init loop counter
l1              tfr     a,b               ; Copy X co-ord to B reg
                jsr     setpixel          ; Set one pixel
                deca                      ; Decrement loop counter
                bpl     l1                ; Loop back for next pixel
                jsr     getkey            ; Wait for a key-press

; Draw diagonal from 31,0 to 0,31
                lda     #31               ; Init X=31
                ldb     #0                ; Init Y=0
l2              jsr     setpixel          ; Set one pixel
                incb                      ; Increment Y
                deca                      ; Decrement X
                bpl     l2                ; Loop back for next pixel
                jsr     getkey            ; Wait for a key-press

; Fill 32x32 pixel square
                ldb     #31               ; Init loop counters
l4              lda     #31
l5              jsr     setpixel          ; Set one pixel
                deca                      ; Decrement X
                bpl     l5
                decb                      ; Decrement Y
                bpl     l4
                jsr     getkey            ; Wait for a key-press

                ldx     #hellostr         ; X->string in RAM
                jsr     prtmsg

; Fill 32x32 pixel square in random sequence
                ldx     #1023             ; Loop counter for 32x32 pixels
l6              jsr     rnd10             ; Get 10-bit random number
                pshs    b                 ; Save LSB
                lslb                      ; Shift D left 3 times:
                rola                      ;  16-bit shift
                lslb
                rola
                lslb
                rola
                puls    b                 ; Recover LSB
                andb    #31
                jsr     setpixel
                jsr     dly1ms            ; Delay 2ms per pixel
                jsr     dly1ms
                leax    -1,x              ; Decrement loop counter
                bne     l6
                ldd     #0                ; Set pixel at 0,0
                jsr     setpixel
                
                jsr     getkey            ; Wait for a key-press

                rts                       ; Exit to monitor

; RND10 --- generate a 10-bit random number using maximal-length LFSR
; Entry: no parameters
; Exit:  pseudo-random number in D (lowest 10 bits)
rnd10           lda     rng1              ; Load the MS byte
                anda    #$02              ; Mask bit 9 of 10-bit word
                tfr     a,b               ; Put into B
                lsrb                      ; Move into LSB of B
                lda     rng2              ; Load the LS byte
                anda    #$40              ; Mask bit 6 of 10-bit word
                beq     r1
                comb                      ; Bit 6 was set, so flip B
r1              lsrb                      ; Bottom bit of B into carry
                rol     rng2              ; Now do a 16-bit left shift
                rol     rng1              ;  taking the carry bit in
                lda     rng1              ; Load 10 random bits
                anda    #$03              ; Mask to ensure 10 bit range
                ldb     rng2
                rts

rng1            fcb     1                 ; Random number, MSB
rng2            fcb     234               ; Random number, LSB

hellostr        fcb     12                ; CTRL-L: clear screen
                fcb     9,9,9,9,9,9,9,9   ; 8xCTRL-I: cursor right
                fcb     9,9,9,9,9,9,9,9   ; 8xCTRL-I: cursor right
                fcb     9,9,9,9,9,9,9,9   ; 8xCTRL-I: cursor right
                fcb     9,9,9,9,9,9,9,9   ; 8xCTRL-I: cursor right
                fcc     " UK109 graphics"
                fcb     cr,lf
                fcb     9,9,9,9,9,9,9,9   ; 8xCTRL-I: cursor right
                fcb     9,9,9,9,9,9,9,9   ; 8xCTRL-I: cursor right
                fcb     9,9,9,9,9,9,9,9   ; 8xCTRL-I: cursor right
                fcb     9,9,9,9,9,9,9,9   ; 8xCTRL-I: cursor right
                fcc     "   demo 48x32"
                fcb     cr,lf,eos
                
; SETPIXEL --- set a single pixel at X,Y
; Entry: A=X, B=Y
; Exit:  Registers unchanged
setpixel        pshs    a,b,x             ; Save registers
                bsr     pixeladdr         ; Get address of pixel into X
                lda     ,x                ; Get character at pixel location
                cmpa    #161              ; Are both pixels already set?
                beq     spdone            ; If so, we're done
                andb    #$01              ; Odd or even Y co-ord?
                beq     speven
                cmpa    #154              ; Is pixel already set?
                beq     spdone            ; If so, we're done
                cmpa    #155              ; Is the other pixel already set?
                bne     sp1
                lda     #161              ; Set both pixels
                bra     spstore
sp1             lda     #154              ; Load pixel to be set
                bra     spstore
speven          cmpa    #155              ; Is pixel already set?
                beq     spdone            ; If so, we're done
                cmpa    #154              ; Is the other pixel already set?
                bne     sp2
                lda     #161              ; Set both pixels
                bra     spstore
sp2             lda     #155              ; Load pixel to be set
spstore         sta     ,x                ; Store in VDU RAM
spdone          puls    a,b,x,pc          ; Restore registers and return

; PIXELADDR --- work out address of character in VDU RAM from X,Y
; Entry: A=X, B=Y
; Exit:  X=address in VDU RAM
pixeladdr       pshs    a                 ; Save registers
                ldx     #vram+lm          ; X->VDU RAM
                leax    a,x               ; Add X co-ord
                tfr     b,a               ; Y co-ord into A
                lsra                      ; Divide by two
                lsla                      ; Multiply by two 
                lsla                      ; Multiply by two 
                lsla                      ; Multiply by two 
                leax    a,x               ; Add once...
                leax    a,x               ; Add twice...
                leax    a,x               ; Add three times...
                leax    a,x               ; Add four times...
                leax    a,x               ; Add five times...
                leax    a,x               ; Add six times...
                leax    a,x               ; Add seven times...
                leax    a,x               ; Add eight times
                puls    a,pc              ; Restore registers and return

                end     main
