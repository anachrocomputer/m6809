; demoapp --- loadable demo app for the UK109 with 6809 CPU    2021-12-07
; Copyright (c) 2021 John Honniball, Froods Software Development

                include "uk101.asm"
                
eos             equ     $00
cr              equ     $0d
lf              equ     $0a

; UK101 character-cell graphics used as pixels
pixnone         equ     32                ; Space: no pixels set
pixeven         equ     155               ; Pixel set at even Y co-ord
pixodd          equ     154               ; Pixel set at odd Y co-ord
pixboth         equ     161               ; Both pixels set

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

; Fill 32x32 pixel square from bottom
                ldb     #31               ; Init loop counters
l4              lda     #31
l5              jsr     setpixel          ; Set one pixel
                deca                      ; Decrement X
                bpl     l5
                jsr     dly1ms            ; Slow down a little
                jsr     dly1ms
                jsr     dly1ms
                jsr     dly1ms
                decb                      ; Decrement Y
                bpl     l4
                jsr     getkey            ; Wait for a key-press

; Clear diagonal from 31,31 to 0,0
                lda     #31               ; Init loop counter
l6              tfr     a,b               ; Copy X co-ord to B reg
                jsr     clrpixel          ; Clear one pixel
                deca                      ; Decrement loop counter
                bpl     l6                ; Loop back for next pixel
                jsr     getkey            ; Wait for a key-press

; Clear diagonal from 31,0 to 0,31
                lda     #31               ; Init X=31
                ldb     #0                ; Init Y=0
l7              jsr     clrpixel          ; Clear one pixel
                incb                      ; Increment Y
                deca                      ; Decrement X
                bpl     l7                ; Loop back for next pixel
                jsr     getkey            ; Wait for a key-press

; Clear 32x32 pixel square from bottom
                ldb     #31               ; Init loop counters
l8              lda     #31
l9              jsr     clrpixel          ; Clear one pixel
                deca                      ; Decrement X
                bpl     l9
                jsr     dly1ms            ; Slow down a little
                jsr     dly1ms
                jsr     dly1ms
                jsr     dly1ms
                decb                      ; Decrement Y
                bpl     l8
                jsr     getkey            ; Wait for a key-press

; Fill 32x32 pixel square in random sequence
                ldx     #hellostr         ; X->string in RAM
                jsr     prtmsg

                ldx     #1023             ; Loop counter for 32x32 pixels
l10             jsr     rnd10             ; Get 10-bit random number
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
                bne     l10
                ldd     #0                ; Set pixel at 0,0
                jsr     setpixel
                
                jsr     getkey            ; Wait for a key-press

; Clear 32x32 pixel square in random sequence
                ldx     #1023             ; Loop counter for 32x32 pixels
l11             jsr     rnd10             ; Get 10-bit random number
                pshs    b                 ; Save LSB
                lslb                      ; Shift D left 3 times:
                rola                      ;  16-bit shift
                lslb
                rola
                lslb
                rola
                puls    b                 ; Recover LSB
                andb    #31
                jsr     clrpixel
                jsr     dly1ms            ; Delay 2ms per pixel
                jsr     dly1ms
                leax    -1,x              ; Decrement loop counter
                bne     l11
                ldd     #0                ; Set pixel at 0,0
                jsr     clrpixel

                jsr     getkey            ; Wait for a key-press

                rts                       ; Exit to monitor

; RND10 --- generate a 10-bit random number using maximal-length LFSR
; Entry: no parameters
; Exit:  pseudo-random number in D (lowest 10 bits)
rnd10           lda     rngmsb            ; Load the MS byte
                anda    #$02              ; Mask bit 9 of 10-bit word
                tfr     a,b               ; Put into B
                lsrb                      ; Move into LSB of B
                lda     rnglsb            ; Load the LS byte
                anda    #$40              ; Mask bit 6 of 10-bit word
                beq     r1
                comb                      ; Bit 6 was set, so flip B
r1              lsrb                      ; Bottom bit of B into carry
                rol     rnglsb            ; Now do a 16-bit left shift
                rol     rngmsb            ;  taking the carry bit in
                lda     rngmsb            ; Load 10 random bits
                anda    #$03              ; Mask to ensure 10 bit range
                ldb     rnglsb
                rts

rngmsb          fcb     1                 ; Random number, MSB
rnglsb          fcb     234               ; Random number, LSB

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
                cmpa    #pixboth          ; Are both pixels already set?
                beq     spdone            ; If so, we're done
                andb    #$01              ; Odd or even Y co-ord?
                beq     speven
                cmpa    #pixodd           ; Is pixel already set?
                beq     spdone            ; If so, we're done
                cmpa    #pixeven          ; Is the other pixel already set?
                bne     sp1
                lda     #pixboth          ; Set both pixels
                bra     spstore
sp1             lda     #pixodd           ; Load pixel to be set
                bra     spstore
speven          cmpa    #pixeven          ; Is pixel already set?
                beq     spdone            ; If so, we're done
                cmpa    #pixodd           ; Is the other pixel already set?
                bne     sp2
                lda     #pixboth          ; Set both pixels
                bra     spstore
sp2             lda     #pixeven          ; Load pixel to be set
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
                
; CLRPIXEL --- clear a single pixel at X,Y
; Entry: A=X, B=Y
; Exit:  Registers unchanged
clrpixel        pshs    a,b,x             ; Save registers
                bsr     pixeladdr         ; Get address of pixel into X
                lda     ,x                ; Get character at pixel location
                cmpa    #pixnone          ; Are both pixels already clear?
                beq     cpdone            ; If so, we're done
                andb    #$01              ; Odd or even Y co-ord?
                beq     cpeven
                cmpa    #pixeven          ; Is pixel already clear?
                beq     cpdone            ; If so, we're done
                cmpa    #pixboth          ; Is the other pixel already set?
                beq     cp1
                lda     #pixnone          ; Clear both pixels
                bra     cpstore
cp1             lda     #pixeven          ; Load pixel to be cleared
                bra     cpstore
cpeven          cmpa    #pixodd           ; Is pixel already clear?
                beq     cpdone            ; If so, we're done
                cmpa    #pixboth          ; Is the other pixel already set?
                beq     cp2
                lda     #pixnone          ; Clear both pixels
                bra     cpstore
cp2             lda     #pixodd           ; Load pixel to be cleared
cpstore         sta     ,x                ; Store in VDU RAM
cpdone          puls    a,b,x,pc          ; Restore registers and return

                end     main
