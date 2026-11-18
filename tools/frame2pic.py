#!/usr/bin/env python3
"""Which picture a frame from the emulator shows.

Usage: frame2pic.py FRAME.pgm PICTURE.pbm [PICTURE.pbm ...]

FRAME.pgm is a frame saved by the emulator's -p. The raced bitmap is
read back from it, 160 x 216 picture dots, each 2 frame dots wide, from
the first picture cell the header names. Prints the name of the
picture it matches dot for dot, or the nearest and how many dots
differ. Exits 1 when none matches.
"""
import os
import sys

W, H = 160, 216


def read_frame(path):
    data = open(path, 'rb').read()
    lines = data.split(b'\n', 4)
    cells = lines[1].split()            # "# cells x0 y0 cw ch cols rows ..."
    x0, y0 = int(cells[2]), int(cells[3])
    w, h = map(int, lines[2].split())
    px = lines[4]
    return [[px[(y0 + y) * w + x0 + 2 * x] != 0 for x in range(W)] for y in range(H)]


def read_pbm(path):
    parts = open(path, 'rb').read().split(maxsplit=3)
    bits = parts[3]
    return [[bits[y * 20 + x // 8] >> (7 - x % 8) & 1 == 1 for x in range(W)] for y in range(H)]


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    try:
        frame = read_frame(sys.argv[1])
    except (IndexError, ValueError):
        print('no raced picture in the frame')
        return 1
    best = None
    for p in sys.argv[2:]:
        pic = read_pbm(p)
        bad = sum(frame[y][x] != pic[y][x] for y in range(H) for x in range(W))
        if best is None or bad < best[0]:
            best = (bad, p)
    name = os.path.basename(best[1])
    if best[0]:
        print('%s nearest, %d dots differ' % (name, best[0]))
        return 1
    print(name)
    return 0


if __name__ == '__main__':
    sys.exit(main())
