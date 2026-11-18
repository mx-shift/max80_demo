#!/usr/bin/env python3
"""Make the demo's boot disk.

Usage: mkdisk.py demo.sys BUILDDIR OUT.imd [--525]

demo.sys is the boot sector and the program after it. The frame code,
BUILDDIR/pool.bin and bank0.bin to bank2.bin, then the real-time window
(win.bin and wintab.bin), follow it on the disk, each padded to whole
sectors, in the order src/boot.asm loads them. The disk
is diag's: one sided, 512-byte sectors numbered from 0, 8-inch FM with
77 tracks of 8 sectors, or with --525 MFM with 40 tracks of 9.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', '..', 'tools'))
from dmk2imd import write_imd  # noqa: E402

EIGHT = (77, 8, [i * 3 % 8 for i in range(8)])
FIVE = (40, 9, [i * 5 % 9 for i in range(9)])


def pad(b):
    return bytes(b) + b'\0' * (-len(b) % 512)


def main():
    args = sys.argv[1:]
    five = '--525' in args
    if five:
        args.remove('--525')
    if len(args) != 3:
        raise SystemExit(__doc__)
    tracks, spt, order = FIVE if five else EIGHT
    sysimg = bytearray(open(args[0], 'rb').read())
    sysimg[2] = spt                     # bspt in src/boot.asm
    disk = pad(sysimg)
    for name in ('pool', 'bank0', 'bank1', 'bank2'):
        disk += pad(open(os.path.join(args[1], name + '.bin'), 'rb').read())
    # the real-time window and its tables, page aligned after it
    win = open(os.path.join(args[1], 'win.bin'), 'rb').read()
    win += b'\0' * (-len(win) % 256)
    disk += pad(win + open(os.path.join(args[1], 'wintab.bin'), 'rb').read())
    size = tracks * spt * 512
    if len(disk) > size:
        raise SystemExit('the demo does not fit on the disk: %d of %d bytes' % (len(disk), size))
    disk += b'\xe5' * (size - len(disk))
    out = []
    for t in range(tracks):
        secs = []
        for r in order:
            off = (t * spt + r) * 512
            secs.append(dict(c=t, h=0, r=r, size=512, dd=five,
                             data=disk[off:off + 512], deleted=False, bad=False))
        out.append((t, 0, secs))
    write_imd(out, args[2], not five, os.path.basename(args[0]),
              tool='software/demo/tools/mkdisk.py')


if __name__ == '__main__':
    main()
