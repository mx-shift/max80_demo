#!/usr/bin/env python3
"""Turn 1-bit pictures into the Z80 code that races the beam.

Usage: racegen.py OUTDIR SEQUENCE

SEQUENCE is a text file, one shown picture a line: a P4 PBM of 160 x
216 dots and how many frames it shows, as `spin00.pbm 2`. A third field
names a second picture, shown in turn with the first, a frame each, for
twice the count: `greya.pbm 120 greyb.pbm`. A count is 1 to 127,
since its bit 7 marks a pair. Paths are
from the file's folder. The demo plays the lines in order.

On the MAX-80 a picture shows in 40 column mode, 20 cells 16 dots wide,
as 27 rows of 8 lines. Font RAM 1 holds two sets of 20 glyphs: set 0
is codes 00h-13h, set 1 is codes 20h-33h. Even rows show set 0, odd
rows set 1. While the beam draws row r, the code writes row r+1's 20
glyphs into the other set, 20 bytes a scan line, each line's code
started when the CRTC's display enable goes high. Row 0's glyphs are
written in the vertical blank.

A picture's code is 27 row blocks. Block 0 writes row 0 in the blank,
block r (1 to 26) writes row r during row r-1. A block is straight-line
code: LD SP into the font window, then the bytes as LD rr,nn and
PUSH rr, with HL, DE and BC holding the last three words so a repeated
word costs one PUSH. Every block ends with a JP that the vertical blank
points at the picture's next block (or FRAME_DONE), so a row that is
the same in two pictures in a bank is there once. Banks are at 8000h,
32K in A2 and B1, 16K in B2, whose top half is the real-time window's
(wingen.py). The blocks most pictures share, then the first
pictures' blocks, go to a pool in A1 at 3400h-6DFFh, which every bank
sees.

Writes OUTDIR/pool.bin, OUTDIR/bank0.bin to bank2.bin, OUTDIR/frames.inc (the equates)
and OUTDIR/frametab.inc (the pictures and the sequence), and prints
the sizes and the slowest scan line.
"""
import os
import sys

FONT = 0x7000           # the font window, block at 7000h
SYSFLG = 0x77E1
FRAME_DONE = 0x1003     # src/demo.asm's jump table
ORG = 0x8000
BANKS = (0x8000, 0x8000, 0x4000)    # B2 from C000h is the real-time window's
PIOS = (0x40, 0x80, 0xC0)
POOL, POOL_END = 0x3400, 0x6E00     # in A1, always there (src/hw.inc)
W, H = 20, 216          # bytes across, lines down
ROWS = H // 8

# A line is 320 T. With 40 characters shown, the display enable is high
# for the first 107 T of each line's 320, low for the rest. Each line's
# code starts on the rise, within a poll (29 T) of it, and must end in
# the low part of the same line: after 107 T, so the next poll waits for
# the next rise, and before 320 T less a poll. So at least LINE_MIN, and
# at most LINE_LIMIT with room for a stretch on its 20 font writes.
LINE_MIN = 150
LINE_LIMIT = 232


def read_pbm(path):
    data = open(path, 'rb').read()
    parts = data.split(maxsplit=3)
    if parts[0] != b'P4':
        raise SystemExit(path + ': not a P4 PBM')
    w, h = int(parts[1]), int(parts[2])
    if (w, h) != (W * 8, H):
        raise SystemExit('%s: %dx%d, want %dx%d' % (path, w, h, W * 8, H))
    bits = parts[3]
    return [bits[y * W:(y + 1) * W] for y in range(H)]


def region(img, r):
    """Row r's 20 glyphs as 160 bytes, glyph c row k at c * 8 + k"""
    return bytes(img[8 * r + k][c] for c in range(W) for k in range(8))


class Code:
    def __init__(self):
        self.b = bytearray()
        self.regs = {'HL': None, 'DE': None, 'BC': None}
        self.age = {'HL': 0, 'DE': 1, 'BC': 2}
        self.clock = 3

    def emit(self, *bs):
        self.b += bytes(bs)

    def word(self, op, v):
        self.emit(op, v & 0xff, v >> 8 & 0xff)    # past FFFFh: thrown away

    def push(self, v):
        """Push word v, returns its T-states"""
        LD = {'HL': 0x21, 'DE': 0x11, 'BC': 0x01}
        PUSH = {'HL': 0xE5, 'DE': 0xD5, 'BC': 0xC5}
        t = 11
        for r, have in self.regs.items():
            if have == v:
                break
        else:
            r = min(self.age, key=self.age.get)     # the oldest
            self.word(LD[r], v)
            self.regs[r] = v
            t += 10
        self.age[r] = self.clock
        self.clock += 1
        self.emit(PUSH[r])
        return t

    def write(self, addr, data):
        """LD SP,addr+len and the bytes down to addr, returns T-states"""
        self.word(0x31, addr + len(data))
        t = 10
        for o in range(len(data) - 2, -1, -2):
            t += self.push(data[o] | data[o + 1] << 8)
        return t

    def pad(self, t):
        """At least t T-states of nothing, returns them"""
        done = 0
        while t - done >= 12:
            self.emit(0x18, 0x00)       # JR $+2, 12 T
            done += 12
        while done < t:
            self.emit(0x00)             # NOP, 4 T
            done += 4
        return done

    def poll(self, org):
        """Loop while the display enable is low. The code sits at org"""
        top = org + len(self.b)
        self.word(0x3A, SYSFLG)         # LD A,(SYSFLG)
        self.emit(0x87)                 # ADD A,A: bit 6 to the sign
        self.word(0xF2, top)            # JP P


def block_code(r, reg, org):
    """Row r's block at org: code, the address of its JP's operand, and
    its slowest line in T-states"""
    c = Code()
    worst = 0
    if r == 0:
        c.write(FONT, reg)              # set 0, in the vertical blank
    else:
        base = FONT + (r & 1) * 0x100
        for j in range(8):
            c.poll(org)                 # line 8(r-1)+j's picture starts
            t = c.write(base + 20 * j, reg[20 * j:20 * j + 20])
            if j == 7:
                t += 10                 # and the JP
            t += c.pad(LINE_MIN - t)
            worst = max(worst, t)
    c.word(0xC3, FRAME_DONE)            # pointed at the next block
    return bytes(c.b), org + len(c.b) - 2, worst


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    out, seqpath = sys.argv[1], sys.argv[2]
    here = os.path.dirname(seqpath)
    seq = []
    for line in open(seqpath):
        line = line.split('#')[0].split()
        if line:
            partner = os.path.join(here, line[2]) if len(line) > 2 else None
            seq.append((os.path.join(here, line[0]), int(line[1]), partner))

    pictures = []                       # paths in first-shown order, a
    for p, _, partner in seq:           # partner right after its picture
        if p not in pictures:
            pictures.append(p)
            if partner:
                pictures.append(partner)
        if partner and pictures.index(partner) != pictures.index(p) + 1:
            raise SystemExit('%s must follow %s' % (partner, p))

    imgs = {}
    for p in pictures:
        img = read_pbm(p)
        imgs[p] = [region(img, r) for r in range(ROWS)]

    # the pool: the most shared blocks, then in the order first shown
    uses, order = {}, []
    for p in pictures:
        for r in range(ROWS):
            key = (r, imgs[p][r])
            if key not in uses:
                order.append(key)
            uses[key] = uses.get(key, 0) + 1
    pool = bytearray()
    pooled = {}
    worst = 0
    for key in sorted(order, key=lambda k: -uses[k] if uses[k] > 1 else 0):
        code, jp, t = block_code(key[0], key[1], POOL + len(pool))
        if POOL + len(pool) + len(code) > POOL_END:
            continue
        pooled[key] = (POOL + len(pool), jp)
        worst = max(worst, t)
        pool += code

    banks = [bytearray() for _ in PIOS]
    placed = [dict(pooled) for _ in PIOS]   # (r, region) -> (start, jp operand)
    frames = []                         # (pio, [(start, jp operand)] x 27)
    b = 0
    for p in pictures:
        regs = imgs[p]
        while True:
            if b == len(banks):
                raise SystemExit('the pictures do not fit in 96K, %d placed' % len(frames))
            new = bytearray()
            got = {}
            for r in range(ROWS):
                key = (r, regs[r])
                if key in placed[b] or key in got:
                    continue
                org = ORG + len(banks[b]) + len(new)
                code, jp, t = block_code(r, regs[r], org)
                worst = max(worst, t)
                got[key] = (org, jp)
                new += code
            if len(banks[b]) + len(new) <= BANKS[b]:
                break
            b += 1
        banks[b] += new
        placed[b].update(got)
        frames.append((PIOS[b], [placed[b][(r, regs[r])] for r in range(ROWS)]))

    if worst > LINE_LIMIT:
        raise SystemExit('a scan line takes %d T, over %d' % (worst, LINE_LIMIT))
    os.makedirs(out, exist_ok=True)
    for i, bank in enumerate(banks):
        open(os.path.join(out, 'bank%d.bin' % i), 'wb').write(bank)
    open(os.path.join(out, 'pool.bin'), 'wb').write(pool)
    with open(os.path.join(out, 'frames.inc'), 'w') as f:
        f.write('; made by tools/racegen.py, do not edit\n')
        f.write('NPICS\tequ\t%d\n' % len(frames))
        f.write('NSEQ\tequ\t%d\n' % len(seq))
        f.write('NROWS\tequ\t%d\n' % ROWS)
        f.write('PICSIZE\tequ\t%d\n' % (3 + 4 * ROWS))
        f.write('POOL\tequ\t0%04Xh\n' % POOL)
        f.write('POOL_END\tequ\t0%04Xh\n' % POOL_END)
        f.write('SEC_POOL\tequ\t%d\n' % ((len(pool) + 511) // 512))
        for i, bank in enumerate(banks):
            f.write('SEC_%s\tequ\t%d\n' % (('A2', 'B1', 'B2')[i], (len(bank) + 511) // 512))
    with open(os.path.join(out, 'frametab.inc'), 'w') as f:
        f.write('; made by tools/racegen.py, do not edit\n')
        f.write('; a picture: its bank, where it starts, then for each row\n')
        f.write('; block the address of its JP operand and where it jumps:\n')
        f.write('; the next block, the last to FRAME_DONE\n')
        for i, (pio, blocks) in enumerate(frames):
            f.write('pic%d:\tdb\t0%02Xh\n\tdw\t0%04Xh\n' % (i, pio, blocks[0][0]))
            for r in range(ROWS):
                nxt = blocks[r + 1][0] if r + 1 < ROWS else FRAME_DONE
                f.write('\tdw\t0%04Xh,0%04Xh\n' % (blocks[r][1], nxt))
        f.write('; the sequence: a picture and the frames it shows\n')
        f.write('seqtab:\n')
        for p, hold, partner in seq:
            if not 0 < hold < 128:      # bit 7 of the count marks a pair
                raise SystemExit('a line shows 1 to 127 frames, or a pair 1 to 127 rounds')
            f.write('\tdw\tpic%d\n\tdb\t0%02Xh\n' % (pictures.index(p), hold | (0x80 if partner else 0)))
    sizes = ', '.join('%d' % len(x) for x in banks)
    print('%d pictures, %d shown, pool %d, banks %s bytes, slowest line %d T'
          % (len(frames), len(seq), len(pool), sizes, worst))


if __name__ == '__main__':
    main()
