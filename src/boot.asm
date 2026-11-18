; The boot sector. Track 0 sector 0, loaded by the boot ROM to
; 0400h and run there with the I/O block at 0000h, IY = MLATCH and AF'
; as the ROM's READ wants them. It puts up a message, then reads the
; rest of the disk in order,
; one sector a call: the program to 1000h and the shared frame code to
; 3400h in A1, then up to three 32K banks of frame code to 8000h in A2,
; B1 and B2. Then it moves the I/O
; block to 7000h and starts the program. tools/mkdisk.py sets the
; sectors a track at offset 2.

	org	0400h
boot:	jr	bstart
bspt:	db	17			; sectors a track
	assert	bspt == 0402h

bstart:	di
	ld	sp,0B00h		; RAM900, bank A whatever the PIO shows

	; first a message, while the rest loads: the boot ROM leaves the
	; CRTC unset and the font RAM as it powered up
	ld	hl,bcrt			; 40 columns of 8-line rows, 24 shown
	ld	b,0
.crt:	ld	a,b
	ld	(B_CRTREG),a
	ld	a,(hl)
	ld	(B_CRTBYT),a
	inc	hl
	inc	b
	ld	a,b
	cp	16
	jr	nz,.crt
	ld	hl,B_VIDLO		; the screen blank, code 0
	ld	de,B_VIDLO+1
	ld	bc,24*40-1
	ld	(hl),0
	ldir
	ld	hl,BOOTMSG		; the message from row 10, each code
	ld	de,B_VIDLO+10*40	; in both cells of a wide one
	ld	c,MSGLINES
.line:	ld	b,20
.char:	ld	a,(hl)
	inc	hl
	ld	(de),a
	inc	de
	ld	(de),a
	inc	de
	djnz	.char
	dec	c
	jr	nz,.line
	ld	a,04h|VL_WIDE		; the window on font RAM 1: glyph 0 blank,
	ld	(B_VLATCH),a		; then the message's letters
	ld	hl,0
	ld	b,8
.blank:	ld	(hl),0
	inc	hl
	djnz	.blank
	ld	hl,BOOTGLYPHS
	ld	de,8
	ld	bc,NBOOTGLYPHS*8
	ldir
	ld	a,VL_WIDE		; the window back on the ROM, for READ
	ld	(B_VLATCH),a

	ld	de,0			; track
	ld	b,1			; sector
	ld	ix,segs
bseg:	ld	a,(ix+1)		; which chunk shows at 8000h, 0 ends
	or	a
	jr	z,bdone
	ld	a,(ix+0)		; sectors in this part, maybe none
	or	a
	jr	z,bskip
	ld	c,a
	ld	a,(ix+1)
	ld	(B_PIODA),a
	ld	l,(ix+2)
	ld	h,(ix+3)
bload:	push	bc
	push	de
	ld	c,b			; first and last sector the same
	xor	a			; head 0
	call	ROMREAD			; HL comes back past the sector
	pop	de
	pop	bc
	inc	b
	ld	a,(bspt)
	cp	b
	jr	nz,bnext
	ld	b,0			; next track, from sector 0
	inc	de
bnext:	dec	c
	jr	nz,bload
bskip:	inc	ix
	inc	ix
	inc	ix
	inc	ix
	jr	bseg

bdone:	ld	a,VL_FONT		; the I/O block to 7000h
	ld	(B_VLATCH),a
	ld	(VLATCH),a		; and its RAM copy at the new place
	jp	main

bcrt:	db	119, 40, 77, 6, 32, 0, 24, 28, 0, 7, 20h, 0, 0, 0, 0, 0
	include	"../build/bootmsg.inc"

segs:	db	PROGSEC, PIO_A2
	dw	1000h
	db	SEC_POOL, PIO_A2
	dw	POOL
	db	SEC_A2, PIO_A2
	dw	8000h
	db	SEC_B1, PIO_B1
	dw	8000h
	db	SEC_B2, PIO_B2
	dw	8000h
	db	SEC_WIN, PIO_B2		; the real-time window, after the pictures in B2
	dw	WIN
	db	0, 0

	assert	$ <= 0600h
	block	0600h-$,0
