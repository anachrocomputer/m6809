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
                rts
                
hellostr        fcc     "Hello, world"
                fcb     cr,lf,eos

                end     main
