#!/usr/bin/env python3
"""Check two frames of the split screen part.

Usage: checksplit.py FRAME1.pgm FRAME2.pgm

Band A, the picture's first 48 lines: every lit dot one of a pair (40
columns) and the same in both frames. Band B: found as the first lit
line after band A's; it must be at a different line in the two frames
(it bounces). The landscape, the picture's last 45 lines: some dots
lit, and different in the two frames (its layers move). With 8-line
rows in bands B and C neither has a blank line inside it: band
B's letters are lit on each of their first 14 lines, and the
landscape's last 70 lines have at most 4 blank ones (its layers' own
empty lines; with 9-line rows there are 10). Band C, the last 104
lines: its 4 rows of stars in 80 columns from their first line, so the
stars' line 1, the top of a '*', is runs of 2 dots, not 4 (the
switch from 40 columns landed two lines into band C). Exits 1 on a
failure.
"""
import sys

Y0, LINES = 14, 216


def read(path):
    d = open(path, 'rb').read().split(b'\n', 4)
    w, h = map(int, d[2].split())
    return w, d[4]


def runs(row):
    """The lengths of the runs of lit dots in a line."""
    out, x = [], 0
    while x < len(row):
        if row[x]:
            s = x
            while x < len(row) and row[x]:
                x += 1
            out.append(x - s)
        x += 1
    return out


def main():
    frames = [read(p) for p in sys.argv[1:3]]
    bad = 0
    tops, lands, bands = [], [], []
    for w, px in frames:
        rows = [bytes(px[(Y0 + y) * w:(Y0 + y + 1) * w]) for y in range(LINES)]
        odd = 0
        for row in rows[:48]:
            x = 0
            while x < w:
                if row[x]:
                    s = x
                    while x < w and row[x]:
                        x += 1
                    odd += (x - s) % 2
                x += 1
        bands.append(b''.join(rows[:48]))
        top = next((y for y in range(48, 120) if any(rows[y])), None)
        tops.append(top)
        if top is not None and not all(any(rows[y]) for y in range(top, top + 14)):
            print('FAIL band B has a blank line inside its letters')
            bad = 1
        last = max(y for y in range(LINES) if any(rows[y]))
        blank = [last - y for y in range(last - 70, last) if not any(rows[y])]
        if len(blank) > 4:
            print('FAIL the landscape has blank lines %s lines above its bottom' % blank)
            bad = 1
        lands.append(b''.join(rows[LINES - 45:]))
        c0 = last + 1 - 104
        wide = [r for r in range(4) if any(n != 2 for n in runs(rows[c0 + 8 * r + 1]))]
        if wide:
            print('FAIL band C: star rows %s start in 40 columns' % wide)
            bad = 1
        if odd:
            print('FAIL band A: %d runs of dots not in pairs' % odd)
            bad = 1
    if bands[0] != bands[1]:
        print('FAIL band A changed between the frames')
        bad = 1
    if None in tops or tops[0] == tops[1]:
        print('FAIL band B did not move: first lines %s' % tops)
        bad = 1
    if not any(lands[0]) or lands[0] == lands[1]:
        print('FAIL the landscape is empty or did not move')
        bad = 1
    if not bad:
        print('ok   band A still in 40 columns, band B at lines %s, the landscape moving' % tops)
    return bad


if __name__ == '__main__':
    sys.exit(main())
