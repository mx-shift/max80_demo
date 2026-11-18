#!/usr/bin/env python3
"""The boot sector's loading message.

Usage: bootmsg.py FONT.bin OUT.inc

The boot ROM never sets up the CRTC or loads a font, so until the
program runs the screen rolls garbage. The boot sector shows a message
first, before it loads the rest. It has room for only the glyphs the
message needs: each letter gets a code from 1 up, code 0 is a space.
Writes OUT.inc: BOOTGLYPHS (8 bytes a code from 1, from FONT.bin, font
RAM 1's image), NBOOTGLYPHS, and the message lines as codes, each line
20 codes, centred, MSGLINES of them.
"""
import sys

LINES = ['GET READY FOR', '', 'SOMETHING AWESOME']
W = 20


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    font = open(sys.argv[1], 'rb').read()
    letters = []
    for line in LINES:
        for ch in line:
            if ch != ' ' and ch not in letters:
                letters.append(ch)
    with open(sys.argv[2], 'w') as f:
        f.write('; made by tools/bootmsg.py, do not edit\n')
        f.write('NBOOTGLYPHS\tequ\t%d\n' % len(letters))
        f.write('MSGLINES\tequ\t%d\n' % len(LINES))
        f.write('BOOTGLYPHS:\n')
        for ch in letters:
            g = font[ord(ch) * 8:ord(ch) * 8 + 8]
            f.write('\tdb\t%s\t; %s\n' % (','.join('0%02Xh' % b for b in g), ch))
        f.write('BOOTMSG:\n')
        for line in LINES:
            line = line.center(W)
            f.write('\tdb\t%s\n' % ','.join(str(0 if ch == ' ' else letters.index(ch) + 1)
                                            for ch in line))


if __name__ == '__main__':
    main()
