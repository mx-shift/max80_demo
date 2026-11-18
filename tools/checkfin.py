#!/usr/bin/env python3
"""Check two frames of the overscan finale.

Usage: checkfin.py FRAME1.pgm FRAME2.pgm

Each frame must be 92 x 22 cells (the PGM header's cell layout), with
dots lit in the four corner cells (the border) and in the middle row
of text, and the border must differ between the two frames (its
stripes move). Exits 1 on a failure.
"""
import sys


def read(path):
    d = open(path, 'rb').read().split(b'\n', 4)
    c = [int(v) for v in d[1].split()[2:8]]
    w, _ = map(int, d[2].split())
    return c, w, d[4]


def cell(px, w, x0, y0, cw, ch, col, row):
    return bytes(px[(y0 + row * ch + y) * w + x0 + col * cw + x]
                 for y in range(8) for x in range(cw))


def main():
    borders = []
    bad = 0
    for p in sys.argv[1:3]:
        (x0, y0, cw, ch, cols, rows), w, px = read(p)
        if (cols, rows) != (92, 22):
            print('FAIL %s: %d x %d cells, not 92 x 22' % (p, cols, rows))
            return 1
        corners = [cell(px, w, x0, y0, cw, ch, c, r) for c, r in ((0, 0), (91, 0), (0, 21), (91, 21))]
        text = any(any(cell(px, w, x0, y0, cw, ch, c, 13)) for c in range(20, 70))
        if not all(any(k) for k in corners) or not text:
            print('FAIL %s: corners lit %s, text %s' % (p, [any(k) for k in corners], text))
            bad = 1
        borders.append(b''.join(cell(px, w, x0, y0, cw, ch, c, 0) for c in range(92)))
    if borders[0] == borders[1]:
        print('FAIL the border did not move')
        bad = 1
    if not bad:
        print('ok   92 x 22 cells, the border at all four corners, the text, the stripes moving')
    return bad


if __name__ == '__main__':
    sys.exit(main())
