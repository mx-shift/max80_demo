; The finale: overscan, 92 x 22 cells of 11 lines, 736 x 242 dots, to
; the edges of the tube, and the opening's raster bars across all of
; it, a bookend.
;
; The cells of rows 1-9 show glyph 80h, the bars, round the big
; MAXIMUM-80's (81h, the bars turned over); the border is 01h, stripes
; that move; below, on black so it reads, the closing lines are typed
; out one by one. At the end it ripples away (rip_start). The bars stay
; in rows 1-9: a sweep over the text would make it hard to read. Line y
; shows row y mod 11 of
; 80h and 81h, so while the beam draws a line the CPU writes the next
; line's row of both, as the opening does with 8-line rows; rows 8-10
; are in font RAM 2's second list, so KADR gives each row's address.
; Only rows 0-9 are raced, 110 lines; the rest of the picture is free
; for the bars' levels and a letter every other frame, and the 22 blank
; lines for the border every 4th frame and line 0's rows.

crover:	db	77h, 92, 103, 06h, 23, 0, 22, 22, 0, 10, 20h, 0, 0, 0, 0, 0
FIN_FRAMES	equ	1200		; 20 seconds: 8 were too short to read
FW		equ	92		; cells across
FH		equ	22		; rows
FLINES		equ	242
G_FBG		equ	80h		; the bars
G_FBIG		equ	81h		; the big letters
FTOP		equ	11		; the bars from row 1 (line 11), within rows 1-9
FBLINES		equ	110		; rows 0-9 raced, the bars' rows and the border's top

finale_start:
	ld	sp,STACK
	call	rt_wait_end		; the blank, then line 0: R4 23 written
.w0:	ld	a,(SYSFLG)		; with the row counter at 0, not past it,
	add	a,a			; or the counter runs on to 127 and the
	jp	p,.w0			; screen rolls for 5 frames
	ld	hl,crover
	call	crtset
	call	fontclr
	ld	a,VL_FONT		; the letters at their ASCII codes, and
	ld	(VLATCH),a		; the border's stripes at 01h
	ld	hl,textfont
	ld	de,FONTWIN+20h*8
	ld	bc,64*8
	ldir
	ld	hl,stripes
	ld	de,FONTWIN+8
	ld	bc,8
	ldir

	ld	hl,0			; the bars, the border on the edge cells
.cell:	push	hl			; row = HL / 92 by subtraction
	ld	b,0
	ld	de,FW
.div:	or	a
	sbc	hl,de
	jr	c,.got
	inc	b
	jr	.div
.got:	add	hl,de			; HL the column
	ld	a,b
	or	a
	jr	z,.edge
	cp	FH-1
	jr	z,.edge
	ld	a,l
	or	a
	jr	z,.edge
	cp	FW-1
	jr	z,.edge
	ld	a,b			; inside: the bars in rows 1-9, else blank
	cp	10
	ld	a,G_FBG
	jr	c,.put
	ld	a,20h
	jr	.put
.edge:	ld	a,01h
.put:	pop	hl
	call	vset
	inc	hl
	ld	de,-FW*FH
	push	hl
	add	hl,de
	pop	hl
	jr	nc,.cell

	ld	ix,bigname		; MAXIMUM-80 in 5 x 7 cells, rows 2-8
	ld	c,0			; the letter
.let:	ld	a,(ix+0)		; its bitmap, 7 bytes in bigtxt
	ld	l,a
	add	a,a
	add	a,a
	add	a,a
	sub	l
	ld	e,a
	ld	d,0
	ld	hl,bigtxt
	add	hl,de
	ld	b,0			; the row
.lrow:	ld	a,(hl)
	inc	hl
	push	hl
	push	bc
	ld	e,a
	ld	d,0			; the column in the letter
.lcol:	sla	e
	jr	nc,.off
	push	de
	push	bc
	ld	a,b			; offset (2 + row) * 92 + 16 + 6 c + d
	add	a,2
	ld	l,a
	push	de
	ld	de,FW
	call	mul8
	pop	de
	ld	a,c
	add	a,a
	add	a,c
	add	a,a
	add	a,16
	add	a,d
	ld	e,a
	ld	d,0
	add	hl,de
	ld	a,G_FBIG
	call	vset
	pop	bc
	pop	de
.off:	inc	d
	ld	a,d
	cp	5
	jr	nz,.lcol
	pop	bc
	pop	hl
	inc	b
	ld	a,b
	cp	7
	jr	nz,.lrow
	inc	ix
	inc	c
	ld	a,c
	cp	10
	jr	nz,.let

	ld	hl,FINALE		; the typing starts at the first line
	ld	(fptr),hl
	ld	hl,0FFFFh
	ld	(fdst),hl
	ld	hl,LEVT			; no bars yet
	ld	de,LEVT+1
	ld	bc,255
	ld	(hl),0
	ldir
	ld	hl,FIN_FRAMES
	ld	(rtleft),hl

fin_loop:
	call	rt_wait_end		; the blank, 22 lines: the border and
	ld	hl,(rtleft)		; line 0's rows only
	ld	a,l
	and	3
	jr	nz,.nb
	ld	a,(FONTWIN+8)		; the border's stripes every 4th frame
	ld	hl,FONTWIN+9
	ld	de,FONTWIN+8
	ld	bc,7
	ldir
	ld	(FONTWIN+15),a
.nb:	ld	a,VL_FONT2		; the bars' rows from here on
	ld	(VLATCH),a
	ld	c,0
	ld	b,0
	call	frow
.w0:	ld	a,(SYSFLG)		; line 0 starts
	add	a,a
	jp	p,.w0
	ld	c,1			; C the next line, B its row of 11
	ld	b,1
.line:	call	frow
.wh:	ld	a,(SYSFLG)
	add	a,a
	jp	m,.wh
.wl:	ld	a,(SYSFLG)
	add	a,a
	jp	p,.wl
	inc	b
	ld	a,b
	cp	11
	jr	nz,.k
	ld	b,0
.k:	inc	c
	ld	a,c
	cp	FBLINES
	jr	nz,.line
	ld	a,VL_FONT
	ld	(VLATCH),a

	; below the bars' rows, the rest of the picture is free: the bars
	; for the next frame, last frame's cleared, moved, drawn again
	ld	ix,fbars
	ld	b,3
.bar:	ld	a,(ix+3)		; last frame's top
	ld	l,a
	ld	h,high LEVT
	push	bc
	ld	b,BARH
.clr:	ld	(hl),0
	inc	l
	djnz	.clr
	ld	a,(ix+0)
	add	a,(ix+6)		; each its own speed
	ld	(ix+0),a
	ld	l,a
	ld	h,high BSIN		; 0-176 scaled to 0-74: x / 2 - x / 16 - x / 64
	ld	a,(hl)
	srl	a
	ld	e,a
	srl	a
	srl	a
	srl	a
	ld	d,a
	srl	a
	srl	a
	neg
	add	a,e
	sub	d
	add	a,FTOP
	ld	(ix+3),a
	ld	e,a
	ld	d,high LEVT
	ld	hl,PROF
	ld	b,BARH
.bl:	ld	a,(de)			; the higher of the bar and what is there
	cp	(hl)
	jr	nc,.bk
	ld	a,(hl)
	ld	(de),a
.bk:	inc	e
	inc	l
	djnz	.bl
	pop	bc
	inc	ix
	djnz	.bar
	ld	hl,(rtleft)		; a letter every other frame
	bit	0,l
	call	z,ftype
	ld	hl,(rtleft)
	dec	hl
	ld	(rtleft),hl
	ld	a,h
	or	l
	jp	z,rip_start		; it ripples away
	jp	fin_loop

; Line C's rows, row B of 11: glyph 80h the line's dither byte, 81h the
; same turned over. Keeps BC.
frow:	ld	h,high LEVT
	ld	l,c
	ld	a,(hl)
	add	a,a
	ld	e,a
	ld	a,c
	and	1
	or	e
	ld	l,a
	ld	h,high PATB
	ld	e,(hl)
	ld	a,b
	add	a,a
	add	a,low KADR
	ld	l,a
	ld	h,high KADR
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a
	ld	(hl),e
	ld	a,l
	add	a,8
	ld	l,a
	ld	a,e
	cpl
	ld	(hl),a
	ret

; The next letter of FINALE onto the screen: a line is its offset, its
; letters and 0; FFFFh ends them
ftype:	ld	hl,(fdst)
	ld	a,h
	and	l
	inc	a
	jr	nz,.ch			; in a line
	ld	hl,(fptr)		; the next line's offset
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,d
	and	e
	inc	a
	ret	z			; all typed
	inc	hl
	ld	(fptr),hl
	ld	(fdst),de
	ret
.ch:	ld	de,(fptr)
	ld	a,(de)
	or	a
	jr	nz,.put
	inc	de			; the line's end
	ld	(fptr),de
	ld	hl,0FFFFh
	ld	(fdst),hl
	ret
.put:	inc	de
	ld	(fptr),de
	call	vset
	inc	hl
	ld	(fdst),hl
	ret

; The ripple-out: after the finale's 20 seconds, its text read,
; the whole picture ripples away for 2.5 seconds, then round again. Each
; line gets its own R2, 103 plus a sine 128 lines long moving 2 lines a
; frame, -1 to +1 characters, then -2 to +2 from RIP_BIG frames on.
; The bars hold still. An R2
; written during a line moves the next, so each line's is
; written while the beam draws the one before. In the raced lines 0-109
; it comes from RTAB, made during the lines below in the frame before;
; below, each line works out its own.
RIP_FRAMES	equ	150
RIP_BIG		equ	105		; frames left when the wave grows
RTAB		equ	LEVT+128	; lines 0-109's R2s, after their levels

rip_start:
	ld	c,0			; the levels as dither bytes, once
.cv:	ld	l,c
	ld	h,high LEVT
	ld	a,(hl)
	add	a,a
	ld	e,a
	ld	a,c
	and	1
	or	e
	ld	e,a
	ld	d,high PATB
	ld	a,(de)
	ld	(hl),a
	inc	c
	ld	a,c
	cp	FBLINES
	jr	nz,.cv
	xor	a
	ld	(wph),a
	ld	(wamp),a
	ld	c,0			; the first frame's R2s
.rt:	ld	a,c
	and	127
	ld	l,a
	ld	h,high WAVE
	ld	a,(hl)
	ld	l,c
	set	7,l
	ld	h,high LEVT
	ld	(hl),a
	inc	c
	ld	a,c
	cp	FBLINES
	jr	nz,.rt
	ld	hl,RIP_FRAMES
	ld	(rtleft),hl

rip_loop:
	call	rt_wait_end		; the blank: the border, line 0's rows
	ld	a,2			; and R2 for the whole frame
	ld	(CRTREG),a
	ld	hl,(rtleft)
	ld	a,l
	and	3
	jr	nz,.nb
	ld	a,(FONTWIN+8)
	ld	hl,FONTWIN+9
	ld	de,FONTWIN+8
	ld	bc,7
	ldir
	ld	(FONTWIN+15),a
.nb:	ld	a,VL_FONT2
	ld	(VLATCH),a
	ld	c,0
	ld	b,0
	call	rrow
.w0:	ld	a,(SYSFLG)		; line 0 starts
	add	a,a
	jp	p,.w0
	ld	c,1			; C the next line, B its row of 11
	ld	b,1
.line:	call	rrow
	ld	a,c			; its R2, before this line's hsync
	or	128
	ld	l,a
	ld	h,high LEVT
	ld	a,(hl)
	ld	(CRTBYT),a
.wh:	ld	a,(SYSFLG)
	add	a,a
	jp	m,.wh
.wl:	ld	a,(SYSFLG)
	add	a,a
	jp	p,.wl
	inc	b
	ld	a,b
	cp	11
	jr	nz,.k
	ld	b,0
.k:	inc	c
	ld	a,c
	cp	FBLINES
	jr	nz,.line
	ld	a,VL_FONT
	ld	(VLATCH),a
	ld	a,(wph)			; D the wave's place, E the size
	ld	d,a
	ld	a,(wamp)
	ld	e,a
.lo:	ld	a,c			; line C's R2, then next frame's for
	add	a,d			; line C - 110
	and	127
	or	e
	ld	l,a
	ld	h,high WAVE
	ld	a,(hl)
	ld	(CRTBYT),a
	ld	a,c
	sub	FBLINES
	cp	FBLINES
	jr	nc,.nr
	ld	b,a
	add	a,d
	add	a,2
	and	127
	or	e
	ld	l,a
	ld	a,(hl)
	ld	l,b
	set	7,l
	ld	h,high LEVT
	ld	(hl),a
.nr:
.lh:	ld	a,(SYSFLG)
	add	a,a
	jp	m,.lh
.ll:	ld	a,(SYSFLG)
	add	a,a
	jp	p,.ll
	inc	c
	ld	a,c
	cp	FLINES
	jr	nz,.lo
	ld	a,(RTAB)		; line 241: line 0's, for the blank's
	ld	(CRTBYT),a		; hsyncs
	ld	a,d
	add	a,2
	ld	(wph),a
	ld	hl,(rtleft)
	dec	hl
	ld	(rtleft),hl
	ld	a,l
	cp	RIP_BIG
	jr	nz,.nbig
	ld	a,128
	ld	(wamp),a
.nbig:	ld	a,h
	or	l
	jp	z,main			; round again
	jp	rip_loop

; Line C's rows, row B of 11, from LEVT's dither bytes. Keeps BC.
rrow:	ld	l,c
	ld	h,high LEVT
	ld	e,(hl)
	ld	a,b
	add	a,a
	add	a,low KADR
	ld	l,a
	ld	h,high KADR
	ld	a,(hl)
	inc	l
	ld	h,(hl)
	ld	l,a
	ld	(hl),e
	ld	a,l
	add	a,8
	ld	l,a
	ld	a,e
	cpl
	ld	(hl),a
	ret
wph:	db	0
wamp:	db	0

; HL = L * DE, L small. Keeps C.
mul8:	ld	b,l
	ld	hl,0
	inc	b
.m:	dec	b
	ret	z
	add	hl,de
	jr	.m

; the big letters: indexes into bigtxt, M A X I M U M - 8 0
bigname:	db	0, 1, 2, 6, 0, 7, 0, 3, 4, 5
stripes:	db	0C3h, 87h, 0Fh, 1Eh, 3Ch, 78h, 0F0h, 0E1h
fbars:	db	0, 85, 170		; the bars' angles
	db	0, 0, 0			; their tops last frame
	db	2, 3, 5			; their speeds
fptr:	dw	0
fdst:	dw	0
