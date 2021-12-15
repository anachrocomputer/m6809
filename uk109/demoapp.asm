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

                setdp   0
                org     $0400
main            ldx     #hellostr         ; X->string in RAM
                jsr     prtmsg
                jsr     getkey            ; Wait for a key-press
                lda     #31               ; Init loop counter
l1              tfr     a,b               ; Copy X co-ord to B reg
                jsr     setpixel          ; Set one pixel
                deca                      ; Decrement loop counter
                bpl     l1                ; Loop back for next pixel
                jsr     getkey            ; Wait for a key-press
                rts
                
hellostr        fcc     "Hello, world"
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
