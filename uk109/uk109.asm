; UK109.asm -- 6809 monitor ROM for UK101                      2004-10-13
; Copyright (c) 2004 John Honniball, Froods Software Development

; Modification:
; 2004-10-13 JRH Initial coding
; 2004-10-14 JRH Added rudimentary 'vduchar' routine
; 2004-10-16 JRH Added ROM checksum
; 2004-10-17 JRH Added initial RAM test
; 2004-10-18 JRH Added 100us delay routine and keyboard polling
; 2004-10-21 JRH Improved keyboard polling, added cursor, VDU scrolling
; 2004-10-22 JRH Introduced hex monitor routines
; 2004-10-25 JRH Hex monitor '@' command
; 2004-10-27 JRH Added screen save/restore and random number generator
; 2004-10-27 JRH Added Matrix display hack
; 2006-03-15 JRH Changed reset message to reduce size of text in EPROM
; 2006-03-15 JRH Altered VDU code to use jump table
; 2006-03-23 JRH Added VDU test pattern
; 2007-06-22 JRH Set up Subversion repository
; 2008-01-17 JRH Fixed bug introduced by VDU jump table code
; 2008-02-01 JRH Split into two ROMs, one at $A000, other at $F800
; 2021-10-26 JRH Converted repo from Subversion to Git
; 2021-11-27 JRH Introduced HD6309 assembler 'asm6809'

HD6309          equ     1

eos             equ     $00
nul             equ     $00
cr              equ     $0d
lf              equ     $0a
ctrl_g          equ     $07
ctrl_h          equ     $08
ctrl_i          equ     $09
ctrl_j          equ     $0a
ctrl_k          equ     $0b
ctrl_l          equ     $0c
ctrl_m          equ     $0d
ctrl_n          equ     $0e
ctrl_o          equ     $0f
sp              equ     $20
del             equ     $7f
crsrch          equ     $06               ; Character to represent cursor
blkch           equ     $a1               ; Block character, all pixels lit
chqch           equ     $bb               ; Block character, chequered
topch           equ     $87               ; Top row of pixels lit
botch           equ     $80               ; Bottom row of pixels lit
lftch           equ     $88               ; Leftmost column of pixels lit
rghch           equ     $8f               ; Rightmost column of pixels lit
trch            equ     207               ; Top right corner
tlch            equ     210               ; Top left corner
brch            equ     208               ; Bottom right corner
blch            equ     209               ; Bottom left corner

kbmodrow        equ     $01               ; Keyboard modifier keys row
kbrow1          equ     $02               ; First row of main keyboard
dbdly           equ     4                 ; Debounce 8ms
longdly         equ     250               ; First repeat 500ms
rptdly          equ     50                ; Auto-repeat 100ms

rngseed1        equ     $c0
rngseed2        equ     $ff
rngseed3        equ     $ee

pad             equ     $ff               ; Padding unused EPROM space

; Hardware adresses
ramtop          equ     $0fff             ; Last byte of 4K 2114 RAM
vram            equ     $d000             ; UK101 video RAM
botrow          equ     $d3c0             ; Address of bottom row of VDU
vramsz          equ     $0400             ; 1k byte of video RAM
vramstride      equ     64
vdurows         equ     16                ; Number of VDU rows
vducols         equ     48                ; Number of VDU columns
lm              equ     13                ; VDU left margin
keymatrix       equ     $df00             ; Keyboard matrix
acias           equ     $f000             ; MC6850 ACIA status/control register
aciad           equ     $f001             ; Data register

basrom          equ     $a000             ; First BASIC ROM on UK101
monrom          equ     $f800             ; Monitor ROM on UK101

uk101reset      equ     $fe00             ; Traditional UK101 reset address

                org     $0
govec           rmb     2                 ; Address for 'Go' command
rega            rmb     1                 ; Saved register contents
regb            rmb     1
rege            rmb     1
regf            rmb     1
regcc           rmb     1
regdp           rmb     1
regmd           rmb     1
                rmb     1                 ; Word alignment
regv            rmb     2
regx            rmb     2
regy            rmb     2
regu            rmb     2
regs            rmb     2
cksum           rmb     1                 ; Hex load/save checksum
illvec          rmb     2                 ; 6309 Illegal Instruction trap
swi3vec         rmb     2
swi2vec         rmb     2
swivec          rmb     2
irqvec          rmb     2
firqvec         rmb     2
nmivec          rmb     2
outvec          rmb     2
crsrrow         rmb     2
crsrpos         rmb     1
chunder         rmb     1                 ; Character under cursor
keydly          rmb     1
prevscan        rmb     1                 ; Previous keyboard scan code
freeram         rmb     1                 ; Beginning of free RAM
rng1            rmb     1
rng2            rmb     1
rng3            rmb     1
matdly          rmb     vducols           ; Delay in ms for this column
mattime         rmb     vducols           ; Current state of timer
matcnt          rmb     vducols           ; Counter
matstat         rmb     vducols           ; State for this column
vdubuf          rmb     vducols*vdurows   ; VDU save/restore buffer
boxcol          rmb     2                 ; Box-drawing temporaries
boxrow          rmb     2
boxncols        rmb     2
boxnrows        rmb     2
boxtladdr       rmb     2
boxtraddr       rmb     2
boxbladdr       rmb     2

                setdp   0
                org     basrom
; CRLF --- print CR and LF
; Entry: no parameters
; Exit:  registers unchanged
crlf            pshs    a
                lda     #cr
                bsr     vduchar
                lda     #lf
                bsr     vduchar
                puls    a,pc
                
; SPACE --- print a space
; Entry: no parameters
; Exit:  registers unchanged
space           pshs    a
                lda     #sp
                bsr     vduchar
                puls    a,pc
                
; PRTMSG
; Print message pointed to by X, terminated by zero byte
prtmsg          pshs    a,x               ; Save A and X registers
prtmsg1         lda     ,x+
                beq     prtmsg2
                bsr     vduchar
                bra     prtmsg1
prtmsg2         puls    a,x,pc            ; Restore A and X, then return

; VDUCHAR --- print a single character to the VDU, allowing for cursor movement
; Entry: char to be printed in A
; Exit: registers unchanged
vduchar         pshs    b,x               ; Save B and X registers
                ldb     crsrpos           ; Get cursor position
                ldx     crsrrow           ; Get cursor row address
                cmpa    #ctrl_o
                bmi     ctrlch
notctrl         sta     b,x               ; Put character in video RAM
                incb                      ; Move cursor right
                cmpb    #vducols          ; Test for right-hand margin
                beq     vwrap             ; Wrap around to next line
vdurtn          stb     crsrpos           ; Save updated cursor position
                puls    b,x,pc            ; Restore B and X, then return
                
ctrlch          cmpa    #nul              ; Ignore NULs
                beq     vdurtn
                cmpa    #ctrl_g
                bmi     notctrl           ; Wasn't a valid control character after all
                pshs    a,y               ; Need to use A and Y so save 'em
                suba    #ctrl_g           ; Subtract offset
                asla                      ; Multiply by two
                ldy     #vctrltab         ; Load pointer to subroutine table
                jsr     [a,y]             ; Call cursor motion subroutine
                puls    a,y               ; Restore A and Y registers
                bra     vdurtn            ; Back to main VDU routine

; VDU control character handling routines
vctrltab        fdb     vctrl_g
                fdb     vctrl_h
                fdb     vctrl_i
                fdb     vctrl_j
                fdb     vctrl_k
                fdb     vctrl_l
                fdb     vctrl_m
                fdb     vctrl_n

vwrap           bsr     vctrl_m           ; Emulate CR/LF
                bsr     vctrl_j
                bra     vdurtn
                
vctrl_g         bsr     vduflip           ; CTRL_G: bell
                lda     #20
flipdly         jsr     dly1ms
                deca
                bne     flipdly
                bsr     vduflip
                rts
                
vctrl_h         decb                      ; CTRL_H: cursor left
                rts
                
vctrl_i         incb                      ; CTRL_I: cursor right
                rts
                
vctrl_j         cmpx    #botrow           ; CTRL_J: cursor down/scroll up
                bhs     scroll
                leax    vramstride,x      ; Simply move the cursor down
                stx     crsrrow
                rts
 if HD6309
scroll          pshs    b,x,y             ; Save registers
                pshsw
 else
scroll          pshs    a,b,x,y,u         ; Save registers
 endif
                ldx     #vram+vramstride+lm
                ldy     #vram+lm
                ldb     #15
 if HD6309
scrlrow         ldw     #vducols
                tfm     x+,y+             ; Load lower row, store upper row
 else
scrlrow         lda     #vducols / 2
scrlch          ldu     ,x++              ; Load from lower row...
                stu     ,y++              ; Store into upper row
                deca
                bne     scrlch
 endif
                leax    16,x
                leay    16,y
                decb
                bne     scrlrow
                ldx     #botrow+lm        ; Clear bottom row
 if HD6309
                ldy     #aspace           ; Y->space character
                ldw     #vducols
                tfm     y,x+
 else
                ldu     #$2020            ; Two ASCII spaces
                lda     #vducols / 2
clrrow          stu     ,x++
                deca
                bne     clrrow
 endif
                
 if HD6309
                pulsw
                puls    b,x,y,pc          ; Restore registers and return
aspace          fcc     " "               ; A single ASCII space
 else
                puls    a,b,x,y,u,pc      ; Restore registers and return
 endif

vctrl_k         leax    -vramstride,x     ; CTRL_K: cursor up
                stx     crsrrow
                rts

vctrl_l         pshs    a,y               ; CTRL_L: clear screen
                ldx     #vram
 if HD6309
                pshsw
                ldy     #aspace           ; Y->an ASCII space
                ldw     #vramsz
                tfm     y,x+
                pulsw
 else
                ldd     #$2020            ; ASCII space in both A and B
                ldy     #vramsz
vcl             std     ,x++
                leay    -2,y
                bne     vcl
 endif
                puls    a,y
vctrl_n         ldx     #vram+lm          ; CTRL_N: home cursor
                stx     crsrrow
vctrl_m         clrb                      ; CTRL_M: carriage return
                rts
                
; VDUFLIP --- flip video display into inverse
; Entry: no parameters
; Exit: A, B, Y changed; X, U unchanged
vduflip         ldy     #vram+lm          ; 4
                lda     #vdurows          ; 2
flp_r           ldb     #vducols          ; 2
                pshs    a
flp_c           lda     ,y                ;     Load from video RAM
                eora    #$81              ;     Flip $20 -> $A1
                sta     ,y+               ;     Store back into video RAM
                decb                      ; 2
                bne     flp_c             ; 3  
                leay    16,y              ; 4+1 Skip 16 bytes in VRAM
                puls    a
                deca                      ; 2
                bne     flp_r             ; 3
                rts
                
; VDUSAVE --- save video display into memory buffer
; Entry: buffer address in X
; Exit: registers unchanged
 if HD6309
vdusave         pshs    a,x,y             ; Save registers
                pshsw
 else
vdusave         pshs    a,b,x,y,u         ; Save registers
 endif
                ldy     #vram+lm          ; 4
                lda     #vdurows          ; 2
 if HD6309
sav_r           ldw     #vducols
                tfm     y+,x+
 else
sav_r           ldb     #vducols / 2      ; 2
sav_c           ldu     ,y++              ; 5+3 Load from video RAM
                stu     ,x++              ; 5+3 Store into buffer
                decb                      ; 2
                bne     sav_c             ; 3  
 endif
                leay    16,y              ; 4+1 Skip 16 bytes in VRAM
                deca                      ; 2
                bne     sav_r             ; 3   
 if HD6309
                pulsw                     ; Restore registers and return
                puls    a,x,y,pc          
 else
                puls    a,b,x,y,u,pc      ; Restore registers and return
 endif
                
; VDURESTORE --- restore video display from buffer in memory
; Entry: buffer address in X
; Exit: registers unchanged
 if HD6309
vdurestore      pshs    a,x,y             ; Save registers
                pshsw
 else
vdurestore      pshs    a,b,x,y,u         ; Save registers
 endif
                ldy     #vram+lm
                lda     #vdurows
 if HD6309
rest_r          ldw     #vducols
                tfm     x+,y+
 else
rest_r          ldb     #vducols / 2
rest_c          ldu     ,x++              ; Load from buffer
                stu     ,y++              ; Store into video RAM
                decb
                bne     rest_c
 endif
                leay    16,y              ; Skip 16 bytes in VRAM
                deca
                bne     rest_r
 if HD6309
                pulsw                     ; Restore registers and return
                puls    a,x,y,pc
 else
                puls    a,b,x,y,u,pc      ; Restore registers and return
 endif
                
; KBHIT --- return with carry set if a key is pressed
kbhit           pshs    a,b
                lda     #$ff
                bsr     keywrb
                andcc   #$fe              ; Clear carry bit
                andb    #$fe              ; Ignore caps-lock
                beq     nokbhit
                orcc    #$01              ; Set carry bit
nokbhit         puls    a,b,pc

; KEYWRB
; Write a bit-pattern to the keyboard matrix from A, then read into B
keywrb          coma                      ; Invert bits because the
                sta     keymatrix         ; key matrix is all active-low
                coma         
                ldb     keymatrix         ; Read the keys...
                comb                      ; and invert bits
                rts
                
; KEYRST
; Reset and test the keyboard
keyrst          lda     #$ff              ; Test all 8 keyboard rows at once
                bsr     keywrb
                andb    #$fe              ; Ignore Caps-Lock
                beq     keyrst1
                ldx     #kberrmsg         ; Print failure message
                jsr     prtmsg
keyrst1         rts

; POLLKB
; Poll all keys apart from shifts, return scan code in A
pollkb          pshs    b,x
                ldx     #1                ; Scancodes are 1-based
                lda     #kbrow1           ; Start scanning at row 1
pollrow         bsr     keywrb
                bne     pollok
                leax    8,x               ; Next row, next eight scan-codes
                asla                      ; Next bit to the left
                bne     pollrow           ; Poll next row
                bra     pollnone          ; Fall through if no key pressed
pollok          aslb                      ; Shift bit in B
                bcs     polled            ; Did we shift out a '1'?
                leax    1,x               ; Inc scan-code
                bra     pollok
polled          tfr     x,d               ; Scancode to B
                tfr     b,a               ; Scancode to A
pollnone        puls    b,x,pc

; Hex output routines

; HEX1OU --- print a single hex digit
; Entry: 4 bit value in A
; Exit:  registers unchanged
hex1ou          pshs    a
                anda    #$0f
                ora     #$30              ; 0..9 OK
                cmpa    #$39              ; ASCII 9
                bls     h1
                adda    #7                ; A..F
h1              jsr     vduchar
                puls    a,pc

; HEX2OU
; Entry: 8 bit value in A
; Exit:  registers unchanged
hex2ou          pshs    a
                asra
                asra
                asra
                asra
                bsr     hex1ou            ; Print high nybble...
                puls    a
                bsr     hex1ou            ; then low nybble
                rts
                
; HEX4OU
; Entry: 16 bit value in D
; Exit:  registers unchanged
hex4ou          pshs    d
                bsr     hex2ou
                tfr     b,a
                bsr     hex2ou
                puls    d,pc
                
; Hex input routines

; HEX1IN --- read a single hex digit from the keyboard
; Entry: no parameters
; Exit:  4-bit value in A
hex1in          jsr     getchar           ; Read one ASCII character
                jsr     vduchar           ; Echo it
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
                jsr     vduchar
                clra
                bra     hexdone
                
; HEX2IN --- read two hex digits from the keyboard
; Entry: no parameters
; Exit:  8-bit value in A
hex2in          bsr     hex1in
                asla
                asla
                asla
                asla
                pshs    a
                bsr     hex1in
                ora     ,s+
                rts

; HEX4IN --- read four hex digits from the keyboard
; Entry: no parameters
; Exit:  16-bit value in D
hex4in          bsr     hex2in
                tfr     a,b
                bsr     hex2in
                exg     a,b
                rts
               
; I/O routines

; TOUPPER --- map an ASCII character to upper case
; Entry: ASCII character in A
; Exit uppercase ASCII character in A, other registers unchanged
toupper         cmpa    #'a'
                blo     uprrtn
                cmpa    #'z'
                bhi     uprrtn
                suba    #'a'-'A'
uprrtn          rts

; T1OU
; Entry: A=ASCII char to send to serial port
; Exit:  registers unchanged
t1ou            pshs    a                 ; Save char in A
t1ou1           lda     acias             ; Read ACIA status
                anda    #$02              ; Transmit ready?
                beq     t1ou1
                puls    a                 ; Restore A
                sta     aciad             ; Send char
                rts
                
; T1IN
; Entry:
; Exit:  A=ASCII char from UART
t1in            lda     acias             ; Read ACIA status
                anda    #$01              ; Check RDRF bit
                beq     t1in
                lda     aciad             ; Get ASCII byte from RDR
                rts

; GETKEY
; Read a single keystroke from the keyboard by polling
getkey          pshs    b,x               ; Save B and X
kbp             jsr     pollkb            ; Poll keyboard matrix
                tsta                      ; Any key(s) pressed?
                beq     keysup
                dec     keydly
                beq     keydone
                jsr     dly1ms            ; Delay for 1ms
                jsr     dly1ms            ; Delay for 1ms
                bra     kbp
keysup          ldb     #dbdly            ; Load debounce delay
                stb     keydly
                clr     prevscan          ; Reset auto-repeat mechanism
                bra     kbp
keydone         ldb     #longdly          ; Load long (first repeat) delay
                cmpa    prevscan
                bne     keynew            ; It's a new key-press
                ldb     #rptdly           ; Same scancode, so auto-repeat
keynew          stb     keydly
                sta     prevscan          ; Remember scan code for next time
                lda     #kbmodrow         ; Deal with SHIFT, CTRL, CAPS
                jsr     keywrb            ; Read modifier bits into B
                lda     prevscan
                ldx     #scantab
                lda     a,x               ; Pick up ASCII code
                bpl     noshift           ; Top bit is 'shiftable' flag
                anda    #$7f              ; Mask off top bit to get ASCII
                bitb    #$06              ; Test bits for SHIFTs
                beq     noshift
                eora    #16               ; Flip bit 4 to shift like a teletype
noshift         cmpa    #'@'              ; CTRL only works on '@' to '_'
                blo     noctrl
                cmpa    #'_'
                bhi     noctrl
                bitb    #$40              ; Test bit for CTRL
                beq     noctrl
                anda    #$1f              ; Mask off bits for CTRL
noctrl          cmpa    #'A'              ; CAPS-LOCK only works on 'A' to 'Z'
                blo     nocaps
                cmpa    #'Z'
                bhi     nocaps
                bitb    #$01              ; Test bit for CAPS-LOCK
                bne     nocaps
                adda    #$20              ; Add 32 for lower-case
nocaps          puls    b,x,pc            ; Restore B, X and return

; GETCHAR
; Get a character from input device
getchar         pshs    b,x               ; Save B and X
                ldb     crsrpos           ; Get cursor position
                ldx     crsrrow           ; Get cursor row address
                lda     b,x               ; Get character under cursor
                sta     chunder           ; Save it
                                          ; Deal with LOAD flag here
                lda     #crsrch
                sta     b,x               ; Display cursor
                bsr     getkey            ; Get a keystroke
                pshs    a
                lda     chunder           ; Get the character back again
                sta     b,x               ; Write it back into VDU RAM
                puls    a                 ; Restore A
                                          ; Handle CTRL-E editing here
                puls    b,x,pc            ; Restore B, X and return
                
; DLY100U
; Delay for 100us when running with 8MHz clock
;dly100u         pshs    a                 ; 6
;                lda     #35               ; 2
;dlyloop         deca                      ; 2 * 35
;                bne     dlyloop           ; 3 * 35
;                puls    a,pc              ; 8
                
; DLY1MS
; Delay for one millisecond
dly1ms          pshs    a                 ; 6
                lda     #220              ; 2
dlyloop         deca                      ; 2 * 220
                nop                       ; 2 * 220
                nop                       ; 2 * 220
                bne     dlyloop           ; 3 * 220
                puls    a,pc              ; 8

; Alternative implementation
;ndly1ms         pshs    x                 ; 7
;                ldx     #246              ; 3
;ndlyloop        leax    -1,x              ; 5 * 246
;                bne     ndlyloop          ; 3 * 246
;                puls    x,pc              ; 9

; RND16 --- generate 16-bit pseudo-random number
; Entry: no parameters
; Exit:  pseudo-random number in D
rnd16           lda     rng3              ; Pick up 3rd byte of 24 bit SR
                anda    #$01              ; Mask bottom bit
                tfr     a,b               ; Put into B
                lda     rng3              
                anda    #$20              ; Mask bit 5
                beq     r1
                comb                      ; Bit 5 set, so flip B
r1              lda     rng3
                anda    #$40              ; Mask bit 6
                beq     r2
                comb                      ; Bit 6 set, so flip B
r2              lsrb                      ; Bottom bit of B into carry
                rol     rng1              ; Now do a 24-bit left shift
                rol     rng2              ; taking the carry bit in
                rol     rng3
                lda     rng1              ; Load 16 random bits
                ldb     rng2
                rts
                
matrixhack      ldx     #vdubuf           ; Matrix display hack (216 bytes)
                jsr     vdusave           ; Save video RAM
                lda     #ctrl_l           ; Clear screen
                jsr     vduchar
                lda     #47               ; Loop counter for cols 0-47
                ldx     #matdly
                ldy     #mattime
                ldu     #matcnt
matinit         pshs    a
                jsr     rnd16
                puls    a
                andb    #63               ; Mask B into range 0-63
                addb    #40               ; 40ms basic timing
                stb     a,x
                stb     a,y
                pshs    a
                jsr     rnd16             ; Get random startup count
                puls    a
                andb    #$0f              ; Mask down to four bits
                stb     a,u               ; 0-15 random startup count
                deca
                bpl     matinit
matwait         jsr     kbhit             ; Wait for key to be released
                bcs     matwait
matrix          lda     #47               ; Loop counter for 48 columns
                ldx     #mattime          ; X->timer array
mtl             dec     a,x
                bne     noanim
                jsr     matanim
                ldx     #matdly           ; X->delay times
                ldb     a,x               ; Get delay time for this column
                ldx     #mattime          ; X->current timers
                stb     a,x               ; Reinitialise timer for this col
noanim          deca
                bpl     mtl
                jsr     dly1ms            ; Delay for 1ms
                jsr     kbhit             ; Test for keyboard
                bcc     matrix
                ldx     #vdubuf
                jmp     vdurestore        ; Put video RAM back again
                
; Entry: A=column number
matanim         ldx     #botrow+lm
                leau    -64,x             ; U-> row above
                ldy     #15               ; 15 screen rows
ani1            ldb     a,u               ; Get byte from screen
                stb     a,x               ; Put back in
                leau    -64,u             ; Move both pointers up one row
                leax    -64,x
                leay    -1,y              ; Decrement loop counter
                bne     ani1
                ldy     #matcnt           ; Y->counter
                ldb     a,y               ; Get counter for this col
                beq     ani2              ; If it's zero, pick a character
                ldb     #sp               ; Otherwise, pick space
                dec     a,y               ; Decrement the counter
                bra     ani3
ani2            pshs    a                 ; Pick a random character
                jsr     rnd16             ; Get a random number
                puls    a
                andb    #63               ; Mask down to 0-63
                ldy     #matsyms
                ldb     b,y               ; Pick up ASCII from table
ani3            stb     a,x               ; Place at top of column
;               inc     a,x               ; Increment char at top
                rts
                
; Table of non-alphabetic symbols for the Matrix display hack
matsyms         fcb     02,03,04,09,11,12,24,25,26,27,28,29,30,31,33,34
                fcb     35,36,37,38,39,40,41,42,43,44,45,46,47,48,58,59
                fcb     60,61,62,64,90,92,94,95,123,124,125,126,127,179,180,181
                fcb     182,211,212,213,214,241,242,243,244,245,246,247,248,249,250,251

; Various message strings
rstmsg          fcb     lf,ctrl_i
 if HD6309
                fcc     "UK109 (6309 CPU) V0.3"
 else
                fcc     "UK109 (6809 CPU) V0.3"
 endif
                fcb     cr,lf,ctrl_i
                fcc     "Copyright (c) 2004-2021"
                fcb     cr,lf
                fcb     eos

romokmsg        fcb     ctrl_i
                fcc     "ROM checksum OK"
                fcb     eos
romerrmsg       fcb     ctrl_i
                fcc     "ROM checksum error,"
                fcb     eos
memokmsg        fcb     ctrl_i
                fcc     "Memory OK"
                fcb     eos
memfail1        fcb     ctrl_i
                fcc     "RAM fail1 at $"
                fcb     eos
memfail2        fcb     ctrl_i
                fcc     "RAM fail2 at $"
                fcb     eos
expmsg          fcc     " expected $"
                fcb     eos
readmsg         fcc     ", read $"
                fcb     eos
                
adrokmsg        fcc     "Memory Addressing OK"
                fcb     cr,lf,eos

adrerrmsg       fcc     "Memory Addressing FAIL"
                fcb     cr,lf,eos
                
kberrmsg        fcb     ctrl_i
                fcc     "Keyboard FAIL"
                fcb     cr,lf,eos

kbokmsg         fcb     ctrl_i
                fcc     "Keyboard OK"
                fcb     cr,lf,eos

monmsg          fcc     "UK109 Machine Code Monitor"
                fcb     cr,lf,eos
chkmsg          fcc     " checksum errors"
                fcb     eos

N               equ     $80                      
NKY             equ     0

scantab         fcb     NKY               ; Skip zeroth index
                fcb     'Q',  'A',  'Z',  sp,   '/'+N,';'+N,'P'+N,NKY ; 1-8
                fcb     'X',  'C',  'V',  'B',  'N'+N,'M'+N,','+N,NKY ; 9-16
                fcb     'S',  'D',  'F',  'G',  'H',  'J',  'K'+N,NKY ; 17-24
                fcb     'W',  'E',  'R',  'T',  'Y',  'U',  'I',  NKY ; 25-32
                fcb     '.'+N,'L'+N,'O'+N,'^',  cr,   NKY,  NKY,  NKY ; 33-40
                fcb     '8'+N,'9'+N,'0',  ':'+N,'-'+N,del,  NKY,  NKY ; 41-48
                fcb     '1'+N,'2'+N,'3'+N,'4'+N,'5'+N,'6'+N,'7'+N,NKY ; 49-56

; Monitor entry point
monitor         clra                      ; Clear all the saved registers
                clrb                      ; so that they're not just random
                sta     rega              ; values if we type 'r' before
                stb     regb              ; we've used 'g'.
                sta     rege
                sta     regf
                sta     regcc
                sta     regdp
                sta     regmd
                std     regv
                std     regx
                std     regy
                std     regu
                std     regs
                ldx     #monmsg           ; Monitor sign-on message
                jsr     prtmsg
                bra     moncmd
cmderr          lda     #'?'              ; Unrecognised command
                jsr     vduchar
                jsr     crlf
moncmd          lda     #'>'              ; Monitor command-level prompt
                jsr     vduchar
                jsr     getchar           ; Read command letter from user
                jsr     vduchar           ; Echo
                jsr     toupper           ; Convert to upper case
                cmpa    #'@'
                blo     cmderr
                cmpa    #'Z'
                bhi     cmderr
                suba    #'@'
                asla
                ldx     #cmdtab
                jsr     [a,x]             ; Call monitor command routine
                jsr     crlf
                bra     moncmd
                
; End of code in the 2k EPROM located at 'basrom'

; UK101 Monitor command routines
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

                org     monrom
cmdtab          fdb     atcmd, acmd, bcmd  ; Jump table for monitor commands
                fdb     ccmd, dcmd, ecmd
                fdb     fcmd, gcmd, hcmd 
                fdb     icmd, jcmd, kcmd
                fdb     lcmd, mcmd, ncmd
                fdb     ocmd, pcmd, qcmd
                fdb     rcmd, scmd, tcmd
                fdb     ucmd, vcmd, wcmd
                fdb     xcmd, ycmd, zcmd

; ATCMD --- monitor '@' command: open memory for editing
atcmd           jsr     hex4in            ; Get starting address
                tfr     d,x
atcmd5          lda     #'='
                jsr     vduchar
atcmd1          lda     ,x                ; Fetch byte from specified address
                jsr     hex2ou            ; Print it in hex
                jsr     space
                jsr     getchar           ; Get a command
                jsr     vduchar
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
atcmd6          cmpa    #'-'              ; -->decrement byte
                bne     atcmd7                   
                dec     ,x    
                bra     atcmd1
atcmd7          cmpa    #'"'              ; "->display as ASCII
                bne     atcmd8
                lda     ,x
                jsr     vduchar
                jsr     space
                bra     atcmd1
atcmd8          nop                       ; Test for hex here
atcmdx          rts
                
; DCMD --- monitor 'D' command: dump memory in hex (incomplete)
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

; GCMD --- monitor 'G' command: go
gcmd            jsr     hex4in            ; Get address
                jsr     crlf
                std     govec             ; Save address in RAM
                lda     rega              ; Load up all registers from RAM
                ldb     regb
 if HD6309
                lde     rege
                ldf     regf
                ldx     regv
                tfr     x,v               ; Can't load V directly
 endif
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
 if HD6309
                ste     rege
                stf     regf
 endif
                stx     regx
 if HD6309
                tfr     v,x               ; Can't store V directly
                stx     regv
 endif
                sty     regy
                stu     regu
                sts     regs
                rts

; ICMD --- monitor 'I' command: 
;icmd            jsr     hex4in
;                tfr     d,x
;                lda     #','
;                jsr     vduchar
;                jsr     hex4in
;                tfr     d,y
;                jsr     crlf
;                tfr     x,d
;                jsr     hex4ou
;                jsr     space
;iloop           lda     ,x
;                jsr     hex2ou
;                jsr     space
;                rts

; HCMD --- monitor 'H' command: help
hcmd            ldx     #monmsg           ; Monitor help command
                jsr     prtmsg
                rts

; Load Intel-format checksum hex
lcmd            jsr     crlf
                ldu     #0                ; Initialise error count
l1              ldy     #0                ; Initialise checksum
                jsr     t1in              ; Read, looking for start of record
                jsr     vduchar           ; Echo to screen
                cmpa    #':'              ; Colon for Intel format
                beq     lintel
                cmpa    #'S'              ; S for Motorola S-Record
                beq     lsrec
                cmpa    #';'              ; Semicolon for MOS Technologies
                lbeq    lmostech
                bra     l1                ; Unrecognised record starter
lintel          jsr     hex2in_ac         ; Read length
                leay    a,y               ; Add to checksum
                pshs    a                 ; Save length
                jsr     hex4in_ac         ; Read start address
                leay    a,y               ; Add to checksum
                leay    b,y               ; Add to checksum
                tfr     d,x               ; Address into X
                puls    b                 ; Get length back into B
                bsr     hex2in_ac         ; Read record type
                bne     li4
                leay    a,y               ; Add to checksum
l2              bsr     hex2in_ac         ; Read data byte
                sta     ,x+               ; Store into memory
                leay    a,y               ; Add to checksum
                decb                      ; Decrement loop counter
                bne     l2                ; Go back for next byte
                bsr     hex2in_ac         ; Read checksum from input
                leay    a,y               ; Add to computed checksum
                tfr     y,d               ; LSB should be 0
                cmpb    #0                ; B contains LSB
                beq     l3
                leau    1,u               ; Increment error counter
l3              bra     l1                ; Go back for next line
li4             bsr     hex2in_ac         ; Dummy read checksum
                bra     ldone
lsrec           jsr     t1in              ; Read record type
                jsr     vduchar           ; Echo to screen
                cmpa    #'1'
                beq     ls1
                cmpa    #'9'              ; Check for EOF
                beq     ls4
                bra     l1                ; Ignore unknown record types
ls1             bsr     hex2in_ac         ; Read length
                leay    a,y               ; Add to checksum
                suba    #3                ; Allow for 3 byte header
                pshs    a                 ; Save length
                bsr     hex4in_ac         ; Read start address
                leay    a,y               ; Add to checksum
                leay    b,y               ; Add to checksum
                tfr     d,x               ; Address into X
                puls    b                 ; Get length back into B
ls2             bsr     hex2in_ac         ; Read data byte
                sta     ,x+               ; Store into memory
                leay    a,y               ; Add to checksum
                decb                      ; Decrement loop counter
                bne     ls2               ; Go back for next byte
                tfr     y,d               ; LSB into B
                comb                      ; Form one's complement of LSB
                stb     cksum             ; Save in memory
                bsr     hex2in_ac         ; Read checksum from input
                cmpa    cksum             ; Compare computed and read-in
                beq     ls3
                leau    1,u               ; Increment error counter
ls3             lbra    l1                ; Go back for next line
ls4             bsr     hex2in_ac         ; Dummy read length
                bsr     hex4in_ac         ; Dummy read address
                bsr     hex2in_ac         ; Dummy read checksum
                bra     ldone
lmostech        nop
                bra     ldone
ldone           tfr     u,d               ; Get error count into D
                jsr     crlf
                jsr     hex4ou
                ldx     #chkmsg
                jsr     prtmsg
                rts

; HEX2IN_AC --- read two hex digits from the ACIA
; Entry: no parameters
; Exit:  8-bit value in A
hex2in_ac       bsr     hex1in_ac
                asla
                asla
                asla
                asla
                pshs    a
                bsr     hex1in_ac
                ora     ,s+
                rts

; HEX4IN_AC --- read four hex digits from the ACIA
; Entry: no parameters
; Exit:  16-bit value in D
hex4in_ac       bsr     hex2in_ac
                tfr     a,b
                bsr     hex2in_ac
                exg     a,b
                rts
               
; HEX1IN_AC --- read a single hex digit from the ACIA
; Entry: no parameters
; Exit:  4-bit value in A
hex1in_ac       jsr     t1in              ; Read one ASCII character
                jsr     vduchar           ; Echo it
                jsr     toupper
                cmpa    #'0'
                blo     hexerr_ac
                cmpa    #'9'
                bhi     hexalph_ac
                suba    #'0'
                bra     hexdone_ac
hexalph_ac      cmpa    #'A'
                blo     hexerr_ac
                cmpa    #'F'
                bhi     hexerr_ac
                suba    #'A'-10
hexdone_ac      rts
hexerr_ac       lda     #'?'
                jsr     vduchar
                clra
                bra     hexdone_ac
                
acmd
bcmd
ccmd
ecmd
fcmd
icmd
jcmd
kcmd
mcmd
ncmd
ocmd
pcmd
qcmd
ucmd            rts

; RCMD --- monitor 'R' command: register dump
rcmd            jsr     crlf
                lda     rega               ; 6809 register A
                ldb     #'A'
                bsr     regprt2
                lda     regb               ; 6809 register A
                ldb     #'B'
                bsr     regprt2
 if HD6309
                lda     rege               ; 6309 register E
                ldb     #'E'
                bsr     regprt2
                lda     regf               ; 6309 register F
                ldb     #'F'
                bsr     regprt2
 endif
                lda     #'C'               ; 6809 register CC
                jsr     vduchar
                lda     regcc
                ldb     #'C'
                bsr     regprt2
                lda     #'D'               ; 6809 register DP
                jsr     vduchar
                lda     regdp
                ldb     #'P'
                bsr     regprt2
 if HD6309
                lda     #'M'               ; 6309 register MD
                jsr     vduchar
                lda     regmd
                ldb     #'D'
                bsr     regprt2
 endif
                jsr     crlf
                ldx     regx               ; 6809 register X
                lda     #'X'
                bsr     regprt4
                ldx     regy               ; 6809 register Y
                lda     #'Y'
                bsr     regprt4
                ldx     regu               ; 6809 register U
                lda     #'U'
                bsr     regprt4
                ldx     regs               ; 6809 register S
                lda     #'S'
                bsr     regprt4
 if HD6309
                ldx     regv               ; 6309 register V
                lda     #'V'
                bsr     regprt4
 endif
                rts
                
; REGPRT2 --- print an 8-bit register value as two-digit hex
regprt2         exg     a,b
                jsr     vduchar
                lda     #':'
                jsr     vduchar
                exg     a,b
                jsr     hex2ou
                jsr     space
                rts

; REGPRT2 --- print a 16-bit register value as four-digit hex
regprt4         jsr     vduchar
                lda     #':'
                jsr     vduchar
                tfr     x,d 
                jsr     hex4ou
                jsr     space
                rts

; SCMD --- monitor 'S' command: save memory in Motorola S-Record format
scmd            jsr     hex4in            ; Get starting address
                tfr     d,x
                lda     #','
                jsr     vduchar
                jsr     hex4in            ; Get ending address
                tfr     d,y
                jsr     crlf
                ldb     #32               ; 32 byte records
                bsr     sblk              ; Write one S-record
                bsr     sblk              ; Write one S-record
                ldx     #s9eof            ; X->EOF record
s1              lda     ,x+
                beq     sdone
                jsr     vduchar
                jsr     t1ou
                bra     s1
sdone           rts
s9eof           fcc     "S9030000FC"
                fcb     cr,lf,eos

; sblk --- write a single block of S-Record data
; X: start address, Y: length
sblk            pshs    b                 ; Save B (length)
                lda     #'S'
                jsr     vduchar
                jsr     t1ou
                lda     #'1'
                jsr     vduchar
                jsr     t1ou
                ldy     #0                ; Initialise checksum
                tfr     b,a               ; Get length
                adda    #3                ; Add three for address & checksum bytes
                jsr     hex2ou            ; Send length
                bsr     hex2ou_ac         ; Send length to ACIA
                leay    a,y               ; Add byte count to checksum
                pshs    d
                tfr     x,d
                jsr     hex4ou            ; Block start address
                bsr     hex2ou_ac         ; Block start address HI to ACIA
                leay    a,y               ; Add MSB of address to checksum
                tfr     b,a
                bsr     hex2ou_ac         ; Block start address LO to ACIA
                leay    a,y               ; Add LSB of address to checksum
                puls    d
sloop           lda     ,x+
                leay    a,y               ; Add byte to checksum
                jsr     hex2ou            ; Payload bytes
                bsr     hex2ou_ac         ; Payload bytes to ACIA
                decb                      ; Decrement byte counter
                bne     sloop
                tfr     y,d               ; Get checksum
                tfr     b,a               ; Get LSB
                coma                      ; Complement checksum
                jsr     hex2ou            ; Checksum
                bsr     hex2ou_ac         ; Checksum to ACIA
                jsr     crlf
                lda     #cr
                jsr     t1ou
                lda     #lf
                jsr     t1ou
                puls    b                 ; Restore B
                rts

; HEX1OU_AC --- print a single hex digit to the ACIA
; Entry: 4 bit value in A
; Exit:  registers unchanged
hex1ou_ac       pshs    a
                anda    #$0f
                ora     #$30              ; 0..9 OK
                cmpa    #$39              ; ASCII 9
                bls     h1ac
                adda    #7                ; A..F
h1ac            jsr     t1ou
                puls    a,pc

; HEX2OU_AC
; Entry: 8 bit value in A
; Exit:  registers unchanged
hex2ou_ac       pshs    a
                asra
                asra
                asra
                asra
                bsr     hex1ou_ac         ; Print high nybble...
                puls    a
                bsr     hex1ou_ac         ; then low nybble
                rts
                
; TCMD --- monitor 'T' command: test ACIA output
tcmd            ldx     #monmsg           ; X->monitor sign-on message
t1              lda     ,x+               ; Get character
                beq     t2
                jsr     vduchar
                jsr     t1ou
                bra     t1
t2              rts

; VCMD --- monitor 'V' command: show VDU character set
vcmd            ldx     #vdubuf           ; Save VDU RAM
                jsr     vdusave
                lda     #ctrl_l           ; Clear the screen
                jsr     vduchar
                clra                      ; Start with ASCII zero
                clrb
                ldx     #vram+lm          ; Start in top LH corner of VDU
vloop           sta     b,x               ; Store byte in VDU RAM
                incb                      ; Write into every other byte
                incb
                cmpb    #32               ; Start a new row
                blo     v1
                clrb
                leax    vramstride,x      ; Move X pointer down one row
v1              inca                      ; Next ASCII character
                bne     vloop             ; Loop for all 256 ASCII codes
                jsr     getkey            ; Wait for a key press
                ldx     #vdubuf           ; Restore VDU RAM
                jmp     vdurestore        ; Put video RAM back again

; WCMD --- monitor 'W' command: draw a box on the VDU
wcmd            lda     #1                ; X or column
                ldb     #2                ; Y or row
                ldx     #32               ; Width or ncols
                ldy     #10               ; Height or nrows
                ldu     #box3             ; Box-drawing char set
                jsr     vdubox            ; Draw box on VDU
                rts

; XCMD --- monitor 'X' command: draw nested boxes on the VDU
xcmd            lda     #8                ; X or column
                ldb     #2                ; Y or row
                ldx     #32               ; Width or ncols
                ldy     #12               ; Height or nrows
                ldu     #box1             ; Box-drawing char set
                jsr     vdubox            ; Draw box on VDU
                inca
                incb
                leax    -2,x
                leay    -2,y
                leau    8,u               ; Point to next block of 8 chars, i.e. box2
                jsr     vdubox            ; Draw box on VDU
                inca
                incb
                leax    -2,x
                leay    -2,y
                leau    8,u               ; Point to next block of 8 chars, i.e. box3
                jsr     vdubox            ; Draw box on VDU
                inca
                incb
                leax    -2,x
                leay    -2,y
                leau    8,u               ; Point to next block of 8 chars, i.e. box4
                jsr     vdubox            ; Draw box on VDU
                inca
                incb
                leax    -2,x
                leay    -2,y
                leau    8,u               ; Point to next block of 8 chars, i.e. box5
                jsr     vdubox            ; Draw box on VDU
                rts

; YCMD --- monitor 'Y' command: print a 16-bit random integer
ycmd            jsr     rnd16             ; Get a 16-bit random number
                jsr     hex4ou
                rts

; ZCMD --- monitor 'Z' command: start the Matrix display hack
zcmd            jmp     matrixhack        ; Jump into other ROM

; VDUBOX --- draw box on the VDU
; Entry: A=col, B=row, X=ncols, Y=nrows, U=boxchars
; Exit:  registers unchanged
vdubox          pshs    a,b,x,y,u         ; Save registers
                clr     boxcol            ; Zero the high-order byte
                sta     boxcol+1          ; Remember that the 6809
                clr     boxrow            ; is big-endian
                stb     boxrow+1
                stx     boxncols          ; X and Y are 16-bit anyway
                sty     boxnrows
                lda     #vramstride       ; VDU stride
                mul
                addd    #vram+lm          ; Add screen base address
                addd    boxcol            ; Add column number
                tfr     d,x               ; Address into X
                stx     boxtladdr         ; Save for later
                
                ldb     boxrow+1          ; Get starting row
                addb    boxnrows+1        ; Add box height (LSB only)
                lda     #vramstride
                mul
                addd    #vram+lm          ; Add screen base address
                addd    boxcol            ; Add column offset
                tfr     d,y               ; Address of bottom row into Y
                sty     boxbladdr         ; Save for later

                lda     4,u               ; Get top-left char
                sta     ,x                ; Store top left corner
                lda     6,u               ; Get bottom-left char
                sta     ,y                ; Store bottom-left corner

                tfr     x,d               ; Address back into D
                addd    boxncols          ; Add box width
                tfr     d,x               ; Address back into X again
                stx     boxtraddr         ; Save for later

                tfr     y,d               ; Address back into D
                addd    boxncols          ; Add box width
                tfr     d,y               ; Address back into Y again

                lda     5,u               ; Get top-right char
                sta     ,x                ; Store top right corner
                lda     7,u               ; Get bottom-right char
                sta     ,y                ; Store bottom-right corner

                ldx     boxtladdr         ; X points to top row
                ldy     boxbladdr         ; Y points to bottom row
                leax    1,x               ; Skip one byte
                leay    1,y
                ldb     boxncols+1        ; Loop counter
                decb
vbcols          lda     0,u               ; Get top row character
                sta     ,x+               ; Store in top row
                lda     1,u               ; Get bottom row character
                sta     ,y+               ; Store in bottom row
                decb
                bne     vbcols

                ldx     boxtladdr         ; X points to left column
                ldy     boxtraddr         ; Y points to right column
                leax    vramstride,x      ; Skip one row down
                leay    vramstride,y
                ldb     boxnrows+1        ; Loop counter
                decb
vbrows          lda     2,u               ; Get left col character
                sta     ,x                ; Store in left column
                lda     3,u               ; Get right col character
                sta     ,y                ; Store in right column
                leax    vramstride,x      ; Next row down
                leay    vramstride,y
                decb
                bne     vbrows

                puls    a,b,x,y,u,pc
                
; Data for box-drawing tests ('X' command)
box1            fcb     topch,botch,lftch,rghch,tlch,trch,blch,brch
box2            fcb     blkch,blkch,blkch,blkch,blkch,blkch,blkch,blkch
box3            fcb     blkch,chqch,lftch,chqch,$E9,  $08,  blch, $B0
box4            fcb     $94,  $94,  $95,  $95,  $E8,  $E8,  $E8,  $E8
box5            fcb     $83,  $84,  $8C,  $8B,  $CC,  $CD,  $CB,  $CE

; Data for 48x32 pixel bitmap
                include "splash.asm"

; PUTLIN_NS
; Entry: X->string, U contains return address
; Exit:  X modified, other registers unchanged
;putlin_ns       tfr     d,s               ; Save A and B in stack pointer
;putlin_ns2      lda     ,x+               ; Fetch char
;                beq     putlin_ns1        ; Test for '\0'
;                ???                       ; Print character
;                bra     putlin_ns2
;putlin_ns1      tfr     s,d               ; Get saved A and B back from stack pointer
;                jmp     ,u                ; Special return via U
                
                org     uk101reset
reset           orcc    #%01010000        ; Disable interrupts
                lds     #ramtop           ; Set up initial stack pointer
 if HD6309
                ldmd    #$01              ; Switch into 6309 native mode
 endif
                clra
                clrb
 if HD6309
                tfr     d,w
 endif
                tfr     d,x
                tfr     d,y
                tfr     d,u
                tfr     a,dp              ; Set up Direct Page register

; ACIARST
; Reset a 6850 ACIA and select divide-by-16 mode
; without calling a subroutine and hence using the stack
                ldd     #$0311
                sta     acias             ; Store $03: master rest
                stb     acias             ; Store $11: divide-by-16
                
; Clear UK101 screen
                ldx     #vram
 if HD6309
                ldy     #aspace           ; Y->an ASCII space
                ldw     #vramsz           ; W contains size of video RAM
                tfm     y,x+
 else
                lda     #sp               ; A contains an ASCII space
                ldy     #vramsz           ; Y contains size of video RAM
clrscn          sta     ,x+
                leay    -1,y
                bne     clrscn
 endif
                
; Draw box around screen for video setup
                ldx     #vram+lm          ; X points to top row
                ldy     #vram+lm          ; Y points to column one
                ldb     #vdurows
boxloop         lda     #botch            ; Bottom row
                sta     15*vramstride,x
                lda     #topch            ; Top row
                sta     ,x+
                lda     #botch            ; Bottom row
                sta     15*vramstride,x
                lda     #topch            ; Top row
                sta     ,x+
                lda     #botch            ; Bottom row
                sta     15*vramstride,x
                lda     #topch            ; Top row
                sta     ,x+
                lda     #lftch            ; Col one
                sta     ,y                ; Write into column one
                lda     #rghch            ; Col 48
                sta     47,y              ; Write into column 48
                leay    vramstride,y      ; Move Y down to next row
                decb
                bne     boxloop
                
                lda     #tlch             ; Place the four corner characters separately
                sta     vram+lm
                lda     #trch
                sta     vram+lm+47
                lda     #blch
                sta     botrow+lm
                lda     #brch
                sta     botrow+lm+47

; Initialise cursor position
                ldx     #vram+lm
                clr     crsrpos           ; Initial cursor pos = 0
                stx     crsrrow
                
; Display sign-on message
                ldx     #rstmsg
                jsr     prtmsg

; ROM checksum
                ldy     #monrom           ; Y->start of monitor ROM
                clra                      ; Start with D=0
                clrb
romloop         addb    ,y+               ; Add one ROM byte into the checksum
                adca    #0
                cmpy    #0                ; See if we've reached the top of ROM yet
                bne     romloop           ; Exit when Y wraps around
                cmpd    #0                ; Correct sum should be 0
                bne     romerr
                ldx     #romokmsg         ; ROM OK
                jsr     prtmsg
                bra     romdone
romerr          ldx     #romerrmsg        ; ROM checksum error
                jsr     prtmsg
                tfr     d,u               ; Save actual checksum in U
                clra
                clrb
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
                ldx     #jsrrtn           ; Initialise I/O vector table
                stx     outvec

; TODO: More hardware initialisation, hardware self-tests

                lda     #rngseed1         ; Seed the random number generator
                sta     rng1
                lda     #rngseed2
                sta     rng2
                lda     #rngseed3
                sta     rng3

                jsr     keyrst            ; Reset the keyboard
                
                jmp     monitor           ; Jump into other ROM
                
intrtn          rti
jsrrtn          rts

                org     $ffb0
; Interrupt jump table
illjmp          jmp     [illvec]          ; Table of indirect jumps to ISRs
swi3jmp         jmp     [swi3vec]
swi2jmp         jmp     [swi2vec]
swijmp          jmp     [swivec]
irqjmp          jmp     [irqvec]
firqjmp         jmp     [firqvec]
nmijmp          jmp     [nmivec]
; I/O jump table
outchar         jmp     [outvec]          ; A few placeholders for
                jmp     [outvec]          ; future use.  Note that jump
                jmp     [outvec]          ; indirect on the 6809 is
                jmp     [outvec]          ; four bytes long
                jmp     [outvec]
                jmp     [outvec]
                jmp     [outvec]
                jmp     [outvec]
                jmp     [outvec]
; ROM vectors
ill             fdb     illjmp            ; Reserved by Motorola
swi3            fdb     swi3jmp
swi2            fdb     swi2jmp
firq            fdb     firqjmp
irq             fdb     irqjmp
swi             fdb     swijmp
nmi             fdb     nmijmp
                fdb     reset
