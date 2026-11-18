# Maximum-80

Maximum-80 is a graphics demo for the stock MAX-80, a boot disk with no
OS. MIT license, in `LICENSE`. The MAX-80 has no bitmap mode: its screen is 2K
of character codes and 2K of font RAM, 192 glyphs at most. This demo
shows a 160 x 216 bitmap anyway, every dot its own, by rewriting the
font RAM while the beam draws the screen.

What it shows, in a loop:

1. Raster bars, 7 seconds: three shaded bars move behind a big MAX-80
   made of character cells, the letters showing the bars turned over.
2. The split screen, 10 seconds: three CRTC frames in one monitor
   frame. A 40-column logo above, a scroller between that bounces a
   line at a time on its own, a landscape of four layers below, each
   scrolling at its own speed.
3. A ray-traced checkered sphere over a mirror floor, spinning, 14
   pictures at 30 a second, about 9 seconds.
4. Real time: a sphere of 128 dots spins and bounces in a 160 x 112
   bitmap, drawn anew every frame, 60 a second, with a beep on each
   bounce, 10 seconds.
5. The finale, 20 seconds: overscan, 92 x 22 cells to the edges of the
   tube. The opening's raster bars behind a big MAXIMUM-80 shown turned
   over, the closing lines typed out below on black, a border of moving
   stripes. At its end, its text read, the whole picture ripples
   away for 2.5 seconds. Then round again.

While the rest of the disk loads, about 12 seconds, the boot sector
shows "GET READY FOR SOMETHING AWESOME": it sets the CRTC and puts the
message's 15 letters in font RAM itself, as the boot ROM does neither.

## How it works

The CRTC runs 40 columns of 8-line rows, 27 rows, so each row shows 20
cells 16 dots wide. Every row shows the same 20 codes, even rows codes
00h-13h and odd rows 20h-33h, two sets of 20 glyphs in font RAM 1.
While the beam draws a row from one set, the CPU writes the next row's
picture into the other: 160 bytes in the row's 8 scan lines, 20 bytes a
line. So each of the 27 rows has glyphs of its own and the whole
picture is a bitmap.

The CPU and the beam run from the same 15.2 MHz crystal, so a scan line
is exactly 320 T-states. Each line's code starts when the CRTC's
display enable (SYSFLG bit 6) goes high, at the start of the line's
picture, and must end in the same line's blank: 150 to 232 T-states,
which `tools/racegen.py` checks for every line it makes. The writes are
unrolled `LD SP` and `LD rr,nn` / `PUSH rr`, 21 T-states for 2 bytes, or
11 when HL, DE or BC already hold the word. Video and font RAM accesses
stretch the CPU clock by an amount the TRM calls unpredictable (TS-3);
the margin is for that. Interrupts stay off for the whole demo.

A picture is 27 blocks of code, one a row, each ending in a JP that the
vertical blank points at the next. A row that two pictures share is
there once, so the spinning sphere, which changes rows 8 to 25, fits 15
pictures and the still in 99K: a pool in A1 at 2000h and three banks at
8000h, A2, B1 and B2.

## The raster bars and the grey

No CRTC tricks in either. The bars: every background cell shows glyph
01h and every cell of a big letter glyph 02h, and line y shows row
y and 7 of both, so while the beam draws a line the CPU writes the next
line's row of each, two bytes. Each of the 200 lines gets its own
pattern across the screen. The bars' level on every line is worked out
in the blank (`src/bars.asm`, tables from `tools/barsgen.py`).

The grey: the still is two pictures, `greya` and `greyb`, shown in turn,
a frame each. A dot lit in both is white, in one only half bright, in
neither black; the half dots go by a checkerboard, half in each
picture, so the screen does not pulse. The amber phosphor's glow helps
the eye add them. A line of the sequence such as `greya.pbm 120
greyb.pbm` shows a pair.

## The split screen

Rupture and the 40/80 split.
Lobo's 80 x 24 timing and three CRTC frames: band A, 3 rows of logo in
40 columns, 16-line rows, MAXIMUM-80 in a font of its own 13 lines
tall at B8h-BFh, the only glyphs that can be taller than 8;
band B, 2 rows of scroller, also 40 columns;
band C, 13 rows shown, 80 columns, 4 of stars and 9 of landscape, with
the vsync. B and C have 8-line rows (R9 = 7, written in each band's
first lines): their glyphs are in font RAM 1, which has no 9th line,
so 9-line rows put a blank line through every row. The blank
lines of A's adjust (R5 = L) and B's (31 - L) put B anywhere in 31
lines, and L follows a sine: B bounces while A and C stay. Every CRTC write is in a group of two
or three registers just after a counted line starts, done by
character 96 of 120: a longer group ran into the next line, and every
write after it landed a line late, band C's first lines in 40 columns
. VLATCH goes back to 80 columns after band B's last line, before
band C's first. The blank lines have no
rise of the display enable, so the count skips them by itself.

Band B's text and the landscape scroll sideways by turning bits, not by
the CRTC: band B's 80 glyphs a bit a frame with the next letter's
column coming in at the right, and each layer's 8 tiles, which repeat
every 64 dots, at its own speed (near and ground every frame, hills
every second, far every fourth). Unrolled `RL (IX+d)` runs carry the
bit from glyph to glyph. Each is done while what it changes is off the
screen, so nothing tears: B's after band C has started, the far layer
after its own rows, the rest after band C has ended
(`src/split.asm`, glyphs and text from `tools/splitgen.py`).

## The finale

Overscan: 92 cells of
11-line rows, 22 rows, 736 x 242 dots, the hsync moved so the picture
is in the middle. Rows 1-9 carry the opening's raster bars round a big
MAXIMUM-80 in the opening's 5 x 7 cell letters, which show the bars
turned over: rows 0-9, 110 lines, are raced, two glyph rows a line,
and with 11-line rows a line's row can be 8 to 10, in font RAM 2's
second list, so `KADR` gives each row's address. The bars stay out of
the text, which would be hard to read through them. Below,
the closing lines are typed a letter every other frame. The rest of
the picture holds the bars' levels for the next frame, the blank the
border's stripes (`src/finale.asm`, the lines from `tools/splitgen.py`).

The ripple-out: once the 20 seconds are over, every line gets
an R2 of its own, 103 plus a sine 128 lines long moving 2 lines a
frame, -1 to +1 characters, then -2 to +2 after 0.75 seconds, for 2.5
seconds; the bars hold still. Moving text is hard to read, so it only comes once the text is
done. A write to R2 moves the next line, so each line's R2 is
written while the beam draws the line before: in the raced lines 0-109
from `RTAB`, made during the lines below in the frame before, below
that worked out on each line (`rip_loop`, `WAVE` from
`tools/barsgen.py`).

## The real-time part

The window is raced the same way, but its code is the framebuffer.
`tools/wingen.py` makes it at C000h in B2 as one `LD HL,nn` / `PUSH HL`
for every word, no register tricks, and a dot is a bit in an `LD`'s
operand. Drawing writes RAM, not video RAM, so it is not stretched and
its time is exact. The CRTC shows 16 rows: two of text, then the
window's 14. Lines 8 to 119 race the window. From the end of the
picture to the next frame's line 0 the display enable stays low, about
43000 T-states: `src/rt.asm` wipes last frame's dots (their addresses
are on the stack), moves the sphere and draws its dots from per-ring
tables of 256 angles, then waits for line 0 and counts lines to 8. The
work ends near line 240 of 264. If it ever runs late, the sync waits
for the next picture's end and loses one frame, not the count.

## Build and run

The emulator is lobo_max80's. `test.sh` and the commands below take
it from a lobo_max80 checkout beside this repo, or from where `MAX80`
points, with `make` run in its `emu/`. The build reads `font.bin`,
xcpmz80's 8 x 8 font, or the file `FONT` names.

`sh build.sh` needs Python 3 and sjasmplus. It ray-traces the pictures
(`tools/scene.py`, a few seconds on several cores), writes the frame
code and the disks:

- `build/demo.imd`: 8-inch, `../lobo_max80/emu/max80 -B -a build/demo.imd`.
- `build/demo_525.imd`: 5.25-inch, add `-D 1`.

The emulator needs `-B` to show it: without it, it draws each frame
from font RAM as it is at the end, which is the last row's glyphs
everywhere. `-V 3` adds a stand-in for the video access stretch.

`sh test.sh` builds and runs the emulator at several times with `-V 0`,
`3` and `6`, and reads the bitmap back from each frame: it must be one
of the pictures dot for dot. At `-V 8` it breaks. For the real-time
part it checks the text and a sphere of dots that moves
(`tools/checkrt.py`).

## On a real MAX-80

Boot the disk with DIP switches set for the drive (2 for 8-inch, 1 for
5.25-inch).

## Files

- `LICENSE`: MIT.
- `font.bin`: xcpmz80's 8 x 8 font, for the loading message, the
  split screen's text and the real-time part's text.
- `build.sh`, `test.sh`: build, and test in the emulator.
- `src/demo.asm`: the program's layout. `src/boot.asm` the boot sector,
  which loads the program, the pool, the banks and the window.
  `src/race.asm` the pictures' set-up and vertical blank, `src/rt.asm`
  the real-time part. `src/hw.inc` the addresses, with the
  I/O block at 7000h.
- `tools/scene.py`: the ray tracer, pictures as PBM files.
- `tools/sequence.py`: the order and length the pictures show.
- `tools/racegen.py`: pictures to frame code.
- `tools/wingen.py`: the real-time window's code and tables, and the
  sphere's.
- `tools/checkrt.py`: checks a frame of the real-time part.
- `src/finale.asm`: the finale and its ripple-out. `tools/checkfin.py`
  checks two frames of the finale, `tools/checkrip.py` two of the
  ripple-out.
- `src/split.asm`: the split screen. `tools/splitgen.py` its glyphs,
  text and rotation code, `tools/checksplit.py` checks two frames.
- `src/bars.asm`: the raster bars. `tools/barsgen.py` their tables,
  `tools/checkbars.py` checks two frames of them.
- `tools/bootmsg.py`: the loading message's letters and lines, for
  the boot sector.
- `tools/mkdisk.py`: the disks.
- `tools/frame2pic.py`: reads the bitmap back from an emulator frame.
