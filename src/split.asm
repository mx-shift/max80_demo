; The split screen: three CRTC frames in one monitor frame. Lobo's
; 80 x 24 timing, 264 lines.
;
;   band A  3 rows of 16 lines, 48, a 40-column logo (VLATCH bit 3
;           set) in a font of its own, 16 lines tall
;   gap     L blank lines, A's vertical adjust (R5)
;   band B  2 rows of 8 lines, 16, a 40-column scroller, its own CRTC
;           frame
;   gap     31 - L blank lines, B's adjust
;   band C  13 rows of 8 lines shown of 21, 80 columns: 4 rows of
;           stars, then a landscape of 4 layers; the vsync at its row 17
;
; Bands B and C have 8-line rows (R9 = 7) because their glyphs are in
; font RAM 1, which has no 9th line, so 9-line rows put a blank line
; through every row. Band A has 16-line rows for the
; logo's font at B8h-BFh in font RAM 2, the only glyphs that can be
; taller than 8; its second line's glyphs show 8 lines. R9 is
; written while a band's first rows are drawn, before its first row
; ends.
;
; L follows BOUNCE, so band B bounces a line at a time while A and C
; stay where they are. Band B's text moves sideways by turning the bits
; of its 80 glyphs, a bit a frame, a new column of the message coming in
; at the right; each landscape layer the same over its 8 tiles, at its
; own speed. Every CRTC write is at a counted line: a group of two or
; three registers just after a line starts, over by character 96
; of 120, so srise finds the next line's start; a group that ran to the
; line's end made every write after it a line late. The bounce
; is read before band A, into D and C, to keep the groups short.
; The blank lines have no rises of the display enable, so counting rises
; skips them by itself.

crsplit:	db	77h, 50h, 61h, 06h, 1Bh, 0Ch, 18h, 1Ah, 0, 8, 20h, 0, 0, 0, 0, 0
SPLIT_FRAMES	equ	600		; 10 seconds
SA		equ	0		; the bands' places in video RAM
SB		equ	400
SC		equ	560

split_start:
	ld	sp,STACK
	ld	hl,crsplit
	call	crtset
	call	fontclr
	ld	a,VL_FONT		; font RAM 1: the ground's tiles from
	ld	(VLATCH),a		; 01h, the letters from 61h
	ld	hl,GROUND
	ld	de,FONTWIN+8
	ld	bc,16*8
	ldir
	ld	hl,LETTERS
	ld	de,FONTWIN+61h*8
	ld	bc,NLETTERS*8
	ldir
	ld	a,VL_FONT2		; font RAM 2: the landscape's tiles
	ld	(VLATCH),a
	ld	hl,LAYERS
	ld	de,FONTWIN
	ld	bc,56*8
	ldir
	ld	hl,BIGTOP		; and the logo's font at B8h-BFh, 16
	ld	de,FONTWIN+38h*8	; lines, rows 0-7 and 8-15
	ld	bc,8*8
	ldir
	ld	hl,BIGBOT
	ld	de,FONTWIN+200h+38h*8
	ld	bc,8*8
	ldir
	ld	a,VL_FONT
	ld	(VLATCH),a

	ld	hl,0			; video RAM all blank
.clr:	xor	a
	call	vset
	inc	hl
	ld	a,h
	cp	8
	jr	nz,.clr
	ld	hl,SA+1*80		; band A: the logo's two lines, wide cells
	ld	de,LOGO0
	call	.wline
	ld	hl,SA+2*80
	ld	de,LOGO1
	call	.wline
	ld	hl,SB			; band B: 40 wide cells a row, codes 11h on
	ld	c,11h
	call	.brow
	ld	hl,SB+80
	ld	c,39h
	call	.brow
	ld	hl,SC			; band C: 4 rows of stars, from an LCG
	ld	b,4*80/2
.star:	push	bc
	call	rnd
	ld	c,0
	cp	12
	jr	nc,.sk
	ld	c,C_DOT
	cp	3
	jr	nc,.sk
	ld	c,C_STAR
.sk:	ld	a,c
	call	vset
	inc	hl
	xor	a
	call	vset
	inc	hl
	pop	bc
	djnz	.star
	ld	ix,lrows		; then 9 rows of tiles: each row's base
	ld	b,9			; code, plus the column and 7
.lrow:	push	bc
	ld	c,0
.lcol:	ld	a,c
	and	7
	add	a,(ix+0)
	call	vset
	inc	hl
	inc	c
	ld	a,c
	cp	80
	jr	nz,.lcol
	inc	ix
	pop	bc
	djnz	.lrow

	ld	hl,SCROLLTXT
	ld	(sptr),hl
	xor	a
	ld	(scol),a
	ld	(sframe),a
	ld	(bphase),a
	ld	hl,SPLIT_FRAMES
	ld	(rtleft),hl
	jp	split_loop

.wline:	ld	b,40			; 40 codes from DE into wide cells at HL
.wl:	ld	a,(de)
	inc	de
	call	vpoke
	inc	hl
	inc	hl
	djnz	.wl
	ret
.brow:	ld	b,40			; codes C up into wide cells at HL
.br:	ld	a,c
	call	vpoke
	inc	hl
	inc	hl
	inc	c
	djnz	.br
	ret

lrows:	db	80h, 88h, 90h, 98h, 0A0h, 0A8h, 0B0h, 01h, 09h

; Video RAM offset HL to A, through the window from 400h on. Keeps all
; but A.
vset:	push	de
	push	hl
	ld	d,a
	ld	a,h
	cp	4
	jr	nc,.hi
	ld	a,d
	ld	de,VIDLO
	add	hl,de
	ld	(hl),a
	pop	hl
	pop	de
	ret
.hi:	ld	a,VL_VIDEO
	ld	(VLATCH),a
	ld	a,d
	ld	de,FONTWIN-400h
	add	hl,de
	ld	(hl),a
	ld	a,VL_FONT
	ld	(VLATCH),a
	pop	hl
	pop	de
	ret

rnd:	ld	a,(seed)		; 8-bit LCG, A the next
	ld	e,a
	add	a,a
	add	a,a
	add	a,e
	inc	a
	ld	(seed),a
	ret
seed:	db	17

; CRTC register A = E
wr:	ld	(CRTREG),a
	ld	a,e
	ld	(CRTBYT),a
	ret

; Wait for the next line's picture to start
srise:
.h:	ld	a,(SYSFLG)
	add	a,a
	jp	m,.h
.l:	ld	a,(SYSFLG)
	add	a,a
	jp	p,.l
	ret
srises:	call	srise
	djnz	srises
	ret

split_loop:
	call	rt_wait_end		; band C shown: the lower layers' turn
	call	land
	ld	a,VL_FONT|VL_WIDE	; 40 columns for bands A and B
	ld	(VLATCH),a
	ld	a,(bphase)		; D = L and C = 31 - L, read now: a
	ld	l,a			; group ends early enough in its line
	ld	h,high BOUNCE		; for srise to find the next one's
	ld	d,(hl)			; start
	ld	a,31
	sub	d
	ld	c,a
.w0:	ld	a,(SYSFLG)		; line 0, band A's first
	add	a,a
	jp	p,.w0
	ld	a,4			; A: 3 rows, L lines of adjust, no vsync
	ld	e,2
	call	wr
	ld	a,5
	ld	e,d
	call	wr
	call	srise			; line 1
	ld	a,6
	ld	e,3
	call	wr
	ld	a,7
	ld	e,127
	call	wr
	ld	a,12
	ld	e,high SB
	call	wr
	call	srise			; line 2: A's rows 16 lines
	ld	a,13
	ld	e,low SB
	call	wr
	ld	a,9
	ld	e,15
	call	wr
	ld	b,46			; line 48: band B, 2 rows, 31 - L of adjust
	call	srises
	ld	a,4
	ld	e,1
	call	wr
	ld	a,5
	ld	e,c
	call	wr
	call	srise			; line 49
	ld	a,6
	ld	e,2
	call	wr
	ld	a,7
	ld	e,127
	call	wr
	ld	a,12
	ld	e,high SC
	call	wr
	call	srise			; line 50: B's and C's rows 8 lines
	ld	a,13
	ld	e,low SC
	call	wr
	ld	a,9
	ld	e,7
	call	wr
	ld	b,13			; line 63, band B's last
	call	srises
.w63:	ld	a,(SYSFLG)		; its picture over, 80 columns
	add	a,a			; before band C's first line
	jp	m,.w63
	ld	a,VL_FONT
	ld	(VLATCH),a
	call	srise			; line 64: band C
	ld	a,4			; 21 rows of 8 and 1 line of adjust, so
	ld	e,20			; the frame stays 264 lines
	call	wr
	ld	a,5
	ld	e,1
	call	wr
	call	srise			; line 65
	ld	a,6
	ld	e,13
	call	wr
	ld	a,7
	ld	e,17
	call	wr
	ld	a,12
	ld	e,high SA
	call	wr
	call	srise			; line 66
	ld	a,13
	ld	e,low SA
	call	wr

	call	scroll			; band B is not on the screen now
	call	landfar			; nor, by the time it ends, the far layer
	ld	hl,bphase
	inc	(hl)
	inc	(hl)
	ld	hl,sframe
	inc	(hl)
	ld	hl,(rtleft)
	dec	hl
	ld	(rtleft),hl
	ld	a,h
	or	l
	jp	z,pics_start
	jp	split_loop

; Band B's message a bit to the left, the next column of the next letter
; coming in at the right: 16 scan lines, each the letter's font row
; (line / 2) shifted, 40 cells of 8 bits, through rot16 in 3 runs
scroll:	ld	hl,(sptr)
	ld	a,(hl)
	or	a
	jr	nz,.ch
	ld	hl,SCROLLTXT
	ld	(sptr),hl
	ld	a,(hl)
.ch:	sub	20h			; the letter's font, ASCII 20h-5Fh
	ld	l,a
	ld	h,0
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	de,textfont
	add	hl,de
	ld	(.fnt+1),hl
	ld	c,0			; the scan line
.line:	ld	a,c
	srl	a
.fnt:	ld	hl,0
	add	a,l
	ld	l,a
	jr	nc,.f1
	inc	h
.f1:	ld	a,(scol)		; the column's bit into carry
	ld	b,a
	ld	a,(hl)
	inc	b
.sh:	dec	b
	jr	z,.sd
	add	a,a
	jr	.sh
.sd:	add	a,a
	ex	af,af'
	ld	a,c			; IX at cell 39's byte: code 11h + 39
	and	7			; (or 39h + 39), row and 7
	ld	e,a
	ld	d,0
	ld	ix,FONTWIN+(11h+39)*8
	bit	3,c
	jr	z,.r0
	ld	ix,FONTWIN+(39h+39)*8
.r0:	add	ix,de
	ex	af,af'
	call	rot16			; cells 39-24
	ex	af,af'
	ld	de,-128
	add	ix,de
	ex	af,af'
	call	rot16			; 23-8
	ex	af,af'
	ld	de,-64
	add	ix,de
	ex	af,af'
	call	rot16+8*4		; 7-0: rot16's last 8 RLs, 4 bytes each, (ix-64) on
	inc	c
	ld	a,c
	cp	16
	jr	nz,.line
	ld	a,(scol)
	inc	a
	and	7
	ld	(scol),a
	ret	nz
	ld	hl,(sptr)		; the next letter
	inc	hl
	ld	(sptr),hl
	ret

; The landscape's layers a dot left: near and ground every frame, hills
; every second, far every fourth. A layer's row r, line k: rot8 with IX
; at tile 7's byte, base + 64 r + 56 + k. The far layer goes in the
; picture, after its own rows are shown (landfar, after scroll); the
; others once band C has ended (land), so none is turned while it shows.
landfar:
	ld	a,(sframe)
	and	3
	ret	nz
	ld	a,VL_FONT2
	ld	(VLATCH),a
	ld	ix,FONTWIN+56		; far, 2 rows
	ld	b,2
	call	.layer
	ld	a,VL_FONT
	ld	(VLATCH),a
	ret
.layer:	ld	c,8			; B rows of 8 lines
.k:	call	rot8
	inc	ix
	dec	c
	jr	nz,.k
	ld	de,64-8
	add	ix,de
	djnz	.layer
	ret

land:	ld	a,VL_FONT2
	ld	(VLATCH),a
	ld	a,(sframe)
	and	1
	jr	nz,.nh
	ld	ix,FONTWIN+128+56	; hills, 3 rows
	ld	b,3
	call	landfar.layer
.nh:	ld	ix,FONTWIN+320+56	; near, 2 rows
	ld	b,2
	call	landfar.layer
	ld	a,VL_FONT
	ld	(VLATCH),a
	ld	ix,FONTWIN+8+56		; ground, 2 rows, font RAM 1
	ld	b,2
	jp	landfar.layer

sptr:	dw	0
scol:	db	0
sframe:	db	0
bphase:	db	0
