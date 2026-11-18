#!/usr/bin/env python3
"""Check two frames of the finale's ripple-out.

Usage: checkrip.py FRAME1.pgm FRAME2.pgm

Each frame must be the finale's 92 x 22 cells (the PGM header's cell
layout), its lit lines must start at six or more places, a character
apart (the wave moves each line by R2), and the lines' starts must
differ between the two frames (the wave moves). The plain finale's
lines start at three places, 11, 12 and 27, so it fails. Exits 1 on a failure.
"""
import sys


def starts(path):
    d = open(path, 'rb').read().split(b'\n', 4)
    cells = d[1].split()
    w, h = map(int, d[2].split())
    px = d[4]
    if (int(cells[6]), int(cells[7])) != (92, 22):
        return None
    out = []
    for y in range(h):
        row = px[y * w:(y + 1) * w]
        xs = [x for x in range(w) if row[x]]
        if xs:
            out.append((y, xs[0] // 8))
    return out


def main():
    got = [starts(p) for p in sys.argv[1:3]]
    if None in got:
        print('FAIL the ripple-out: not the finale\'s 92 x 22 cells')
        return 1
    places = [sorted(set(x for _, x in s)) for s in got]
    if min(len(p) for p in places) < 6:
        print('FAIL the ripple-out: the lines start at %s' % places)
        return 1
    if got[0] == got[1]:
        print('FAIL the ripple-out: the wave did not move')
        return 1
    print('ok   the ripple-out: the lines start at %s and %s characters' % (places[0], places[1]))
    return 0


if __name__ == '__main__':
    sys.exit(main())
