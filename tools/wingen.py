#!/usr/bin/env python3
"""The real-time window's code and tables.

Usage: wingen.py OUTDIR

The second part of the demo draws in real time into a 160 x 112 dot
bitmap. As in the raced pictures (racegen.py), the window is raced: the
next row's 20 glyphs are written into font RAM while the beam draws a
row, 20 bytes a scan line. Here the code is the framebuffer: every
word is an `LD HL,nn` / `PUSH HL`, so a dot is a bit in an instruction's
operand, and drawing is a write to RAM, with no video access stretch.

The CRTC shows 16 rows: rows 0 and 1 are text, rows 2 to 15 the window.
Row r's glyphs (2 to 15) are written during row r-1. The block for row
r is 8 lines of code, each a poll for the display enable's rise, LD SP
and 10 words, 50 bytes. The blocks follow each other, and the last ends
with a JP to WORK, in src/rt.asm.

Writes OUTDIR/win.bin, the code, at WIN, and OUTDIR/wintab.bin, the
tables at WTAB, page aligned:

- OFSL, OFSH: for o = (x and F8h) or (y and 7), the dot's byte offset
  in its row's block (o is the byte's place in the row's 160 glyph
  bytes, glyph x / 8 row y and 7).
- YBL, YBH: for y, the address of row y / 8's block.
- MASK: for x, the bit, 80h shifted right by x and 7.
- The sphere: for ring i, page RING + 2 i holds the dot's x for each of
  256 angles round the ring, centre 80, and the next page its y offset
  from the centre.

and OUTDIR/rt.inc, the addresses, and OUTDIR/rings.inc, each ring's
page, dot count (8, 16 or 32) and the angle between its dots.
"""
import math
import os
import sys

FONT = 0x7000
SYSFLG = 0x77E1
WORK = 0x1006           # src/demo.asm's jump table
WIN = 0xC000            # in B2
W = 20                  # bytes across
ROW0 = 2                # the first window row
NROWS = 14              # window rows, 112 lines
CHUNK = 50
BLOCK = 8 * CHUNK

RINGS = 9               # the sphere's rings of dots
RADIUS = 36             # dots, across; up and down it is ASPECT less
ASPECT = 0.807          # a dot's width over its height
TILT = 0.45             # radians, the axis leaning towards us
VIEW = 4.0              # the eye's distance, in radii


def win_code():
    b = bytearray()
    for r in range(ROW0, ROW0 + NROWS):
        base = FONT + (r & 1) * 0x100
        for j in range(8):
            top = WIN + len(b)
            b += bytes([0x3A, SYSFLG & 0xff, SYSFLG >> 8, 0x87, 0xF2, top & 0xff, top >> 8])
            sp = base + 20 * j + 20
            b += bytes([0x31, sp & 0xff, sp >> 8])
            for _ in range(10):
                b += bytes([0x21, 0, 0, 0xE5])  # LD HL,0 / PUSH HL
    b += bytes([0xC3, WORK & 0xff, WORK >> 8])
    return bytes(b)


def offset(o):
    """Byte o of a row's 160 in its block: chunk o / 20 writes o's
    word, the words from the top down"""
    j, p = divmod(o, 20)
    return j * CHUNK + 10 + 4 * ((18 - (p & ~1)) // 2) + 1 + (p & 1)


def sphere():
    """For each ring, 256 angles: x and y offsets and front or back"""
    rings = []
    for i in range(RINGS):
        lat = (i + 0.5) / RINGS * math.pi - math.pi / 2
        xs, ys, vs = [], [], []
        for a in range(256):
            lon = a / 256 * 2 * math.pi
            x = math.cos(lat) * math.sin(lon)
            y = math.sin(lat)
            z = math.cos(lat) * math.cos(lon)
            y, z = y * math.cos(TILT) - z * math.sin(TILT), y * math.sin(TILT) + z * math.cos(TILT)
            s = VIEW / (VIEW + z)        # z towards the back
            xs.append(80 + round(x * s * RADIUS))
            ys.append(round(-y * s * RADIUS * ASPECT) & 0xff)
            vs.append(1 if z < 0 else 0)
        rings.append((xs, ys, vs, math.cos(lat)))
    return rings


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    code = win_code()
    open(os.path.join(out, 'win.bin'), 'wb').write(code)

    wtab = WIN + len(code) + 255 & ~255
    pages = {}
    t = bytearray()

    def page(name, data):
        pages[name] = wtab + len(t)
        t.extend(data)
        t.extend(b'\0' * (256 - len(data)))

    offs = [offset(o) if o < 160 else 0 for o in range(256)]
    page('OFSL', bytes(v & 0xff for v in offs))
    page('OFSH', bytes(v >> 8 for v in offs))
    yb = [WIN + (y // 8) * BLOCK if y < 8 * NROWS else WIN for y in range(256)]
    page('YBL', bytes(v & 0xff for v in yb))
    page('YBH', bytes(v >> 8 for v in yb))
    page('MASK', bytes(0x80 >> (x & 7) for x in range(256)))
    rings = sphere()
    for i, (xs, ys, _, _) in enumerate(rings):
        page('X%d' % i, bytes(xs))
        page('Y%d' % i, bytes(ys))
    open(os.path.join(out, 'wintab.bin'), 'wb').write(bytes(t))
    if wtab + len(t) > 0x10000:
        raise SystemExit('the window and its tables pass FFFFh')

    # the dots: a ring has 8, 16 or 32, as it is long
    counts = [32 if c > 0.95 else 16 if c > 0.6 else 8 for _, _, _, c in rings]
    with open(os.path.join(out, 'rt.inc'), 'w') as f:
        f.write('; made by tools/wingen.py, do not edit\n')
        f.write('WIN\tequ\t0%04Xh\n' % WIN)
        f.write('WINEND\tequ\t0%04Xh\n' % (wtab + len(t)))
        f.write('WTAB\tequ\t0%04Xh\n' % wtab)
        f.write('WROW0\tequ\t%d\n' % ROW0)
        f.write('WROWS\tequ\t%d\n' % NROWS)
        f.write('WH\tequ\t%d\n' % (8 * NROWS))
        f.write('RINGS\tequ\t%d\n' % RINGS)
        for name, addr in pages.items():
            if not (name[0] in 'XY' and name[1:].isdigit()):
                f.write('%s\tequ\t0%02Xh\n' % (name, addr >> 8))
        f.write('NDOTS\tequ\t%d\n' % sum(counts))
        f.write('SEC_WIN\tequ\t%d\n' % ((wtab + len(t) - WIN + 511) // 512))
    with open(os.path.join(out, 'rings.inc'), 'w') as f:
        f.write('; made by tools/wingen.py: a ring\'s x page, its dots and\n')
        f.write('; the angle between them, then its first dot\'s angle\n')
        f.write('rings:\n')
        for i, n in enumerate(counts):
            f.write('\tdb\t0%02Xh,%d,%d,%d\n' % (pages['X%d' % i] >> 8, n, 256 // n, i * 37 & 0xff))
    print('window %d bytes, tables %d, %d dots' % (len(code), len(t), sum(counts)))


if __name__ == '__main__':
    main()
