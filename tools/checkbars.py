#!/usr/bin/env python3
"""Check two frames of the raster bars.

Usage: checkbars.py FRAME1.pgm FRAME2.pgm

In each, the first wide cell's dots on each of the 200 lines must make
at least 4 different patterns (the bars' shading), and the two frames
must differ there (the bars move). The big letters' cells must be the
background's turned over: at line y, a dot of a letter cell is lit
exactly where the first cell's is not. Exits 1 on a failure.
"""
import sys

LINES = 200


def read(path):
    d = open(path, 'rb').read().split(b'\n', 4)
    c = d[1].split()
    w, _ = map(int, d[2].split())
    return int(c[2]), int(c[3]), w, d[4]


def main():
    cols = []
    bad = 0
    for p in sys.argv[1:3]:
        x0, y0, w, px = read(p)
        bg = [bytes(px[(y0 + y) * w + x0:(y0 + y) * w + x0 + 16]) for y in range(LINES)]
        # a big letter's cell: M's left side, wide cell 2, rows 9 to 15
        lx = x0 + 2 * 16
        inv = all(bytes(px[(y0 + y) * w + lx:(y0 + y) * w + lx + 16])
                  == bytes(255 - b for b in bg[y]) for y in range(72, 128))
        kinds = len(set(bg))
        ok = kinds >= 4 and inv
        print('%s %s: %d patterns down the screen, letters turned over: %s'
              % ('ok  ' if ok else 'FAIL', p, kinds, inv))
        bad |= not ok
        cols.append(bg)
    if cols[0] == cols[1]:
        print('FAIL the bars did not move')
        bad = 1
    return bad


if __name__ == '__main__':
    sys.exit(main())
