; The raced bitmap: a 160 x 216 picture on a machine with no
; bitmap mode. The CRTC is set for 40 columns of 8-line rows, 27 rows.
; Every row shows 20 glyphs, even rows codes 00h-13h, odd rows codes
; 20h-33h. The frame code (tools/racegen.py) rewrites the glyphs of the
; next row while the beam draws this one, so each row has glyphs of its
; own. Interrupts stay off: nothing may take the CPU during a frame.

; Lobo's 264-line frame from 33 rows of 8 lines, 216 of them in the
; picture, 40 characters across centred where Lobo's 80 are
crtab:	db	119, 40, 77, 6, 32, 0, 27, 29, 0, 7, 20h, 0, 0, 0, 0, 0
CRTN	equ	$-crtab

main:	jp	bars_start		; the bars first, then the pictures

pics_start:
	di
	ld	sp,STACK
	ld	a,PIO_A2
	ld	(PIODA),a
	call	crtinit
	call	fontclr
	call	rowsinit
	ld	a,VL_FONT|VL_WIDE
	ld	(VLATCH),a
	ld	hl,seqtab-3		; so the first frame starts the sequence
	ld	(fseq),hl
	xor	a
	ld	(fhold),a
	jp	frame_done

; The CRTC from crtab
crtinit:
	ld	hl,crtab
	ld	b,0
.next:	ld	a,b
	ld	(CRTREG),a
	ld	a,(hl)
	ld	(CRTBYT),a
	inc	hl
	inc	b
	ld	a,b
	cp	CRTN
	jr	nz,.next
	ret

; Both font RAMs to 0
fontclr:
	ld	a,VL_FONT
	call	.clr
	ld	a,VL_FONT2
.clr:	ld	(VLATCH),a
	ld	hl,FONTWIN
	ld	de,FONTWIN+1
	ld	bc,3FFh
	ld	(hl),0
	ldir
	ret

; Video RAM: row r is 40 bytes at r * 40, cell c (two bytes, the even
; one shown) holds code (r and 1) * 20h + c. Rows 0-25 and the start of
; 26 are in video RAM 000h-3FFh, the rest through the window at 400h.
rowsinit:
	ld	hl,VIDLO
	ld	c,0			; row
.row:	ld	b,0			; byte in the row
.col:	ld	a,b
	srl	a
	bit	0,c
	jr	z,.even
	or	20h
.even:	ld	(hl),a
	inc	hl
	ld	a,h			; past video RAM 3FFh: on in the window
	cp	high (VIDLO+400h)
	jr	nz,.in
	ld	a,VL_VIDEO
	ld	(VLATCH),a
	ld	hl,FONTWIN
.in:	inc	b
	ld	a,b
	cp	40
	jr	nz,.col
	inc	c
	ld	a,c
	cp	27
	jr	nz,.row
	ld	a,VL_FONT
	ld	(VLATCH),a
	ret

; The frame code jumps here after the last row's glyphs, with the beam
; in row 25 or 26. Wait for the vertical blank, a low display enable
; that outlasts a line's blank (about 107 T), then start the next frame.
frame_done:
	ld	sp,STACK
.wlow:	ld	a,(SYSFLG)
	add	a,a
	jp	m,.wlow
	ld	b,8			; 8 polls of 42 T, 336 T low
.still:	ld	a,(SYSFLG)
	add	a,a
	jp	m,.wlow
	djnz	.still

	; in the vertical blank, about 14000 T to spare
	ld	a,(fhold)		; frames left on this picture, less 1:
	sub	1			; 0 is the last, up to 254
	jr	nc,.same
	ld	hl,(fseq)		; the next line of the sequence
	ld	de,3
	add	hl,de
	ld	de,seqend
	or	a
	sbc	hl,de
	add	hl,de
	jp	nc,dots_start		; the pictures are done: the real-time parts
	ld	(fseq),hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	(fpic),de
	ld	(fbase),de
	ld	a,(hl)			; the frames; bit 7: in turn with the
	ld	c,a			; next picture, for twice as many
	and	7Fh
	bit	7,c
	jr	z,.one
	add	a,a
.one:	ld	b,a
	ld	a,c
	and	80h
	ld	(fpair),a
	ld	a,b
	dec	a
	jr	.hold
.same:	ld	b,a			; a pair: the other one this frame
	ld	a,(fpair)
	or	a
	jr	z,.nop
	ld	hl,(fpic)
	ld	de,(fbase)
	or	a
	sbc	hl,de
	ex	de,hl			; HL the first
	jr	nz,.set
	ld	de,PICSIZE
	add	hl,de
.set:	ld	(fpic),hl
.nop:	ld	a,b
.hold:	ld	(fhold),a

	; the picture's bank to 8000h, then point each row block at the next
	ld	hl,(fpic)
	ld	a,(hl)
	ld	(PIODA),a
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	push	de			; where it starts
	ld	b,NROWS
.patch:	ld	e,(hl)			; a block's JP operand
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,(hl)			; gets the next block's address
	ld	(de),a
	inc	hl
	inc	de
	ld	a,(hl)
	ld	(de),a
	inc	hl
	djnz	.patch
	pop	hl
	jp	(hl)

fseq:	dw	seqtab-3		; the sequence line showing
fpic:	dw	0
fbase:	dw	0			; a pair's first picture
fpair:	db	0			; nonzero while a pair shows
fhold:	db	0
