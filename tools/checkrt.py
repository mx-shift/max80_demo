#!/usr/bin/env python3
"""Check a frame of the real-time part.

Usage: checkrt.py FRAME.pgm [FRAME.pgm ...]

Each frame, saved by the emulator's -p, must show the two text rows and
the sphere of dots in the 160 x 112 window below them: 60 to 260 of the
window's dots lit, in one patch no wider or taller than the sphere.
With two or more frames, the sphere must have moved between the first
and the last. Exits 1 on a failure.
"""
import sys

W, H, TOP = 160, 112, 16        # the window, from line 16 of the picture


def dots(path):
    data = open(path, 'rb').read()
    lines = data.split(b'\n', 4)
    cells = lines[1].split()
    x0, y0 = int(cells[2]), int(cells[3])
    w, _ = map(int, lines[2].split())
    px = lines[4]
    text = sum(px[(y0 + y) * w + x0 + 2 * x] != 0 for y in range(TOP) for x in range(W))
    win = {(x, y) for y in range(H) for x in range(W)
           if px[(y0 + TOP + y) * w + x0 + 2 * x]}
    return text, win


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    bad = 0
    got = []
    for p in sys.argv[1:]:
        text, win = dots(p)
        xs = [x for x, _ in win] or [0]
        ys = [y for _, y in win] or [0]
        size = (max(xs) - min(xs), max(ys) - min(ys))
        ok = text > 300 and 60 <= len(win) <= 260 and size[0] <= 80 and size[1] <= 70
        print('%s %s: text %d dots, window %d dots in %d x %d'
              % ('ok  ' if ok else 'FAIL', p, text, len(win), size[0], size[1]))
        bad |= not ok
        got.append(win)
    if len(got) > 1 and got[0] == got[-1]:
        print('FAIL the sphere did not move')
        bad = 1
    return bad


if __name__ == '__main__':
    sys.exit(main())
