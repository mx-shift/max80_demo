#!/usr/bin/env python3
"""Tables for the raster bars.

Usage: barsgen.py OUT.inc

PROF: a bar's shading, 24 lines, levels 0 to 8 up to the middle and
down. PATB: for level L, the glyph row byte on even lines at 2 L and on
odd lines at 2 L + 1, an ordered dither from black to solid. BSIN: 256
angles of the bars' travel, 0 to 176, the top line of a 24-line bar on
a 200-line screen. All page aligned.
"""
import math
import sys

BAR = 24
LINES = 200
PAT = [(0x00, 0x00), (0x88, 0x00), (0x88, 0x22), (0xAA, 0x22), (0xAA, 0x55),
       (0xEE, 0x55), (0xEE, 0xBB), (0xFF, 0xBB), (0xFF, 0xFF)]


def rows(name, vals, f):
    f.write('\talign\t256\n%s:\n' % name)
    for i in range(0, len(vals), 16):
        f.write('\tdb\t%s\n' % ','.join(str(v) for v in vals[i:i + 16]))


def main():
    with open(sys.argv[1], 'w') as f:
        f.write('; made by tools/barsgen.py, do not edit\n')
        f.write('BARH\tequ\t%d\n' % BAR)
        f.write('BLINES\tequ\t%d\n' % LINES)
        prof = [round(8 * math.sin(math.pi * (i + 0.5) / BAR)) for i in range(BAR)]
        rows('PROF', prof, f)
        # the finale's: for each of an 11-line row's lines k, the
        # address of glyph 80h's row k in the font RAM 2 window at 7000h,
        # rows 8-10 in the second list; in PROF's page, after it
        f.write('KADR:\n')
        for k in range(11):
            a = 0x7000 + (k if k < 8 else 512 + k - 8)
            f.write('\tdw\t0%04Xh\n' % a)
        rows('PATB', [b for p in PAT for b in p], f)
        # the finale's ripple-out: R2 for a line, 103 plus a sine
        # 128 lines long, -1 to +1 in the first half, -2 to +2 in the second
        rows('WAVE', [103 + round(1.2 * math.sin(2 * math.pi * a / 128)) for a in range(128)]
             + [103 + round(2.2 * math.sin(2 * math.pi * a / 128)) for a in range(128)], f)
        travel = LINES - BAR
        rows('BSIN', [round(travel / 2 + travel / 2 * math.sin(2 * math.pi * a / 256))
                      for a in range(256)], f)


if __name__ == '__main__':
    main()
