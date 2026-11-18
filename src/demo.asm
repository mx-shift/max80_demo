; Maximum-80, a graphics demo for the stock MAX-80. MIT license,
; LICENSE. Boots
; with no OS. The output is the boot sector (512 bytes), then the
; program it loads to 1000h. The frame code made by tools/racegen.py is
; loaded into the banks at 8000h.

	include	"hw.inc"
	include	"../build/frames.inc"
	include	"../build/rt.inc"
	include	"boot.asm"		; file offset 0, runs at 0400h
	org	1000h			; file offset 200h
	jp	main
	jp	frame_done		; 1003h, where the frame code ends
	jp	rt_work			; 1006h, where the window's code ends
	include	"race.asm"
	include	"rt.asm"
	include	"bars.asm"
	include	"split.asm"
	include	"finale.asm"
	include	"../build/frametab.inc"
seqend:
	include	"../build/bars.inc"
	include	"../build/split.inc"
	align	256
LEVT:	ds	256			; the bars: a level for each line
PROG_END:

PROGSEC	equ	(PROG_END-1000h+511)/512
	assert	PROG_END <= POOL
	assert	POOL_END <= STACK - 100h
