; Raster bars, the opening: three shaded bars move up and down
; behind a big MAX-80 made of character cells, the letters showing the
; bars turned over, under two lines of text. No CRTC tricks: 40 wide
; columns of 8-line rows, 25 rows, 200 lines.
;
; Every background cell shows glyph 01h and every cell of a big letter
; glyph 02h. Line y of the picture shows row y and 7 of each, so while
; the beam draws line y the CPU writes row (y+1) and 7 of both for line
; y+1: two bytes a line, and each of the 200 lines has a pattern of its
; own. The bars' levels for every line are worked out in the blank,
; into LEVT, a level 0 to 8 a line, and PATB turns a level into a dither
; byte, a different one on odd lines.

crbars:	db	119, 80, 97, 6, 32, 0, 25, 29, 0, 7, 20h, 0, 0, 0, 0, 0

BARS_FRAMES	equ	420		; 7 seconds
G_BG		equ	01h		; the background's glyph
G_BIG		equ	02h		; the big letters'

bars_start:
	ld	sp,STACK
	ld	hl,crbars
	call	crtset
	ld	a,VL_FONT2|VL_WIDE	; the text's letters into font RAM 2
	ld	(VLATCH),a
	ld	hl,textfont
	ld	de,FONTWIN
	ld	bc,64*8
	ldir
	ld	a,VL_FONT|VL_WIDE
	ld	(VLATCH),a
	ld	hl,FONTWIN		; glyphs 00h-02h blank to start
	ld	b,24
.g:	ld	(hl),0
	inc	hl
	djnz	.g

	ld	hl,0			; every cell the background
.fill:	ld	a,G_BG
	call	vpoke
	inc	hl
	inc	hl
	ld	de,-25*80
	push	hl
	add	hl,de
	pop	hl
	jr	nc,.fill

	ld	ix,bigtxt		; the big letters, 6 of 5 x 7
	ld	c,0			; the letter
.let:	ld	b,0			; the row
.lrow:	ld	a,(ix+0)
	ld	(.bits+1),a
	ld	e,0			; the column in the letter
.lcol:
.bits:	ld	a,0
	add	a,a
	ld	(.bits+1),a
	jr	nc,.off
	push	bc
	push	de
	ld	a,c			; cell column 2 + 6 c + e, row 9 + b
	add	a,a
	add	a,c
	add	a,a
	add	a,2
	add	a,e
	ld	l,a
	ld	h,0
	add	hl,hl			; 2 bytes a wide cell
	push	hl
	ld	a,b
	add	a,9
	ld	l,a
	ld	h,0
	add	hl,hl			; times 80
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	d,h
	ld	e,l
	add	hl,hl
	add	hl,hl
	add	hl,de
	pop	de
	add	hl,de
	ld	a,G_BIG
	call	vpoke
	pop	de
	pop	bc
.off:	inc	e
	ld	a,e
	cp	5
	jr	nz,.lcol
	inc	ix
	inc	b
	ld	a,b
	cp	7
	jr	nz,.lrow
	inc	c
	ld	a,c
	cp	6
	jr	nz,.let

	ld	hl,btext		; the text lines: offset, then 0-ended
.tline:	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,d
	or	e
	jr	z,.tdone
.tch:	ld	a,(hl)
	inc	hl
	or	a
	jr	z,.tline
	push	hl
	sub	20h
	or	80h
	ex	de,hl
	call	vpoke
	inc	hl
	inc	hl
	ex	de,hl
	pop	hl
	jr	.tch
.tdone:
	ld	hl,BARS_FRAMES
	ld	(rtleft),hl

bars_loop:
	call	rt_wait_end
	ld	hl,bph			; the bars move
	ld	a,(hl)
	add	a,2
	ld	(hl),a
	inc	hl
	ld	a,(hl)
	add	a,3
	ld	(hl),a
	inc	hl
	ld	a,(hl)
	add	a,5
	ld	(hl),a
	ld	hl,LEVT			; the levels: 0, then each bar's, the
	ld	de,LEVT+1		; higher where they cross
	ld	bc,BLINES-1
	ld	(hl),0
	ldir
	ld	ix,bph
	ld	b,3
.bar:	push	bc
	ld	l,(ix+0)
	ld	h,high BSIN
	ld	e,(hl)			; the bar's top line
	ld	d,high LEVT
	ld	hl,PROF
	ld	b,BARH
.bl:	ld	a,(de)
	cp	(hl)
	jr	nc,.bk
	ld	a,(hl)
	ld	(de),a
.bk:	inc	e
	inc	l
	djnz	.bl
	inc	ix
	pop	bc
	djnz	.bar

	ld	c,0			; line 0's rows, in the blank
	call	brow
.w0:	ld	a,(SYSFLG)		; line 0 starts
	add	a,a
	jp	p,.w0
	ld	c,1
.line:	call	brow			; the next line's rows
.wh:	ld	a,(SYSFLG)		; and its start
	add	a,a
	jp	m,.wh
.wl:	ld	a,(SYSFLG)
	add	a,a
	jp	p,.wl
	inc	c
	ld	a,c
	cp	BLINES
	jr	nz,.line

	ld	hl,(rtleft)
	dec	hl
	ld	(rtleft),hl
	ld	a,h
	or	l
	jp	z,split_start
	jr	bars_loop

; The rows for line C: row C and 7 of glyph 01h, the line's dither byte,
; and of glyph 02h, the same turned over
brow:	ld	h,high LEVT
	ld	l,c
	ld	a,(hl)
	add	a,a
	ld	b,a
	ld	a,c
	and	1
	or	b
	ld	l,a
	ld	h,high PATB
	ld	b,(hl)
	ld	a,c
	and	7
	or	G_BG*8
	ld	l,a
	ld	h,high FONTWIN
	ld	(hl),b
	ld	a,l
	add	a,8			; glyph 02h's row
	ld	l,a
	ld	a,b
	cpl
	ld	(hl),a
	ret

; Video RAM offset HL and HL+1, both cells of a wide one, to A. 400h
; and on through the window. Keeps BC, DE, HL.
vpoke:	push	de
	push	hl
	ld	d,a
	ld	a,h
	cp	4
	jr	nc,.hi
	ld	a,d
	ld	de,VIDLO
	add	hl,de
	ld	(hl),a
	inc	hl
	ld	(hl),a
	pop	hl
	pop	de
	ret
.hi:	ld	a,VL_VIDEO|VL_WIDE
	ld	(VLATCH),a
	ld	a,d
	ld	de,FONTWIN-400h
	add	hl,de
	ld	(hl),a
	inc	hl
	ld	(hl),a
	ld	a,VL_FONT|VL_WIDE
	ld	(VLATCH),a
	pop	hl
	pop	de
	ret

; M A X - 8 0, then I U, 5 x 7, bit 7 the left
bigtxt:	db	88h, 0D8h, 0A8h, 0A8h, 88h, 88h, 88h
	db	70h, 88h, 88h, 0F8h, 88h, 88h, 88h
	db	88h, 88h, 50h, 20h, 50h, 88h, 88h
	db	00h, 00h, 00h, 0F8h, 00h, 00h, 00h
	db	70h, 88h, 88h, 70h, 88h, 88h, 70h
	db	70h, 88h, 98h, 0A8h, 0C8h, 88h, 70h
	db	70h, 20h, 20h, 20h, 20h, 20h, 70h	; I and U, for the finale
	db	88h, 88h, 88h, 88h, 88h, 88h, 70h

; a line: the offset of its first cell, then the text, 0
btext:	dw	19*80+2*15
	db	"MAXIMUM-80", 0
	dw	21*80+2*7
	db	"A DEMO FOR THE LOBO MAX-80", 0
	dw	0

bph:	db	0, 85, 170		; the bars' angles
