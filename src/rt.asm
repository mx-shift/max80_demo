; The real-time part: a 160 x 112 bitmap drawn anew every frame,
; 60 frames a second, under two rows of text, where a sphere of dots
; spins and bounces.
;
; The window is raced like the pictures, but its code is the
; framebuffer: tools/wingen.py makes it at WIN in B2 as LD HL,nn and
; PUSH HL, and a dot is a bit in an LD's operand. The CRTC shows 16
; rows, 128 lines: two rows of text, then the window's 14. The window's
; code runs from line 8, writing row 2's glyphs, to line 119, and jumps
; through 1006h to the part's work routine, in workvec. From then until
; the next frame's line 0 the display enable stays low, about 43000 T:
; the work routine draws the next frame, in RAM only, then rt_sync waits
; for line 0 and counts its way to line 8.

; Lobo's 264-line frame, 33 rows of 8 lines, 16 shown, the picture in
; the middle of the screen
crtab2:	db	119, 40, 77, 6, 32, 0, 16, 23, 0, 7, 20h, 0, 0, 0, 0, 0

DOT_FRAMES	equ	600		; 10 seconds, then the pictures again
GRAV		equ	40		; down, 1/256 line a frame a frame
FLOOR		equ	WH-31		; the lowest centre: the sphere's foot on the floor
SPIN		equ	2		; angle a frame, 256 a turn

; Into the real-time layout, the title at HL: the CRTC, the text's
; letters in font RAM 2, rows 0 and 1, B2 at 8000h, the window clear
rt_enter:
	push	hl
	ld	hl,crtab2
	call	crtset
	ld	a,VL_FONT2|VL_WIDE
	ld	(VLATCH),a
	ld	hl,textfont
	ld	de,FONTWIN
	ld	bc,64*8
	ldir
	ld	a,VL_FONT|VL_WIDE
	ld	(VLATCH),a
	pop	hl			; rows 0 and 1, the even cells
	ld	de,VIDLO
	ld	b,40
.text:	ld	a,(hl)
	inc	hl
	sub	20h
	or	80h
	ld	(de),a
	inc	de
	ld	(de),a
	inc	de
	djnz	.text
	ld	a,PIO_B2
	ld	(PIODA),a
	; every operand in the window to 0: 112 lines of 10 words, the
	; first operand 11 bytes into a line's 50
	ld	hl,WIN+11
	ld	c,8*WROWS
.wline:	ld	b,10
.word:	ld	(hl),0
	inc	hl
	ld	(hl),0
	inc	hl
	inc	hl
	inc	hl
	djnz	.word
	ld	de,50-40
	add	hl,de
	dec	c
	jr	nz,.wline
	ret

; Wait for the picture's end: the display enable low for longer than a
; line's blank
rt_wait_end:
.wlow:	ld	a,(SYSFLG)
	add	a,a
	jp	m,.wlow
	ld	b,8
.still:	ld	a,(SYSFLG)
	add	a,a
	jp	m,.wlow
	djnz	.still
	ret

; The window's code ends here, through 1006h
rt_work:
	ld	hl,(workvec)
	jp	(hl)

dots_start:
	ld	sp,STACK
	ld	hl,dtitle
	call	rt_enter
	ld	hl,0			; nothing to wipe
	ld	(elist),hl
	ld	hl,dots_work
	ld	(workvec),hl
	ld	hl,DOT_FRAMES
	ld	(rtleft),hl
	jp	rt_sync

; The dots. The stack is the wipe list: each dot's byte is pushed as it
; is drawn, from 10000h down, and popped and cleared the next frame.
dots_work:
	ld	sp,STACK
	call	rt_wait_end
	ld	hl,0
	ld	sp,(elist)
	or	a
	sbc	hl,sp
	srl	h
	rr	l
	ld	b,l
	ld	a,b
	or	a
	jr	z,.wiped
.wipe:	pop	hl
	ld	(hl),0
	djnz	.wipe
.wiped:	ld	sp,0

	; move: the spin, then the bounce in 8.8 lines
	ld	a,(theta)
	add	a,SPIN
	ld	(theta),a
	ld	hl,(vely)
	ld	de,GRAV
	add	hl,de
	ex	de,hl			; DE the speed
	ld	hl,(posy)
	add	hl,de
	ld	a,h
	cp	FLOOR
	jr	c,.air
	ld	a,FLOOR*2-1		; bounce: as far up again as it went past
	sub	h
	ld	h,a
	ld	a,l
	cpl
	ld	l,a
	ld	(posy),hl
	ld	hl,0			; and the speed turned round
	or	a
	sbc	hl,de
	ld	(vely),hl
	ld	(BEEP),a		; and a beep on the floor
	jr	.moved
.air:	ld	(posy),hl
	ld	(vely),de
.moved:	ld	a,(posy+1)
	ld	(.cy+1),a

	; draw: each ring's dots, from its first dot's angle round
	ld	ix,rings
	ld	b,RINGS
.ring:	ld	h,(ix+0)		; the ring's x page
	ld	d,(ix+1)		; its dots
	ld	e,(ix+2)		; the angle between them
	ld	a,(theta)
	add	a,(ix+3)
	ld	l,a
.dot:	ld	a,(hl)			; x
	inc	h
	exx
	ld	c,a
	exx
	ld	a,(hl)			; y from the centre
	dec	h
.cy:	add	a,0			; the centre's line
	cp	WH
	jr	nc,.skip		; out of the window
	exx
	ld	b,a
	and	7			; the dot's byte: o = (x and F8h) or (y and 7)
	ld	l,a
	ld	a,c
	and	0F8h
	or	l
	ld	l,a
	ld	h,OFSL			; its place in a row's block
	ld	e,(hl)
	inc	h
	ld	d,(hl)
	ld	l,b
	ld	h,YBL			; and the row's block
	ld	a,(hl)
	inc	h
	ld	h,(hl)
	ld	l,a
	add	hl,de
	ld	d,MASK
	ld	e,c
	ld	a,(de)
	or	(hl)
	ld	(hl),a
	push	hl			; to wipe next frame
	exx
.skip:	ld	a,l
	add	a,e
	ld	l,a
	dec	d
	jr	nz,.dot
	inc	ix
	inc	ix
	inc	ix
	inc	ix
	djnz	.ring
	ld	(elist),sp

	ld	hl,(rtleft)		; the part's time up?
	dec	hl
	ld	(rtleft),hl
	ld	a,h
	or	l
	jp	z,finale_start		; then the finale

; Wait for line 0, count to line 7's blank, and race from line 8. If
; the work ran late, into the next frame's picture, wait for that
; picture's end first, and lose a frame rather than the count.
rt_sync:
	ld	sp,STACK
.late:	ld	b,9			; low for 9 polls, 378 T: past the picture
.blank:	ld	a,(SYSFLG)
	add	a,a
	jp	m,.inpic
	djnz	.blank
	jr	.w0
.inpic:	ld	a,(SYSFLG)		; in a picture: wait for a long low
	add	a,a
	jp	m,.inpic
	jr	.late
.w0:	ld	a,(SYSFLG)
	add	a,a
	jp	p,.w0
	ld	b,7
.wl:	ld	a,(SYSFLG)
	add	a,a
	jp	m,.wl
.wh:	ld	a,(SYSFLG)
	add	a,a
	jp	p,.wh
	djnz	.wl
.wl7:	ld	a,(SYSFLG)
	add	a,a
	jp	m,.wl7
	jp	WIN

; The CRTC's 16 registers from HL
crtset:	ld	b,0
.next:	ld	a,b
	ld	(CRTREG),a
	ld	a,(hl)
	ld	(CRTBYT),a
	inc	hl
	inc	b
	ld	a,b
	cp	16
	jr	nz,.next
	ret

dtitle:	db	"     MAXIMUM-80     "
	db	" REAL TIME 160 X 112"

theta:	db	0
posy:	dw	30*256			; the centre's line, 8.8
vely:	dw	0
elist:	dw	0			; the wipe list's bottom, 0 when empty
rtleft:	dw	0			; frames left in the part
workvec:
	dw	dots_work

	include	"../build/rings.inc"
textfont:
	incbin	"../build/font.bin", 20h*8, 64*8	; ASCII 20h-5Fh
