; The demo's addresses. The I/O block sits at 7000h once booted,
; so the high half, 8000h-FFFFh, is all RAM and can be swapped between
; A2, B1 and B2. The low half is A1: code, tables and the stack.

BLK		equ	7000h
FONTWIN		equ	BLK		; the 1K window, font RAM 1 when VLATCH bits 2-0 = 4
VLATCH		equ	BLK+7DCh
CRTREG		equ	BLK+7E0h
CRTBYT		equ	BLK+7E1h
SYSCLR		equ	BLK+7E0h
SYSFLG		equ	BLK+7E1h	; bit 6 the CRTC's display enable
BEEP		equ	BLK+7F8h
PIODA		equ	BLK+7FCh	; bank select, bits 7-4
MATRIX		equ	BLK+800h
VIDLO		equ	BLK+0C00h	; video RAM 000h-3FFh

VL_FONT		equ	74h		; block at 7000h, window font RAM 1
VL_FONT2	equ	76h		; window font RAM 2
VL_VIDEO	equ	72h		; window video RAM 400h-7FFh
VL_WIDE		equ	08h		; 40 columns, cells 16 dots wide

PIO_A2		equ	40h		; A1 low, A2 high
PIO_B1		equ	80h
PIO_B2		equ	0C0h

; The boot ROM's, while the block is at 0000h
ROMREAD		equ	0003h
B_VLATCH	equ	07DCh
B_CRTREG	equ	07E0h
B_CRTBYT	equ	07E1h
B_VIDLO		equ	0C00h
B_PIODA		equ	07FCh

STACK		equ	6F00h
