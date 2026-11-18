#!/usr/bin/env python3
"""The split screen part's glyphs and text.

Usage: splitgen.py FONT.bin OUT.inc

Font RAM 1: 00h blank, 01h-10h the ground layer's 16 tiles, 11h-60h band
B's scroller, 80 glyphs (row 0 cells 11h-38h, row 1 39h-60h), then from
61h the letters band A's logo needs and the stars. Font RAM 2: 80h-B7h
the landscape's three upper layers, 8 tiles a row: far 2 rows (80h),
hills 3 rows (90h), near 2 rows (A8h). Every layer is 64 dots wide and
repeats, so turning a row's 8 tiles' bits round scrolls it for ever.

Writes OUT.inc: LAYERS (each layer's tiles as glyphs, 8 bytes a glyph,
in code order), GROUND, the letters' glyphs with their codes, band A's
two lines as codes, and SCROLLTXT, the scroller's message in ASCII.
"""
import math
import sys

LOGO = ['MAXIMUM-80', 'THREE CRTC FRAMES IN ONE']

# band A's logo font: MAXIMUM-80's 8 characters, 8 dots wide and
# 13 lines tall, at codes B8h-BFh in font RAM 2, whose glyphs can be 16
# lines; line 0 and lines 14-15 are blank, a gap above the line below
BIG = {
 'M': ["###..###","########","########","##.##.##","##.##.##","##.##.##","##....##",
       "##....##","##....##","##....##","##....##","##....##","##....##"],
 'A': ["..####..",".######.","###..###","##....##","##....##","##....##","########",
       "########","##....##","##....##","##....##","##....##","##....##"],
 'X': ["##....##","###..###",".######.","..####..","..####..","..####..","..####..",
       "..####..","..####..","..####..",".######.","###..###","##....##"],
 'I': ["########","########","...##...","...##...","...##...","...##...","...##...",
       "...##...","...##...","...##...","...##...","########","########"],
 'U': ["##....##"]*10 + ["###..###","########",".######."],
 '-': ["........"]*5 + ["########","########"] + ["........"]*6,
 '8': [".######.","########","##....##","##....##","##....##","########",".######.",
       "########","##....##","##....##","##....##","########",".######."],
 '0': [".######.","########","##....##","##...###","##..####","##.##.##","##.##.##",
       "####..##","###...##","##....##","##....##","########",".######."],
}
BIGCODES = 'MAXIU-80'

SCROLL = ('    A SCROLLER BOUNCING BETWEEN TWO STILL BANDS, '
          'EACH BAND ITS OWN CRTC FRAME ... 40 COLUMNS ABOVE, 80 BELOW ... '
          'A LANDSCAPE IN FOUR LAYERS, EACH AT ITS OWN SPEED ... '
          'NO BITMAP MODE ON THIS MACHINE, ONLY 192 GLYPHS ...    ')


FINALE = [
    (11, 'A DEMO FOR THE LOBO MAX-80, ON THE STOCK MACHINE'),
    (13, 'A 160 X 216 BITMAP, RACED INTO FONT RAM A SCAN LINE AT A TIME'),
    (14, 'DOTS IN REAL TIME, 60 FRAMES A SECOND, IN A WINDOW WHOSE CODE IS ITS PICTURE'),
    (15, 'RASTER BARS FROM GLYPH ROWS WRITTEN ON EVERY LINE, AS ABOVE'),
    (16, 'THREE CRTC FRAMES IN ONE MONITOR FRAME, EACH BAND ITS OWN'),
    (17, 'AND NOW 92 X 22 CHARACTERS, EDGE TO EDGE'),
    (19, 'THANKS FOR WATCHING'),
]


def layer(h, fn):
    """A 64 x h layer from fn(x, y), as 8 tiles x (h / 8) rows of glyphs"""
    img = [[1 if fn(x, y) else 0 for x in range(64)] for y in range(h)]
    out = []
    for r in range(h // 8):
        for t in range(8):
            for k in range(8):
                y = 8 * r + k
                out.append(sum(img[y][8 * t + b] << (7 - b) for b in range(8)))
    return out


def far(x, y):
    top = 6 + 4 * math.sin(2 * math.pi * x / 64) + 2 * math.sin(2 * math.pi * 3 * x / 64 + 1)
    return y >= top and (y <= top + 1 or (x + 2 * y) % 4 == 0)


def hills(x, y):
    top = 8 + 5 * math.sin(2 * math.pi * x / 64 + 2) + 2 * math.sin(2 * math.pi * 2 * x / 64)
    return y >= top and (y <= top + 1 or (x + y) % 2 == 0)


def near(x, y):
    # four trees of different heights on a solid strip at the bottom
    if y >= 13:
        return True
    for cx, ht in ((6, 9), (22, 12), (38, 7), (54, 11)):
        if y >= 13 - ht and abs(x - cx) <= (y - (13 - ht)) // 2:
            return True
    return False


def ground(x, y):
    return y == 0 or (x + 2 * y) % 8 < 2


def main():
    font = open(sys.argv[1], 'rb').read()
    letters = []
    for line in LOGO[1:]:
        for ch in line:
            if ch != ' ' and ch not in letters:
                letters.append(ch)
    letters += ['.', '*']                  # the stars
    if 0x61 + len(letters) > 0x80:
        raise SystemExit('too many letters')
    with open(sys.argv[2], 'w') as f:
        f.write('; made by tools/splitgen.py, do not edit\n')

        def rows(name, vals):
            f.write('%s:\n' % name)
            for i in range(0, len(vals), 16):
                f.write('\tdb\t%s\n' % ','.join('0%02Xh' % v for v in vals[i:i + 16]))
        rows('LAYERS', layer(16, far) + layer(24, hills) + layer(16, near))
        rows('GROUND', layer(16, ground))
        rows('LETTERS', [b for ch in letters for b in font[ord(ch) * 8:ord(ch) * 8 + 8]])
        f.write('NLETTERS\tequ\t%d\n' % len(letters))
        f.write('C_DOT\tequ\t0%02Xh\nC_STAR\tequ\t0%02Xh\n'
                % (0x61 + letters.index('.'), 0x61 + letters.index('*')))
        line = ' '.join(LOGO[0]).center(40)   # a letter every other wide cell
        rows('LOGO0', [0 if ch == ' ' else 0xB8 + BIGCODES.index(ch) for ch in line])
        line = LOGO[1].center(40)
        rows('LOGO1', [0 if ch == ' ' else 0x61 + letters.index(ch) for ch in line])
        # its glyphs' rows 0-7, then rows 8-15, as font RAM 2's two lists
        glyph = [([0] + [int(r.replace('#', '1').replace('.', '0'), 2) for r in BIG[ch]] + [0] * 16)[:16]
                 for ch in BIGCODES]
        rows('BIGTOP', [g[k] for g in glyph for k in range(8)])
        rows('BIGBOT', [g[k] for g in glyph for k in range(8, 16)])
        f.write('SCROLLTXT:\n')
        for i in range(0, len(SCROLL), 64):   # sjasmplus takes 128 bytes a DB
            f.write('\tdb\t"%s"\n' % SCROLL[i:i + 64])
        f.write('\tdb\t0\n')
        # rot16: RL of 16 cells' bytes, IX at the rightmost, the next
        # cell 8 bytes on the left; rot8: the same for a layer's 8 tiles
        f.write('rot16:\n')
        for n in range(16):
            f.write('\trl\t(ix-%d)\n' % (8 * n))
        f.write('\tret\nrot8:\n\tld\ta,(ix-56)\t; the leftmost tile\'s bit 7 goes round\n\trla\n')
        for n in range(8):
            f.write('\trl\t(ix-%d)\n' % (8 * n))
        f.write('\tret\n')
        # the finale: its lines, each the offset of its first cell
        # in a 92-wide screen and its text, centred, 0-ended
        f.write('FINALE:\n')
        for row, text in FINALE:
            f.write('\tdw\t%d\n\tdb\t"%s",0\n' % (row * 92 + (92 - len(text)) // 2, text))
        f.write('\tdw\t0FFFFh\n')
        bounce = [round(15.5 + 15.5 * math.sin(2 * math.pi * a / 256)) for a in range(256)]
        f.write('\talign\t256\n')
        rows('BOUNCE', bounce)


if __name__ == '__main__':
    main()
