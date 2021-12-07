; uk101.asm --- UK101 hardware addresses                       2021-12-07
; Copyright (c) 2021 John Honniball, Froods Software Development

; Hardware adresses
vram            equ     $d000             ; UK101 video RAM
keymatrix       equ     $df00             ; Keyboard matrix
acias           equ     $f000             ; MC6850 ACIA status/control register
aciad           equ     $f001             ; MC6850 ACIA data register

; VDU addresses and dimensions
botrow          equ     $d3c0             ; Address of bottom row of VDU
vramsz          equ     $0400             ; 1k byte of video RAM
vramstride      equ     64
vdurows         equ     16                ; Number of VDU rows
vducols         equ     48                ; Number of VDU columns
lm              equ     13                ; VDU left margin

; ROM addresses
basrom          equ     $a000             ; First BASIC ROM on UK101
monrom          equ     $f800             ; Monitor ROM on UK101

uk101reset      equ     $fe00             ; Traditional UK101 reset address
