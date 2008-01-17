; UK109.asm -- 6809 monitor ROM for UK101
; Copyright (c) 2004 BJ, Froods Software Development

; Modification:
; 13/10/2004 BJ  Initial coding
; 14/10/2004 BJ  Added rudimentary 'vduchar' routine
; 16/10/2004 BJ  Added ROM checksum
; 17/10/2004 BJ  Added initial RAM test
; 18/10/2004 BJ  Added 100us delay routine and keyboard polling
; 21/10/2004 BJ  Improved keyboard polling, added cursor, VDU scrolling
; 22/10/2004 BJ  Introduced hex monitor routines
; 25/10/2004 BJ  Hex monitor '@' command
; 27/10/2004 BJ  Added screen save/restore and random number generator
; 27/10/2004 BJ  Added Matrix display hack
; 15/03/2006 BJ  Changed reset message to reduce size of text in EPROM
; 15/03/2006 BJ  Altered VDU code to use jump table
; 23/03/2006 BJ  Added VDU test pattern
; 17/01/2008 BJ  Fixed bug introduced by VDU jump table code

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

                org     $0
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
matdly          rmb     48                ; Delay in ms for this column
mattime         rmb     48                ; Current state of timer
matcnt          rmb     48                ; Counter
matstat         rmb     48                ; State for this column
vdubuf          rmb     16*48             ; VDU save/restore buffer

pad             equ     $ff               ; Padding unused EPROM space

; Hardware adresses
ramtop          equ     $0fff             ; Last byte of 4K 2114 RAM
vram            equ     $d000             ; UK101 video RAM
botrow          equ     $d3c0             ; Address of bottom row of VDU
vramsz          equ     $0400             ; 1k byte of video RAM
vramstride      equ     64
vducols         equ     48                ; Number of VDU columns
lm              equ     13                ; VDU left margin
keymatrix       equ     $df00             ; Keyboard matrix
acias           equ     $f000             ; MC6850 ACIA status/control register
aciad           equ     $f001             ; Data register

monrom          equ     $f800

uk101reset      equ     $fe00

                org     monrom
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
                
vctrl_g         nop                       ; CTRL_G: bell
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
scroll          pshs    a,b,x,y,u
                ldx     #vram+vramstride+lm
                ldy     #vram+lm
                ldb     #15
scrlrow         lda     #24               ; vducols / 2
scrlch          ldu     ,x++              ; Load from lower row...
                stu     ,y++              ; Store into upper row
                deca
                bne     scrlch
                leax    16,x
                leay    16,y
                decb
                bne     scrlrow
                ldx     #botrow+lm        ; Clear bottom row
                ldu     #$2020            ; Two ASCII spaces
                lda     #24               ; vducols / 2
clrrow          stu     ,x++
                deca
                bne     clrrow
                puls    a,b,x,y,u,pc      ; Restore registers and return

vctrl_k         leax    -vramstride,x     ; CTRL_K: cursor up
                stx     crsrrow
                rts

vctrl_l         pshs    a,y               ; CTRL_L: clear screen
                ldd     #$2020            ; ASCII space in both A and B
                ldx     #vram
                ldy     #vramsz
vcl             std     ,x++
                leay    -2,y
                bne     vcl
                puls    a,y
vctrl_n         ldx     #vram+lm          ; CTRL_N: home cursor
                stx     crsrrow
vctrl_m         clrb                      ; CTRL_M: carriage return
                rts
                
; VDUSAVE --- save video display into memory buffer
; Entry: buffer address in X
vdusave         pshs    a,b,x,y,u
                ldy     #vram+lm          ; 4
                lda     #16               ; 2 vdurows
sav_r           ldb     #24               ; 2 vducols / 2
sav_c           ldu     ,y++              ; 5+3 Load from video RAM
                stu     ,x++              ; 5+3 Store into buffer
                decb                      ; 2
                bne     sav_c             ; 3  
                leay    16,y              ; 4+1 Skip 16 bytes in VRAM
                deca                      ; 2
                bne     sav_r             ; 3   
                puls    a,b,x,y,u,pc
                
; VDURESTORE --- restore video display from buffer in memory
; Entry: buffer address in X
vdurestore      pshs    a,b,x,y,u
                ldy     #vram+lm
                lda     #16               ; vdurows
rest_r          ldb     #24               ; vducols / 2
rest_c          ldu     ,x++              ; Load from buffer
                stu     ,y++              ; Store into video RAM
                decb
                bne     rest_c
                leay    16,y              ; Skip 16 bytes in VRAM
                deca
                bne     rest_r
                puls    a,b,x,y,u,pc
                
; KEYW
; Write a bit-pattern to the keyboard matrix from A
;keyw            coma                      ; Invert bits because the
;                sta     keymatrix         ; key matrix is all active-low
;                coma         
;                rts
                
; KEYRB
; Read the keyboard matrix, result in B
;keyrb           ldb     keymatrix         ; Read the keys...
;                comb                      ; and invert bits
;                rts
                
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
                ldx     #kbmsg            ; Print failure message
                jsr     prtmsg
keyrst1         rts

; POLLKB
; Poll all keys apart from shifts, return scan code in A
pollkb          pshs    b,x
                ldx     #1                ; Scancodes are 1-based
                lda     #kbrow1           ; Start scanning at row 1
pollrow         jsr     keywrb
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

; PRTMSG
; Print message pointed to by X, terminated by zero byte
prtmsg          pshs    a,x               ; Save A and X registers
prtmsg1         lda     ,x+
                beq     prtmsg2
                jsr     vduchar
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
                jsr     vduchar
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
                jsr     vduchar
                lda     #lf
                jsr     vduchar
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
t1ou1           lda     acias             ; Read ACIA status
                anda    #$02              ; Transmit ready?
                beq     t1ou1
                puls    a                 ; Restore A
                sta     aciad             ; Send char
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
                jsr     getkey            ; Get a keystroke
                pshs    a
                lda     chunder           ; Get the character back again
                sta     b,x               ; Write it back into VDU RAM
                puls    a                 ; Restore A
                                          ; Handle CTRL-E editing here
                puls    b,x,pc            ; Restore B, X and return
                
; DLY100U
; Delay for 100us when running with 8MHz clock
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
                
ndly1ms         pshs    x                 ; 7
                ldx     #246              ; 3
ndlyloop        leax    -1,x              ; 5 * 246
                bne     ndlyloop          ; 3 * 246
                puls    x,pc              ; 9

dly1ms2         pshs    a                 ; 6
                lda     #220              ; 2
dlyloop2        deca                      ; 2 * 220
                nop                       ; 2 * 220
                nop                       ; 2 * 220
                bne     dlyloop2          ; 3 * 220
                puls    a,pc              ; 8

; Various message strings
rstmsg          fcb     lf,ctrl_i
                fcc     'UK109 (6809 CPU) V0.1'
                fcb     cr,lf,ctrl_i
                fcc     'Copyright (c) 2004-2006'
                fcb     cr,lf
                fcb     eos

romokmsg        fcb     ctrl_i
                fcc     'ROM checksum OK'
                fcb     eos
romerrmsg       fcb     ctrl_i
                fcc     'ROM checksum error,'
                fcb     eos
memokmsg        fcb     ctrl_i
                fcc     'Memory OK'
                fcb     eos
memfail1        fcb     ctrl_i
                fcc     "RAM test fail1 at $"
                fcb     eos
memfail2        fcb     ctrl_i
                fcc     "RAM test fail2 at $"
                fcb     eos
expmsg          fcc     " expected $"
                fcb     eos
readmsg         fcc     ", read $"
                fcb     eos
                
;adrokmsg        fcc     'Memory Addressing OK'
;                fcb     cr,lf,eos

;adrerrmsg       fcc     'Memory Addressing FAIL'
;                fcb     cr,lf,eos
                
kbmsg           fcb     ctrl_i
                fcc     'Keyboard FAIL'
                fcb     cr,lf,eos

hexdig          fcc     '0123456789ABCDEF'

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

helpmsg         fcc     '6809 Monitor'
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
                jsr     vduchar
                jsr     crlf
monitor         lda     #'>'              ; Monitor command-level prompt
                jsr     vduchar
                jsr     getchar           ; Read command letter from user
                jsr     vduchar
;                cmpa    #42               ; SIM
;                beq     exit              ; SIM
                jsr     toupper
                cmpa    #'@'
                blo     cmderr
                cmpa    #'Z'
                bhi     cmderr
                suba    #'@'
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
atcmd           jsr     hex4in            ; '@' command - open memory for editing
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
atcmd4          nop                       ; Test for hex here
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
gcmd            jsr     hex4in
                jsr     crlf
                jsr     hex4ou
                rts
hcmd            ldx     #helpmsg
                jsr     prtmsg
                rts
icmd            jsr     hex4in
                tfr     d,x
                lda     #','
                jsr     vduchar
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
jcmd            rts
kcmd            rts
lcmd            rts
mcmd            rts
ncmd            rts
ocmd            rts
pcmd            rts
qcmd            rts
rcmd            rts
scmd            rts
;scmd            jsr     hex4in            ; Save
;                tfr     d,x
;                lda     #','
;                jsr     vduchar
;                jsr     hex4in
;                tfr     d,y
;                jsr     crlf
;                ; Send S9 record
;                rts

; sblk --- write a single block of S-Record data
; X: start address, Y: length
;sblk            lda     #'S'
;                jsr     vduchar
;                lda     #'1'
;                jsr     vduchar
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
tcmd            clrb
thang           jsr     ndly1ms           ; 8
                incb                      ; 2
                stb     keymatrix         ; 5
                bra     thang             ; 3 Hang here

ucmd            clrb
uhang           jsr     dly1ms2           ; 8
                incb                      ; 2
                stb     keymatrix         ; 5
                bra     uhang             ; 3 Hang here

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
wcmd            rts
xcmd            rts
ycmd            jsr     rnd16             ; Get a 16-bit random number
                jsr     hex4ou
                rts
zcmd            ldx     #vdubuf           ; Matrix display hack (216 bytes)
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

; KBHIT --- return with carry set if a key is pressed
kbhit           pshs    a,b
                lda     #$ff
                jsr     keywrb
                andcc   #$fe              ; Clear carry bit
                andb    #$fe              ; Ignore caps-lock
                beq     nokbhit
                orcc    #$01              ; Set carry bit
nokbhit         puls    a,b,pc

; RND16 --- generate 16-bit pseudo-random number
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
                
; HEX2IN --- read a two hex digits from the keyboard
; Entry: no parameters
; Exit:  8-bit value in A
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
                jsr     vduchar
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

                org     uk101reset
reset           orcc    #%01010000        ; Disable interrupts
                lds     #ramtop           ; Set up initial stack pointer
;                lda     #3                ; SIM Into CBREAK mode
;                swi                       ; SIM
                clra
                clrb
                tfr     d,x
                tfr     d,y
                tfr     d,u
                tfr     a,dp              ; Set up Direct Page register

; ACIARST
; Reset a 6850 ACIA and select divide-by-16 mode
; without calling a subroutine and hence using the stack
                lda     #$03
                sta     acias
                lda     #$11              ; Divide-by-16 mode
                sta     acias
                
; Clear UK101 screen
                lda     #sp
                ldx     #vram
                ldy     #vramsz
clrscn          sta     ,x+
                leay    -1,y
                bne     clrscn
                
; Draw box around screen for video setup
                ldx     #vram+lm          ; X points to top row
                ldy     #vram+lm          ; Y points to column one
                ldb     #16
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
                clra
                ldx     #vram+lm
                sta     crsrpos
                stx     crsrrow
                
; Display sign-on message
                ldx     #rstmsg
                jsr     prtmsg

; ROM checksum
                ldy     #monrom           ; Y->start of monitor ROM
                ldd     #0                ; Start with D=0
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
                ldd     #0
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
                stx     swi3vec
                stx     swi2vec
                stx     swivec
                stx     irqvec
                stx     firqvec
                stx     nmivec
                ldx     #jsrrtn
                stx     outvec

; TODO: More hardware initialisation, hardware self-tests

                lda     #rngseed1         ; Seed the random number generator
                sta     rng1
                lda     #rngseed2
                sta     rng2
                lda     #rngseed3
                sta     rng3

                jsr     keyrst            ; Reset the keyboard
                
                jmp     monitor
;                lda     #$42
;                jsr     t1ou              ; Send to serial port (300 baud)
                
;loop            jsr     getchar           ; Get a keystroke
;                jsr     hex2ou            ; Print ASCII code in hex
;                pshs    a
;                lda     #$20
;                jsr     vduchar
;                puls    a
;                jsr     vduchar
;                lda     #$20
;                jsr     vduchar
;                bra     loop
                
swi3jmp         jmp     [swi3vec]         ; Table of indirect jumps to ISRs
swi2jmp         jmp     [swi2vec]
swijmp          jmp     [swivec]
irqjmp          jmp     [irqvec]
firqjmp         jmp     [firqvec]
nmijmp          jmp     [nmivec]
intrtn          rti
jsrrtn          rts

                org     $ffe0
outchar         jmp     [outvec]          ; A few placeholders for
                jmp     [outvec]          ; future use.  Note that jump
                jmp     [outvec]          ; indirect on the 6809 is
                jmp     [outvec]          ; four bytes long
; ROM vectors
                fdb     $ffff             ; Reserved by Motorola
swi3            fdb     swi3jmp
swi2            fdb     swi2jmp
firq            fdb     firqjmp
irq             fdb     irqjmp
swi             fdb     swijmp
nmi             fdb     nmijmp
                fdb     reset
