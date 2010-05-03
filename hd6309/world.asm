; world --- print "hello, world"
;
cr              equ     $0d
lf              equ     $0a
eos             equ     $00

t1in            equ     $ffe8
t1ou            equ     $ffec

                org     $8000
                nop
                nop
                nop
                ldx     #world
                jsr     prtmsg
                nop
                nop
                nop
                rts

; PRTMSG
; Print message pointed to by X, terminated by zero byte
prtmsg          pshs    a,x               ; Save A and X registers
prtmsg1         lda     ,x+
                beq     prtmsg2
                jsr     t1ou
                bra     prtmsg1
prtmsg2         puls    a,x,pc            ; Restore A and X, then return

world           fcc     "Hello, world"
                fcb     cr,lf,eos
